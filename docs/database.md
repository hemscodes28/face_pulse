# Face Pulse — Database Design Documentation

> **Branch:** `backend/database-guardians`
> **Last updated:** 2026-08-14
> **Scope:** Milestone 1 (Measurement Session), Milestone 2 (User Foundation), & Milestone 2.5 (Guardian Relationships & Sharing Permissions).

---

## Overview

The Face Pulse backend uses **PostgreSQL** as its primary relational store, accessed through **SQLAlchemy 2.x** (async) in the application and via **Alembic** for schema migrations.

The database architecture is centered around three primary entities:

```
                  ┌──────────┐
                  │  users   │
                  └────┬─────┘
                       │
       ┌───────────────┴───────────────┐
  1:N  │                          1:N  │ (via user_guardians)
       ▼                               ▼
┌──────────────┐              ┌─────────────────┐
│ measurements │              │ user_guardians  │
└──────────────┘              └─────────────────┘
```

---

## Identifiers & Core Rules

> **CRITICAL ARCHITECTURAL RULE: IDENTIFIER INDEPENDENCE**
> 
> `users.id`, `measurements.id`, and `user_guardians.id` are **THREE INDEPENDENT UUID IDENTIFIERS**.
> 
> - `users.id`: Primary key for a user account.
> - `measurements.id`: Primary key for a unique measurement session.
> - `user_guardians.id`: Primary key for a guardian relationship record.
> 
> IDs are never reused or shared across these entities.

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

### Role Rationale & Guardian Identity

- **No `GUARDIAN` Role:** A guardian is **not** a user role (`role = "GUARDIAN"`). Every account in `users` has `role = 'USER'`.
- Both the data owner and the guardian recipient exist as standard rows in `users`.
- A guardian relationship is established purely by connecting two `users.id` records in `user_guardians`.
- This enables a user account to be both a data owner and a guardian for other family members simultaneously.

---

## `user_guardians` Table

### Architecture

```
USER A (data owner)
  │
  │ user_id
  ▼
USER_GUARDIANS (id: UUID)
  │
  │ guardian_user_id
  ▼
USER B (guardian recipient)
```

Both `User A` and `User B` exist in the `users` table with `role = 'USER'`.

### Schema

| Column             | PostgreSQL Type                       | Nullable | Default              | Notes                                                         |
|--------------------|---------------------------------------|----------|----------------------|---------------------------------------------------------------|
| `id`               | `UUID`                                | NOT NULL | `gen_random_uuid()`  | Independent primary key UUID                                  |
| `user_id`          | `UUID`                                | NOT NULL | —                    | Foreign Key referencing `users.id` (data owner), indexed      |
| `guardian_user_id` | `UUID`                                | NOT NULL | —                    | Foreign Key referencing `users.id` (guardian recipient), indexed |
| `status`           | `guardian_relationship_status` (ENUM) | NOT NULL | `'PENDING'`          | Relationship lifecycle status (`PENDING`, `ACCEPTED`, `REJECTED`, `REVOKED`) |
| `share_results`    | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for viewing completed measurement results     |
| `share_trends`     | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for viewing historical measurement trends     |
| `share_alerts`     | `BOOLEAN`                             | NOT NULL | `FALSE`              | Permission flag for receiving measurement alerts              |
| `created_at`       | `TIMESTAMPTZ`                         | NOT NULL | `now()`              | Relationship creation timestamp                               |
| `updated_at`       | `TIMESTAMPTZ`                         | NOT NULL | `now()`              | Relationship last update timestamp                            |

### Database Constraints

1. **Foreign Keys:** `user_id` -> `users.id` and `guardian_user_id` -> `users.id`. **No `ON DELETE CASCADE`**, preserving metadata.
2. **Self-Guardian Prevention Check Constraint:** `ck_user_guardians_prevent_self_guardian` (`user_id <> guardian_user_id`). A user cannot be their own guardian.
3. **Duplicate Relationship Unique Constraint:** `uq_user_guardians_user_guardian` on `(user_id, guardian_user_id)`. Prevents duplicate invitations/relationships between the same pair.

### Status Lifecycle

```
           ┌──────────┐
  Invite   │          │
 ────────► │ PENDING  ├───────────┐ Reject
           │          │           │
           └────┬─────┘           ▼
                │ Accept    ┌──────────┐
                ▼           │ REJECTED │
           ┌──────────┐     └──────────┘
           │ ACCEPTED │
           └────┬─────┘
                │ Revoke
                ▼
           ┌──────────┐
           │ REVOKED  │
           └──────────┘
```

- `ACCEPTED` represents an active guardian relationship.
- Permissions (`share_results`, `share_trends`, `share_alerts`) are only granted when `status = 'ACCEPTED'` **and** the specific permission flag is `TRUE`.

### Future Guardian API Architecture

The schema supports the following planned API endpoints:
- `POST /api/v1/guardians/invite` — Creates `user_guardians` record in `PENDING` state.
- `POST /api/v1/guardians/invitations/{relationship_id}/accept` — Updates status to `ACCEPTED`.
- `POST /api/v1/guardians/invitations/{relationship_id}/reject` — Updates status to `REJECTED`.
- `GET /api/v1/guardians` — Lists active guardians (`ACCEPTED`).
- `DELETE /api/v1/guardians/{relationship_id}` — Updates status to `REVOKED`.
- `PATCH /api/v1/guardians/{relationship_id}/permissions` — Updates `share_results`, `share_trends`, `share_alerts`.

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

## Future Health Diary Architecture

```
User (users)
  │
  └── 1:N ──► Measurements (measurements)
                │
                └── 1:1 / 1:N ──► Measurement Results (future milestone)
```

Guardian access will provide a controlled view of selected measurement results based on `user_guardians` permissions (`share_results`, `share_trends`, `share_alerts`).
