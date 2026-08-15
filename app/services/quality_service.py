import random

def evaluate_face_position() -> dict:
    """Mock evaluating face position in the frame."""
    return {
        "x": random.uniform(0.4, 0.6),
        "y": random.uniform(0.4, 0.6),
        "width": random.uniform(0.2, 0.4),
        "height": random.uniform(0.2, 0.4)
    }

def evaluate_lighting() -> float:
    """Mock evaluating lighting score (0-1)."""
    return random.uniform(0.7, 1.0)

def evaluate_face_size() -> float:
    """Mock evaluating face size score (0-1)."""
    return random.uniform(0.6, 1.0)

def evaluate_movement() -> float:
    """Mock evaluating movement score (0-1, lower is less movement)."""
    return random.uniform(0.0, 0.2)

def get_overall_quality() -> float:
    """Combine scores into a mock overall quality (0-1)."""
    return (evaluate_lighting() * 0.4 + evaluate_face_size() * 0.4 + (1 - evaluate_movement()) * 0.2)

def get_quality_status(quality_score: float) -> str:
    if quality_score < 0.5:
        return "POOR"
    elif quality_score < 0.7:
        return "FAIR"
    return "GOOD"

def get_instruction() -> str:
    """Provide one of the specific instructions requested."""
    instructions = [
        "Move to a brighter area",
        "Center your face",
        "Hold your face steady"
    ]
    return random.choice(instructions)
