"""
rPPG Mathematical Signal Processor Core
Implements Plane-Orthogonal-to-Skin (POS) algorithm, zero-phase Butterworth filtering,
2048-FFT Welch PSD estimation with Prioritized Passband Peak Picking,
Sub-Peak Disambiguation, Non-creeping Velocity Limiting, Buffer Integrity Guarding, and Exponential Smoothing.
"""

import logging
import time
import numpy as np
from scipy import signal as scipy_signal
from typing import Dict, List, Optional, Tuple, Union

from schemas import ProcessedRPPGMetrics, QualityStatus

logger = logging.getLogger("RPPGSignalProcessor")


class RPPGSignalProcessor:
    """
    Real-time rPPG Signal Processor using POS algorithm, Welch PSD Spectral Analysis,
    Prioritized Passband Peak Picking, Sub-Peak Disambiguation, Non-creeping Velocity Limiter,
    Buffer Integrity Guard, and Exponential Smoothing.
    """

    def __init__(
        self,
        buffer_size: int = 240,
        fs: float = 30.0,
        low_cutoff: float = 0.75,
        high_cutoff: float = 3.0,
        filter_order: int = 4,
        snr_half_bandwidth: float = 0.15,
        min_samples_for_dsp: int = 180,  # 180 samples (6 seconds @ 30 FPS)
        ema_alpha: float = 0.10,         # 0.10 * target_bpm + 0.90 * smoothed_bpm
        max_bpm_delta: float = 12.0,      # Delta clamp threshold for velocity limiter
        max_step_per_frame: float = 2.0, # Maximum BPM delta step per frame update
    ) -> None:
        """
        Initialize the rPPG signal processor.

        :param buffer_size: Circular buffer length N (240 samples = 8s @ 30 FPS).
        :param fs: Sampling frequency in Hz (default 30.0 FPS).
        :param low_cutoff: Minimum pulse frequency in Hz (0.75 Hz = 45 BPM).
        :param high_cutoff: Maximum pulse frequency in Hz (3.0 Hz = 180 BPM).
        :param filter_order: Order of the Butterworth bandpass filter.
        :param snr_half_bandwidth: Delta frequency (+/- Hz) around peak for SNR calculation.
        :param min_samples_for_dsp: Minimum samples required for DSP (default 180).
        :param ema_alpha: Exponential moving average factor (default 0.10).
        :param max_bpm_delta: Maximum delta before velocity limiter clamps.
        :param max_step_per_frame: Maximum step per frame update when clamped.
        """
        self.buffer_size = buffer_size
        self.fs = fs
        self.low_cutoff = low_cutoff
        self.high_cutoff = high_cutoff
        self.filter_order = filter_order
        self.snr_half_bandwidth = snr_half_bandwidth
        self.min_samples_for_dsp = min_samples_for_dsp
        self.ema_alpha = ema_alpha
        self.max_bpm_delta = max_bpm_delta
        self.max_step_per_frame = max_step_per_frame

        # Circular temporal buffers for R, G, B mean values
        self._r_buffer: List[float] = []
        self._g_buffer: List[float] = []
        self._b_buffer: List[float] = []

        # SOS Butterworth Filter Coefficients
        self._sos = scipy_signal.butter(
            N=self.filter_order,
            Wn=[self.low_cutoff, self.high_cutoff],
            btype="bandpass",
            fs=self.fs,
            output="sos",
        )

        # Velocity Limiter & Tracking State
        self.last_valid_bpm: Optional[float] = None
        self.smoothed_bpm: float = 0.0
        self._consecutive_candidate_bpm: Optional[float] = None
        self._consecutive_count: int = 0

        # Latest metrics cache
        self.latest_raw_bpm: float = 0.0
        self.latest_snr_db: float = 0.0
        self.latest_quality: float = 0.0
        self.latest_pulse_signal: List[float] = []

    def reset_buffers(self) -> None:
        """Clears the temporal circular RGB buffers to protect buffer integrity."""
        self._r_buffer.clear()
        self._g_buffer.clear()
        self._b_buffer.clear()

    def reset(self) -> None:
        """Reset internal circular temporal buffers and filter tracking states."""
        self.reset_buffers()
        self.last_valid_bpm = None
        self.smoothed_bpm = 0.0
        self._consecutive_candidate_bpm = None
        self._consecutive_count = 0
        self.latest_raw_bpm = 0.0
        self.latest_snr_db = 0.0
        self.latest_quality = 0.0
        self.latest_pulse_signal.clear()

    def update(
        self,
        r: float,
        g: float,
        b: float,
        timestamp: Optional[float] = None,
        status: QualityStatus = QualityStatus.OK,
    ) -> ProcessedRPPGMetrics:
        """
        Append a new frame's spatial RGB mean values and update rPPG pulse estimate.

        :param r: Mean Red channel value.
        :param g: Mean Green channel value.
        :param b: Mean Blue channel value.
        :param timestamp: Frame timestamp (defaults to current time if None).
        :param status: Quality gate status of current frame.
        :return: ProcessedRPPGMetrics containing updated BPM, SNR, waveform, and status.
        """
        if timestamp is None:
            timestamp = time.time()

        # 2. Buffer Integrity Guard: If status != QualityStatus.OK, do not append noisy/zero RGB values.
        if status != QualityStatus.OK:
            if status == QualityStatus.NO_FACE:
                self.reset_buffers()
            self.latest_quality = max(0.0, self.latest_quality * 0.9)
            return ProcessedRPPGMetrics(
                timestamp=timestamp,
                bpm=round(self.smoothed_bpm, 1),
                snr_db=round(self.latest_snr_db, 2),
                signal_quality=round(self.latest_quality, 2),
                status=status,
                pulse_waveform=[round(x, 4) for x in self.latest_pulse_signal[-60:]],
            )

        # Update circular temporal buffer for valid OK frames
        self._r_buffer.append(r)
        self._g_buffer.append(g)
        self._b_buffer.append(b)

        # Trim buffer to fixed rolling window length N
        if len(self._r_buffer) > self.buffer_size:
            self._r_buffer.pop(0)
            self._g_buffer.pop(0)
            self._b_buffer.pop(0)

        # 1. Hard Buffer Guard: If buffer has fewer than 180 valid frames (~6s), return BPM = 0.0 and SNR = 0.0 immediately
        if len(self._r_buffer) < self.min_samples_for_dsp:
            return ProcessedRPPGMetrics(
                timestamp=timestamp,
                bpm=0.0,
                snr_db=0.0,
                signal_quality=0.0,
                status=status,
                pulse_waveform=[],
            )

        # Process valid buffer
        raw_bpm, snr_db, signal_quality, filtered_h = self.process_buffers()
        self.latest_raw_bpm = raw_bpm
        self.latest_snr_db = snr_db
        self.latest_pulse_signal = filtered_h.tolist()

        # 3. History-Based Velocity Limiter (Prevent Creep on Isolated Noise)
        if self.last_valid_bpm is None or self.last_valid_bpm == 0.0:
            target_bpm = raw_bpm
            self.last_valid_bpm = raw_bpm
            self._consecutive_candidate_bpm = None
            self._consecutive_count = 0
        else:
            bpm_diff = raw_bpm - self.last_valid_bpm
            if abs(bpm_diff) > self.max_bpm_delta:
                # Check 3-frame consecutive agreement for genuine shifts
                if (
                    self._consecutive_candidate_bpm is not None
                    and abs(raw_bpm - self._consecutive_candidate_bpm) <= 5.0
                ):
                    self._consecutive_count += 1
                else:
                    self._consecutive_candidate_bpm = raw_bpm
                    self._consecutive_count = 1

                if self._consecutive_count >= 3:
                    target_bpm = raw_bpm
                    self.last_valid_bpm = raw_bpm
                    self._consecutive_candidate_bpm = None
                    self._consecutive_count = 0
                    logger.info(f"BPM range shift verified after 3 consecutive frames: {raw_bpm:.1f} BPM")
                else:
                    # Clamp output target_bpm, but DO NOT update self.last_valid_bpm to prevent creep!
                    clamped_step = float(np.clip(bpm_diff, -self.max_step_per_frame, self.max_step_per_frame))
                    target_bpm = self.last_valid_bpm + clamped_step
                    # self.last_valid_bpm remains unchanged to prevent creep on noisy frames!
            else:
                self._consecutive_candidate_bpm = None
                self._consecutive_count = 0
                target_bpm = raw_bpm
                self.last_valid_bpm = raw_bpm

        # 4. Exponential Smoothing: self.smoothed_bpm = 0.10 * target_bpm + 0.90 * self.smoothed_bpm
        if self.smoothed_bpm == 0.0:
            self.smoothed_bpm = target_bpm
        else:
            self.smoothed_bpm = self.ema_alpha * target_bpm + (1.0 - self.ema_alpha) * self.smoothed_bpm

        self.latest_quality = signal_quality

        return ProcessedRPPGMetrics(
            timestamp=timestamp,
            bpm=round(self.smoothed_bpm, 1),
            snr_db=round(self.latest_snr_db, 2),
            signal_quality=round(self.latest_quality, 2),
            status=status,
            pulse_waveform=[round(x, 4) for x in self.latest_pulse_signal[-60:]],
        )

    def process_buffers(self) -> Tuple[float, float, float, np.ndarray]:
        """
        Runs POS algorithm, Bandpass filter, and Welch Spectral analysis on temporal buffers.

        :return: Tuple of (raw_bpm, snr_db, signal_quality, filtered_pulse_array).
        """
        r_arr = np.array(self._r_buffer, dtype=np.float64)
        g_arr = np.array(self._g_buffer, dtype=np.float64)
        b_arr = np.array(self._b_buffer, dtype=np.float64)

        # 1. POS Algorithm (Plane-Orthogonal-to-Skin)
        h_raw = self.compute_pos(r_arr, g_arr, b_arr)

        # 2. 4th-Order Zero-Phase Butterworth Bandpass Filter
        filtered_h = self.apply_bandpass(h_raw)

        # 3. Prioritized Passband Spectral Analysis
        raw_bpm, snr_db, quality = self.spectral_analysis(filtered_h)

        return raw_bpm, snr_db, quality, filtered_h

    def compute_pos(self, r: np.ndarray, g: np.ndarray, b: np.ndarray) -> np.ndarray:
        """
        Computes POS (Plane-Orthogonal-to-Skin) pulse signal H(t).
        """
        mean_r = np.mean(r) + 1e-7
        mean_g = np.mean(g) + 1e-7
        mean_b = np.mean(b) + 1e-7

        r_n = (r / mean_r) - 1.0
        g_n = (g / mean_g) - 1.0
        b_n = (b / mean_b) - 1.0

        s1 = g_n - b_n
        s2 = g_n + b_n - 2.0 * r_n

        std_s1 = np.std(s1)
        std_s2 = np.std(s2)
        epsilon = 1e-7

        alpha = std_s1 / (std_s2 + epsilon)
        h = s1 + alpha * s2

        return h

    def apply_bandpass(self, signal_arr: np.ndarray) -> np.ndarray:
        """
        Applies a 4th-order zero-phase Butterworth Bandpass filter (0.75 Hz to 3.0 Hz).
        """
        n_samples = len(signal_arr)
        pad_len = min(n_samples - 1, 3 * self.filter_order)
        if pad_len < 1:
            return signal_arr

        try:
            filtered = scipy_signal.sosfiltfilt(self._sos, signal_arr, padlen=pad_len)
            return filtered
        except Exception:
            return scipy_signal.sosfilt(self._sos, signal_arr)

    def spectral_analysis(self, filtered_signal: np.ndarray) -> Tuple[float, float, float]:
        """
        Prioritized Passband Peak Picking:
        - Run Welch PSD with nperseg=len(signal) and nfft=2048 for fs=30.0 directly on filtered_signal.
          (No double windowing with np.hanning).
        - Search for local peaks strictly within [0.75 Hz, 3.0 Hz] (45 to 180 BPM).
        - Human Resting Bias: Evaluate peaks between [0.9 Hz, 1.8 Hz] (54 to 108 BPM) first.
        - Sub-peak check: If f_high is selected, check for sub-peak at f_high / 2 (+/- 0.2 Hz) with >= 25% power.

        :param filtered_signal: 1D bandpass filtered rPPG signal array.
        :return: Tuple (raw_bpm, snr_db, signal_quality).
        """
        n_samples = len(filtered_signal)

        # 1. Remove Double Windowing: Pass filtered_signal directly into scipy_signal.welch
        freqs, psd = scipy_signal.welch(
            filtered_signal,
            fs=self.fs,
            nperseg=n_samples,
            nfft=2048,
            scaling="density",
        )

        # Filter PSD strictly within passband [0.75, 3.0] Hz (45 to 180 BPM)
        valid_idx = np.where((freqs >= self.low_cutoff) & (freqs <= self.high_cutoff))[0]

        if len(valid_idx) == 0:
            return 0.0, 0.0, 0.0

        band_freqs = freqs[valid_idx]
        band_psd = psd[valid_idx]

        max_power = np.max(band_psd)
        peak_indices, _ = scipy_signal.find_peaks(band_psd, height=max_power * 0.15)

        if len(peak_indices) == 0:
            highest_sub_idx = np.argmax(band_psd)
            peak_indices = np.array([highest_sub_idx])

        # Highest power peak overall
        highest_sub_idx = peak_indices[np.argmax(band_psd[peak_indices])]
        f_high = band_freqs[highest_sub_idx]
        p_high = band_psd[highest_sub_idx]

        # Human Resting Bias: evaluate peaks between [0.9 Hz, 1.8 Hz] (54 to 108 BPM) first
        resting_peaks = [idx for idx in peak_indices if 0.9 <= band_freqs[idx] <= 1.8]

        chosen_f = f_high
        sub_peak_found = False

        # Sub-peak check: if f_high is selected (or > 1.8 Hz), check for sub-peak at f_high / 2 (+/- 0.2 Hz) with >= 25% power
        f_sub_target = f_high / 2.0
        for idx in peak_indices:
            f_p = band_freqs[idx]
            p_p = band_psd[idx]
            if abs(f_p - f_sub_target) <= 0.2 and p_p >= 0.25 * p_high:
                logger.debug(
                    f"Sub-peak selected: {f_p*60.0:.1f} BPM (power ratio {p_p/p_high:.2f}) at f_high/2 of {f_high*60.0:.1f} BPM"
                )
                chosen_f = f_p
                sub_peak_found = True
                break

        if not sub_peak_found and len(resting_peaks) > 0:
            best_rest_idx = resting_peaks[np.argmax(band_psd[resting_peaks])]
            p_rest = band_psd[best_rest_idx]
            f_rest = band_freqs[best_rest_idx]
            # Prioritize resting range peak if it has >= 25% of highest power
            if f_high > 1.8 or p_rest >= 0.25 * p_high:
                chosen_f = f_rest

        raw_bpm = chosen_f * 60.0

        # Compute Signal-to-Noise Ratio (SNR) in dB around chosen_f
        peak_band_mask = (band_freqs >= chosen_f - self.snr_half_bandwidth) & (
            band_freqs <= chosen_f + self.snr_half_bandwidth
        )

        signal_power = np.sum(band_psd[peak_band_mask])
        total_passband_power = np.sum(band_psd)
        noise_power = total_passband_power - signal_power

        epsilon = 1e-7
        if noise_power <= 0:
            snr_db = 15.0
        else:
            snr_ratio = signal_power / (noise_power + epsilon)
            snr_db = 10.0 * np.log10(max(snr_ratio, 1e-3))

        snr_db = float(np.clip(snr_db, -10.0, 25.0))
        quality_score = float(np.clip((snr_db + 5.0) / 20.0, 0.0, 1.0))

        return float(raw_bpm), float(snr_db), float(quality_score)
