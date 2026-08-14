import asyncio
import uuid
from datetime import datetime, timezone
from fastapi import WebSocket, WebSocketDisconnect

from app.models.enums import MeasurementStatus, SignalQualityLevelEnum
from app.schemas.measurement_schema import (
    MeasurementStartResponse, 
    DeviceInfo, 
    LiveMeasurementData, 
    MeasurementResult,
    MeasurementQuality
)
from app.services.session_store import sessions
from app.services.diary_service import add_diary_entry
from app.services.user_store import users
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
        "status": MeasurementStatus.READY,
        "started_at": started_at.isoformat(),
        "completed_at": None,
        "results": None
    }
    
    return MeasurementStartResponse(
        measurement_id=measurement_id,
        status=MeasurementStatus.READY,
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
        
    if session["status"] != MeasurementStatus.READY:
        await websocket.close(code=4000, reason="Session is not in READY state")
        return
        
    await websocket.accept()
    session["status"] = MeasurementStatus.MEASURING
    
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
        session["status"] = MeasurementStatus.PROCESSING
        await websocket.send_text('{"status": "PROCESSING", "message": "Analyzing data..."}')
        
        # Simulate processing delay
        await asyncio.sleep(2.0)
        
        # Completed
        completed_at = datetime.now(timezone.utc)
        session["status"] = MeasurementStatus.COMPLETED
        session["completed_at"] = completed_at.isoformat()
        
        user_id = session["user_id"]
        user = users.get(user_id, {})
        
        session["results"] = {
            "id": str(uuid.uuid4()),
            "measurement_id": measurement_id,
            "status": MeasurementStatus.COMPLETED,
            "heart_rate_bpm": 72.0,
            "systolic_bp_mmhg": 120.0,
            "diastolic_bp_mmhg": 80.0,
            "hrv_ms": 48.5,
            "breathing_rate_bpm": 16.0,
            "stress_index": 1.25,
            "cardiac_workload": 8640.0,
            "parasympathetic_activity_percent": 68.5,
            "bmi": user.get("bmi", 22.86),
            "bmi_classification": user.get("bmi_classification", "Normal"),
            "signal_quality_score": 0.85,
            "signal_quality_level": SignalQualityLevelEnum.GOOD,
            "rescan_recommended": False,
            "quality_message": "Good lighting and stable tracking throughout the session.",
            "analysis": {
                "rhythm": "Normal sinus rhythm",
                "cardiovascular_state": "Optimal resting condition",
                "autonomic_balance": "Parasympathetic dominant (relaxed)"
            },
            "model_name": "FacePulse-rPPG-Core",
            "model_version": "v1.2.0",
            "processed_at": completed_at,
            "vitals": {"hr": 72, "spo2": 98, "bp": "120/80"},
            "quality_summary": {"avg_quality": 0.85}
        }
        
        # Save final vitals + time-series to Diary Store
        vitals = session["results"]["vitals"]
        add_diary_entry(
            user_id=session["user_id"],
            measurement_id=measurement_id,
            recorded_at=completed_at,
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
        session["status"] = MeasurementStatus.FAILED
        print(f"WebSocket disconnected for {measurement_id}")
    except Exception as e:
        session["status"] = MeasurementStatus.FAILED
        print(f"Error in measurement loop: {e}")
        await websocket.close(code=1011, reason="Internal server error")


def get_measurement_result(measurement_id: str) -> MeasurementResult:
    session = sessions.get(measurement_id)
    if not session:
        return None
        
    if session["status"] != MeasurementStatus.COMPLETED or not session.get("results"):
        return None
        
    duration = (datetime.now(timezone.utc) - datetime.fromisoformat(session["started_at"])).total_seconds()
    res = session["results"]
    
    return MeasurementResult(
        id=res.get("id"),
        measurement_id=measurement_id,
        status=session["status"],
        duration_sec=round(duration, 2),
        started_at=datetime.fromisoformat(session["started_at"]),
        completed_at=datetime.fromisoformat(session["completed_at"]) if session.get("completed_at") else None,
        heart_rate_bpm=res.get("heart_rate_bpm"),
        systolic_bp_mmhg=res.get("systolic_bp_mmhg"),
        diastolic_bp_mmhg=res.get("diastolic_bp_mmhg"),
        hrv_ms=res.get("hrv_ms"),
        breathing_rate_bpm=res.get("breathing_rate_bpm"),
        stress_index=res.get("stress_index"),
        cardiac_workload=res.get("cardiac_workload"),
        parasympathetic_activity_percent=res.get("parasympathetic_activity_percent"),
        bmi=res.get("bmi"),
        bmi_classification=res.get("bmi_classification"),
        signal_quality_score=res.get("signal_quality_score"),
        signal_quality_level=res.get("signal_quality_level"),
        rescan_recommended=res.get("rescan_recommended", False),
        quality_message=res.get("quality_message"),
        analysis=res.get("analysis"),
        model_name=res.get("model_name"),
        model_version=res.get("model_version"),
        processed_at=res.get("processed_at"),
        vitals=res.get("vitals"),
        quality_summary=res.get("quality_summary")
    )
