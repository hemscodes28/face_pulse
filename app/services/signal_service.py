import math
from typing import Dict, List, Optional, Any
from collections import defaultdict

# ─── Configuration & Thresholds ──────────────────────────────
# SNR Classification Thresholds (dB)
SNR_THRESHOLDS = {
    "EXCELLENT": 2.0,    # snr_db >= 2.0
    "GOOD": -1.0,        # -1.0 <= snr_db < 2.0
    "FAIR": -4.0,        # -4.0 <= snr_db < -1.0
    # < -4.0 is POOR
}

# Luminance Classification Thresholds (0 - 255)
LUMINANCE_THRESHOLDS = {
    "TOO_DARK": 45.0,    # luminance < 45.0
    "TOO_BRIGHT": 215.0  # luminance > 215.0
}

# Rolling observation buffers per session_id
session_buffers: Dict[str, List[Dict[str, Any]]] = defaultdict(list)


def classify_snr(snr_db: float) -> str:
    """
    Classifies raw SNR (dB) into clinical/signal quality level:
    EXCELLENT, GOOD, FAIR, or POOR.
    """
    if snr_db >= SNR_THRESHOLDS["EXCELLENT"]:
        return "EXCELLENT"
    elif snr_db >= SNR_THRESHOLDS["GOOD"]:
        return "GOOD"
    elif snr_db >= SNR_THRESHOLDS["FAIR"]:
        return "FAIR"
    else:
        return "POOR"


def classify_luminance(luminance: float) -> str:
    """
    Classifies video frame luminance into:
    TOO_DARK, GOOD, or TOO_BRIGHT.
    """
    if luminance < LUMINANCE_THRESHOLDS["TOO_DARK"]:
        return "TOO_DARK"
    elif luminance > LUMINANCE_THRESHOLDS["TOO_BRIGHT"]:
        return "TOO_BRIGHT"
    else:
        return "GOOD"


def get_recommendation(snr_quality: str, video_quality: str) -> str:
    """
    Generates actionable user guidance with strict priority:
    1. Poor luminance (TOO_DARK / TOO_BRIGHT)
    2. Poor SNR / Signal stability (POOR / FAIR)
    3. Good conditions
    """
    # Priority 1: Luminance
    if video_quality == "TOO_DARK":
        return "Move to a brighter area"
    if video_quality == "TOO_BRIGHT":
        return "Avoid direct bright light or glare"

    # Priority 2: SNR / Signal Quality
    if snr_quality == "POOR":
        return "Hold your face steady and look directly at camera"
    if snr_quality == "FAIR":
        return "Minimize head movement for clearer signal"

    # Priority 3: Optimal
    return "Good conditions. Continue scanning."


def add_observation(session_id: str, obs: Dict[str, Any]) -> Dict[str, Any]:
    """
    Appends an observation to the session's rolling buffer and returns
    the enriched/processed live metrics.
    """
    bpm = float(obs.get("bpm", 0.0))
    snr_db = float(obs.get("snr_db", 0.0))
    luminance = float(obs.get("luminance", 0.0))
    frame_status = str(obs.get("status", "OK"))
    
    snr_quality = classify_snr(snr_db)
    video_quality = classify_luminance(luminance)
    recommendation = get_recommendation(snr_quality, video_quality)
    
    enriched = {
        "bpm": round(bpm, 1),
        "snr_db": round(snr_db, 2),
        "signal_quality": snr_quality,
        "luminance": round(luminance, 1),
        "video_quality": video_quality,
        "recommendation": recommendation,
        "frame": obs.get("frame") or obs.get("frame_number"),
        "status": frame_status
    }
    
    session_buffers[session_id].append(enriched)
    return enriched


def calculate_hrv_sdnn(bpms: List[float]) -> float:
    """
    Mathematically computes Heart Rate Variability (SDNN in ms)
    directly from the sequence of observed BPM values.
    IBI_i (ms) = 60,000 / BPM_i
    SDNN = sqrt( 1/N * sum((IBI_i - mean_IBI)^2) )
    """
    if len(bpms) < 2:
        return 0.0
        
    ibis = [60000.0 / bpm for bpm in bpms if bpm > 0]
    if len(ibis) < 2:
        return 0.0
        
    mean_ibi = sum(ibis) / len(ibis)
    variance = sum((ibi - mean_ibi) ** 2 for ibi in ibis) / len(ibis)
    sdnn = math.sqrt(variance)
    return round(sdnn, 1)


def get_hr_zone(bpm: float) -> str:
    """
    Classifies heart rate into physiological zones.
    """
    if bpm < 60:
        return "Bradycardia / Deep Rest"
    elif bpm <= 100:
        return "Normal Resting Zone"
    elif bpm <= 120:
        return "Mild Tachycardia / Elevated"
    else:
        return "High Cardiac Zone"


def get_stress_level(hrv_ms: float) -> str:
    """
    Computes Autonomic Nervous System (ANS) stress index from HRV (SDNN).
    """
    if hrv_ms >= 50.0:
        return "Low (High Parasympathetic Tone)"
    elif hrv_ms >= 30.0:
        return "Balanced / Moderate"
    elif hrv_ms > 0:
        return "Elevated Sympathetic Tone"
    return "Assessing"


def get_session_metrics(session_id: str) -> Dict[str, Any]:
    """
    Aggregates all observations in the buffer to compute:
    - current_bpm, average_bpm, min_bpm, max_bpm, hr_range
    - hrv_ms (SDNN) & stress_index (100% computed from real BPM variation)
    - bpm_trend (list of values over time)
    - avg_snr_db, signal_quality
    - avg_luminance, video_quality
    - detailed interpretations: luminance_suggestion, snr_suggestion, frame_suggestion, rescan_recommended
    - hr_zone & overall recommendation
    """
    buf = session_buffers.get(session_id, [])
    if not buf:
        return {
            "current_bpm": 0.0,
            "average_bpm": 0.0,
            "min_bpm": 0.0,
            "max_bpm": 0.0,
            "hr_range": 0.0,
            "hrv_ms": 0.0,
            "hr_zone": "Normal Resting Zone",
            "stress_index": "Normal",
            "bpm_trend": [],
            "avg_snr_db": 0.0,
            "signal_quality": "POOR",
            "avg_luminance": 0.0,
            "video_quality": "TOO_DARK",
            "recommendation": "No signal data recorded",
            "total_frames": 0,
            "interpretations": {
                "luminance_suggestion": "No video feed recorded.",
                "snr_suggestion": "No pulse signal recorded.",
                "frame_suggestion": "No frames received.",
                "rescan_recommended": True,
                "rescan_reason": "No frame data was received during this scan session.",
                "cardiac_status": "Unknown"
            }
        }
        
    bpms = [item["bpm"] for item in buf if item["bpm"] > 0]
    snrs = [item["snr_db"] for item in buf]
    lums = [item["luminance"] for item in buf]
    statuses = [item["status"] for item in buf]
    
    avg_bpm = round(sum(bpms) / len(bpms), 1) if bpms else 0.0
    min_bpm = round(min(bpms), 1) if bpms else 0.0
    max_bpm = round(max(bpms), 1) if bpms else 0.0
    current_bpm = bpms[-1] if bpms else 0.0
    hr_range = round(max_bpm - min_bpm, 1)
    
    hrv_ms = calculate_hrv_sdnn(bpms)
    hr_zone = get_hr_zone(avg_bpm)
    stress_index = get_stress_level(hrv_ms)
    
    avg_snr = round(sum(snrs) / len(snrs), 2) if snrs else 0.0
    avg_lum = round(sum(lums) / len(lums), 1) if lums else 0.0
    
    final_snr_quality = classify_snr(avg_snr)
    final_video_quality = classify_luminance(avg_lum)
    final_rec = get_recommendation(final_snr_quality, final_video_quality)
    
    # ── Detailed Interpretations ──────────────────────────
    # 1. Luminance Interpretation
    if final_video_quality == "TOO_DARK":
        lum_sugg = f"Lighting was dim (avg {avg_lum:.1f} Y < 45). Please scan in a brighter room or face a soft lamp."
    elif final_video_quality == "TOO_BRIGHT":
        lum_sugg = f"Overexposed lighting (avg {avg_lum:.1f} Y > 215). Please reduce harsh backlighting or glare."
    else:
        lum_sugg = f"Optimal facial illumination (avg {avg_lum:.1f} Y). High optical absorption contrast."

    # 2. SNR Suggestion
    if final_snr_quality == "EXCELLENT":
        snr_sugg = f"Excellent optical SNR ({avg_snr:+.1f} dB). Sharp pulsatile waveform with minimal noise."
    elif final_snr_quality == "GOOD":
        snr_sugg = f"Good optical SNR ({avg_snr:+.1f} dB). Physiological pulse peaks clearly disambiguated."
    elif final_snr_quality == "FAIR":
        snr_sugg = f"Fair optical SNR ({avg_snr:+.1f} dB). Moderate noise. Keep head still during future scans."
    else:
        snr_sugg = f"Poor optical SNR ({avg_snr:+.1f} dB). High noise interference detected in signal buffer."

    # 3. Frame / Face Tracking Suggestion
    bad_frames = [s for s in statuses if s not in ["OK", "GOOD"]]
    bad_ratio = len(bad_frames) / len(statuses) if statuses else 0.0
    if bad_ratio > 0.3:
        frame_sugg = f"Intermittent tracking ({int(bad_ratio*100)}% non-optimal frames). Keep face directly centered."
    else:
        frame_sugg = "Face tracking remained centered and stable throughout the 40-second scan window."

    # 4. Rescan Recommendation Determination
    rescan_recommended = False
    rescan_reasons = []
    if final_snr_quality == "POOR" or avg_snr < -3.5:
        rescan_recommended = True
        rescan_reasons.append("low signal-to-noise ratio")
    if final_video_quality in ["TOO_DARK", "TOO_BRIGHT"]:
        rescan_recommended = True
        rescan_reasons.append("sub-optimal ambient lighting")
    if bad_ratio > 0.4:
        rescan_recommended = True
        rescan_reasons.append("frequent head movement")

    rescan_reason_text = f"Recommended to retake scan due to {', '.join(rescan_reasons)}." if rescan_recommended else None

    # 5. Cardiac Interpretation
    if 60 <= avg_bpm <= 100:
        cardiac_status = "Normal resting heart rate within typical healthy adult baseline (60 - 100 BPM)."
    elif avg_bpm < 60:
        cardiac_status = "Resting rate indicates bradycardia or high athletic conditioning (< 60 BPM)."
    else:
        cardiac_status = "Elevated resting heart rate above typical baseline (> 100 BPM)."

    interpretations = {
        "luminance_suggestion": lum_sugg,
        "snr_suggestion": snr_sugg,
        "frame_suggestion": frame_sugg,
        "rescan_recommended": rescan_recommended,
        "rescan_reason": rescan_reason_text,
        "cardiac_status": cardiac_status
    }

    return {
        "current_bpm": current_bpm,
        "average_bpm": avg_bpm,
        "min_bpm": min_bpm,
        "max_bpm": max_bpm,
        "hr_range": hr_range,
        "hrv_ms": hrv_ms,
        "hr_zone": hr_zone,
        "stress_index": stress_index,
        "bpm_trend": bpms,
        "avg_snr_db": avg_snr,
        "signal_quality": final_snr_quality,
        "avg_luminance": avg_lum,
        "video_quality": final_video_quality,
        "recommendation": final_rec,
        "total_frames": len(buf),
        "interpretations": interpretations
    }


def clear_session(session_id: str):
    """
    Cleans up memory buffer for a finished session.
    """
    if session_id in session_buffers:
        del session_buffers[session_id]
