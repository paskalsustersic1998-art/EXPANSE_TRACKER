# EXPANSE TRACKER — Claude Code Guide

A Splitwise-like expense sharing app for friends to track shared costs during trips. Built as a learning project with production-style practices.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (web), Riverpod, GoRouter, Dio, flutter_secure_storage |
| Backend | FastAPI, SQLAlchemy 2.0, Pydantic, Alembic, JWT |
| Database | PostgreSQL |
| DevOps | Docker, Docker Compose, Nginx |

---

## Project Structure

```
EXPANSE_TRACKER/
├── backend/
│   └── app/
│       ├── main.py
│       ├── core/          # config, security, dependencies
│       ├── models/        # SQLAlchemy ORM models
│       ├── schemas/       # Pydantic request/response schemas
│       ├── api/           # route handlers
│       ├── services/      # business logic
│       └── tests/
├── frontend/
│   └── lib/
│       ├── core/          # theme, router, constants, dio client
│       ├── features/      # auth, trips, expenses, settlements
│       └── shared/        # shared widgets, utils
├── docker-compose.yml
├── .env.example
└── CLAUDE.md
```

---

## Development Commands

### Full Stack (Docker)
```bash
docker-compose up --build     # start all services
docker-compose down           # stop all services
docker-compose logs -f        # follow logs
```

### Backend (local dev)
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Database Migrations (Alembic)
```bash
alembic revision --autogenerate -m "description"
alembic upgrade head
alembic downgrade -1
```

### Frontend (local dev)
```bash
cd frontend
flutter pub get
flutter run -d chrome
flutter build web
```

### Backend Tests
```bash
cd backend
pytest app/tests/ -v
pytest app/tests/ -v --cov=app
```

---

## API Routes

```
POST   /auth/register
POST   /auth/login
GET    /auth/me

GET    /trips
POST   /trips
GET    /trips/{id}

POST   /trips/{id}/expenses
GET    /trips/{id}/balances

POST   /trips/{id}/settlements

GET    /admin/users
PATCH  /admin/users/{id}/role
```

All protected routes require `Authorization: Bearer <token>` header.

---

## Database Schema

Tables: `users`, `trips`, `trip_participants`, `expenses`, `expense_splits`, `settlements`

- Always define models in `backend/app/models/`
- Always create a corresponding Pydantic schema in `backend/app/schemas/`
- Use Alembic for every schema change — never modify the DB directly

---

## Architecture Conventions

### Backend
- Route handlers live in `api/` — keep them thin (validate input, call service, return response)
- Business logic lives in `services/` — no direct DB queries in route handlers
- DB queries live in `services/` using SQLAlchemy sessions
- Use `Depends()` for auth, DB session injection
- Return Pydantic response models from every endpoint
- Use `async def` for route handlers

### Frontend
- Each feature gets its own folder under `features/` (e.g., `features/auth/`, `features/trips/`)
- Each feature folder contains: `screens/`, `widgets/`, `providers/`, `models/`
- Use Riverpod providers for all state — no raw `setState` in feature code
- All API calls go through a single Dio client defined in `core/`
- Store JWT in `flutter_secure_storage` only — never in SharedPreferences or memory across restarts
- Use GoRouter for all navigation — no `Navigator.push` directly

---

## Security Rules

- **Never commit `.env` files** — only `.env.example` with placeholder values
- Passwords must always be hashed with bcrypt — never store or log plain text passwords
- JWT secret must come from environment variable, never hardcoded
- All DB queries must use SQLAlchemy ORM — no raw SQL strings
- Validate all user input with Pydantic schemas before touching the DB
- Role checks (`user` / `admin`) must happen in route dependencies, not inside service logic

---

## Git Workflow

```
main      → stable, production-ready
develop   → integration branch (merge feature branches here first)
feature/* → one branch per feature
```

Branch naming:
```
feature/auth
feature/trips
feature/expenses
feature/settlements
feature/admin
```

Commit style — keep messages short and imperative:
```
add JWT auth middleware
fix balance calculation for unequal splits
refactor expense service to use repository pattern
```

---

## Environment Variables

All secrets live in `.env` (never committed). Copy from `.env.example`:

```
DATABASE_URL=postgresql://user:password@db:5432/expanse_tracker
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

---

## What NOT to Do

- Do not add features beyond what is asked in the current task
- Do not write raw SQL — always use SQLAlchemy ORM
- Do not put business logic in route handlers
- Do not use `Navigator.push` directly in Flutter — use GoRouter
- Do not store secrets in code or commit `.env`
- Do not skip Alembic migrations for schema changes
- Do not mock the database in integration tests
