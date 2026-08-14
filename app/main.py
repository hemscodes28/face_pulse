from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import measurement_routes, auth_routes, user_routes, diary_routes

app = FastAPI(
    title="Face Pulse API",
    description="Backend API for Face Pulse",
    version="1.0.0"
)

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

@app.get("/")
def read_root():
    return {"message": "Face Pulse Backend is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
