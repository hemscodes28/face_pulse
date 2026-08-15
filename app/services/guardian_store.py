from typing import Dict, Any, List

# In-memory storage for user_guardians relationships
# Key: relationship_id (UUID), Value: dict adhering to UserGuardian model
guardians_store: Dict[str, Dict[str, Any]] = {}
