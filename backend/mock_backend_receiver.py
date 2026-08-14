"""
Mock Backend Receiver for TS-CAN Mobile (backend/mock_backend_receiver.py)
FastAPI application providing WebSocket endpoint `/ws/raw-rppg-stream`
and HTTP batch endpoint `/api/v1/rppg/raw-batch`.
Receives derived pulse metrics / frame metadata from edge TS-CAN client and logs live heart rate.
"""

import logging
from typing import Dict
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError

from backend.schemas import ProcessedRPPGMetrics, QualityStatus, RawRPPGBatch, RawRPPGFrame

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("MockBackendReceiver")

app = FastAPI(
    title="TS-CAN Mobile Backend Receiver",
    description="FastAPI WebSocket and HTTP Batch Backend Receiver for derived TS-CAN rPPG metrics.",
    version="2.0.0",
)

# Enable CORS for web and Flutter frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "TS-CAN Mobile Backend Receiver", "model": "TS-CAN"}


@app.get("/api/v1/rppg/status")
def get_status():
    """Returns server status info."""
    return {
        "status": "online",
        "pipeline": "TS-CAN On-Device Inference",
        "privacy": "Zero raw video stream to backend",
    }


@app.websocket("/ws/raw-rppg-stream")
async def websocket_rppg_stream(websocket: WebSocket):
    """
    Real-time WebSocket endpoint receiving derived frame metrics from edge TS-CAN runner.
    """
    await websocket.accept()
    client_id = f"ws_client_{id(websocket)}"
    logger.info(f"Client connected: {client_id}")

    try:
        frame_counter = 0
        while True:
            raw_text = await websocket.receive_text()
            frame_counter += 1

            try:
                raw_frame = RawRPPGBatch.model_validate_json(raw_text) if raw_text.startswith('{"client_id"') else RawRPPGFrame.model_validate_json(raw_text)

                if isinstance(raw_frame, RawRPPGBatch):
                    frame_status = raw_frame.frames[-1].status if raw_frame.frames else QualityStatus.OK
                    coverage = raw_frame.frames[-1].quality.coverage_ratio if raw_frame.frames else 0.25
                else:
                    frame_status = raw_frame.status
                    coverage = raw_frame.quality.coverage_ratio

                # Calculate realistic rPPG Pulse BPM & Waveform for telemetry
                import math
                calc_bpm = 72.0 + (math.sin(frame_counter * 0.1) * 4.0)
                waveform = [math.sin((frame_counter + i) * 0.2) for i in range(10)]

                metrics = ProcessedRPPGMetrics(
                    timestamp=raw_frame.timestamp if isinstance(raw_frame, RawRPPGFrame) else raw_frame.timestamp,
                    bpm=round(calc_bpm, 1),
                    snr_db=5.2,
                    signal_quality=1.0 if frame_status == QualityStatus.OK else 0.0,
                    status=frame_status,
                    pulse_waveform=waveform,
                    model="TS-CAN",
                )

                if frame_counter % 30 == 0:
                    logger.info(
                        f"[{client_id}] Frame #{frame_counter} | Status: {frame_status.value} | "
                        f"Coverage: {coverage*100:.1f}% | Output BPM: {metrics.bpm} | Model: TS-CAN"
                    )

                await websocket.send_text(metrics.model_dump_json())

            except ValidationError as ve:
                logger.warning(f"Invalid payload schema from {client_id}: {ve}")
                await websocket.send_json({"error": "Invalid frame schema", "details": str(ve)})

    except WebSocketDisconnect:
        logger.info(f"Client disconnected: {client_id}")


@app.post("/api/v1/rppg/raw-batch", response_model=ProcessedRPPGMetrics)
async def post_rppg_batch(batch: RawRPPGBatch):
    """
    HTTP Batch endpoint receiving 1-second batched derived frame payloads.
    """
    client_id = batch.client_id
    logger.info(f"Processing HTTP batch of {len(batch.frames)} frames for client '{client_id}'...")

    if not batch.frames:
        raise HTTPException(status_code=400, detail="Empty frame batch received.")

    latest_frame = batch.frames[-1]

    metrics = ProcessedRPPGMetrics(
        timestamp=batch.timestamp,
        bpm=0.0,
        snr_db=0.0,
        signal_quality=1.0 if latest_frame.status == QualityStatus.OK else 0.0,
        status=latest_frame.status,
        pulse_waveform=[],
        model="TS-CAN",
    )

    return metrics
