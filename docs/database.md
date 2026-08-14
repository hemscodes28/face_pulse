# Face Pulse — Database Design Documentation

> **Branch:** `backend/database-profile`
> **Last updated:** 2026-08-14
> **Scope:** Milestone 1 (Measurement Session), Milestone 2 (User Foundation), Milestone 2.5 (Guardian Relationships), Milestone 2.75 (User Health Profile), & Milestone 3 (Measurement Results).

---

## Overview

The Face Pulse backend uses **PostgreSQL** as its primary relational store, accessed through **SQLAlchemy 2.x** (async) in the application and via **Alembic** for schema migrations.

The database architecture is centered around five primary entities:

```
                          ┌──────────┐
                          │  users   │
                          └────┬─────┘
                               │
       ┌───────────────────────┼───────────────────────┐
  1:N  │                  1:1  │                  1:N  │ (via user_guardians)
       ▼                       ▼                       ▼
┌──────────────┐      ┌─────────────────┐     ┌─────────────────┐
│ measurements │      │  user_profiles  │     │ user_guardians  │
└──────┬───────┘      └─────────────────┘     └─────────────────┘
       │
  1:1  │
       ▼
┌──────────────────────┐
│ measurement_results  │
└──────────────────────┘
```

---

## Identifiers & Core Rules

> **CRITICAL ARCHITECTURAL RULE: IDENTIFIER INDEPENDENCE**
> 
> `users.id`, `user_profiles.id`, `measurements.id`, and `user_guardians.id` are **FOUR INDEPENDENT UUID IDENTIFIERS**.
> 
> - `users.id`: Primary key for a user account.
> - `user_profiles.id`: Primary key for a user health profile.
> - `measurements.id`: Primary key for a unique measurement session.
> - `user_guardians.id`: Primary key for a guardian relationship record.
> 
> Primary key IDs are **never** reused across entities.

---

## `users` Table

### Schema

| Column          | PostgreSQL Type    | Nullable | Default              | Notes                                                |
|-----------------|--------------------|----------|----------------------|------------------------------------------------------|
| `id`            | `UUID`             | NOT NULL | `gen_random_uuid()`  | Primary key UUID                                     |
| `full_name`     | `VARCHAR(100)`     | NOT NULL | —                    | Full name of the user                                |
| `email`         | `VARCHAR(255)`     | NOT NULL | —                    | Unique user email address, indexed                    |
| `password_hash` | `VARCHAR(255)`     | NOT NULL | —                    | Hashed password (plaintext forbidden)                |
| `role`          | `user_role` (ENUM) | NOT NULL | `'USER'`             | Role enum (allowed value: `USER`)                    |
| `is_active`     | `BOOLEAN`          | NOT NULL | `TRUE`               | Boolean active account flag                          |
| `created_at`    | `TIMESTAMPTZ`      | NOT NULL | `now()`              | Account creation timestamp (set by DB)               |
| `updated_at`    | `TIMESTAMPTZ`      | NOT NULL | `now()`              | Account last update timestamp (set by DB)            |

---

## `user_profiles` Table

### Architecture (1:1 Relationship)

```
USER (users.id)
  │
  └── 1:1 (user_id UNIQUE) ──► USER_PROFILE (user_profiles.id)
```

The `user_profiles` table stores health and demographic attributes in a separate 1:1 table to keep the core `users` authentication table lightweight and normalized.

### Schema

| Column          | PostgreSQL Type       | Nullable | Default              | Notes                                                        |
|-----------------|-----------------------|----------|----------------------|--------------------------------------------------------------|
| `id`            | `UUID`                | NOT NULL | `gen_random_uuid()`  | Independent primary key UUID                                 |
| `user_id`       | `UUID`                | NOT NULL | —                    | Foreign Key referencing `users.id`, `UNIQUE`, indexed        |
| `date_of_birth` | `DATE`                | NOT NULL | —                    | Date of birth (used to compute derived `age`)                |
| `gender`        | `gender_enum` (ENUM)  | NOT NULL | —                    | `MALE`, `FEMALE`, `OTHER`, `PREFER_NOT_TO_SAY`               |
| `height_cm`     | `NUMERIC(5, 2)`       | NOT NULL | —                    | Height in cm (CHECK constraint: `height_cm > 0`)            |
| `weight_kg`     | `NUMERIC(5, 2)`       | NOT NULL | —                    | Weight in kg (CHECK constraint: `weight_kg > 0`)            |
| `blood_group`   | `blood_group_enum`    | NOT NULL | —                    | `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`            |
| `created_at`    | `TIMESTAMPTZ`         | NOT NULL | `now()`              | Profile creation timestamp                                   |
| `updated_at`    | `TIMESTAMPTZ`         | NOT NULL | `now()`              | Profile update timestamp                                     |

### Derived Properties (NOT Stored in DB)

To prevent stale data, `age` and `BMI` are **NOT** stored as permanent database columns. They are calculated dynamically at runtime:

1. **`age`**:
   - Calculated dynamically from `date_of_birth` relative to current date.
   - Formula: `today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))`

2. **`bmi`**:
   - Calculated dynamically from `weight_kg` and `height_cm`.
   - Formula: `weight_kg / ((height_cm / 100) ^ 2)` rounded to 2 decimal places.

### Enums & Constraints

- **`gender_enum`**: `MALE`, `FEMALE`, `OTHER`, `PREFER_NOT_TO_SAY`
- **`blood_group_enum`**: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`
- **Constraints**:
  - `CONSTRAINT ck_user_profiles_positive_height CHECK (height_cm > 0)`
  - `CONSTRAINT ck_user_profiles_positive_weight CHECK (weight_kg > 0)`
  - `CONSTRAINT uq_user_profiles_user_id UNIQUE (user_id)` (enforces 1:1 relationship)

---

## `user_guardians` Table

### Architecture

```
USER A (data owner) ──user_id──► USER_GUARDIANS (id) ──guardian_user_id──► USER B (guardian recipient)
```

### Schema

| Column             | PostgreSQL Type                       | Nullable | Default              | Notes                                                         |
|--------------------|---------------------------------------|----------|----------------------|---------------------------------------------------------------|
| `id`               | `UUID`                                | NOT NULL | `gen_random_uuid()`  | Independent primary key UUID                                  |
| `user_id`          | `UUID`                                | NOT NULL | —                    | Foreign Key referencing `users.id` (data owner), indexed      |
| `guardian_user_id` | `UUID`                                | NOT NULL | —                    | Foreign Key referencing `users.id` (guardian recipient), indexed |
| `status`           | `guardian_relationship_status` (ENUM) | NOT NULL | `'PENDING'`          | `PENDING`, `ACCEPTED`, `REJECTED`, `REVOKED`                   |
| `share_results`    | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for viewing completed measurement results     |
| `share_trends`     | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for viewing historical measurement trends     |
| `share_alerts`     | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for receiving measurement alerts              |
| `created_at`       | `TIMESTAMPTZ`                         | NOT NULL | `now()`              | Relationship creation timestamp                               |
| `updated_at`       | `TIMESTAMPTZ`                         | NOT NULL | `now()`              | Relationship last update timestamp                            |

---

## `measurements` Table

### Schema

| Column         | PostgreSQL Type              | Nullable | Default              | Notes                                                |
|----------------|------------------------------|----------|----------------------|------------------------------------------------------|
| `id`           | `UUID`                       | NOT NULL | `gen_random_uuid()`  | Primary key. Exposed as `measurement_id`             |
| `user_id`      | `UUID`                       | NOT NULL | —                    | Foreign Key referencing `users.id`, indexed           |
| `status`       | `measurement_status` (ENUM)  | NOT NULL | `'READY'`            | Lifecycle state (`READY`, `MEASURING`, `PROCESSING`, `COMPLETED`, `FAILED`) |
| `started_at`   | `TIMESTAMPTZ`                | NOT NULL | `now()`              | Session start timestamp                              |
| `completed_at` | `TIMESTAMPTZ`                | YES      | `NULL`               | Set when session ends                                |
| `created_at`   | `TIMESTAMPTZ`                | NOT NULL | `now()`              | Row creation timestamp                               |

---

## `measurement_results` Table

### Architecture (1:1 Relationship)

```
MEASUREMENT (measurements.id)
  │
  └── 1:1 (measurement_id UNIQUE) ──► MEASUREMENT_RESULT (measurement_results.id)
```

Each measurement session has at most one finalized ML analysis result. The 1:1
relationship is enforced at the database level via `UNIQUE (measurement_id)`.

### Schema

| Column                            | PostgreSQL Type                     | Nullable | Default             | Notes                                                                         |
|-----------------------------------|-------------------------------------|----------|---------------------|-------------------------------------------------------------------------------|
| `id`                              | `UUID`                              | NOT NULL | `gen_random_uuid()` | Independent primary key UUID                                                  |
| `measurement_id`                  | `UUID`                              | NOT NULL | —                   | FK → `measurements.id`, UNIQUE, indexed — enforces 1:1                        |
| `heart_rate_bpm`                  | `NUMERIC(6, 2)`                     | nullable | —                   | Heart rate in beats per minute                                                |
| `systolic_bp_mmhg`                | `NUMERIC(6, 2)`                     | nullable | —                   | Systolic blood pressure in millimeters of mercury                             |
| `diastolic_bp_mmhg`               | `NUMERIC(6, 2)`                     | nullable | —                   | Diastolic blood pressure in millimeters of mercury                            |
| `hrv_ms`                          | `NUMERIC(7, 2)`                     | nullable | —                   | Heart rate variability in milliseconds (SDNN or similar)                      |
| `breathing_rate_bpm`              | `NUMERIC(6, 2)`                     | nullable | —                   | Breathing rate in breaths per minute                                          |
| `stress_index`                    | `NUMERIC(7, 3)`                     | nullable | —                   | Stress index derived from HRV and autonomic metrics                           |
| `cardiac_workload`                | `NUMERIC(10, 2)`                    | nullable | —                   | Cardiac workload (product of HR and systolic BP)                              |
| `parasympathetic_activity_percent`| `NUMERIC(5, 2)`                     | nullable | —                   | Parasympathetic nervous system activity as a percentage                       |
| `bmi`                             | `NUMERIC(5, 2)`                     | nullable | —                   | Historical BMI snapshot at time of this measurement (see note below)          |
| `bmi_classification`              | `VARCHAR(50)`                       | nullable | —                   | BMI classification label at time of measurement (e.g. `Normal`, `Overweight`)|
| `signal_quality_score`            | `NUMERIC(5, 4)`                     | nullable | —                   | Signal quality score in range `[0.0, 1.0]`                                   |
| `signal_quality_level`            | `signal_quality_level_enum` (ENUM)  | nullable | —                   | `LOW`, `FAIR`, `GOOD`, `EXCELLENT`                                            |
| `rescan_recommended`              | `BOOLEAN`                           | NOT NULL | `FALSE`             | Whether the ML pipeline recommends a rescan                                   |
| `quality_message`                 | `TEXT`                              | nullable | —                   | Optional human-readable quality explanation                                   |
| `analysis`                        | `JSONB`                             | nullable | —                   | Structured interpretation metadata (see JSONB note below)                     |
| `model_name`                      | `VARCHAR(100)`                      | nullable | —                   | Name of the ML model that generated this result                               |
| `model_version`                   | `VARCHAR(50)`                       | nullable | —                   | Version string of the ML model (e.g. `1.2.3`)                                |
| `processed_at`                    | `TIMESTAMPTZ`                       | nullable | —                   | When the ML pipeline completed processing                                     |
| `created_at`                      | `TIMESTAMPTZ`                       | NOT NULL | `now()`             | Row creation timestamp                                                        |
| `updated_at`                      | `TIMESTAMPTZ`                       | NOT NULL | `now()`             | Row update timestamp                                                          |

### Nullability Design

Only `id`, `measurement_id`, `rescan_recommended`, `created_at`, and `updated_at`
are `NOT NULL`. All ML result metric columns are **nullable** for two reasons:

1. **Partial results**: The ML pipeline may be unable to compute certain metrics
   (e.g. blood pressure) if signal quality is insufficient.
2. **Evolving contract**: New metric types may be added in future ML versions.
   Nullable columns allow incremental rollout without breaking existing rows.

### BMI Historical Snapshot

`measurement_results.bmi` stores the **historical BMI** captured at the time of
the measurement, typically computed from the user's profile height/weight at that
moment. This is **intentionally distinct** from `UserProfile.bmi` (a derived
property on current profile data) because:

- Users' height/weight may change over time.
- Historical health reports must reflect the BMI at the time of the scan.
- `user_profiles` stores *current* profile data; `measurement_results` stores
  *historical snapshots* tied to a specific measurement event.

### JSONB `analysis` Column

The `analysis` column stores **structured interpretation metadata** in JSONB format.
It does **NOT** duplicate the canonical numeric values (those are in their own
dedicated columns). It is used for status classifications and human-readable messages.

**Example:**
```json
{
  "heart_rate": { "status": "NORMAL" },
  "blood_pressure": { "status": "ELEVATED" },
  "bmi": { "status": "OVERWEIGHT", "message": "Consider lifestyle adjustments." },
  "stress": { "status": "HIGH", "score": 3.5 }
}
```

### Signal Quality

| Field                  | Type                          | Notes                                           |
|------------------------|-------------------------------|-------------------------------------------------|
| `signal_quality_score` | `NUMERIC(5,4)` range `[0,1]`  | Raw quality confidence from ML pipeline         |
| `signal_quality_level` | `signal_quality_level_enum`   | `LOW` / `FAIR` / `GOOD` / `EXCELLENT`           |
| `rescan_recommended`   | `BOOLEAN NOT NULL DEFAULT FALSE` | Set `TRUE` when quality < acceptable threshold |
| `quality_message`      | `TEXT` nullable               | Human-readable explanation for the user         |

### ML Provenance

`model_name`, `model_version`, and `processed_at` allow every historical result
to be traced back to the exact ML model version that generated it. Model weights
and tensors are **NOT** stored here.

### Future Health Diary Access

The Health Diary will query:

```
User → Measurements → MeasurementResults
  ordered by measurements.created_at DESC
```

No separate diary table is required.

### Guardian Access Flow (Future)

```
JWT → guardian_user_id
    → accepted user_guardians row
    → permission check (share_results = TRUE)
    → measurement_results data for the guarded user
```

