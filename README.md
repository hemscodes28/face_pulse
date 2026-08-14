# FacePulse - Backend

Backend API and WebSocket streaming service for **FacePulse**, a contactless vitals measurement platform.

---

## 📋 Features

- **Authentication & Security**: User signup, login, mock Google SSO, and JWT Bearer token authorization.
- **User Profile & Onboarding**: 3-step profile completion (Basic Demographics, Body Metrics with automatic BMI calculation, Medical Details).
- **Real-Time Measurement Engine**:
  - Session creation with device configuration metadata.
  - Live WebSocket telemetry stream for vital signs (Heart Rate, $\text{SpO}_2$, Blood Pressure waveforms) with signal quality & positioning guidance.
  - Measurement results retrieval with clinical analysis summaries.
- **Vitals Diary**:
  - Automatic persistence of completed measurement vitals and time-series telemetry.
  - Date-filtered queries (`GET /api/v1/diary?date=YYYY-MM-DD`).
  - Interactive visualization of time-series graphs (Heart Rate, $\text{SpO}_2$, BP waveforms).

---

## 🛠 Tech Stack

- **Framework**: [FastAPI](https://fastapi.tiangolo.com/)
- **ASGI Server**: [Uvicorn](https://www.uvicorn.org/)
- **Data Validation & Schemas**: [Pydantic v2](https://docs.pydantic.dev/)
- **Authentication**: PyJWT (HMAC-SHA256 tokens)
- **Real-Time Communication**: WebSockets

---

## 🚀 Setup & Installation Procedures

### Prerequisites

- **Python 3.10+**
- **pip** and **Git**

### 1. Clone & Navigate to Backend

```bash
git clone -b backend-sarvesh https://github.com/hemscodes28/face_pulse.git
cd face_pulse/backend
```

### 2. Create and Activate Virtual Environment

**On Windows (PowerShell):**
```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

**On Windows (Command Prompt):**
```cmd
python -m venv venv
.\venv\Scripts\activate.bat
```

**On Linux / macOS:**
```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Create a `.env` file from `.env.example`:
```bash
cp .env.example .env
```

### 5. Run the Backend Server

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The API will be accessible at:
- **Root**: `http://127.0.0.1:8000/`
- **Interactive Swagger Docs**: `http://127.0.0.1:8000/docs`
- **ReDoc Documentation**: `http://127.0.0.1:8000/redoc`
- **Health Check**: `http://127.0.0.1:8000/health`

---

## 💻 Optional: Running the Frontend UI

If you want to run the React testing interface located in `frontend/`:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173/` in your browser.

---

## 📡 API Reference

### 🔐 Authentication (`/api/v1/auth`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/signup` | Register a new user account |
| `POST` | `/api/v1/auth/login` | Authenticate and obtain JWT access token |
| `POST` | `/api/v1/auth/google` | Mock Google OAuth login |

### 👤 User & Onboarding (`/api/v1/users`)

*Requires `Authorization: Bearer <token>` header.*

| Method | Endpoint | Description |
|---|---|---|
| `PUT` | `/api/v1/users/{user_id}/profile/basic` | Update date of birth and gender |
| `PUT` | `/api/v1/users/{user_id}/profile/body` | Update height & weight (calculates BMI) |
| `PUT` | `/api/v1/users/{user_id}/profile/medical` | Update blood group |
| `POST` | `/api/v1/users/{user_id}/onboarding/complete` | Finalize onboarding |
| `GET` | `/api/v1/users/{user_id}/profile` | Retrieve user profile |

### 💓 Measurements (`/api/v1/measurements`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/measurements/session` | Create a measurement session |
| `WS` | `/api/v1/measurements/{id}/live` | Live WebSocket streaming telemetry |
| `GET` | `/api/v1/measurements/{id}/result` | Fetch final measurement report |

### 📅 Vitals Diary (`/api/v1/diary`)

*Requires `Authorization: Bearer <token>` header.*

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/diary?date=YYYY-MM-DD` | Retrieve measurements recorded on a date |

---

## 🧪 Testing

Run backend import and schema checks:
```bash
python -c "import app.main; print('API Loaded Successfully')"
```
