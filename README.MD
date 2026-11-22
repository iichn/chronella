# Chronella

Веб-приложение для студентов: загрузка расписания и рейтинг-плана из ЭИОС МГУ им. Н.П. Огарёва, экспорт событий в Google Calendar и аналитика учебной нагрузки.
Стек: React + TypeScript + Vite (Nginx), FastAPI (Python 3.12), PostgreSQL 16.
Вся система развёртывается одной командой через Docker Compose.

## Архитектура

Система состоит из трёх контейнеров в изолированной bridge-сети `chronella_net` с именованным томом `pgdata` для хранения данных PostgreSQL. На хост опубликован только порт `8080` (Nginx); `backend` и `db` напрямую с хоста недоступны.

```mermaid
flowchart LR
    Browser[Браузер] -->|http://localhost:8080| Frontend[frontend: Nginx :80]
    Frontend -->|статика SPA| Browser
    Frontend -->|/api/* -> /*| Backend[backend: FastAPI :8000]
    Backend -->|psycopg :5432| DB[(db: PostgreSQL 16)]
    DB --- Volume[(volume: pgdata)]
```

## Требования

- Docker
- Docker Compose v2 (`docker compose`)

## Быстрый старт

1. Клонировать репозиторий (URL уточнить):

```powershell
git clone <URL-репозитория>
cd <папка-проекта>
```

2. Создать `.env` из шаблона:

PowerShell:

```powershell
Copy-Item .env.example .env
```

Linux / macOS:

```bash
cp .env.example .env
```

3. Заполнить переменные в `.env` (см. таблицу ниже).

4. Собрать и запустить систему:

```bash
docker compose up --build
```

5. Открыть приложение в браузере: `http://localhost:8080`.

## Переменные окружения

| Переменная | Назначение | Пример |
| --- | --- | --- |
| `POSTGRES_USER` | Пользователь PostgreSQL | `change-me` |
| `POSTGRES_PASSWORD` | Пароль пользователя PostgreSQL | `change-me` |
| `POSTGRES_DB` | Имя базы данных PostgreSQL | `change-me` |
| `DATABASE_URL` | Строка подключения к БД (в Docker Compose переопределяется из `POSTGRES_*`) | `postgresql+psycopg://change-me:change-me@db:5432/change-me` |
| `SECRET_KEY` | Секретный ключ для подписи JWT | `change-me` |
| `ENCRYPTION_KEY` | Ключ Fernet для шифрования паролей ЭИОС (`python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`) | `change-me` |
| `FRONTEND_URL` | Базовый URL фронтенда (в `.env.example` закомментирован) | `http://localhost:8080` |
| `GOOGLE_CLIENT_ID` | Client ID приложения Google OAuth | `change-me` |
| `GOOGLE_CLIENT_SECRET` | Client Secret приложения Google OAuth | `change-me` |
| `GOOGLE_REDIRECT_URI` | URI обратного вызова Google OAuth | `http://localhost:8080/google-callback` |

## Настройка Google OAuth

Файлов Google credentials в проекте нет — `GOOGLE_CLIENT_ID` и `GOOGLE_CLIENT_SECRET` передаются через `.env`, а токены пользователей хранятся в базе данных.

В настройках OAuth 2.0 Client ID (Google Cloud Console → APIs & Services → Credentials) добавьте в **Authorized redirect URIs** значение `GOOGLE_REDIRECT_URI` из `.env` (`http://localhost:8080/google-callback`).

## Управление

Остановка контейнеров с сохранением данных БД:

```bash
docker compose down
```

Остановка с удалением тома `pgdata` (**удаляет все данные базы данных**):

```bash
docker compose down -v
```

Просмотр логов:

```bash
docker compose logs -f
```

Пересборка образов и запуск в фоне:

```bash
docker compose up --build -d
```

## Структура репозитория

```text
.
├── backend/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── requirements.txt
│   ├── main.py
│   └── app/
├── frontend/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── nginx.conf
│   └── package.json
├── scripts/
│   └── smoke.ps1
├── docs/
│   └── CHECKLIST.md
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

## Проверка развёртывания

Автоматическая проверка (Windows PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke.ps1
```

Полный ручной чек-лист приёмки находится в `docs/CHECKLIST.md`.

## Режим разработки на хосте

### Backend

PowerShell:

```powershell
$env:DATABASE_URL="postgresql+psycopg://USER:PASSWORD@localhost:5432/DBNAME"; uvicorn main:app --reload --port 8000
```

bash:

```bash
DATABASE_URL="postgresql+psycopg://USER:PASSWORD@localhost:5432/DBNAME" uvicorn main:app --reload --port 8000
```

### Frontend

PowerShell:

```powershell
$env:VITE_API_BASE_URL="http://localhost:8000"; npm run dev
```

bash:

```bash
VITE_API_BASE_URL=http://localhost:8000 npm run dev
```

## Типовые проблемы

- **Порт 8080 занят**: остановите процесс, занимающий порт `8080` на хосте, либо измените внешний порт сервиса `frontend` в `docker-compose.yml` (например, `"8081:80"`) и обновите `GOOGLE_REDIRECT_URI` в `.env`.
- **Backend ждёт db**: `backend` стартует только после перехода `db` в статус `healthy` (`pg_isready`). Если запуск затянулся, проверьте логи (`docker compose logs db`) и значения `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` в `.env`.
- **404 при обновлении страницы на вложенном маршруте**: убедитесь, что `frontend/nginx.conf` скопирован в `/etc/nginx/conf.d/default.conf` и содержит `try_files $uri$uri/ /index.html;` в `location /`, затем пересоберите `frontend` (`docker compose up --build -d`).