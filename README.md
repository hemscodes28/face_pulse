# Face Pulse

Real-time Mobile rPPG Vital Measurement & Facial HUD Tracking application built with Flutter and Python FastAPI backend engine.

## Features
- Real-time rPPG pulse extraction & heart rate measurement
- Cybernetic face-tracking HUD overlay (forehead & cheeks tracking)
- Asynchronous periodic JSON measurement push (`POST /api/v1/measurements`)
- Cross-platform support (Android, iOS, Web, Desktop)

## Getting Started
1. Run backend server: `python mock_backend_receiver.py`
2. Run Flutter app: `flutter run`
