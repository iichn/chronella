# SCOPE

## Входит
- Вынос конфигурации и секретов в переменные окружения (`.env`, python-dotenv)
- Замена SQLite на PostgreSQL 16 (драйвер `psycopg`, строка подключения из env)
- Создание схемы в Postgres при старте backend
- Dockerfile backend (`python:3.12-slim`) и frontend (multi-stage: Vite build → Nginx)
- Nginx: раздача статики, SPA-fallback, проксирование `/api` на backend
- `docker-compose.yml`: 3 сервиса, сеть `chronella_net`, том `pgdata`, healthcheck `pg_isready`, `depends_on: service_healthy`
- Минимальные правки кода, без которых система не работает в контейнерах: базовый URL API на фронте (`/api`), OAuth-поток Google (redirect URI, редирект на фронт), поведение при отсутствии SECRET_KEY/ENCRYPTION_KEY
- `.env.example`, `.gitignore`, `.dockerignore`
- `scripts/smoke.ps1`, `docs/CHECKLIST.md`
- README, сценарий видео

## Не входит
- Новый функционал приложения, рефакторинг прикладной логики
- Alembic и система миграций схемы
- Перенос данных из `chronella.db` (БД стартует пустой)
- CI/CD, container registry, публикация образов
- Kubernetes, Swagger-деплой, облачный деплой, HTTPS/TLS-терминация
- Мониторинг, логирование, сканирование безопасности
- Написание тестов
- Горизонтальное масштабирование, реплики БД, бэкапы БД
- Миграция фронтенда на другой фреймворк или сборщик
- Настройка CORS (в контейнерах один origin через Nginx)
- `backend/migrate_db.py` (одноразовый SQLite-скрипт, системой не используется)
- `verify=False` в клиентах ЭИОС (известный риск, не исправляем)

## Подтверждено разведкой (T-001, `docs/recon.md`)
- Таблицы создаются `Base.metadata.create_all()` при старте (`backend/main.py:15-19`), Alembic нет.
- Роуты backend без префикса `/api`; точка входа `main:app`; эндпоинт живости `GET /`.
- Google credentials-файлов нет: client id/secret из env, refresh-токены в БД.
- Frontend с хардкодом `http://localhost:8000` в нескольких файлах.

## Допущения
- A-1: Python 3.12, Node 22 (в проекте версии не зафиксированы).
- A-2: ЭИОС (`papi.mrsu.ru`) доступен из контейнера без прокси.
