import sys
import logging
import time
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.routes import measurement_routes, auth_routes, user_routes, diary_routes, guardian_routes

# Configure logger to write directly to stdout
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("face_pulse_api")

app = FastAPI(
    title="Face Pulse API",
    description="Backend API for Face Pulse",
    version="1.0.0"
)

# Endpoint Logging Middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    url_path = request.url.path
    method = request.method
    client_ip = request.client.host if request.client else "unknown"
    
    print(f"📥 [API INCOMING] {method} {url_path} from {client_ip}", flush=True)
    
    response = await call_next(request)
    
    duration = (time.time() - start_time) * 1000
    status_code = response.status_code
    print(f"📤 [API RESPONSE] {method} {url_path} -> Status {status_code} ({duration:.1f}ms)", flush=True)
    
    return response

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development, allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(measurement_routes.router)
app.include_router(auth_routes.router)
app.include_router(user_routes.router)
app.include_router(diary_routes.router)
app.include_router(guardian_routes.router)

@app.get("/")
def read_root():
    return {"message": "Face Pulse Backend is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
