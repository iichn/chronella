# Recon для контейнеризации и миграции на PostgreSQL

## 1. Где создаётся SQLAlchemy engine и сессия, откуда берётся URL БД (хардкод, env, файл)

- URL БД и engine создаются в `backend/app/database.py:7-18`:
  - `SQLALCHEMY_DATABASE_URL = "sqlite:///./database.db"`
  - `create_engine(..., connect_args={"check_same_thread": False})`
- Сессия создаётся в `backend/app/database.py:20-33`:
  - `SessionLocal = sessionmaker(...)`
  - `def get_db(): ... yield db ... finally: db.close()`
- Источник URL: хардкод в коде, а не env/file. В repo нет отдельного `.env` для DB URL; поиск по `backend/**/*.py` не нашёл другого источника для URL БД.

## 2. Как создаются таблицы: create_all, Alembic, SQL-файл, вручную. Где вызывается

- Таблицы создаются через SQLAlchemy `Base.metadata.create_all(bind=engine)` в `backend/main.py:15-19`.
- Инициализация приложения и `Base.metadata.create_all(bind=engine)` вызываются при старте в `backend/main.py:15-19`.
- Alembic: не найдено.
- SQL-файл миграций: не найдено.
- Вручную через SQLite создаётся/переинициализируется база в `backend/migrate_db.py:8-10`:
  - `Base.metadata.drop_all(bind=engine)`
  - `Base.metadata.create_all(bind=engine)`
- Дополнительная ручная миграция через `sqlite3` и `ALTER TABLE` есть в `backend/migrate_db.py:17-63`.

## 3. SQLite-специфика: connect_args (`check_same_thread`), `PRAGMA`, функции `strftime`/`date()`/`julianday`, `AUTOINCREMENT`, прочий sqlite-синтаксис

- `connect_args={"check_same_thread": False}` есть в `backend/app/database.py:13-18`.
- `PRAGMA table_info(users)` есть в `backend/migrate_db.py:29-30`.
- `ALTER TABLE users ADD COLUMN ...` есть в `backend/migrate_db.py:46-49`.
- SQLite-специфичные функции `strftime`, `date()`, `julianday` в SQL-контексте: не найдено.
- `AUTOINCREMENT`: не найдено.
- Прочий sqlite-синтаксис в коде: не найдено, кроме прямого `sqlite3.connect(...)` и `PRAGMA/ALTER TABLE` в `backend/migrate_db.py:17-63`.
- В Python коде есть вызовы `datetime.strftime(...)` для форматирования дат, но это не SQLite SQL-функции: `backend/app/services/google_calendar.py:52-59`, `backend/app/routers/performance.py:136`.

## 4. Сырой SQL: все места с `text(...)`, `execute("...")`, `.from_statement`, строковые фильтры

- Прямые SQL-команды через `sqlite3` есть в `backend/migrate_db.py:25-49`:
  - `conn = sqlite3.connect(DB_PATH)`
  - `cursor.execute("PRAGMA table_info(users)")`
  - `cursor.execute(alter_sql)`
- Использование `text(...)` в SQLAlchemy: не найдено.
- `.from_statement(...)`: не найдено.
- Строковые фильтры через SQLAlchemy `filter(...)`/`filter_by(...)` встречаются, но это не сырой SQL; пример: `backend/app/routers/performance.py:19-22`, `backend/app/routers/performance.py:80-88`, `backend/app/routers/performance.py:118-135`.
- Сырой SQL в проекте ограничен миграционным скриптом `backend/migrate_db.py:25-49`.

## 5. Типы колонок, потенциально чувствительные к смене СУБД: Boolean, DateTime (с/без timezone), JSON, Enum, LargeBinary; сравнения строк, зависящие от регистра

- Поля в модели `User` и др.:
  - `Boolean` в `backend/app/models.py:23-39`
  - `DateTime` в `backend/app/models.py:32-33`, `backend/app/models.py:53-54`, `backend/app/models.py:88`
  - `JSON` в `backend/app/models.py:61`, `backend/app/models.py:94`
  - `Enum` в `backend/app/models.py:6-20` и `backend/app/models.py:1`
- `LargeBinary`: не найдено.
- Сравнения строк, зависящие от регистра: не найдены как явные SQL-операции; в проекте используются Python-строки и `filter`/`filter_by`, например `backend/app/routers/performance.py:118-135` и `backend/app/routers/performance.py:143-152`. Но явных `LOWER(...)`/case-insensitive SQL-операций не найдено.
- `DateTime` без timezone явно используется в `backend/app/models.py:32-33`, `backend/app/models.py:53-54`, `backend/app/models.py:88`; timezone-aware `DateTime` не используется в модели.
- `JSON` хранится как `Column(JSON, nullable=True)` в `backend/app/models.py:61`, `backend/app/models.py:94`.
- `Enum` используется как `class EventType(str, enum.Enum)` и `class ControlPointType(str, enum.Enum)` в `backend/app/models.py:6-20`.

## 6. Конфигурация и секреты: где и как читаются (`os.environ`, dotenv, json/yaml-файлы). Список всех имён переменных/ключей с указанием, где используются. Значения не выписывать

- `.env`/`dotenv` загружается в `backend/main.py:1-4`:
  - `from dotenv import load_dotenv`
  - `load_dotenv()`
- Переменные окружения читаются через `os.getenv(...)`:
  - `GOOGLE_CLIENT_ID` в `backend/app/routers/google_auth.py:17-20` и `backend/app/services/google_calendar.py:24-31`
  - `GOOGLE_CLIENT_SECRET` в `backend/app/routers/google_auth.py:17-20` и `backend/app/services/google_calendar.py:24-31`
  - `GOOGLE_REDIRECT_URI` в `backend/app/routers/google_auth.py:17-20`
  - `SECRET_KEY` в `backend/app/auth_utils.py:10-15`
  - `ENCRYPTION_KEY` в `backend/app/core/security.py:17-29`
- В `backend/main.py:21` есть отладочный вывод `print(f"DEBUG: Client ID is {os.getenv('GOOGLE_CLIENT_ID')}")`.
- JSON/YAML-конфиги: не найдено.
- Файл `.env`/`env.example` в проекте: не найдено.

## 7. Файлы на диске, которые backend читает или пишет: Google credentials, токены, `chronella.db`, кэш, логи. Какие пути, абсолютные или относительные

- Основной файл БД — относительный SQLite путь `sqlite:///./database.db` в `backend/app/database.py:7-18`. Это приводит к созданию/чтению файла `database.db` в каталоге `backend/`.
- Ручная миграция работает с `database.db` через `DB_PATH = "database.db"` и `sqlite3.connect(DB_PATH)` в `backend/migrate_db.py:17-25`.
- Google credentials JSON-файл: не найдено.
- Кэш Google OAuth / токены / логов на диске: не найдено.
- Токены Google и MRSU хранятся в БД, а не как отдельные файлы: `google_refresh_token`, `mrsu_access_token`, `mrsu_password_encrypted` в `backend/app/models.py:29-39`.
- Логи в файл: не найдено.

## 8. Google OAuth: тип потока, где задан redirect URI, какие URL участвуют

- Тип потока: OAuth 2.0 Authorization Code Flow (`flow.authorization_url(...)` + `flow.fetch_token(code=code)`) в `backend/app/routers/google_auth.py:17-37`, `backend/app/routers/google_auth.py:45-67`.
- Redirect URI берётся из env: `redirect_uri = os.getenv("GOOGLE_REDIRECT_URI")` в `backend/app/routers/google_auth.py:17-20`.
- Конфигурация OAuth-ендпоинтов задаётся в `backend/app/routers/google_auth.py:22-35`:
  - `"auth_uri": "https://accounts.google.com/o/oauth2/auth"`
  - `"token_uri": "https://oauth2.googleapis.com/token"`
- URL, участвующие в потоке:
  - `https://accounts.google.com/o/oauth2/auth` — auth URI
  - `https://oauth2.googleapis.com/token` — token URI
  - `http://localhost:8000/auth/google/callback` — используется из frontend redirect flow и серверного callback (`backend/app/routers/google_auth.py:45-67`, `frontend/src/pages/SetupPage.tsx:143-182`, `frontend/src/pages/GoogleCallback.tsx:8-32`)
- Frontend вызывает `GET http://localhost:8000/auth/google/url` в `frontend/src/pages/SetupPage.tsx:145-182` и затем редиректится через `window.location.href = data.url`.

## 9. CORS: где настроен, какие origins разрешены. Frontend: откуда берётся базовый URL API (константа, env, `vite.config` proxy). Есть ли префикс `/api` у роутов backend, или он добавляется где-то ещё

- CORS настроен в `backend/main.py:27-46`:
  - `origins = [...]`
  - `app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])`
- Разрешённые origins:
  - `http://localhost`
  - `http://localhost:3000`
  - `http://localhost:5173`
  - `http://127.0.0.1:5173`
  - `http://127.0.0.1:3000`
- Frontend базовый URL API: константы в клиентском коде, например:
  - `frontend/src/pages/LoginPage.tsx:10`
  - `frontend/src/pages/RegistrationPage.tsx:9`
  - `frontend/src/pages/SetupPage.tsx:11`
  - `frontend/src/pages/GoogleCallback.tsx:10-18`
  - Все указаны как `http://localhost:8000`.
- `vite.config.ts` не содержит `server.proxy`/`proxy` и не добавляет `/api` префикс: `frontend/vite.config.ts:1-7`.
- Префикс `/api` в backend: не найдено.
- Роутеры подключаются напрямую в `backend/main.py:54-58` без глобального префикса `/api`:
  - `app.include_router(schedule.router)`
  - `app.include_router(auth.router)`
  - `app.include_router(users.router)`
  - `app.include_router(google_auth.router)`
  - `app.include_router(performance.router)`

## 10. Запуск и версии: команды запуска backend и frontend, порты, версия Python (по `.python-version`/`runtime.txt`/README, иначе «не указана»), версия Node (`.nvmrc`/`engines`/lock-файл), наличие `requirements.txt` и lock-файла фронтенда, точка входа ASGI (`module:app`)

- Команда запуска backend: `uvicorn main:app --reload --port 8000` в `start.bat:5`.
- Команда запуска frontend: `npm run dev` в `start.bat:8`.
- Порты:
  - backend: `8000` (`start.bat:5`)
  - frontend: `5173` (`backend/main.py:32-39`, `start.bat:8`)
- Точка входа ASGI: `main:app` — FastAPI app создаётся в `backend/main.py:22-27` и запускается как `uvicorn main:app`.
- Версия Python: не указана. В repo не найдено `.python-version`, `runtime.txt` и явной версии в README; требования в `backend/requirements.txt` есть, но версия Python не зафиксирована.
- Версия Node: не указана. В repo не найдено `.nvmrc`, и `frontend/package.json` не содержит `engines`.
- `backend/requirements.txt` существует: `backend/requirements.txt`.
- Frontend lock-файл: `frontend/package-lock.json` существует.
- Frontend `package.json` scripts: `vite`, `tsc -b && vite build` в `frontend/package.json:5-17`.

## 11. Исходящие запросы к ЭИОС: URL (домен), используются ли прокси, `verify=False`, кастомные сертификаты, таймауты

- Домен и URL:
  - `https://papi.mrsu.ru/v1` в `backend/app/services/mrsu.py:4-5`
  - `https://p.mrsu.ru/OAuth/Token` в `backend/app/services/mrsu.py:5`
- Использование прокси: не найдено.
- `verify=False` используется в исходящих запросах:
  - `async with httpx.AsyncClient(verify=False, timeout=20.0)` в `backend/app/routers/performance.py:29-33`
  - `async with httpx.AsyncClient(verify=False, timeout=15.0)` в `backend/app/routers/performance.py:72-76`
  - `async with httpx.AsyncClient(verify=False, timeout=30.0)` в `backend/app/routers/schedule.py:68`, `backend/app/routers/schedule.py:79` (при чтении в файле есть вызовы с `verify=False`; момент строки может зависеть от конкретной записи в файле)
- Кастомные сертификаты: не найдено.
- Таймауты:
  - `httpx.AsyncClient(timeout=10)` в `backend/app/services/mrsu.py:18-20`
  - `httpx.AsyncClient(verify=False, timeout=20.0)` в `backend/app/routers/performance.py:29-33`
  - `httpx.AsyncClient(verify=False, timeout=15.0)` в `backend/app/routers/performance.py:72-76`
  - `httpx.AsyncClient(verify=False, timeout=30.0)` в `backend/app/routers/schedule.py:68`, `backend/app/routers/schedule.py:79`

## 12. Эндпоинт, подходящий для проверки живости backend (`/docs`, `/health` и т.п.)

- Базовый root endpoint есть в `backend/main.py:49-50`:
  - `@app.get("/")`
  - возвращает `{"message": "Hello from Chronella FastAPI Backend!"}`
- FastAPI docs endpoint существует автоматически: комментарий в `backend/main.py:60-61` указывает на `/docs`.
- Специальный `/health` endpoint: не найдено.
- Специальный `/ready`/`/status` endpoint: не найдено.
- Для проверки живости backend в текущем коде ближайший очевидный вариант — `/docs` или root `/`.

# Риски для миграции на PostgreSQL

- `sqlite:///./database.db` и `check_same_thread` делают БД SQLite-специфичной: `backend/app/database.py:7-18`.
- Ручная миграция через `PRAGMA table_info(users)` и `ALTER TABLE users ADD COLUMN ...` привязана к SQLite: `backend/migrate_db.py:17-63`.
- `Boolean`, `DateTime`, `JSON`, `Enum` типы могут вести себя по-разному в PostgreSQL, особенно при миграции данных: `backend/app/models.py:1-94`.
- `DateTime` без timezone может потребовать явного выбора timezone и преобразований при переходе на PostgreSQL: `backend/app/models.py:32-33`, `backend/app/models.py:53-54`, `backend/app/models.py:88`.
- `JSON` поля могут различаться по типу хранения и индексированию между SQLite и PostgreSQL: `backend/app/models.py:61`, `backend/app/models.py:94`.
- `Enum`-поля в SQLAlchemy при генерации схемы могут отличаться от SQLite-стиля и потребуют проверки миграции: `backend/app/models.py:6-20`.
- Отсутствие `AUTOINCREMENT`/sqlite-специфичных DDL и прямых SQLite функций в коде не обнаружено, но миграционный скрипт и DB engine всё равно привязаны к SQLite-стилю: `backend/migrate_db.py:17-63`, `backend/app/database.py:7-18`.
- Сравнения строк как case-insensitive SQL-операции явно не найдены, однако перенос на PostgreSQL всё равно потребуется проверить на регистрозависимость и сортировку в реальных запросах: `backend/app/routers/performance.py:80-88`, `backend/app/routers/performance.py:118-135`.
