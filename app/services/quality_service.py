"""
Quality Evaluation Service for Face Pulse.
Multi-factor quality assessment focusing on face presence detection, head position stability,
and secondary illumination evaluation.
"""

from typing import Dict, Any


def evaluate_face_detection(face_found: bool = True, face_lost_ratio: float = 0.0) -> Dict[str, Any]:
    """
    Evaluates face presence.
    If the face is not found or face lost ratio > 0.15, video quality is marked POOR.
    """
    if not face_found or face_lost_ratio > 0.15:
        return {"score": 0.1, "quality": "POOR", "reason": "No Face Found"}
    return {"score": max(0.0, 1.0 - face_lost_ratio), "quality": "GOOD", "reason": "Face Detected"}


def evaluate_head_position(
    yaw: float = 0.0,
    pitch: float = 0.0,
    roll: float = 0.0,
    bad_pose_ratio: float = 0.0,
    offset_x: float = 0.0,
    offset_y: float = 0.0,
) -> Dict[str, Any]:
    """
    Evaluates head position changes, pose rotation (yaw/pitch/roll), and alignment offsets.
    """
    pose_rotation = (abs(yaw) + abs(pitch) + abs(roll)) / 75.0
    alignment_offset = (abs(offset_x) + abs(offset_y)) / 0.60
    head_movement_penalty = (bad_pose_ratio * 1.5) + pose_rotation + alignment_offset

    score = max(0.0, min(1.0, 1.0 - head_movement_penalty))
    return {
        "score": round(score, 2),
        "is_stable": score >= 0.70,
        "reason": "Unstable Head Position" if score < 0.50 else "Stable Head Position",
    }


def evaluate_lighting(luminance_y: float = 120.0, luminance_std: float = 5.0) -> float:
    """
    Evaluates illumination as a secondary factor.
    """
    if luminance_y < 45.0 or luminance_y > 230.0:
        return 0.3
    if luminance_std > 20.0:
        return 0.6
    return 0.95


def get_overall_quality(
    face_found: bool = True,
    face_lost_ratio: float = 0.0,
    bad_pose_ratio: float = 0.0,
    luminance_y: float = 120.0,
    luminance_std: float = 5.0,
    yaw: float = 0.0,
    pitch: float = 0.0,
    roll: float = 0.0,
) -> float:
    """
    Calculates overall quality score (0.0 to 1.0).
    - If face is NOT found (face_found=False or face_lost_ratio > 0.15), quality is forced to 0.1 (POOR).
    - Otherwise, heavily weighs head position stability (60%) over lighting (20%) and detection stability (20%).
    """
    if not face_found or face_lost_ratio > 0.15:
        return 0.1  # Force POOR when face is not found

    head_eval = evaluate_head_position(
        yaw=yaw, pitch=pitch, roll=roll, bad_pose_ratio=bad_pose_ratio
    )
    light_score = evaluate_lighting(luminance_y=luminance_y, luminance_std=luminance_std)
    detection_score = max(0.0, 1.0 - face_lost_ratio)

    overall = (head_eval["score"] * 0.60) + (detection_score * 0.20) + (light_score * 0.20)
    return round(max(0.0, min(1.0, overall)), 2)


def get_quality_status(quality_score: float, face_found: bool = True) -> str:
    """
    Returns text quality status: POOR, FAIR, or GOOD.
    If face is not found, status is always POOR.
    """
    if not face_found or quality_score < 0.40:
        return "POOR"
    elif quality_score < 0.70:
        return "FAIR"
    return "GOOD"
