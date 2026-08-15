import asyncio
import json
import uuid
from typing import Optional

from fastapi import APIRouter, WebSocket, HTTPException, Request, status

from sse_starlette.sse import EventSourceResponse

from app.schemas.measurement_schema import (
    MeasurementStartRequest,
    MeasurementStartResponse,
    MeasurementResult,
    ModelIngestPayload,
    MeasurementRequest,
    MeasurementResponse,
    # Visual debugger schemas
    DebuggerStartResponse,
    DebuggerLatestResult,
    DebuggerStopResponse,
)
from app.services.measurement_service import (
    start_measurement_session,
    run_measurement_loop,
    get_measurement_result,
    ingest_model_payload,
    ingest_structured_measurement_request,
)
from app.services.measurement_runtime import runtime
from app.services.debugger_runner import start_debugger, stop_debugger

router = APIRouter(
    prefix="/api/v1/measurements",
    tags=["Measurements"]
)

# ── Existing routes (unchanged) ───────────────────────────────────────────────

@router.post("", response_model=MeasurementResponse, status_code=200)
async def post_structured_measurement(request: MeasurementRequest):
    """
    Direct model ingestion endpoint for FacePulseEngine (C:\\Users\\sarve\\Desktop\\FacePulse\\Model\\face_pulse-Model).
    Receives periodic JSON measurement push payloads (~1 Hz).
    """
    return await ingest_structured_measurement_request(request)

@router.post("/session", response_model=MeasurementStartResponse, status_code=201)
def start_measurement(request: MeasurementStartRequest):
    return start_measurement_session(request.user_id, request.device)

@router.post("/{measurement_id}/ingest", status_code=status.HTTP_200_OK)
async def ingest_model_data(measurement_id: str, payload: ModelIngestPayload):
    """
    Ingestion endpoint for external rPPG model to push raw frames / telemetry.
    """
    if payload.session_id != measurement_id:
        payload.session_id = measurement_id
    return await ingest_model_payload(payload)

@router.websocket("/{measurement_id}/live")
async def websocket_endpoint(websocket: WebSocket, measurement_id: str):
    await run_measurement_loop(measurement_id, websocket)

@router.get("/{measurement_id}/result", response_model=MeasurementResult)
def get_result(measurement_id: str):
    result = get_measurement_result(measurement_id)
    if not result:
        raise HTTPException(status_code=404, detail="Measurement result not found or session not completed")
    return result


# ── Visual Debugger endpoints ─────────────────────────────────────────────────

@router.post("/start", status_code=200)
def debugger_start(request: Request):
    """
    Start the existing visual debugger pipeline in a background thread.

    Returns measurement_id AND a stream_url.
    Flutter should immediately GET the stream_url to receive continuous
    Server-Sent Events (SSE) with live BPM/SNR/luminance data.
    """
    measurement_id = str(uuid.uuid4())
    start_debugger(measurement_id=measurement_id)

    base_url = str(request.base_url).rstrip("/")
    stream_url = f"{base_url}/api/v1/measurements/{measurement_id}/stream"

    return {
        "measurement_id": measurement_id,
        "status": "started",
        "stream_url": stream_url,
    }


@router.get("/{measurement_id}/stream")
async def debugger_stream(measurement_id: str, request: Request):
    """
    Server-Sent Events (SSE) stream — subscribe here after POST /start.

    Pushes a JSON event every second:
      data: {"frame":240,"status":"OK","bpm":72.7,"luminance":110.5,"snr":-3.78,"timestamp":"..."}

    During warmup (~6 s): status="WAITING", bpm/luminance/snr are null.
    Stream closes automatically when POST /stop is called or client disconnects.

    Flutter usage:
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final streamedResponse = await client.send(request);
      streamedResponse.stream.listen((chunk) { ... });
    """
    snap = runtime.snapshot()
    if snap["measurement_id"] != measurement_id:
        raise HTTPException(
            status_code=404,
            detail=f"No active session for measurement_id={measurement_id}. "
                   "Call POST /api/v1/measurements/start first.",
        )

    async def event_generator():
        last_frame = None  # only emit when data actually changes

        while True:
            # Stop if client disconnected
            if await request.is_disconnected():
                break

            snap = runtime.snapshot()

            # Stop if this session was stopped or a new session started
            if snap["measurement_id"] != measurement_id:
                yield {
                    "event": "stopped",
                    "data": json.dumps({
                        "measurement_id": measurement_id,
                        "status": "stopped",
                    }),
                }
                break

            # Stop if the runtime has been asked to stop
            if not snap["running"] and snap["frame"] is not None:
                yield {
                    "event": "stopped",
                    "data": json.dumps({
                        "measurement_id": measurement_id,
                        "status": "completed",
                        "bpm": snap["bpm"],
                        "luminance": snap["luminance"],
                        "snr": snap["snr"],
                    }),
                }
                break

            # Build the event payload
            effective_status = snap["status"] or "WAITING"
            if snap["bpm"] is None:
                effective_status = "WAITING"

            payload = {
                "measurement_id": measurement_id,
                "frame": snap["frame"],
                "status": effective_status,
                "bpm": snap["bpm"],
                "luminance": snap["luminance"],
                "snr": snap["snr"],
                "timestamp": snap["timestamp"],
            }

            # Only emit when frame index advances (avoids duplicate events)
            if snap["frame"] != last_frame:
                last_frame = snap["frame"]
                yield {
                    "event": "measurement",
                    "data": json.dumps(payload),
                }

            await asyncio.sleep(1.0)  # push ~1 update per second to Flutter

    return EventSourceResponse(event_generator())


@router.get("/latest", response_model=DebuggerLatestResult)
@router.get("/{measurement_id}/latest", response_model=DebuggerLatestResult)
def debugger_latest(measurement_id: Optional[str] = "latest"):
    """
    Return the most recent frame result produced by the visual debugger.

    During the first ~6 seconds (180-frame warmup), BPM/SNR/luminance are
    null and status is 'WAITING'.  After warmup, real values are returned.
    """
    snap = runtime.snapshot()

    # If runtime is active but has a new measurement_id, return active snapshot
    active_id = snap["measurement_id"] or measurement_id or "latest"

    # During warmup (bpm still None), preserve specific quality status (NO_FACE, BAD_POSE, etc.)
    raw_status = snap["status"] or "WAITING"
    if raw_status in ("NO_FACE", "BAD_POSE", "FACE_MISALIGNED", "LOW_LIGHT", "OVER_EXPOSED"):
        effective_status = raw_status
    elif snap["bpm"] is None:
        effective_status = "WAITING"
    else:
        effective_status = raw_status

    return DebuggerLatestResult(
        measurement_id=active_id,
        frame=snap["frame"],
        status=effective_status,
        bpm=snap["bpm"],
        luminance=snap["luminance"],
        snr=snap["snr"],
        timestamp=snap["timestamp"],
    )


@router.post("/{measurement_id}/stop", response_model=DebuggerStopResponse)
def debugger_stop(measurement_id: str):
    """
    Stop the visual debugger, release the webcam, and return the final result.

    Waits up to 5 seconds for the background thread to exit cleanly.
    """
    snap = runtime.snapshot()
    if snap["measurement_id"] != measurement_id:
        raise HTTPException(
            status_code=404,
            detail=f"No active session for measurement_id={measurement_id}."
        )

    stop_debugger(timeout=5.0)

    # Capture final snapshot after stop
    final = runtime.snapshot()

    return DebuggerStopResponse(
        measurement_id=measurement_id,
        status="completed",
        bpm=final["bpm"],
        luminance=final["luminance"],
        snr=final["snr"],
    )
