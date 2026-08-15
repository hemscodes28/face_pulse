import { useState, useRef, useEffect } from 'react';
import './index.css';

const API = 'http://127.0.0.1:8000/api/v1';

// ─── Helpers ───────────────────────────────────────────────
function computeAge(dobStr) {
  if (!dobStr) return null;
  const birth = new Date(dobStr);
  if (isNaN(birth.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const m = now.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < birth.getDate())) {
    age--;
  }
  return age >= 0 ? age : null;
}

function formatHeight(height_cm, unit = 'cm') {
  if (!height_cm) return '--';
  if (unit === 'ft') {
    const totalInches = height_cm / 2.54;
    const feet = Math.floor(totalInches / 12);
    const inches = Math.round(totalInches % 12);
    return `${feet}' ${inches}"`;
  }
  return `${Math.round(height_cm)} cm`;
}

function formatWeight(weight_kg, unit = 'kg') {
  if (!weight_kg) return '--';
  if (unit === 'lbs') {
    return `${(weight_kg * 2.20462).toFixed(1)} lbs`;
  }
  return `${Number(weight_kg).toFixed(1)} kg`;
}

function getInitials(name) {
  if (!name) return 'FP';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function getQualityBadgeClass(status) {
  switch ((status || '').toUpperCase()) {
    case 'EXCELLENT': return 'badge-completed';
    case 'GOOD': return 'badge-measuring';
    case 'FAIR': return 'badge-processing';
    case 'POOR':
    case 'TOO_DARK':
    case 'TOO_BRIGHT': return 'badge-poor';
    default: return 'badge-measuring';
  }
}

function NavBar({ title, onLogout, onProfile, profileInitials, onBrandClick }) {
  return (
    <div className="nav">
      <div className="nav-brand" onClick={onBrandClick}>
        Face<span>Pulse</span>
      </div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        {title && <span style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>{title}</span>}
        {onProfile && (
          <div className="avatar" title="View Profile" onClick={onProfile}>
            {profileInitials || '👤'}
          </div>
        )}
        {onLogout && (
          <button className="btn btn-ghost btn-sm" onClick={onLogout}>Log out</button>
        )}
      </div>
    </div>
  );
}

function StepBar({ total, current }) {
  return (
    <div className="step-bar">
      {Array.from({ length: total }).map((_, i) => (
        <div
          key={i}
          className={`step-dot ${i < current ? 'done' : i === current ? 'active' : ''}`}
        />
      ))}
    </div>
  );
}

// ─── Heart Rate Zone Spectrum Diagram ──────────────────────
function HeartRateZoneDiagram({ bpm = 75 }) {
  // Clamp between 40 and 160 for visual scale
  const minScale = 40;
  const maxScale = 160;
  const clamped = Math.max(minScale, Math.min(maxScale, bpm));
  const pinPercent = ((clamped - minScale) / (maxScale - minScale)) * 100;

  return (
    <div style={{ background: 'var(--surface)', padding: '14px', borderRadius: 10, border: '1px solid var(--border)', marginBottom: 16 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 8 }}>
        <span>Heart Rate Zone Spectrum</span>
        <span style={{ color: bpm >= 60 && bpm <= 100 ? '#10b981' : '#f59e0b', fontWeight: 700 }}>
          {bpm < 60 ? 'Resting / Low' : bpm <= 100 ? 'Normal Resting Zone' : 'Elevated'}
        </span>
      </div>
      
      {/* Visual Zone Bar */}
      <div style={{ position: 'relative', height: 16, borderRadius: 8, background: 'linear-gradient(90deg, #60a5fa 0%, #10b981 35%, #10b981 65%, #f59e0b 85%, #f87171 100%)', margin: '14px 0 20px 0', border: '1px solid rgba(255,255,255,0.1)' }}>
        {/* Animated Pin Indicator */}
        <div style={{ position: 'absolute', left: `${pinPercent}%`, top: -6, transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ width: 14, height: 14, borderRadius: '50%', background: '#ffffff', border: '3px solid #10b981', boxShadow: '0 0 10px rgba(16, 185, 129, 0.8)' }}></div>
          <div style={{ fontSize: '0.72rem', fontWeight: 800, color: '#ffffff', background: '#1e293b', padding: '1px 6px', borderRadius: 4, marginTop: 4, whiteSpace: 'nowrap', border: '1px solid var(--border)' }}>
            {bpm.toFixed(1)} BPM
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--muted)' }}>
        <span>40 bpm (Low)</span>
        <span>60 - 100 bpm (Normal)</span>
        <span>160 bpm (Max)</span>
      </div>
    </div>
  );
}

// ─── Inline SVG Line Chart (Dynamic 40s Curve) ────────────
function LineChart({ data = [], color = '#6ee7b7', label = '', unit = '', height = 85 }) {
  if (!data || data.length < 2) return (
    <div style={{ textAlign: 'center', color: 'var(--muted)', fontSize: '0.8rem', padding: '12px 0' }}>
      Waiting for rPPG model observations...
    </div>
  );

  const W = 380, H = height, PAD = 10;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;

  const pts = data.map((v, i) => {
    const x = PAD + (i / (data.length - 1)) * (W - PAD * 2);
    const y = PAD + (1 - (v - min) / range) * (H - PAD * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');

  const firstX = PAD;
  const lastX  = PAD + (W - PAD * 2);
  const bottom = H - PAD;
  const areaPts = `${firstX},${bottom} ${pts} ${lastX},${bottom}`;
  const latestVal = data[data.length - 1];

  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 6 }}>
        <span>{label}</span>
        <span style={{ color, fontWeight: 700 }}>
          {typeof latestVal === 'number' ? latestVal.toFixed(1) : latestVal}{unit}
          <span style={{ color: 'var(--muted)', fontWeight: 400, marginLeft: 8, fontSize: '0.72rem' }}>
            ({min.toFixed(1)} - {max.toFixed(1)}{unit})
          </span>
        </span>
      </div>
      <svg width="100%" height={H} viewBox={`0 0 ${W} ${H}`} style={{ display: 'block', overflow: 'visible' }}>
        <defs>
          <linearGradient id={`grad-${label.replace(/[^a-zA-Z0-9]/g,'')}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.42" />
            <stop offset="100%" stopColor={color} stopOpacity="0.01" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map(p => (
          <line key={p}
            x1={PAD} x2={W - PAD}
            y1={PAD + p * (H - PAD * 2)}
            y2={PAD + p * (H - PAD * 2)}
            stroke="rgba(255,255,255,0.06)" strokeWidth="1" strokeDasharray="3 3"
          />
        ))}
        <polygon points={areaPts} fill={`url(#grad-${label.replace(/[^a-zA-Z0-9]/g,'')})`} />
        <polyline
          points={pts}
          fill="none"
          stroke={color}
          strokeWidth="2.5"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {(() => {
          const lastPt = pts.split(' ').pop().split(',');
          return (
            <g>
              <circle cx={lastPt[0]} cy={lastPt[1]} r="6" fill={color} opacity="0.3" />
              <circle cx={lastPt[0]} cy={lastPt[1]} r="3.5" fill="#ffffff" />
            </g>
          );
        })()}
      </svg>
    </div>
  );
}

// ─── App Component ────────────────────────────────────────
export default function App() {
  const [page, setPage]               = useState('landing'); 
  // pages: landing | signup | login | onboard-basic | onboard-body | onboard-medical | dashboard | profile | ward-view | measure | results | diary

  const [auth, setAuth]               = useState(null);   // { token, user_id }
  const [error, setError]             = useState('');
  const [loading, setLoading]         = useState(false);

  // Profile & Unit Preferences
  const [userProfile, setUserProfile] = useState(null);
  const [heightUnit, setHeightUnit]   = useState('cm');   // 'cm' | 'ft'
  const [weightUnit, setWeightUnit]   = useState('kg');   // 'kg' | 'lbs'

  // Guardian State
  const [guardians, setGuardians]               = useState([]);
  const [guardianRequests, setGuardianRequests] = useState([]);
  const [myWards, setMyWards]                   = useState([]);
  const [showInviteForm, setShowInviteForm]     = useState(false);
  const [inviteEmail, setInviteEmail]           = useState('');
  const [shareResults, setShareResults]         = useState(true);
  const [shareTrends, setShareTrends]           = useState(true);
  const [shareAlerts, setShareAlerts]           = useState(true);

  // Ward Monitoring Portal State
  const [selectedWard, setSelectedWard]         = useState(null);
  const [wardProfile, setWardProfile]           = useState(null);
  const [wardLatestResult, setWardLatestResult] = useState(null);
  const [wardDiaryDate, setWardDiaryDate]       = useState(() => new Date().toISOString().slice(0, 10));
  const [wardDiaryRecords, setWardDiaryRecords] = useState([]);
  const [wardExpandedDiary, setWardExpandedDiary] = useState(null);

  // Measurement State & Real rPPG Telemetry
  const [sessionId, setSessionId]               = useState(null);
  const [liveData, setLiveData]                 = useState(null);
  const [scanStatus, setScanStatus]             = useState('READY');
  const [liveBpmHistory, setLiveBpmHistory]     = useState([]);
  const [results, setResults]                   = useState(null);
  const wsRef = useRef(null);

  // Live Biometric Camera State
  const videoRef = useRef(null);
  const cameraStreamRef = useRef(null);
  const [cameraActive, setCameraActive]         = useState(false);

  useEffect(() => {
    if (page === 'measure') {
      startCamera();
    } else {
      stopCamera();
    }
    return () => stopCamera();
  }, [page]);

  async function startCamera() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 640 }, height: { ideal: 480 }, facingMode: 'user' }
      });
      cameraStreamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
      }
      setCameraActive(true);
    } catch (err) {
      console.warn('Webcam permission error or camera not accessible:', err);
      setCameraActive(false);
    }
  }

  function stopCamera() {
    if (cameraStreamRef.current) {
      cameraStreamRef.current.getTracks().forEach(track => track.stop());
      cameraStreamRef.current = null;
    }
    setCameraActive(false);
  }

  // Real-Time Optical Face ROI Sampler Loop (30 FPS)
  const sampleCanvasRef = useRef(null);
  const frameIntervalRef = useRef(null);

  useEffect(() => {
    if (scanStatus === 'MEASURING') {
      if (!sampleCanvasRef.current) {
        sampleCanvasRef.current = document.createElement('canvas');
        sampleCanvasRef.current.width = 48;
        sampleCanvasRef.current.height = 48;
      }
      const canvas = sampleCanvasRef.current;
      const ctx = canvas.getContext('2d', { willReadFrequently: true });

      let frameCount = 0;
      frameIntervalRef.current = setInterval(() => {
        if (!videoRef.current || videoRef.current.readyState < 2 || !wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
          return;
        }

        const v = videoRef.current;
        const vw = v.videoWidth || 640;
        const vh = v.videoHeight || 480;

        // Crop center forehead / face ROI from live camera
        const cropW = vw * 0.35;
        const cropH = vh * 0.35;
        const cropX = (vw - cropW) / 2;
        const cropY = (vh - cropH) / 2;

        ctx.drawImage(v, cropX, cropY, cropW, cropH, 0, 0, 48, 48);
        const imgData = ctx.getImageData(0, 0, 48, 48).data;

        let totalR = 0, totalG = 0, totalB = 0;
        const numPixels = 48 * 48;
        for (let i = 0; i < imgData.length; i += 4) {
          totalR += imgData[i];
          totalG += imgData[i + 1];
          totalB += imgData[i + 2];
        }

        const r_mean = totalR / numPixels;
        const g_mean = totalG / numPixels;
        const b_mean = totalB / numPixels;
        const luminance = 0.299 * r_mean + 0.587 * g_mean + 0.114 * b_mean;
        frameCount++;

        // Send real optical photon sample to backend POS rPPG DSP Processor
        wsRef.current.send(JSON.stringify({
          type: "frame_sample",
          r: r_mean,
          g: g_mean,
          b: b_mean,
          luminance: luminance,
          frame: frameCount,
          status: "OK"
        }));
      }, 1000 / 30);
    } else {
      if (frameIntervalRef.current) {
        clearInterval(frameIntervalRef.current);
        frameIntervalRef.current = null;
      }
    }

    return () => {
      if (frameIntervalRef.current) {
        clearInterval(frameIntervalRef.current);
        frameIntervalRef.current = null;
      }
    };
  }, [scanStatus]);

  // Diary (My Own)
  const [diaryDate, setDiaryDate]       = useState(() => new Date().toISOString().slice(0, 10));

  const [diaryRecords, setDiaryRecords] = useState([]);
  const [expandedDiary, setExpandedDiary] = useState(null);

  const headers = (extra = {}) => ({
    'Content-Type': 'application/json',
    ...(auth ? { Authorization: `Bearer ${auth.token}` } : {}),
    ...extra,
  });

  const go = (p) => { setError(''); setPage(p); };

  const logout = () => {
    stopCamera();
    setAuth(null); setUserProfile(null); setSessionId(null); setLiveData(null);
    setLiveBpmHistory([]); setScanStatus('READY'); setResults(null);
    setGuardians([]); setMyWards([]); setSelectedWard(null); go('landing');
    if (wsRef.current) wsRef.current.close();
  };

  useEffect(() => () => { if (wsRef.current) wsRef.current.close(); stopCamera(); }, []);


  useEffect(() => {
    if (auth && auth.user_id) {
      fetchProfile();
      fetchGuardians();
    }
  }, [auth]);

  // ── Profile API Calls ───────────────────────────────────
  async function fetchProfile() {
    if (!auth) return;
    try {
      const res = await fetch(`${API}/users/${auth.user_id}/profile`, { headers: headers() });
      if (res.ok) {
        const data = await res.json();
        setUserProfile(data);
      }
    } catch (err) {
      console.error('Failed to fetch profile', err);
    }
  }

  async function fetchGuardians() {
    if (!auth) return;
    try {
      const [gRes, reqRes, wardRes] = await Promise.all([
        fetch(`${API}/guardians`, { headers: headers() }),
        fetch(`${API}/guardians/requests`, { headers: headers() }),
        fetch(`${API}/guardians/wards`, { headers: headers() })
      ]);
      if (gRes.ok) setGuardians(await gRes.json());
      if (reqRes.ok) setGuardianRequests(await reqRes.json());
      if (wardRes.ok) setMyWards(await wardRes.json());
    } catch (err) {
      console.error('Failed to fetch guardians', err);
    }
  }

  async function handleInviteGuardian(e) {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/guardians/invite`, {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify({
          guardian_email: inviteEmail,
          share_results: shareResults,
          share_trends: shareTrends,
          share_alerts: shareAlerts
        })
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Invite failed');
      setInviteEmail('');
      setShowInviteForm(false);
      fetchGuardians();
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function handleRemoveGuardian(relId) {
    if (!confirm('Are you sure you want to revoke access for this guardian?')) return;
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/guardians/${relId}`, {
        method: 'DELETE',
        headers: headers()
      });
      if (!res.ok) throw new Error((await res.json()).detail || 'Failed to remove');
      fetchGuardians();
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function handleRespondRequest(relId, action) {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/guardians/requests/${relId}/respond`, {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify({ action })
      });
      if (!res.ok) throw new Error((await res.json()).detail || 'Failed to respond');
      fetchGuardians();
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  // ── Guardian Ward Monitoring Portal ─────────────────────
  async function openWardPortal(ward) {
    setSelectedWard(ward);
    setLoading(true); setError('');
    try {
      const pRes = await fetch(`${API}/guardians/wards/${ward.ward_id}/profile`, { headers: headers() });
      if (pRes.ok) setWardProfile(await pRes.json());

      if (ward.permissions?.share_results) {
        const rRes = await fetch(`${API}/guardians/wards/${ward.ward_id}/latest-result`, { headers: headers() });
        if (rRes.ok) setWardLatestResult(await rRes.json());
        else setWardLatestResult(null);
      } else {
        setWardLatestResult(null);
      }

      const today = new Date().toISOString().slice(0, 10);
      setWardDiaryDate(today);
      if (ward.permissions?.share_trends) {
        const dRes = await fetch(`${API}/guardians/wards/${ward.ward_id}/diary?date=${today}`, { headers: headers() });
        if (dRes.ok) {
          const dData = await dRes.json();
          setWardDiaryRecords(dData.measurements || []);
        } else {
          setWardDiaryRecords([]);
        }
      } else {
        setWardDiaryRecords([]);
      }

      go('ward-view');
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  }

  async function fetchWardDiary(targetDate) {
    if (!selectedWard) return;
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/guardians/wards/${selectedWard.ward_id}/diary?date=${targetDate}`, { headers: headers() });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Failed to fetch ward diary records');
      setWardDiaryRecords(data.measurements || []);
      setWardDiaryDate(targetDate);
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  // ── Auth handlers ──────────────────────────────────────
  async function handleSignup(e) {
    e.preventDefault();
    const fd = new FormData(e.target);
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/auth/signup`, {
        method: 'POST', headers: headers(),
        body: JSON.stringify({
          full_name:        fd.get('full_name'),
          email:            fd.get('email'),
          password:         fd.get('password'),
          confirm_password: fd.get('confirm_password'),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Signup failed');
      setAuth({ token: data.access_token, user_id: data.user_id });
      go('onboard-basic');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function handleLogin(e) {
    e.preventDefault();
    const fd = new FormData(e.target);
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/auth/login`, {
        method: 'POST', headers: headers(),
        body: JSON.stringify({ email: fd.get('email'), password: fd.get('password') }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Login failed');
      setAuth({ token: data.access_token, user_id: data.user_id });
      go('dashboard');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  // ── Onboarding handlers ────────────────────────────────
  async function handleOnboardBasic(e) {
    e.preventDefault();
    const fd = new FormData(e.target);
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/users/${auth.user_id}/profile/basic`, {
        method: 'PUT', headers: headers(),
        body: JSON.stringify({ date_of_birth: fd.get('dob'), gender: fd.get('gender') }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Update failed');
      go('onboard-body');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function handleOnboardBody(e) {
    e.preventDefault();
    const fd = new FormData(e.target);
    setLoading(true); setError('');
    try {
      const rawHeight = parseFloat(fd.get('height'));
      const height_cm = rawHeight < 3.0 ? rawHeight * 100 : rawHeight;
      const res = await fetch(`${API}/users/${auth.user_id}/profile/body`, {
        method: 'PUT', headers: headers(),
        body: JSON.stringify({ height_cm: height_cm, weight_kg: parseFloat(fd.get('weight')) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Update failed');
      go('onboard-medical');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function handleOnboardMedical(e) {
    e.preventDefault();
    const fd = new FormData(e.target);
    setLoading(true); setError('');
    try {
      const r1 = await fetch(`${API}/users/${auth.user_id}/profile/medical`, {
        method: 'PUT', headers: headers(),
        body: JSON.stringify({ blood_group: fd.get('blood_group') }),
      });
      if (!r1.ok) throw new Error((await r1.json()).detail || 'Update failed');

      const r2 = await fetch(`${API}/users/${auth.user_id}/onboarding/complete`, {
        method: 'POST', headers: headers(),
      });
      if (!r2.ok) throw new Error((await r2.json()).detail || 'Complete failed');

      fetchProfile();
      go('dashboard');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  // ── Measurement handlers ───────────────────────────────
  async function startSession() {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/measurements/session`, {
        method: 'POST', headers: headers(),
        body: JSON.stringify({ user_id: auth.user_id, device: { platform: 'React Web', camera: 'front' } }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Failed to create session');
      setSessionId(data.measurement_id);
      setScanStatus('READY');
      setLiveData(null);
      setLiveBpmHistory([]);
      go('measure');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  function startScan() {
    if (!sessionId) return;
    setLiveBpmHistory([]);

    const ws = new WebSocket(`ws://127.0.0.1:8000/api/v1/measurements/${sessionId}/live`);
    wsRef.current = ws;

    ws.onopen = () => setScanStatus('MEASURING');
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.status === 'PROCESSING') {
        setScanStatus('PROCESSING');
      } else if (data.status === 'COMPLETED') {
        setScanStatus('COMPLETED');
      } else if (data.bpm !== undefined || data.elapsed_time_sec !== undefined) {
        setLiveData(data);
        const bpmVal = data.bpm || data.hr;
        if (bpmVal && bpmVal > 0) {
          setLiveBpmHistory(prev => [...prev, bpmVal]);
        }
      }
    };

    ws.onerror = () => setError('WebSocket error. Is the backend server running?');
  }

  async function fetchResults() {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/measurements/${sessionId}/result`, { headers: headers() });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Failed to fetch results');
      setResults(data);
      go('results');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  async function fetchDiary(targetDate) {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API}/diary?date=${targetDate}`, { headers: headers() });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Failed to fetch diary records');
      setDiaryRecords(data.measurements || []);
      setDiaryDate(targetDate);
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  // ══════════════════════════════════════════════════════
  // RENDER
  // ══════════════════════════════════════════════════════

  // ── Landing ────────────────────────────────────────────
  if (page === 'landing') return (
    <div className="page">
      <div className="card">
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: '2.8rem', fontWeight: 800, letterSpacing: '-1px' }}>
            Face<span style={{ color: 'var(--primary)' }}>Pulse</span>
          </div>
          <p className="card-sub" style={{ marginBottom: 0 }}>
            Contactless vitals measurement powered by real rPPG
          </p>
        </div>
        <button className="btn btn-primary" onClick={() => go('signup')}>Create Account</button>
        <button className="btn btn-ghost" style={{ marginTop: 10 }} onClick={() => go('login')}>Log In</button>
        <div className="divider">or</div>
        <button className="btn btn-ghost" onClick={async () => {
          try {
            const r = await fetch(`http://127.0.0.1:8000/health`);
            const d = await r.json();
            alert('✅ Backend alive: ' + JSON.stringify(d));
          } catch { alert('❌ Cannot reach backend. Start Uvicorn!'); }
        }}>Ping Server (/health)</button>
      </div>
    </div>
  );

  // ── Signup ─────────────────────────────────────────────
  if (page === 'signup') return (
    <div className="page">
      <div className="card">
        <NavBar />
        <div className="card-title">Create account</div>
        <div className="card-sub">Get started with FacePulse</div>
        <form onSubmit={handleSignup}>
          <div className="form-group">
            <label>Full Name</label>
            <input name="full_name" placeholder="John Doe" required />
          </div>
          <div className="form-group">
            <label>Email</label>
            <input name="email" type="email" placeholder="you@example.com" required />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input name="password" type="password" placeholder="Min 6 characters" required />
          </div>
          <div className="form-group">
            <label>Confirm Password</label>
            <input name="confirm_password" type="password" placeholder="Repeat password" required />
          </div>
          {error && <div className="alert alert-error">{error}</div>}
          <button className="btn btn-primary" type="submit" disabled={loading}>
            {loading ? 'Creating...' : 'Create Account'}
          </button>
        </form>
        <div className="link-text" onClick={() => go('login')}>Already have an account? Log in</div>
      </div>
    </div>
  );

  // ── Login ──────────────────────────────────────────────
  if (page === 'login') return (
    <div className="page">
      <div className="card">
        <NavBar />
        <div className="card-title">Welcome back</div>
        <div className="card-sub">Log in to your FacePulse account</div>
        <form onSubmit={handleLogin}>
          <div className="form-group">
            <label>Email</label>
            <input name="email" type="email" placeholder="you@example.com" required />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input name="password" type="password" placeholder="Your password" required />
          </div>
          {error && <div className="alert alert-error">{error}</div>}
          <button className="btn btn-primary" type="submit" disabled={loading}>
            {loading ? 'Logging in...' : 'Log In'}
          </button>
        </form>
        <div className="link-text" onClick={() => go('signup')}>Don't have an account? Sign up</div>
      </div>
    </div>
  );

  // ── Onboarding: Basic ──────────────────────────────────
  if (page === 'onboard-basic') return (
    <div className="page">
      <div className="card">
        <NavBar title="Onboarding" />
        <StepBar total={3} current={0} />
        <div className="card-title">Basic Info</div>
        <div className="card-sub">Tell us a little about yourself</div>
        <form onSubmit={handleOnboardBasic}>
          <div className="form-group">
            <label>Date of Birth</label>
            <input name="dob" type="date" required />
          </div>
          <div className="form-group">
            <label>Gender</label>
            <select name="gender" required>
              <option value="">Select gender</option>
              <option value="MALE">Male</option>
              <option value="FEMALE">Female</option>
              <option value="OTHER">Other</option>
              <option value="PREFER_NOT_TO_SAY">Prefer not to say</option>
            </select>
          </div>
          {error && <div className="alert alert-error">{error}</div>}
          <button className="btn btn-primary" type="submit" disabled={loading}>
            {loading ? 'Saving...' : 'Next →'}
          </button>
        </form>
      </div>
    </div>
  );

  // ── Onboarding: Body ───────────────────────────────────
  if (page === 'onboard-body') return (
    <div className="page">
      <div className="card">
        <NavBar title="Onboarding" />
        <StepBar total={3} current={1} />
        <div className="card-title">Body Metrics</div>
        <div className="card-sub">BMI will be calculated automatically</div>
        <form onSubmit={handleOnboardBody}>
          <div className="form-group">
            <label>Height (cm or meters)</label>
            <input name="height" type="number" step="0.1" min="0.5" max="250" placeholder="e.g. 175 cm (or 1.75 m)" required />
          </div>
          <div className="form-group">
            <label>Weight (kg)</label>
            <input name="weight" type="number" step="0.1" min="1" max="300" placeholder="e.g. 70.5" required />
          </div>
          {error && <div className="alert alert-error">{error}</div>}
          <button className="btn btn-primary" type="submit" disabled={loading}>
            {loading ? 'Saving...' : 'Next →'}
          </button>
        </form>
      </div>
    </div>
  );

  // ── Onboarding: Medical ────────────────────────────────
  if (page === 'onboard-medical') return (
    <div className="page">
      <div className="card">
        <NavBar title="Onboarding" />
        <StepBar total={3} current={2} />
        <div className="card-title">Medical Info</div>
        <div className="card-sub">Last step — you're almost ready!</div>
        <form onSubmit={handleOnboardMedical}>
          <div className="form-group">
            <label>Blood Group</label>
            <select name="blood_group" required>
              <option value="">Select blood group</option>
              {['A+','A-','B+','B-','AB+','AB-','O+','O-'].map(g => (
                <option key={g} value={g}>{g}</option>
              ))}
            </select>
          </div>
          {error && <div className="alert alert-error">{error}</div>}
          <button className="btn btn-success" type="submit" disabled={loading}>
            {loading ? 'Finishing...' : '✓ Complete Onboarding'}
          </button>
        </form>
      </div>
    </div>
  );

  // ── Dashboard ──────────────────────────────────────────
  if (page === 'dashboard') {
    const age = computeAge(userProfile?.date_of_birth);
    const initials = getInitials(userProfile?.full_name);

    return (
      <div className="page">
        <div className="card">
          <NavBar 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={initials}
            onBrandClick={() => go('dashboard')}
          />

          {/* Profile Summary Card */}
          <div className="profile-card">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div className="avatar" style={{ width: 44, height: 44, fontSize: '1.1rem' }} onClick={() => go('profile')}>
                  {initials}
                </div>
                <div>
                  <div style={{ fontWeight: 800, fontSize: '1.15rem' }}>{userProfile?.full_name || 'FacePulse User'}</div>
                  <div style={{ color: 'var(--muted)', fontSize: '0.8rem' }}>{userProfile?.email}</div>
                </div>
              </div>
              <button className="btn btn-ghost btn-sm" onClick={() => go('profile')}>
                ⚙ Profile
              </button>
            </div>

            {/* Vitals & Demographics Badges */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: '0.85rem' }}>
              <div className="metric-item" style={{ padding: 10 }}>
                <div className="metric-label">Age & DOB</div>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>
                  {age !== null ? `${age} yrs` : '--'}
                  <span style={{ fontSize: '0.75rem', color: 'var(--muted)', fontWeight: 500, marginLeft: 4 }}>
                    ({userProfile?.date_of_birth || 'N/A'})
                  </span>
                </div>
              </div>

              <div className="metric-item" style={{ padding: 10 }}>
                <div className="metric-label">Sex & Blood Group</div>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>
                  {userProfile?.gender || '--'} · <span style={{ color: '#f87171' }}>{userProfile?.blood_group || '--'}</span>
                </div>
              </div>

              <div className="metric-item" style={{ padding: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div className="metric-label">Height</div>
                  <div className="unit-toggle">
                    <button className={`unit-btn ${heightUnit === 'cm' ? 'active' : ''}`} onClick={() => setHeightUnit('cm')}>cm</button>
                    <button className={`unit-btn ${heightUnit === 'ft' ? 'active' : ''}`} onClick={() => setHeightUnit('ft')}>ft</button>
                  </div>
                </div>
                <div style={{ fontWeight: 700, fontSize: '1.05rem', marginTop: 4 }}>
                  {formatHeight(userProfile?.height_cm, heightUnit)}
                </div>
              </div>

              <div className="metric-item" style={{ padding: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div className="metric-label">Weight</div>
                  <div className="unit-toggle">
                    <button className={`unit-btn ${weightUnit === 'kg' ? 'active' : ''}`} onClick={() => setWeightUnit('kg')}>kg</button>
                    <button className={`unit-btn ${weightUnit === 'lbs' ? 'active' : ''}`} onClick={() => setWeightUnit('lbs')}>lbs</button>
                  </div>
                </div>
                <div style={{ fontWeight: 700, fontSize: '1.05rem', marginTop: 4 }}>
                  {formatWeight(userProfile?.weight_kg, weightUnit)}
                </div>
              </div>
            </div>

            {userProfile?.bmi && (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 12, padding: '8px 12px', background: 'rgba(255,255,255,0.03)', borderRadius: 8 }}>
                <span style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>Body Mass Index (BMI):</span>
                <span style={{ fontWeight: 700, fontSize: '0.9rem' }}>
                  {userProfile.bmi} <span className="pill" style={{ marginLeft: 6 }}>{userProfile.bmi_classification || 'Normal'}</span>
                </span>
              </div>
            )}
          </div>

          {/* Monitored Wards Section */}
          {myWards.length > 0 && (
            <div className="profile-card" style={{ borderColor: 'rgba(99, 102, 241, 0.4)', background: 'rgba(99, 102, 241, 0.05)' }}>
              <div className="metric-label" style={{ color: 'var(--primary)', marginBottom: 8 }}>
                👥 Monitored Family & Wards ({myWards.length})
              </div>
              <p style={{ color: 'var(--muted)', fontSize: '0.8rem', marginBottom: 12 }}>
                You have active access to view health records for the following people:
              </p>
              {myWards.map(w => (
                <div key={w.relationship_id} className="guardian-item" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{w.ward_name}</div>
                    <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>{w.ward_email}</div>
                    <div style={{ marginTop: 4 }}>
                      {w.permissions?.share_results && <span className="pill">Results</span>}
                      {w.permissions?.share_trends && <span className="pill">Diary</span>}
                      {w.permissions?.share_alerts && <span className="pill">Alerts</span>}
                    </div>
                  </div>
                  <button className="btn btn-primary btn-sm" onClick={() => openWardPortal(w)}>
                    📊 View Health Records →
                  </button>
                </div>
              ))}
            </div>
          )}

          <div className="card-title">Ready for your scan?</div>
          <div className="card-sub">Measure heart rate BPM, HRV, and signal quality with real rPPG</div>

          {error && <div className="alert alert-error">{error}</div>}

          <button className="btn btn-primary" onClick={startSession} disabled={loading}>
            {loading ? 'Starting...' : '▶  Start New Scan'}
          </button>
          
          <button className="btn btn-ghost" style={{ marginTop: 12 }} onClick={() => {
            const today = new Date().toISOString().slice(0, 10);
            fetchDiary(today);
            go('diary');
          }} disabled={loading}>
            📅 Open Vitals Diary
          </button>
        </div>
      </div>
    );
  }

  // ── Profile Page ───────────────────────────────────────
  if (page === 'profile') {
    const age = computeAge(userProfile?.date_of_birth);
    const initials = getInitials(userProfile?.full_name);

    return (
      <div className="page">
        <div className="card">
          <NavBar 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={initials}
            onBrandClick={() => go('dashboard')}
          />

          {/* Large Avatar Header */}
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <div className="avatar-lg">{initials}</div>
            <div className="card-title" style={{ marginBottom: 2 }}>{userProfile?.full_name || 'My Profile'}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>{userProfile?.email}</div>
          </div>

          {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

          {/* Unit Toggle Preferences */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div className="metric-label" style={{ marginBottom: 12 }}>⚙️ Unit Preferences</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.85rem' }}>Height Unit:</span>
                <div className="unit-toggle">
                  <button className={`unit-btn ${heightUnit === 'cm' ? 'active' : ''}`} onClick={() => setHeightUnit('cm')}>cm</button>
                  <button className={`unit-btn ${heightUnit === 'ft' ? 'active' : ''}`} onClick={() => setHeightUnit('ft')}>ft/in</button>
                </div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.85rem' }}>Weight Unit:</span>
                <div className="unit-toggle">
                  <button className={`unit-btn ${weightUnit === 'kg' ? 'active' : ''}`} onClick={() => setWeightUnit('kg')}>kg</button>
                  <button className={`unit-btn ${weightUnit === 'lbs' ? 'active' : ''}`} onClick={() => setWeightUnit('lbs')}>lbs</button>
                </div>
              </div>
            </div>
          </div>

          {/* Personal & Health Details */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div className="metric-label" style={{ marginBottom: 12 }}>📋 Demographics & Biometrics</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, fontSize: '0.9rem' }}>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>DATE OF BIRTH</span>
                <strong>{userProfile?.date_of_birth || 'Not set'}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>COMPUTED AGE</span>
                <strong>{age !== null ? `${age} years old` : 'N/A'}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>SEX / GENDER</span>
                <strong>{userProfile?.gender || 'Not set'}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>BLOOD GROUP</span>
                <strong style={{ color: '#f87171' }}>{userProfile?.blood_group || 'Not set'}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>HEIGHT ({heightUnit.toUpperCase()})</span>
                <strong>{formatHeight(userProfile?.height_cm, heightUnit)}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>WEIGHT ({weightUnit.toUpperCase()})</span>
                <strong>{formatWeight(userProfile?.weight_kg, weightUnit)}</strong>
              </div>
            </div>
          </div>

          {/* Monitored Wards */}
          {myWards.length > 0 && (
            <div className="profile-card" style={{ marginBottom: 16, borderColor: 'rgba(99, 102, 241, 0.4)' }}>
              <div className="metric-label" style={{ color: 'var(--primary)', marginBottom: 12 }}>
                👥 Wards I am Monitoring ({myWards.length})
              </div>
              {myWards.map(w => (
                <div key={w.relationship_id} className="guardian-item" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{w.ward_name}</div>
                    <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>{w.ward_email}</div>
                    <div style={{ marginTop: 4 }}>
                      {w.permissions?.share_results && <span className="pill">Results</span>}
                      {w.permissions?.share_trends && <span className="pill">Diary</span>}
                      {w.permissions?.share_alerts && <span className="pill">Alerts</span>}
                    </div>
                  </div>
                  <button className="btn btn-primary btn-sm" onClick={() => openWardPortal(w)}>
                    View Records →
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Guardians & Family Access */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <div className="metric-label" style={{ marginBottom: 0 }}>🛡 My Guardians ({guardians.length})</div>
              <button className="btn btn-ghost btn-sm" onClick={() => setShowInviteForm(!showInviteForm)}>
                {showInviteForm ? 'Cancel' : '+ Add Guardian'}
              </button>
            </div>

            {/* Invite Form */}
            {showInviteForm && (
              <form onSubmit={handleInviteGuardian} style={{ background: 'var(--surface)', padding: 14, borderRadius: 8, marginBottom: 14, border: '1px solid var(--border)' }}>
                <div className="form-group" style={{ marginBottom: 10 }}>
                  <label>Guardian User Email</label>
                  <input 
                    type="email" 
                    placeholder="guardian@example.com" 
                    value={inviteEmail} 
                    onChange={e => setInviteEmail(e.target.value)} 
                    required 
                  />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6, fontSize: '0.8rem', color: 'var(--muted)', marginBottom: 12 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', textTransform: 'none' }}>
                    <input type="checkbox" checked={shareResults} onChange={e => setShareResults(e.target.checked)} style={{ width: 'auto' }} />
                    Share Measurement Results
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', textTransform: 'none' }}>
                    <input type="checkbox" checked={shareTrends} onChange={e => setShareTrends(e.target.checked)} style={{ width: 'auto' }} />
                    Share Vitals Diary & Trends
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', textTransform: 'none' }}>
                    <input type="checkbox" checked={shareAlerts} onChange={e => setShareAlerts(e.target.checked)} style={{ width: 'auto' }} />
                    Share Vitals Anomaly Alerts
                  </label>
                </div>
                <button className="btn btn-primary btn-sm" type="submit" disabled={loading}>
                  {loading ? 'Inviting...' : 'Send Guardian Invite'}
                </button>
              </form>
            )}

            {/* Guardians List */}
            {guardians.length === 0 ? (
              <div style={{ color: 'var(--muted)', fontSize: '0.85rem', textAlign: 'center', padding: '10px 0' }}>
                No guardians linked. Add a trusted family member or doctor to share your health metrics.
              </div>
            ) : (
              <div>
                {guardians.map(g => (
                  <div key={g.id} className="guardian-item" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>
                        {g.guardian_name || g.guardian_email}
                        <span className={`badge ${g.status === 'ACCEPTED' ? 'badge-completed' : 'badge-processing'}`} style={{ marginLeft: 8, fontSize: '0.65rem' }}>
                          {g.status}
                        </span>
                      </div>
                      <div style={{ color: 'var(--muted)', fontSize: '0.75rem', marginTop: 2 }}>{g.guardian_email}</div>
                      <div style={{ marginTop: 6 }}>
                        {g.share_results && <span className="pill">Results</span>}
                        {g.share_trends && <span className="pill">Trends</span>}
                        {g.share_alerts && <span className="pill">Alerts</span>}
                      </div>
                    </div>
                    <button 
                      className="btn btn-ghost btn-sm" 
                      style={{ color: '#f87171', borderColor: '#ef444450' }}
                      onClick={() => handleRemoveGuardian(g.id)}
                    >
                      Remove
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Incoming Requests */}
            {guardianRequests.length > 0 && (
              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 14 }}>
                <div className="metric-label">📩 Incoming Requests ({guardianRequests.length})</div>
                {guardianRequests.map(r => (
                  <div key={r.id} className="guardian-item" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 8 }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>{r.ward_name || r.ward_email}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>Wants you as their guardian</div>
                    </div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-success btn-sm" onClick={() => handleRespondRequest(r.id, 'ACCEPT')}>Accept</button>
                      <button className="btn btn-ghost btn-sm" onClick={() => handleRespondRequest(r.id, 'REJECT')}>Reject</button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <button className="btn btn-ghost" onClick={() => go('dashboard')}>
            ← Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  // ── Ward Health Portal (Guardian's View) ─────────────────────
  if (page === 'ward-view') {
    const wardAge = computeAge(wardProfile?.date_of_birth);
    const initials = getInitials(wardProfile?.full_name || selectedWard?.ward_name);

    return (
      <div className="page">
        <div className="card">
          <NavBar 
            title="Guardian Portal" 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={getInitials(userProfile?.full_name)}
            onBrandClick={() => go('dashboard')}
          />

          {/* Ward Header */}
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <div className="avatar-lg" style={{ background: 'linear-gradient(135deg, #3b82f6, #6366f1)' }}>
              {initials}
            </div>
            <div className="card-title" style={{ marginBottom: 2 }}>{wardProfile?.full_name || selectedWard?.ward_name}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>{wardProfile?.email || selectedWard?.ward_email}</div>
            <div style={{ marginTop: 8 }}>
              <span className="badge badge-completed" style={{ fontSize: '0.7rem' }}>Authorized Ward</span>
            </div>
          </div>

          {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

          {/* Ward Biometrics Snapshot */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div className="metric-label" style={{ marginBottom: 12 }}>👤 Ward Demographic Snapshot</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: '0.85rem' }}>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>AGE / DOB</span>
                <strong>{wardAge !== null ? `${wardAge} yrs` : '--'} ({wardProfile?.date_of_birth || 'N/A'})</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>GENDER & BLOOD GROUP</span>
                <strong>{wardProfile?.gender || '--'} · <span style={{ color: '#f87171' }}>{wardProfile?.blood_group || '--'}</span></strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>HEIGHT</span>
                <strong>{formatHeight(wardProfile?.height_cm, heightUnit)}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--muted)', fontSize: '0.75rem', display: 'block' }}>WEIGHT</span>
                <strong>{formatWeight(wardProfile?.weight_kg, weightUnit)}</strong>
              </div>
              {wardProfile?.bmi && (
                <div style={{ gridColumn: '1 / -1', marginTop: 4 }}>
                  <span style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>BMI: </span>
                  <strong>{wardProfile.bmi}</strong> <span className="pill">{wardProfile.bmi_classification || 'Normal'}</span>
                </div>
              )}
            </div>
          </div>

          {/* Section 1: Latest Measurement Report */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div className="metric-label" style={{ marginBottom: 12 }}>📊 Latest Measurement Report</div>
            {!selectedWard?.permissions?.share_results ? (
              <div className="instruction-box" style={{ background: 'rgba(245, 158, 11, 0.1)', borderColor: 'rgba(245, 158, 11, 0.3)', color: '#fcd34d' }}>
                🔒 The ward has not enabled the "share_results" permission for you.
              </div>
            ) : !wardLatestResult ? (
              <div style={{ color: 'var(--muted)', fontSize: '0.85rem', textAlign: 'center', padding: '12px 0' }}>
                No completed measurement scans recorded yet for this ward.
              </div>
            ) : (
              <div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 12 }}>
                  <div className="metric-item">
                    <div className="metric-label">Average BPM</div>
                    <div className="metric-value" style={{ color: '#f87171' }}>
                      {wardLatestResult.average_bpm || wardLatestResult.bpm || wardLatestResult.vitals?.hr} bpm
                    </div>
                  </div>
                  <div className="metric-item">
                    <div className="metric-label">Signal Quality</div>
                    <div className="metric-value">
                      <span className={`badge ${getQualityBadgeClass(wardLatestResult.signal_quality || wardLatestResult.signal_quality_level)}`}>
                        {wardLatestResult.signal_quality || wardLatestResult.signal_quality_level || 'GOOD'}
                      </span>
                    </div>
                  </div>
                  <div className="metric-item">
                    <div className="metric-label">Avg SNR (dB)</div>
                    <div className="metric-value">{wardLatestResult.avg_snr_db ?? '--'} dB</div>
                  </div>
                  <div className="metric-item">
                    <div className="metric-label">Video Quality</div>
                    <div className="metric-value">{wardLatestResult.video_quality || 'GOOD'}</div>
                  </div>
                </div>

                <div className="result-row">
                  <span className="result-label">Guidance Recommendation</span>
                  <span className="result-val" style={{ fontSize: '0.85rem', textAlign: 'right', maxWidth: '65%' }}>
                    {wardLatestResult.recommendation || wardLatestResult.analysis?.recommendation || 'Conditions normal'}
                  </span>
                </div>
              </div>
            )}
          </div>

          {/* Section 2: Vitals Diary */}
          <div className="profile-card" style={{ marginBottom: 16 }}>
            <div className="metric-label" style={{ marginBottom: 12 }}>📅 Ward's Vitals Diary</div>
            {!selectedWard?.permissions?.share_trends ? (
              <div className="instruction-box" style={{ background: 'rgba(245, 158, 11, 0.1)', borderColor: 'rgba(245, 158, 11, 0.3)', color: '#fcd34d' }}>
                🔒 The ward has not enabled the "share_trends" permission for you.
              </div>
            ) : (
              <div>
                <div className="form-group" style={{ marginBottom: 12 }}>
                  <label>Select Date</label>
                  <input 
                    type="date" 
                    value={wardDiaryDate} 
                    onChange={e => {
                      const sel = e.target.value;
                      setWardDiaryDate(sel);
                      if (sel) fetchWardDiary(sel);
                    }} 
                  />
                </div>

                {wardDiaryRecords.length === 0 ? (
                  <div style={{ color: 'var(--muted)', fontSize: '0.85rem', textAlign: 'center', padding: '12px 0' }}>
                    No measurements recorded by ward on {wardDiaryDate}.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                    {wardDiaryRecords.map((m, idx) => (
                      <div key={m.measurement_id || idx}
                        className="metric-item"
                        style={{ textAlign: 'left', padding: '14px', cursor: 'pointer' }}
                        onClick={() => setWardExpandedDiary(wardExpandedDiary === m.measurement_id ? null : m.measurement_id)}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6, fontSize: '0.75rem', color: 'var(--muted)' }}>
                          <span>Session: {m.measurement_id?.slice(0, 12)}...</span>
                          <span>{m.recorded_at ? new Date(m.recorded_at).toLocaleTimeString() : ''} {wardExpandedDiary === m.measurement_id ? '▲' : '▼'}</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <div>
                            <div className="metric-label">Heart Rate (BPM)</div>
                            <div style={{ fontWeight: 700, fontSize: '1.1rem', color: '#f87171' }}>{m.heart_rate} bpm</div>
                          </div>
                          <span className="badge badge-completed">Recorded</span>
                        </div>

                        {/* Expanded Graphs */}
                        {wardExpandedDiary === m.measurement_id && m.hr_series && (
                          <div style={{ marginTop: 16, borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: 14 }} onClick={e => e.stopPropagation()}>
                            <LineChart data={m.hr_series} color="#f87171" label="BPM Trajectory" unit=" bpm" />
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          <button className="btn btn-ghost" onClick={() => go('dashboard')}>
            ← Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  // ── Diary ───────────────────────────────────────────────
  if (page === 'diary') {
    const initials = getInitials(userProfile?.full_name);
    return (
      <div className="page">
        <div className="card">
          <NavBar 
            title="Diary" 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={initials}
            onBrandClick={() => go('dashboard')}
          />
          <div className="card-title">Vitals Diary</div>
          <div className="card-sub">Select a date to view past measurements</div>

          <div className="form-group" style={{ marginTop: 16 }}>
            <label>Select Date</label>
            <input 
              type="date" 
              value={diaryDate} 
              onChange={(e) => {
                const selected = e.target.value;
                setDiaryDate(selected);
                if (selected) fetchDiary(selected);
              }} 
            />
          </div>

          {error && <div className="alert alert-error" style={{ marginTop: 12 }}>{error}</div>}

          {loading ? (
            <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--muted)' }}>
              Loading diary records...
            </div>
          ) : diaryRecords.length === 0 ? (
            <div className="instruction-box" style={{ marginTop: 16, textAlign: 'center' }}>
              No measurements recorded on {diaryDate}.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 16 }}>
              {diaryRecords.map((m, idx) => (
                <div key={m.measurement_id || idx}
                  className="metric-item"
                  style={{ textAlign: 'left', padding: '16px', cursor: 'pointer', transition: 'box-shadow 0.2s' }}
                  onClick={() => setExpandedDiary(expandedDiary === m.measurement_id ? null : m.measurement_id)}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8, fontSize: '0.8rem', color: 'var(--muted)' }}>
                    <span>Session: {m.measurement_id?.slice(0, 12)}...</span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      {m.recorded_at ? new Date(m.recorded_at).toLocaleTimeString() : ''}
                      <span style={{ fontSize: '0.7rem', opacity: 0.6 }}>{expandedDiary === m.measurement_id ? '▲ hide' : '▼ trend'}</span>
                    </span>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div className="metric-label">Heart Rate</div>
                      <div className="metric-value" style={{ fontSize: '1.2rem', color: '#f87171' }}>{m.heart_rate} bpm</div>
                    </div>
                    <span className="badge badge-completed">Saved</span>
                  </div>

                  {expandedDiary === m.measurement_id && m.hr_series && m.hr_series.length > 0 && (
                    <div style={{ marginTop: 16, borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: 14 }}
                      onClick={e => e.stopPropagation()}
                    >
                      <LineChart
                        data={m.hr_series}
                        color="#f87171"
                        label="40-Second BPM Trajectory"
                        unit=" bpm"
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          <button className="btn btn-ghost" style={{ marginTop: 24 }} onClick={() => go('dashboard')}>
            ← Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  // ── Measure (Real rPPG WebSocket Telemetry) ──────────────
  if (page === 'measure') {
    const initials = getInitials(userProfile?.full_name);
    const elapsed = liveData?.elapsed_time_sec || 0;
    const progressPercent = Math.min(100, Math.round((elapsed / 40) * 100));
    
    const snrVal = liveData?.quality?.snr_db ?? '--';
    const sigQuality = liveData?.quality?.signal_quality || 'GOOD';
    const lumVal = liveData?.quality?.luminance ?? '--';
    const videoQuality = liveData?.quality?.video_quality || 'GOOD';
    const recommendation = liveData?.recommendation || 'Hold your face steady and look directly at camera';

    return (
      <div className="page">
        <div className="card" style={{ maxWidth: 500 }}>
          <NavBar 
            title="Real rPPG Scan" 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={initials}
            onBrandClick={() => go('dashboard')}
          />

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div>
              <div className="card-title" style={{ marginBottom: 2 }}>rPPG Live Measurement</div>
              <div style={{ color: 'var(--muted)', fontSize: '0.78rem' }}>Session: {sessionId?.slice(0, 18)}...</div>
            </div>
            {scanStatus !== 'READY' && (
              <span className={`badge badge-${scanStatus.toLowerCase()}`}>{scanStatus}</span>
            )}
          </div>

          {/* Live Biometric Camera HUD */}
          <div className="camera-container">
            <video 
              ref={videoRef} 
              autoPlay 
              playsInline 
              muted 
              className="camera-video" 
            />
            <div className="camera-overlay">
              <div className={`face-guide-oval ${scanStatus === 'MEASURING' ? 'measuring' : ''}`}>
                {scanStatus === 'MEASURING' && <div className="scan-line" />}
              </div>
            </div>
            <div className="camera-status-pill">
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: cameraActive ? '#10b981' : '#ef4444', display: 'inline-block' }}></span>
              <span>{cameraActive ? (scanStatus === 'MEASURING' ? 'Scanning Face ROI...' : 'Camera Active') : 'Camera Offline (Check Permissions)'}</span>
            </div>
          </div>

          {/* Start Button */}
          {scanStatus === 'READY' && (
            <div style={{ textAlign: 'center', marginTop: 12 }}>
              <div className="instruction-box" style={{ marginBottom: 14, textAlign: 'center', justifyContent: 'center' }}>
                Position your face inside the guide oval with good lighting and remain still.
              </div>
              <button className="btn btn-primary" onClick={startScan}>
                ▶ Start 40-Second Live Scan
              </button>
            </div>
          )}

          {/* Active Measuring State */}
          {scanStatus !== 'READY' && (
            <div style={{ marginTop: 14 }}>

              {/* Progress Bar */}
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 2 }}>
                <span>Scan Progress</span>
                <span style={{ fontWeight: 700, color: 'var(--text)' }}>{elapsed}s / 40s ({progressPercent}%)</span>
              </div>
              <div className="progress-track" style={{ marginBottom: 14 }}>
                <div className="progress-fill" style={{ width: `${progressPercent}%` }}></div>
              </div>

              {/* Dynamic Priority Recommendation Box */}
              <div className="instruction-box" style={{ marginTop: 0, marginBottom: 16, background: sigQuality === 'POOR' || videoQuality !== 'GOOD' ? 'rgba(239, 68, 68, 0.12)' : 'rgba(16, 185, 129, 0.12)', borderColor: sigQuality === 'POOR' || videoQuality !== 'GOOD' ? 'rgba(239, 68, 68, 0.3)' : 'rgba(16, 185, 129, 0.3)', color: sigQuality === 'POOR' || videoQuality !== 'GOOD' ? '#fca5a5' : '#6ee7b7' }}>
                {scanStatus === 'PROCESSING'
                  ? '⏳ Aggregating observations & calculating final metrics...'
                  : scanStatus === 'COMPLETED'
                  ? '✅ Measurement complete! High-confidence BPM processed. Redirecting...'
                  : (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <span className="heart-beat-icon">💡</span>
                      <span>{recommendation}</span>
                    </div>
                  )}
              </div>

              {/* Primary Real-Time Metric: Live BPM */}
              <div style={{ background: 'var(--surface2)', padding: '16px', borderRadius: 12, border: '1px solid var(--border)', textAlign: 'center', marginBottom: 14 }}>
                <div className="metric-label" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: '0.85rem' }}>
                  <span className="heart-beat-icon">❤️</span> LIVE HEART RATE
                </div>
                <div style={{ fontSize: '2.8rem', fontWeight: 800, color: '#f87171', margin: '4px 0' }}>
                  {liveData?.bpm ? liveData.bpm.toFixed(1) : '--'}
                  <span style={{ fontSize: '1rem', color: 'var(--muted)', fontWeight: 500, marginLeft: 4 }}>BPM</span>
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>
                  Model Output Stream (1 tick / sec)
                </div>
              </div>

              {/* Real-time BPM Trend Graph */}
              <div style={{ background: 'var(--surface2)', padding: '14px', borderRadius: 10, border: '1px solid var(--border)', marginBottom: 14 }}>
                <LineChart 
                  data={liveBpmHistory} 
                  color="#f87171" 
                  label="Live BPM Trend" 
                  unit=" bpm" 
                  height={80} 
                />
              </div>

              {/* Real-time SNR and Luminance Quality Meters */}
              <div className="profile-card" style={{ padding: 14, marginBottom: 14 }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <div className="metric-label">Signal Quality (SNR)</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                      <span className={`badge ${getQualityBadgeClass(sigQuality)}`}>{sigQuality}</span>
                      <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{snrVal} dB</span>
                    </div>
                  </div>
                  <div>
                    <div className="metric-label">Video Luminance</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                      <span className={`badge ${getQualityBadgeClass(videoQuality)}`}>{videoQuality}</span>
                      <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{lumVal}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {scanStatus === 'COMPLETED' && (
            <div style={{ marginTop: 18, textAlign: 'center' }}>
              <div className="instruction-box" style={{ background: 'rgba(16, 185, 129, 0.12)', borderColor: 'rgba(16, 185, 129, 0.4)', color: '#6ee7b7', marginBottom: 14 }}>
                🎉 <strong>40-Second Scan Successfully Completed!</strong>
                <div style={{ fontSize: '0.8rem', marginTop: 4, opacity: 0.9 }}>
                  Optical rPPG signal data aggregated. Ready for diagnostic analysis.
                </div>
              </div>
              <button 
                className="btn btn-success" 
                style={{ 
                  width: '100%', 
                  padding: '14px', 
                  fontSize: '1.05rem', 
                  fontWeight: 800, 
                  boxShadow: '0 0 20px rgba(16, 185, 129, 0.35)' 
                }} 
                onClick={fetchResults} 
                disabled={loading}
              >
                {loading ? 'Analyzing Vitals...' : '👉 Click Here to See the Results →'}
              </button>
            </div>
          )}

          {error && <div className="alert alert-error" style={{ marginTop: 12 }}>{error}</div>}
        </div>
      </div>
    );
  }

  // ── Results (Final Real rPPG Result Page) ────────────────
  if (page === 'results') {
    const initials = getInitials(userProfile?.full_name);
    const avgBpm = results?.average_bpm || results?.bpm || results?.vitals?.hr || 0;
    const minBpm = results?.min_bpm || 0;
    const maxBpm = results?.max_bpm || 0;
    const hrvVal = results?.hrv_ms || 0;
    const hrRange = results?.hr_range || (maxBpm - minBpm > 0 ? (maxBpm - minBpm).toFixed(1) : 0);
    const interp = results?.interpretations || {};

    return (
      <div className="page">
        <div className="card" style={{ maxWidth: 540 }}>
          <NavBar 
            title="Analysis Report" 
            onLogout={logout} 
            onProfile={() => go('profile')} 
            profileInitials={initials}
            onBrandClick={() => go('dashboard')}
          />

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <div className="card-title" style={{ color: 'var(--success)', marginBottom: 0 }}>Vitals Analysis Report</div>
            <span className={`badge ${getQualityBadgeClass(results?.signal_quality)}`}>
              {results?.signal_quality || 'GOOD'} SIGNAL
            </span>
          </div>
          <div className="card-sub">Session ID: {sessionId?.slice(0, 18)}...</div>

          {results && (
            <div style={{ marginTop: 16 }}>
              {/* Primary Average Heart Rate Card */}
              <div style={{ background: 'linear-gradient(135deg, rgba(248, 113, 113, 0.12), rgba(99, 102, 241, 0.12))', padding: '18px', borderRadius: 12, border: '1px solid rgba(248, 113, 113, 0.3)', textAlign: 'center', marginBottom: 14 }}>
                <div className="metric-label" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: '0.85rem' }}>
                  <span className="heart-beat-icon">❤️</span> AVERAGE HEART RATE
                </div>
                <div style={{ fontSize: '3.2rem', fontWeight: 800, color: '#f87171', margin: '4px 0' }}>
                  {typeof avgBpm === 'number' ? avgBpm.toFixed(1) : avgBpm}
                  <span style={{ fontSize: '1rem', color: 'var(--muted)', fontWeight: 500, marginLeft: 4 }}>BPM</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 4 }}>
                  <span className="pill" style={{ background: 'rgba(248, 113, 113, 0.15)', color: '#fca5a5', borderColor: 'rgba(248, 113, 113, 0.3)' }}>
                    {results.hr_zone || (avgBpm < 60 ? 'Resting / Low' : avgBpm <= 100 ? 'Normal Resting Zone' : 'Elevated')}
                  </span>
                </div>
              </div>

              {/* 4-Metric Vitals HUD: High HR, Low HR, HRV (ms), HR Spread */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 8, marginBottom: 14 }}>
                <div className="metric-item" style={{ padding: '10px 6px' }}>
                  <div className="metric-label" style={{ fontSize: '0.68rem' }}>LOW HR</div>
                  <div className="metric-value" style={{ fontSize: '1.1rem', color: '#60a5fa' }}>
                    {minBpm ? minBpm.toFixed(1) : '--'}
                  </div>
                  <span style={{ fontSize: '0.65rem', color: 'var(--muted)' }}>bpm</span>
                </div>

                <div className="metric-item" style={{ padding: '10px 6px' }}>
                  <div className="metric-label" style={{ fontSize: '0.68rem' }}>HIGH HR</div>
                  <div className="metric-value" style={{ fontSize: '1.1rem', color: '#f87171' }}>
                    {maxBpm ? maxBpm.toFixed(1) : '--'}
                  </div>
                  <span style={{ fontSize: '0.65rem', color: 'var(--muted)' }}>bpm</span>
                </div>

                <div className="metric-item" style={{ padding: '10px 6px' }}>
                  <div className="metric-label" style={{ fontSize: '0.68rem' }}>HRV (SDNN)</div>
                  <div className="metric-value" style={{ fontSize: '1.1rem', color: '#34d399' }}>
                    {hrvVal ? `${hrvVal.toFixed(1)}` : '--'}
                  </div>
                  <span style={{ fontSize: '0.65rem', color: 'var(--muted)' }}>ms</span>
                </div>

                <div className="metric-item" style={{ padding: '10px 6px' }}>
                  <div className="metric-label" style={{ fontSize: '0.68rem' }}>HR SPREAD</div>
                  <div className="metric-value" style={{ fontSize: '1.1rem', color: '#a78bfa' }}>
                    {hrRange ? `±${hrRange}` : '--'}
                  </div>
                  <span style={{ fontSize: '0.65rem', color: 'var(--muted)' }}>bpm</span>
                </div>
              </div>

              {/* Diagram 1: Heart Rate Zone Spectrum Diagram */}
              <HeartRateZoneDiagram bpm={avgBpm} />

              {/* Diagram 2: Full 40-Second BPM Trajectory Curve */}
              <div className="profile-card" style={{ marginBottom: 14, padding: '16px' }}>
                <div className="metric-label" style={{ marginBottom: 8 }}>📈 40-Second Real-Time BPM Trajectory Curve</div>
                <LineChart 
                  data={results.bpm_trend && results.bpm_trend.length > 0 ? results.bpm_trend : liveBpmHistory} 
                  color="#f87171" 
                  label="Computed BPM per Second" 
                  unit=" bpm" 
                  height={90}
                />
              </div>

              {/* Quality & Environmental Diagnostics */}
              <div className="profile-card" style={{ marginBottom: 14, padding: '14px' }}>
                <div className="metric-label" style={{ marginBottom: 10 }}>📡 Optical Telemetry Diagnostics</div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, fontSize: '0.85rem' }}>
                  <div>
                    <span style={{ color: 'var(--muted)', display: 'block', fontSize: '0.75rem' }}>AVERAGE SNR</span>
                    <strong>{results.avg_snr_db ?? '--'} dB</strong> <span className={`badge ${getQualityBadgeClass(results.signal_quality)}`} style={{ fontSize: '0.65rem', marginLeft: 4 }}>{results.signal_quality || 'GOOD'}</span>
                  </div>
                  <div>
                    <span style={{ color: 'var(--muted)', display: 'block', fontSize: '0.75rem' }}>AVERAGE LUMINANCE</span>
                    <strong>{results.avg_luminance ?? '--'}</strong> <span className={`badge ${getQualityBadgeClass(results.video_quality)}`} style={{ fontSize: '0.65rem', marginLeft: 4 }}>{results.video_quality || 'GOOD'}</span>
                  </div>
                </div>
              </div>

              {/* Detailed Suggestions & Interpretations */}
              <div className="profile-card" style={{ marginBottom: 14, padding: '14px', background: 'rgba(255,255,255,0.02)' }}>
                <div className="metric-label" style={{ marginBottom: 10 }}>📋 Detailed Signal & Environmental Suggestions</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, fontSize: '0.86rem', lineHeight: 1.45 }}>
                  <div>
                    <strong style={{ color: '#60a5fa' }}>💡 Lighting & Luminance:</strong>
                    <div style={{ color: 'var(--muted)', marginTop: 2 }}>{interp.luminance_suggestion || 'Optimal lighting conditions observed.'}</div>
                  </div>
                  <div>
                    <strong style={{ color: '#34d399' }}>📡 Signal Quality & SNR:</strong>
                    <div style={{ color: 'var(--muted)', marginTop: 2 }}>{interp.snr_suggestion || 'High pulsatile confidence.'}</div>
                  </div>
                  <div>
                    <strong style={{ color: '#f59e0b' }}>🎯 Face Tracking & Frame Alignment:</strong>
                    <div style={{ color: 'var(--muted)', marginTop: 2 }}>{interp.frame_suggestion || 'Stable face tracking throughout recording.'}</div>
                  </div>
                  <div>
                    <strong style={{ color: '#f87171' }}>🩺 Cardiac Assessment:</strong>
                    <div style={{ color: 'var(--muted)', marginTop: 2 }}>{interp.cardiac_status || (avgBpm >= 60 && avgBpm <= 100 ? 'Normal resting heart rate.' : 'Resting rate outside standard baseline.')}</div>
                  </div>
                </div>
              </div>

              {/* Rescan Recommendation Banner */}
              {interp.rescan_recommended ? (
                <div className="instruction-box" style={{ marginBottom: 16, background: 'rgba(239, 68, 68, 0.12)', borderColor: 'rgba(239, 68, 68, 0.35)', color: '#fca5a5' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                    <div>
                      <div style={{ fontWeight: 800, fontSize: '0.92rem' }}>⚠️ Re-scan Recommended for Higher Precision</div>
                      <div style={{ fontSize: '0.78rem', marginTop: 2, color: 'var(--muted)' }}>
                        {interp.rescan_reason || 'Sub-optimal lighting or motion noise detected.'}
                      </div>
                    </div>
                    <button className="btn btn-primary btn-sm" style={{ whiteSpace: 'nowrap' }} onClick={startSession}>
                      🔄 Retake Scan
                    </button>
                  </div>
                </div>
              ) : (
                <div className="instruction-box" style={{ marginBottom: 16, background: 'rgba(16, 185, 129, 0.08)', borderColor: 'rgba(16, 185, 129, 0.3)', color: '#6ee7b7' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>✅ High-Confidence Vital Signs Captured</div>
                    <div style={{ fontSize: '0.78rem', marginTop: 2, color: 'var(--muted)' }}>
                      Signal clarity and ambient lighting satisfied all clinical quality thresholds.
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <button className="btn btn-primary" style={{ flex: 1 }} onClick={() => {
              setScanStatus('READY'); setLiveData(null); setResults(null);
              setLiveBpmHistory([]); go('dashboard');
            }}>
              ▶ New Scan
            </button>
            <button className="btn btn-ghost" style={{ flex: 1 }} onClick={() => {
              const today = new Date().toISOString().slice(0, 10);
              fetchDiary(today);
              go('diary');
            }}>
              📅 Open Diary
            </button>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

