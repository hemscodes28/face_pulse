from fastapi import APIRouter, WebSocket, HTTPException
from app.schemas.measurement_schema import (
    MeasurementStartRequest, 
    MeasurementStartResponse, 
    MeasurementResult
)
from app.services.measurement_service import (
    start_measurement_session, 
    run_measurement_loop, 
    get_measurement_result
)

router = APIRouter(
    prefix="/api/v1/measurements",
    tags=["Measurements"]
)

@router.post("/session", response_model=MeasurementStartResponse, status_code=201)
def start_measurement(request: MeasurementStartRequest):
    return start_measurement_session(request.user_id, request.device)

@router.websocket("/{measurement_id}/live")
async def websocket_endpoint(websocket: WebSocket, measurement_id: str):
    await run_measurement_loop(measurement_id, websocket)

@router.get("/{measurement_id}/result", response_model=MeasurementResult)
def get_result(measurement_id: str):
    result = get_measurement_result(measurement_id)
    if not result:
        raise HTTPException(status_code=404, detail="Measurement result not found or session not completed")
    return result
