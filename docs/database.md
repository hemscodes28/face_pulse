# Face Pulse — Database Design Documentation

> **Branch:** `backend/database-profile`
> **Last updated:** 2026-08-14
> **Scope:** Milestone 1 (Measurement Session), Milestone 2 (User Foundation), Milestone 2.5 (Guardian Relationships), & Milestone 2.75 (User Health Profile).

---

## Overview

The Face Pulse backend uses **PostgreSQL** as its primary relational store, accessed through **SQLAlchemy 2.x** (async) in the application and via **Alembic** for schema migrations.

The database architecture is centered around four primary entities:

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
└──────────────┘      └─────────────────┘     └─────────────────┘
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
