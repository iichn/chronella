# Chronella

Веб-приложение для студентов: загрузка расписания и рейтинг-плана из ЭИОС МГУ им. Н.П. Огарёва, экспорт событий в Google Calendar и аналитика учебной нагрузки.
Стек: React + TypeScript + Vite (Nginx), FastAPI (Python 3.12), PostgreSQL 16.
Вся система развёртывается одной командой через Docker Compose.

## Архитектура

Система состоит из трёх контейнеров в изолированной bridge-сети `chronella_net` с именованным томом `pgdata` для данных PostgreSQL. На хост опубликован только порт `8080` (Nginx); `backend` и `db` напрямую с хоста недоступны.

- `frontend`: Nginx раздаёт собранное React-приложение и проксирует запросы `/api/*` на backend. Собственный Dockerfile, multi-stage сборка.
- `backend`: FastAPI-приложение (интеграция с ЭИОС и Google Calendar, аналитика, JWT). Собственный Dockerfile.
- `db`: официальный образ `postgres:16`, данные в томе `pgdata`. Backend стартует только после того, как healthcheck базы стал `healthy`.

```mermaid
flowchart LR
    Browser["Браузер"] -->|"http://localhost:8080"| Frontend["frontend: Nginx :80"]
    Frontend -->|"статика SPA"| Browser
    Frontend -->|"/api/* → /*"| Backend["backend: FastAPI :8000"]
    Backend -->|"psycopg :5432"| DB[("db: PostgreSQL 16")]
    DB --- Volume[("volume: pgdata")]
```

## Требования

- Docker
- Docker Compose v2 (`docker compose`)

## Быстрый старт

1. Клонировать репозиторий:

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

3. Заполнить `.env` (таблица ниже). Ключи `SECRET_KEY` и `ENCRYPTION_KEY` нужно сгенерировать: без валидных значений backend не стартует (так задумано), заглушка `change-me` не подходит.

4. Собрать и запустить систему:

```powershell
docker compose up --build -d
```

5. Открыть приложение: `http://localhost:8080`.

## Переменные окружения

Файл `.env` лежит в корне проекта и в репозиторий не попадает (в `.gitignore`). Строку подключения `DATABASE_URL` для backend Docker Compose собирает сам из `POSTGRES_*`, отдельно задавать её не нужно.

| Переменная | Назначение | Пример |
| --- | --- | --- |
| `POSTGRES_USER` | Пользователь PostgreSQL | `chronella` |
| `POSTGRES_PASSWORD` | Пароль PostgreSQL. Только латиница и цифры: пароль попадает в URL подключения | `change-me` |
| `POSTGRES_DB` | Имя базы данных | `chronella` |
| `SECRET_KEY` | Ключ подписи JWT. Генерация: `python -c "import secrets; print(secrets.token_hex(32))"` | `change-me` |
| `ENCRYPTION_KEY` | Ключ Fernet для шифрования паролей ЭИОС. Генерация: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` | `change-me` |
| `GOOGLE_CLIENT_ID` | Client ID приложения Google OAuth | `change-me` |
| `GOOGLE_CLIENT_SECRET` | Client Secret приложения Google OAuth | `change-me` |
| `GOOGLE_REDIRECT_URI` | Адрес возврата после авторизации Google (маршрут фронтенда) | `http://localhost:8080/google-callback` |

Python на хосте для генерации ключей можно не ставить: ключ создаётся командой внутри контейнера после первой сборки:

```powershell
docker compose run --rm --no-deps --entrypoint python backend -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

## Настройка Google OAuth

Файлов Google credentials в проекте нет: `GOOGLE_CLIENT_ID` и `GOOGLE_CLIENT_SECRET` передаются через `.env`, токены пользователей хранятся в базе данных.

В Google Cloud Console (APIs & Services → Credentials → OAuth 2.0 Client ID) добавьте в **Authorized redirect URIs** точное значение `GOOGLE_REDIRECT_URI` из `.env`: `http://localhost:8080/google-callback`. Google возвращает браузер на эту страницу фронтенда, она передаёт код авторизации на backend.

## Управление

Остановка с сохранением данных БД:

```powershell
docker compose down
```

Остановка с удалением тома `pgdata` (**удаляет все данные базы**):

```powershell
docker compose down -v
```

Логи:

```powershell
docker compose logs -f
```

Пересборка образов и запуск в фоне:

```powershell
docker compose up --build -d
```

Применить изменения в `.env` (контейнер читает его при создании):

```powershell
docker compose up -d --force-recreate backend
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
│   ├── package.json
│   └── src/
├── scripts/
│   └── smoke.ps1
├── docs/                 чек-лист приёмки и рабочие документы проекта
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

## Проверка развёртывания

Автоматическая проверка (Windows PowerShell). Проверяет, что сервисы работают, БД `healthy`, фронтенд и `/api/` отвечают, порты 5432 и 8000 с хоста закрыты, опубликован только порт 8080:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke.ps1
```

Полный ручной чек-лист приёмки: `docs/CHECKLIST.md`.

## Режим разработки на хосте

Нужен для работы над кодом без пересборки образов. В Compose порт БД на хост не публикуется, поэтому для этого режима отдельно запускается временный Postgres.

База:

```powershell
docker run -d --name chronella-pg-dev -e POSTGRES_USER=chronella -e POSTGRES_PASSWORD=devpass -e POSTGRES_DB=chronella -p 5432:5432 postgres:16
```

Backend (создать `backend/.env` с `SECRET_KEY`, `ENCRYPTION_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` и `GOOGLE_REDIRECT_URI=http://localhost:5173/google-callback`; этот адрес тоже должен быть в списке Authorized redirect URIs; файл в `.gitignore`):

PowerShell:

```powershell
cd backend
pip install -r requirements.txt
$env:DATABASE_URL="postgresql+psycopg://chronella:devpass@localhost:5432/chronella"; uvicorn main:app --reload --port 8000
```

bash:

```bash
cd backend
pip install -r requirements.txt
DATABASE_URL="postgresql+psycopg://chronella:devpass@localhost:5432/chronella" uvicorn main:app --reload --port 8000
```

Frontend:

PowerShell:

```powershell
cd frontend
npm ci
$env:VITE_API_BASE_URL="http://localhost:8000"; npm run dev
```

bash:

```bash
cd frontend
npm ci
VITE_API_BASE_URL=http://localhost:8000 npm run dev
```

## Типовые проблемы

- **Порт 8080 занят**: остановите процесс на этом порту либо измените внешний порт `frontend` в `docker-compose.yml` (например, `"8081:80"`). Тогда обновите `GOOGLE_REDIRECT_URI` в `.env` и в Google Cloud Console.
- **Backend не стартует**: `docker compose logs backend`. Сообщения `SECRET_KEY is not set`, `ENCRYPTION_KEY is not set`, `Invalid ENCRYPTION_KEY` означают, что ключ не задан или не является валидным ключом Fernet.
- **Backend ждёт db**: backend запускается после перехода `db` в `healthy`. Если запуск затянулся, смотрите `docker compose logs db` и значения `POSTGRES_*` в `.env`.
- **Пароль PostgreSQL поменяли после первого запуска**: том `pgdata` хранит старый пароль. Выполните `docker compose down -v` (данные БД будут удалены) и запустите заново.
- **`redirect_uri_mismatch` при Google-авторизации**: адрес из `GOOGLE_REDIRECT_URI` должен точно совпадать со значением в Google Cloud Console.
- **502 или 504 на `/api/`**: backend остановлен или упал, смотрите `docker compose ps` и `docker compose logs backend`.
- **404 при обновлении страницы на вложенном маршруте**: в `frontend/nginx.conf` в `location /` должна быть строка `try_files $uri $uri/ /index.html;`. После правки пересоберите `frontend`: `docker compose up --build -d`.

## Известные ограничения

- Схема БД создаётся при старте backend (`create_all`), система миграций не используется.
- В запросах к ЭИОС отключена проверка TLS-сертификата (`verify=False`).
- В коде фронтенда есть ошибки типов TypeScript, не связанные с контейнеризацией, поэтому образ собирается командой `vite build` без `tsc -b`.
- Скрипт `backend/migrate_db.py` остался от SQLite-версии и в контейнерной системе не используется.
