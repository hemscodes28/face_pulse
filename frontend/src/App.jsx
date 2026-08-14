import { useState, useRef, useEffect } from 'react';
import './index.css';

const API = 'http://127.0.0.1:8000/api/v1';

// ─── Helper ───────────────────────────────────────────────
function NavBar({ title, onLogout }) {
  return (
    <div className="nav">
      <div className="nav-brand">Face<span>Pulse</span></div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        {title && <span style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>{title}</span>}
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

// ─── Inline SVG Line Chart ────────────────────────────────
function LineChart({ data = [], color = '#6ee7b7', label = '', unit = '' }) {
  if (!data || data.length < 2) return (
    <div style={{ textAlign: 'center', color: 'var(--muted)', fontSize: '0.8rem', padding: '8px 0' }}>
      No graph data
    </div>
  );

  const W = 280, H = 70, PAD = 8;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;

  const pts = data.map((v, i) => {
    const x = PAD + (i / (data.length - 1)) * (W - PAD * 2);
    const y = PAD + (1 - (v - min) / range) * (H - PAD * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');

  // Filled area: close path along bottom
  const firstX = PAD;
  const lastX  = PAD + (W - PAD * 2);
  const bottom = H - PAD;
  const areaPts = `${firstX},${bottom} ${pts} ${lastX},${bottom}`;

  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginBottom: 4 }}>
        {label} &nbsp;
        <span style={{ color, fontWeight: 600 }}>
          {data[data.length - 1]}{unit}
        </span>
        <span style={{ float: 'right', opacity: 0.5 }}>
          {min}{unit} – {max}{unit}
        </span>
      </div>
      <svg width={W} height={H} style={{ display: 'block', overflow: 'visible' }}>
        <defs>
          <linearGradient id={`grad-${label.replace(/\s/g,'')}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.35" />
            <stop offset="100%" stopColor={color} stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {/* Grid lines */}
        {[0.25, 0.5, 0.75].map(p => (
          <line key={p}
            x1={PAD} x2={W - PAD}
            y1={PAD + p * (H - PAD * 2)}
            y2={PAD + p * (H - PAD * 2)}
            stroke="rgba(255,255,255,0.06)" strokeWidth="1"
          />
        ))}
        {/* Area fill */}
        <polygon points={areaPts} fill={`url(#grad-${label.replace(/\s/g,'')})`} />
        {/* Line */}
        <polyline
          points={pts}
          fill="none"
          stroke={color}
          strokeWidth="2"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {/* Last dot */}
        {(() => {
          const lastPt = pts.split(' ').pop().split(',');
          return <circle cx={lastPt[0]} cy={lastPt[1]} r="3" fill={color} />;
        })()}
      </svg>
    </div>
  );
}

// ─── App ──────────────────────────────────────────────────
export default function App() {
  const [page, setPage]           = useState('landing'); 
  // pages: landing | signup | login | onboard-basic | onboard-body | onboard-medical | dashboard | measure | results

  const [auth, setAuth]           = useState(null);   // { token, user_id }
  const [error, setError]         = useState('');
  const [loading, setLoading]     = useState(false);

  // Measurement
  const [sessionId, setSessionId] = useState(null);
  const [liveData, setLiveData]   = useState(null);
  const [scanStatus, setScanStatus] = useState('READY');
  const [results, setResults]     = useState(null);
  const wsRef = useRef(null);

  // Diary
  const [diaryDate, setDiaryDate]       = useState(() => new Date().toISOString().slice(0, 10));
  const [diaryRecords, setDiaryRecords] = useState([]);
  const [expandedDiary, setExpandedDiary] = useState(null); // measurement_id of expanded card

  const headers = (extra = {}) => ({
    'Content-Type': 'application/json',
    ...(auth ? { Authorization: `Bearer ${auth.token}` } : {}),
    ...extra,
  });

  const go = (p) => { setError(''); setPage(p); };

  const logout = () => {
    setAuth(null); setSessionId(null); setLiveData(null);
    setScanStatus('READY'); setResults(null); go('landing');
    if (wsRef.current) wsRef.current.close();
  };

  // Cleanup ws on unmount
  useEffect(() => () => { if (wsRef.current) wsRef.current.close(); }, []);

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
      const res = await fetch(`${API}/users/${auth.user_id}/profile/body`, {
        method: 'PUT', headers: headers(),
        body: JSON.stringify({ height: parseFloat(fd.get('height')), weight: parseFloat(fd.get('weight')) }),
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
      // update blood group
      const r1 = await fetch(`${API}/users/${auth.user_id}/profile/medical`, {
        method: 'PUT', headers: headers(),
        body: JSON.stringify({ blood_group: fd.get('blood_group') }),
      });
      if (!r1.ok) throw new Error((await r1.json()).detail || 'Update failed');

      // mark onboarding complete
      const r2 = await fetch(`${API}/users/${auth.user_id}/onboarding/complete`, {
        method: 'POST', headers: headers(),
      });
      if (!r2.ok) throw new Error((await r2.json()).detail || 'Complete failed');

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
      go('measure');
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  function startScan() {
    if (!sessionId) return;
    const ws = new WebSocket(`ws://127.0.0.1:8000/api/v1/measurements/${sessionId}/live`);
    wsRef.current = ws;

    ws.onopen = () => setScanStatus('MEASURING');
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.status === 'PROCESSING') setScanStatus('PROCESSING');
      else if (data.status === 'COMPLETED') setScanStatus('COMPLETED');
      else if (data.elapsed_time_sec !== undefined) setLiveData(data);
    };
    ws.onerror = () => setError('WebSocket error. Is the backend running?');
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
            Contactless vitals measurement powered by rPPG
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
              <option value="Male">Male</option>
              <option value="Female">Female</option>
              <option value="Other">Other</option>
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
            <label>Height (meters)</label>
            <input name="height" type="number" step="0.01" min="0.5" max="3" placeholder="e.g. 1.75" required />
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
  if (page === 'dashboard') return (
    <div className="page">
      <div className="card">
        <NavBar title={`uid: ${auth?.user_id?.slice(0,8)}...`} onLogout={logout} />
        <div className="card-title">Dashboard</div>
        <div className="card-sub">Ready for your measurement?</div>
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

  // ── Diary ───────────────────────────────────────────────
  if (page === 'diary') return (
    <div className="page">
      <div className="card">
        <NavBar title="Diary" onLogout={logout} />
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
                {/* Header row */}
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8, fontSize: '0.8rem', color: 'var(--muted)' }}>
                  <span>Session: {m.measurement_id?.slice(0, 12)}...</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    {m.recorded_at ? new Date(m.recorded_at).toLocaleTimeString() : ''}
                    <span style={{ fontSize: '0.7rem', opacity: 0.6 }}>{expandedDiary === m.measurement_id ? '▲ hide' : '▼ graphs'}</span>
                  </span>
                </div>

                {/* Vital badges */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
                  <div>
                    <div className="metric-label">Heart Rate</div>
                    <div className="metric-value" style={{ fontSize: '1.1rem' }}>{m.heart_rate} bpm</div>
                  </div>
                  <div>
                    <div className="metric-label">SpO2</div>
                    <div className="metric-value" style={{ fontSize: '1.1rem' }}>{m.spo2}%</div>
                  </div>
                  <div>
                    <div className="metric-label">Blood Pressure</div>
                    <div className="metric-value" style={{ fontSize: '1.1rem' }}>{m.systolic}/{m.diastolic}</div>
                  </div>
                </div>

                {/* Expanded graphs */}
                {expandedDiary === m.measurement_id && (
                  <div style={{ marginTop: 20, borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: 16 }}
                    onClick={e => e.stopPropagation()}
                  >
                    <LineChart
                      data={m.hr_series}
                      color="#f87171"
                      label="Heart Rate"
                      unit=" bpm"
                    />
                    <LineChart
                      data={m.spo2_series}
                      color="#60a5fa"
                      label="SpO2"
                      unit="%"
                    />
                    <LineChart
                      data={m.bp_series ? m.bp_series.map(pts => pts.length ? pts.reduce((a,b)=>a+b,0)/pts.length : 0) : []}
                      color="#a78bfa"
                      label="BP avg waveform"
                      unit=" mmHg"
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

  // ── Measure ────────────────────────────────────────────
  if (page === 'measure') return (
    <div className="page">
      <div className="card">
        <NavBar title="Measuring" onLogout={logout} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div className="card-title" style={{ marginBottom: 0 }}>Live Scan</div>
          {scanStatus !== 'READY' && (
            <span className={`badge badge-${scanStatus.toLowerCase()}`}>{scanStatus}</span>
          )}
        </div>
        <p style={{ color: 'var(--muted)', fontSize: '0.8rem', marginTop: 4 }}>
          Session: {sessionId?.slice(0, 18)}...
        </p>

        {scanStatus === 'READY' && (
          <button className="btn btn-primary" style={{ marginTop: 24 }} onClick={startScan}>
            Start Scan
          </button>
        )}

        {scanStatus !== 'READY' && (
          <>
            <div className="instruction-box">
              {scanStatus === 'PROCESSING'
                ? '⏳ Analyzing data, please wait...'
                : scanStatus === 'COMPLETED'
                ? '✅ Measurement complete!'
                : liveData?.instruction || 'Initializing...'}
            </div>

            <div className="metrics-grid">
              <div className="metric-item">
                <div className="metric-label">Elapsed</div>
                <div className="metric-value">{liveData ? `${liveData.elapsed_time_sec}s` : '0s'}</div>
              </div>
              <div className="metric-item">
                <div className="metric-label">Quality</div>
                <div className="metric-value">{liveData?.quality?.overall_score ?? '--'}</div>
              </div>
              <div className="metric-item">
                <div className="metric-label">Heart Rate</div>
                <div className="metric-value">{liveData?.hr ? `${liveData.hr} bpm` : '--'}</div>
              </div>
              <div className="metric-item">
                <div className="metric-label">SpO2</div>
                <div className="metric-value">{liveData?.spo2 ? `${liveData.spo2}%` : '--'}</div>
              </div>
              <div className="metric-item" style={{ gridColumn: '1/-1' }}>
                <div className="metric-label">BP Graph Points</div>
                <div className="metric-value" style={{ fontSize: '0.95rem', fontWeight: 500 }}>
                  {liveData?.bp ? liveData.bp.join('  ·  ') : '--'}
                </div>
              </div>
            </div>
          </>
        )}

        {scanStatus === 'COMPLETED' && (
          <button className="btn btn-success" style={{ marginTop: 20 }} onClick={fetchResults} disabled={loading}>
            {loading ? 'Loading...' : 'Click here for Results →'}
          </button>
        )}

        {error && <div className="alert alert-error" style={{ marginTop: 12 }}>{error}</div>}
      </div>
    </div>
  );

  // ── Results ────────────────────────────────────────────
  if (page === 'results') return (
    <div className="page">
      <div className="card">
        <NavBar title="Results" onLogout={logout} />
        <div className="card-title" style={{ color: 'var(--success)' }}>Results</div>
        <div className="card-sub">Session complete — {sessionId?.slice(0, 18)}...</div>

        {results && (
          <>
            <div className="result-row">
              <span className="result-label">Heart Rate</span>
              <span className="result-val">{results.vitals?.hr} bpm</span>
            </div>
            <div className="result-row">
              <span className="result-label">Blood Pressure</span>
              <span className="result-val">{results.vitals?.bp}</span>
            </div>
            <div className="result-row">
              <span className="result-label">SpO2</span>
              <span className="result-val">{results.vitals?.spo2}%</span>
            </div>
            <div className="result-row">
              <span className="result-label">Avg Quality</span>
              <span className="result-val">{results.quality_summary?.avg_quality}</span>
            </div>
            <div className="result-row">
              <span className="result-label">Duration</span>
              <span className="result-val">{results.duration_sec}s</span>
            </div>
            <div className="result-row">
              <span className="result-label">Analysis</span>
              <span className="result-val" style={{ fontSize: '0.9rem', textAlign: 'right', maxWidth: '60%' }}>
                {results.analysis}
              </span>
            </div>
          </>
        )}

        <button className="btn btn-primary" style={{ marginTop: 24 }} onClick={() => {
          setScanStatus('READY'); setLiveData(null); setResults(null); go('dashboard');
        }}>Start New Scan</button>
      </div>
    </div>
  );

  return null;
}
