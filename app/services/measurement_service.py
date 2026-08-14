import asyncio
import uuid
from datetime import datetime, timezone
from fastapi import WebSocket, WebSocketDisconnect

from app.schemas.measurement_schema import (
    MeasurementStartResponse, 
    DeviceInfo, 
    LiveMeasurementData, 
    MeasurementResult,
    MeasurementQuality
)
from app.services.session_store import sessions
from app.services.diary_service import add_diary_entry
import app.services.quality_service as qs

def start_measurement_session(user_id: str, device: DeviceInfo) -> MeasurementStartResponse:
    """
    Creates a new measurement session and stores it in memory.
    """
    measurement_id = str(uuid.uuid4())
    started_at = datetime.now(timezone.utc)
    
    sessions[measurement_id] = {
        "user_id": user_id,
        "device": device.model_dump(),
        "status": "READY",
        "started_at": started_at.isoformat(),
        "results": None
    }
    
    return MeasurementStartResponse(
        measurement_id=measurement_id,
        status="READY",
        message="Measurement session created",
        started_at=started_at
    )

async def run_measurement_loop(measurement_id: str, websocket: WebSocket):
    """
    Handles the live measurement logic via WebSocket.
    """
    session = sessions.get(measurement_id)
    if not session:
        await websocket.close(code=4004, reason="Session not found")
        return
        
    if session["status"] != "READY":
        await websocket.close(code=4000, reason="Session is not in READY state")
        return
        
    await websocket.accept()
    session["status"] = "MEASURING"
    
    start_time = datetime.now(timezone.utc)
    measurement_duration = 40.0  # Simulate 40 seconds of measuring
    update_interval = 1.0  # ~1 sec
    
    # Accumulate time-series for diary graphs
    hr_series: list = []
    spo2_series: list = []
    bp_series: list = []
    
    try:
        while True:
            elapsed = (datetime.now(timezone.utc) - start_time).total_seconds()
            
            if elapsed >= measurement_duration:
                break
                
            # Generate mock live data
            q_score = qs.get_overall_quality()
            instruction = qs.get_instruction()
            
            quality = MeasurementQuality(
                overall_score=round(q_score, 2),
                status=qs.get_quality_status(q_score),
                lighting=round(qs.evaluate_lighting(), 2),
                face_position=qs.evaluate_face_position(),
                face_detected=True
            )
            
            import random
            
            hr_val   = round(random.uniform(60, 100), 1)
            spo2_val = round(random.uniform(95, 100), 1)
            bp_val   = [round(random.uniform(70, 120), 1) for _ in range(5)]
            
            # Accumulate series
            hr_series.append(hr_val)
            spo2_series.append(spo2_val)
            bp_series.append(bp_val)
            
            live_data = LiveMeasurementData(
                measurement_id=measurement_id,
                elapsed_time_sec=round(elapsed, 2),
                quality=quality,
                instruction=instruction,
                hr=hr_val,
                spo2=spo2_val,
                bp=bp_val
            )
            
            await websocket.send_text(live_data.model_dump_json())
            await asyncio.sleep(update_interval)
            
        # Processing state
        session["status"] = "PROCESSING"
        await websocket.send_text('{"status": "PROCESSING", "message": "Analyzing data..."}')
        
        # Simulate processing delay
        await asyncio.sleep(2.0)
        
        # Completed
        session["status"] = "COMPLETED"
        session["results"] = {
            "vitals": {"hr": 72, "spo2": 98, "bp": "120/80"},
            "quality_summary": {"avg_quality": 0.85},
            "analysis": "Normal sinus rhythm."
        }
        
        # Save final vitals + time-series to Diary Store
        vitals = session["results"]["vitals"]
        add_diary_entry(
            user_id=session["user_id"],
            measurement_id=measurement_id,
            recorded_at=datetime.now(timezone.utc),
            hr=vitals["hr"],
            spo2=vitals["spo2"],
            bp_str=vitals["bp"],
            hr_series=hr_series,
            spo2_series=spo2_series,
            bp_series=bp_series
        )
        
        await websocket.send_text('{"status": "COMPLETED", "message": "Measurement finished."}')
        await websocket.close(code=1000, reason="Measurement completed successfully")
        
    except WebSocketDisconnect:
        session["status"] = "FAILED"
        print(f"WebSocket disconnected for {measurement_id}")
    except Exception as e:
        session["status"] = "FAILED"
        print(f"Error in measurement loop: {e}")
        await websocket.close(code=1011, reason="Internal server error")


def get_measurement_result(measurement_id: str) -> MeasurementResult:
    session = sessions.get(measurement_id)
    if not session:
        return None
        
    if session["status"] != "COMPLETED" or not session.get("results"):
        return None
        
    duration = (datetime.now(timezone.utc) - datetime.fromisoformat(session["started_at"])).total_seconds()
    
    return MeasurementResult(
        measurement_id=measurement_id,
        status=session["status"],
        duration_sec=round(duration, 2),
        vitals=session["results"]["vitals"],
        quality_summary=session["results"]["quality_summary"],
        analysis=session["results"]["analysis"]
    )
