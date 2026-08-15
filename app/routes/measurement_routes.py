from fastapi import APIRouter, WebSocket, HTTPException, status
from app.schemas.measurement_schema import (
    MeasurementStartRequest, 
    MeasurementStartResponse, 
    MeasurementResult,
    ModelIngestPayload,
    MeasurementRequest,
    MeasurementResponse
)
from app.services.measurement_service import (
    start_measurement_session, 
    run_measurement_loop, 
    get_measurement_result,
    ingest_model_payload,
    ingest_structured_measurement_request
)

router = APIRouter(
    prefix="/api/v1/measurements",
    tags=["Measurements"]
)

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
