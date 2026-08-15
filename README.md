# FacePulseEngine

FacePulseEngine is a high-performance Python-based computer vision & remote photoplethysmography (rPPG) engine for real-time heart rate estimation, face tracking HUD visual debugging, and FastAPI measurement streaming.

## Features
- **Real-Time rPPG Signal Processor**: POS algorithm with Butterworth bandpass filtering, Welch PSD, harmonic peak guarding, and temporal EMA smoothing.
- **MediaPipe Face Tracking**: Face landmark extraction, 2D forehead and cheek polygon ROI extraction, and quality gate metrics (yaw, pitch, roll, coverage ratio, luminance Y channel).
- **Cybernetic Visual Debugger**: OpenCV visual debugger with smoothed bio-wireframe mesh, corner tracking reticles, and telemetry HUD overlays.
- **FastAPI Measurement Backend Server**: Endpoints for per-frame raw rPPG streaming (`/ws/raw-rppg-stream`), HTTP batch processing (`/api/v1/rppg/raw-batch`), and periodic JSON measurement push (`POST /api/v1/measurements`).

## Project Structure
- `mock_backend_receiver.py`: FastAPI server for rPPG streaming & measurement ingestion.
- `schemas.py`: Pydantic schemas and validation for rPPG metrics and measurement requests.
- `rppg_processor.py`: Core POS rPPG pulse extraction & signal processing algorithms.
- `face_feature_extractor.py`: MediaPipe Face Landmarker & quality gate evaluator.
- `face_tracker.py`: FaceMeshTracker subclass module.
- `visual_debugger.py`: OpenCV real-time face HUD visualizer.
- `stream_producer.py`: Stream producer client for video frames.
- `test_engine.py`: Comprehensive Python unit and integration test suite.
- `models/`: Pre-trained face landmarker and rPPG neural net model files.

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run Python Unit & Endpoint Test Suite
```bash
python test_engine.py
```

### 3. Start FastAPI Receiver Server
```bash
python mock_backend_receiver.py
```

### 4. Run OpenCV Real-Time Face HUD Debugger
```bash
python visual_debugger.py --test-mode
```
