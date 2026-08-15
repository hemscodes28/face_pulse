from typing import Dict, Any

# Simple in-memory storage for measurement sessions.
# Keys are measurement_ids (UUID strings), values are dicts containing session state.
sessions: Dict[str, Dict[str, Any]] = {}
