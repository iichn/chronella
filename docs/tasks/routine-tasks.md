# ТЗ для Routine

Каждый блок ниже вставляется в чат отдельно. К сообщению приложить файлы из строки «Приложить».
Выполнять строго по порядку зависимостей из `docs/PLAN.md`. Значения из `docs/recon.md` уже подставлены.

---

## T-003: `.env.example`, `.gitignore`, `.dockerignore`

Приложить: текущий `.gitignore`.

```
ID: T-003
Цель: Подготовить файлы-исключения и шаблон переменных окружения для проекта в Docker.
Контекст: Проект: backend (FastAPI) в `backend/`, frontend (React+Vite) в `frontend/`. Конфиг и секреты хранятся в `.env`, который нельзя коммитить. Файлов Google credentials в проекте нет: client id/secret приходят из env, токены хранятся в БД.
Файлы: создать `.env.example`, `backend/.dockerignore`, `frontend/.dockerignore`; изменить `.gitignore`.
Делать:
1. `.env.example` в корне: переменные для db (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB), backend (DATABASE_URL в формате postgresql+psycopg://USER:PASSWORD@db:5432/DBNAME, SECRET_KEY для JWT, ENCRYPTION_KEY для шифрования паролей ЭИОС (формат ключа уточнить по `backend/app/core/security.py`, указать в комментарии, как его сгенерировать), GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI=http://localhost:8080/api/auth/google/callback (может уточниться в T-007), FRONTEND_URL=http://localhost:8080 (добавить как закомментированную строку, раскомментирует T-007). Значения-заглушки вида `change-me`, возле каждой группы комментарий в одну строку.
2. `backend/.dockerignore`: `.env*`, `*.db`, `__pycache__`, `.venv`, `venv`, `.git`, `*.pyc`, `tests`, `*.md`.
3. `frontend/.dockerignore`: `node_modules`, `dist`, `.env*`, `.git`, `*.md`.
4. `.gitignore`: добавить недостающее (`.env`, `*.db`, `node_modules`, `dist`, `__pycache__`, `.venv`). Существующие строки не удалять.
Не трогать: исходный код, остальные файлы.
Готово, когда: `.env.example` не содержит реальных секретов; присутствуют все переменные из списка выше; `.env` и `*.db` есть в `.gitignore`, `.env*` и `*.db` есть в `backend/.dockerignore`.
Как проверить: `git check-ignore -v .env backend/database.db` выводит правило; `git status` не показывает `.env`.
Формат ответа: файлы целиком; для `.gitignore` только добавленные строки и куда их вставить.
```

---

## T-004: `backend/Dockerfile`

Приложить: `backend/requirements.txt`.

```
ID: T-004
Цель: Написать Dockerfile для backend (FastAPI + Uvicorn).
Контекст: Базовый образ python:3.12-slim. Зависимости в requirements.txt. Приложение стартует командой `uvicorn main:app` из каталога `backend/` (файл `backend/main.py`), контекст сборки `./backend`. Секреты в образ не копируются (приходят через env). БД Postgres доступна по имени `db`. Версия Python в проекте не зафиксирована, берём 3.12.
Файлы: создать `backend/Dockerfile`.
Делать:
1. FROM python:3.12-slim; WORKDIR /app.
2. Сначала COPY requirements.txt и RUN pip install --no-cache-dir -r requirements.txt (кэш слоя), потом COPY остального кода.
3. Переменные PYTHONDONTWRITEBYTECODE=1 и PYTHONUNBUFFERED=1.
4. Запуск от непривилегированного пользователя (создать пользователя, chown /app).
5. EXPOSE 8000; CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"].
Не трогать: код приложения, requirements.txt, .dockerignore. Не копировать .env и *.db в образ. Не добавлять build-tools, если для установки зависимостей они не нужны (если нужны, перечислить какие и почему).
Готово, когда: образ собирается (`docker build -t chronella-backend ./backend`), `pip install` проходит на Python 3.12; в образе нет `.env` и `*.db`; процесс не root; итоговый образ без лишних пакетов.
Как проверить: `docker build`; `docker run --rm chronella-backend id` (не root); `docker run --rm chronella-backend ls -a /app` (нет .env, *.db); `docker images chronella-backend` (размер).
Формат ответа: файл целиком.
```

---

## T-005: `frontend/Dockerfile` + `frontend/nginx.conf`

Приложить: `frontend/package.json`. Ревью Bridge: да (прокси и пути).

```
ID: T-005
Цель: Multi-stage Dockerfile для frontend и конфиг Nginx, отдающий статику и проксирующий /api на backend.
Контекст: React + TypeScript + Vite. Сборка `npm run build` даёт каталог dist. В compose backend доступен как `http://backend:8000`. Браузер ходит на единый origin `http://localhost:8080`, запросы `/api/...` Nginx передаёт backend. Префикса `/api` у роутов backend нет (роуты вида `/auth/...`, `/`). Сборка: `tsc -b && vite build`. Версия Node в проекте не зафиксирована, берём 22 LTS.
Файлы: создать `frontend/Dockerfile`, `frontend/nginx.conf`.
Делать:
1. Dockerfile, stage 1 `build`: FROM node:22-alpine; COPY package*.json; `npm ci`; COPY остального; `npm run build`.
2. Stage 2: FROM nginx:alpine; COPY --from=build /app/dist /usr/share/nginx/html; COPY nginx.conf /etc/nginx/conf.d/default.conf; EXPOSE 80.
3. nginx.conf: `listen 80`; `location /` с `try_files $uri $uri/ /index.html` (SPA-роутинг); `location /api/` с `proxy_pass` на backend и заголовками Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto.
4. Про `proxy_pass`: у backend нет префикса /api, поэтому использовать `proxy_pass http://backend:8000/;` (слэш в конце срезает /api). В ответе одной строкой пояснить, зачем слэш.
5. Включить gzip для js/css/json.
Не трогать: код фронтенда, package.json.
Готово, когда: образ собирается; в итоговом образе нет node_modules и исходников; обновление страницы на вложенном маршруте SPA отдаёт приложение, а не 404; запрос `/api/...` доходит до backend.
Как проверить: `docker build -t chronella-frontend ./frontend`; `docker run --rm chronella-frontend ls /usr/share/nginx/html`; `docker run --rm chronella-frontend nginx -t`; после T-006: открыть вложенный маршрут и нажать F5.
Формат ответа: оба файла целиком.
```

---

## T-006: `docker-compose.yml`

Приложить: `.env.example`, `backend/Dockerfile`, `frontend/Dockerfile`. Ревью Bridge: да (порты, секреты).

```
ID: T-006
Цель: Описать всю систему одним docker-compose.yml: три сервиса, сеть, том, healthcheck.
Контекст: Сервисы: `db` (postgres:16), `backend` (build ./backend), `frontend` (build ./frontend, Nginx). Конфиг из `.env` (шаблон `.env.example`). Файлов Google credentials нет, всё приходит через env.
Файлы: создать `docker-compose.yml` в корне.
Делать:
1. Сеть `chronella_net` (driver bridge). Все сервисы в ней.
2. `db`: image postgres:16; environment POSTGRES_USER/PASSWORD/DB из `.env` через `${...}`; volume `pgdata:/var/lib/postgresql/data`; healthcheck `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}` (interval 5s, timeout 5s, retries 10); БЕЗ `ports`.
3. `backend`: build ./backend; `env_file: .env`; `depends_on: db: condition: service_healthy`; БЕЗ `ports`; `restart: unless-stopped`.
4. `frontend`: build ./frontend; `depends_on: backend`; `ports: "8080:80"` (единственный опубликованный порт); `restart: unless-stopped`.
5. Верхнеуровневые `volumes: pgdata` и `networks: chronella_net`.
6. Пароли и секреты не писать в файл, только `${VAR}`.
Не трогать: Dockerfile'ы, код, `.env`.
Готово, когда: `docker compose config` без ошибок; `docker compose up --build` поднимает все три сервиса; backend стартует после healthy db; с хоста доступен только 8080; данные в pgdata переживают `docker compose down && docker compose up`.
Как проверить: `docker compose config`; `docker compose up --build -d`; `docker compose ps` (db healthy, опубликован только 8080); `curl -sS localhost:5432` и `curl -sS localhost:8000` не соединяются; `curl -I localhost:8080` возвращает 200.
Формат ответа: файл целиком + список переменных, которые должны быть в `.env`.
```

---

## T-009: `scripts/smoke.sh` + `docs/CHECKLIST.md`

Приложить: `docker-compose.yml`.

```
ID: T-009
Цель: Автоматизировать базовую проверку развёртывания и описать ручной сценарий приёмки.
Контекст: Тестов нет. Система запускается `docker compose up --build`, фронтенд доступен на http://localhost:8080, backend и db с хоста недоступны. Эндпоинт живости backend: `GET /` (возвращает JSON-приветствие), через Nginx доступен как `GET /api/`.
Файлы: создать `scripts/smoke.sh`, `docs/CHECKLIST.md`.
Делать:
1. `scripts/smoke.sh` (bash, `set -u`, понятный вывод PASS/FAIL по каждой проверке, код возврата ≠0 при любом FAIL):
   a. `docker compose ps` показывает db, backend, frontend в состоянии running (db healthy);
   b. GET http://localhost:8080 возвращает 200;
   c. GET http://localhost:8080/api/ возвращает 200;
   d. порты 5432 и 8000 на хосте закрыты (нет соединения);
   e. в `docker compose ps --format json` опубликован только порт 8080.
2. `docs/CHECKLIST.md`: чек-лист для чистого клона: клонировать → `cp .env.example .env` → заполнить → `docker compose up --build` → `scripts/smoke.sh` → ручной сценарий (логин, подтяжка расписания из ЭИОС, правка события, экспорт в Google Calendar) → проверка сохранности данных (создать событие → `docker compose down` без `-v` → `up` → событие на месте) → `docker compose exec db psql -U <user> -d <db> -c "\dt"`.
Не трогать: остальные файлы.
Готово, когда: `bash scripts/smoke.sh` на рабочем стенде печатает PASS по всем пунктам, на остановленном стенде возвращает ненулевой код; CHECKLIST содержит все шаги выше.
Как проверить: запустить скрипт при поднятой системе, затем после `docker compose stop backend`.
Формат ответа: оба файла целиком.
```

---

## T-010: `README.md`

Приложить: `docker-compose.yml`, `.env.example`.

```
ID: T-010
Цель: Написать README с инструкцией запуска одной командой.
Контекст: Chronella: веб-приложение для студентов (расписание и рейтинг-план из ЭИОС МГУ им. Н.П. Огарёва, экспорт в Google Calendar, аналитика нагрузки). Стек: React + FastAPI + PostgreSQL 16 + Nginx, всё в Docker Compose. README читает преподаватель курса «Управление конфигурацией ПО».
Файлы: создать/заменить `README.md`.
Делать:
1. Разделы: описание (3–4 строки); архитектура (3 контейнера, сеть, том, порт 8080, текстовая схема или mermaid); требования (Docker, Docker Compose v2); быстрый старт (clone → `cp .env.example .env` → заполнить → `docker compose up --build` → http://localhost:8080); таблица переменных окружения (имя, назначение, пример без секретов); настройка Google OAuth (куда добавить redirect URI; файлов credentials нет, client id/secret в `.env`); управление (`down`, `down -v` с пояснением, что `-v` удаляет данные, логи, пересборка); структура репозитория; проверка (`scripts/smoke.sh`); типовые проблемы (порт 8080 занят, backend ждёт db, 404 при обновлении страницы).
2. Режим разработки на хосте: backend `uvicorn main:app --reload --port 8000` (с `DATABASE_URL` на Postgres), frontend `VITE_API_BASE_URL=http://localhost:8000 npm run dev`.
3. Только факты, подтверждённые приложенными файлами. Нет данных, пиши «уточнить».
Не трогать: остальные файлы.
Готово, когда: по README с чистой машины можно запустить систему без других источников; все переменные из `.env.example` описаны; нет реальных секретов.
Как проверить: пройти README пошагово в чистом клоне.
Формат ответа: файл целиком.
```

---

## T-011: `docs/VIDEO.md` (сценарий видео)

Приложить: `docs/CHECKLIST.md`, `docker-compose.yml`.

```
ID: T-011
Цель: Составить сценарий видео-демонстрации курсовой длительностью 10–12 минут.
Контекст: Курсовая по УКПО, тема C. Преподаватель ждёт видео ≥10 минут, отражающее весь объём работы. Для каждой практики из плана нужно показать доказательство, что она работает.
Файлы: создать `docs/VIDEO.md`.
Делать: таблица «время | что на экране | что говорить (тезисы, 2–3 строки) | команда/файл»:
0:00–1:00 проект и схема «было/стало»; 1:00–3:00 конфиг вне кода (.env.example, .gitignore, DATABASE_URL из env); 3:00–5:30 Dockerfile'ы (multi-stage, `docker images`); 5:30–7:00 docker-compose.yml (healthcheck, depends_on, сеть, том, один опубликованный порт); 7:00–8:30 чистый клон и `docker compose up --build` (ускорение сборки при монтаже); 8:30–10:00 работа приложения (логин, расписание, правка, экспорт в календарь); 10:00–11:30 доказательства (изоляция портов, сохранность данных после down/up, `\dt` и SELECT, порядок старта по логам, отсутствие секретов в образе); 11:30–12:00 итог по этапам плана.
Добавить раздел «Перед записью»: проверить, что токены, client secret и пароли не попадают в кадр; очистить кэш сборки (`docker builder prune`) для честной демонстрации; подготовить тестового пользователя.
Не трогать: остальные файлы.
Готово, когда: у каждого этапа плана курсовой есть соответствующий фрагмент; суммарная длительность 10–12 минут; указаны точные команды для каждого показа.
Как проверить: прогнать сценарий вслух с таймером.
Формат ответа: файл целиком.
```
