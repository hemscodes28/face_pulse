"""
Mock Backend Receiver for FacePulseEngine.
FastAPI application providing WebSocket streaming endpoint `/ws/raw-rppg-stream`
and HTTP batch endpoint `/api/v1/rppg/raw-batch`.
Processes incoming raw temporal signals through RPPGSignalProcessor and logs live heart rate metrics.
"""

import logging
from typing import Dict
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError

from schemas import ProcessedRPPGMetrics, QualityStatus, RawRPPGBatch, RawRPPGFrame
from rppg_processor import RPPGSignalProcessor

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("MockBackendReceiver")

app = FastAPI(
    title="FacePulseEngine Backend Receiver",
    description="FastAPI WebSocket and HTTP Batch Backend Receiver for real-time rPPG metrics processing.",
    version="1.0.0",
)

# Enable CORS for web and Flutter frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory dictionary mapping client session IDs to active RPPGSignalProcessor instances
active_processors: Dict[str, RPPGSignalProcessor] = {}


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "FacePulseEngine Mock Backend"}


@app.get("/api/v1/rppg/status")
def get_status():
    """Returns active streams and server info."""
    return {
        "active_streams": len(active_processors),
        "status": "online",
        "supported_codecs": ["raw_json_v1"],
    }


@app.websocket("/ws/raw-rppg-stream")
async def websocket_raw_rppg_stream(websocket: WebSocket):
    """
    Mode A: Real-time WebSocket endpoint receiving per-frame raw ROI signals at 30 Hz.
    Runs POS DSP, Butterworth bandpass filtering, and Welch PSD to output live BPM & SNR metrics.
    """
    await websocket.accept()
    client_id = f"ws_client_{id(websocket)}"
    processor = RPPGSignalProcessor(buffer_size=240, fs=30.0)
    active_processors[client_id] = processor

    logger.info(f"Client connected: {client_id}")

    try:
        frame_counter = 0
        while True:
            # Receive raw frame JSON text payload from client
            raw_text = await websocket.receive_text()
            frame_counter += 1

            try:
                # Validate JSON payload using Pydantic model
                raw_frame = RawRPPGFrame.model_validate_json(raw_text)

                # Extract RGB from global skin ROI (or average of facial ROIs)
                r_val = raw_frame.rois.global_skin.red
                g_val = raw_frame.rois.global_skin.green
                b_val = raw_frame.rois.global_skin.blue

                # Update DSP Processor state
                metrics: ProcessedRPPGMetrics = processor.update(
                    r=r_val,
                    g=g_val,
                    b=b_val,
                    timestamp=raw_frame.timestamp,
                    status=raw_frame.status,
                )

                # Log incoming rate and metrics every 30 frames (~1 sec)
                if frame_counter % 30 == 0:
                    logger.info(
                        f"[{client_id}] Frame #{raw_frame.frame_id} | Status: {raw_frame.status.value} | "
                        f"RGB: ({r_val:.1f}, {g_val:.1f}, {b_val:.1f}) | BPM: {metrics.bpm:.1f} | SNR: {metrics.snr_db:.1f} dB"
                    )

                # Send processed rPPG metrics back to client over WebSocket
                await websocket.send_text(metrics.model_dump_json())

            except ValidationError as ve:
                logger.warning(f"Invalid JSON payload format from {client_id}: {ve}")
                await websocket.send_json({"error": "Invalid frame schema", "details": str(ve)})

    except WebSocketDisconnect:
        logger.info(f"Client disconnected: {client_id}")
    finally:
        active_processors.pop(client_id, None)


@app.post("/api/v1/rppg/raw-batch", response_model=ProcessedRPPGMetrics)
async def post_raw_rppg_batch(batch: RawRPPGBatch):
    """
    Mode B: HTTP Batch endpoint receiving 1-second batched frame payloads (30 frames).
    Processes frames sequentially and returns updated pulse metrics.
    """
    client_id = batch.client_id
    if client_id not in active_processors:
        active_processors[client_id] = RPPGSignalProcessor(buffer_size=240, fs=30.0)

    processor = active_processors[client_id]
    latest_metrics: ProcessedRPPGMetrics = None

    logger.info(f"Processing HTTP batch of {len(batch.frames)} frames for client '{client_id}'...")

    for frame in batch.frames:
        r_val = frame.rois.global_skin.red
        g_val = frame.rois.global_skin.green
        b_val = frame.rois.global_skin.blue

        latest_metrics = processor.update(
            r=r_val,
            g=g_val,
            b=b_val,
            timestamp=frame.timestamp,
            status=frame.status,
        )

    if latest_metrics is None:
        raise HTTPException(status_code=400, detail="Empty frame batch received.")

    logger.info(
        f"HTTP Batch Result [{client_id}] -> BPM: {latest_metrics.bpm:.1f} | SNR: {latest_metrics.snr_db:.1f} dB"
    )

    return latest_metrics


if __name__ == "__main__":
    import uvicorn
    logger.info("Starting FacePulseEngine Mock Backend Server on http://0.0.0.0:8000...")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
