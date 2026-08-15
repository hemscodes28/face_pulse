from typing import Dict, Any

# In-memory store: user_id -> dict(UserRecord)
users: Dict[str, Any] = {}

# In-memory lookup: email -> user_id
user_emails: Dict[str, str] = {}
