# PLAN

Статусы: `todo` | `doing` | `review` | `done` | `blocked`

## Бюджет
Дедлайн 1 декабря 2026. Не более 4 вечеров разработки (по 3–4 часа). Запись видео сверх этого.

## Раскладка по вечерам

| Вечер | Что делаем | Результат |
|---|---|---|
| 1 | T-002 (Executor); T-012–T-014 (Executor); параллельно Routine: T-003, T-004, T-005 | Приложение работает на PostgreSQL на хосте; фронтенд без хардкода; Dockerfile'ы и nginx.conf написаны |
| 2 | T-006 (Routine) + ревью Bridge (T-005, T-006); L-2; первый `docker compose up --build`, починка | Три контейнера поднимаются, фронтенд открывается на :8080 |
| 3 | T-007 (Executor) + ревью; L-1; T-009; полный сценарий: Google-авторизация, ЭИОС, правка события, экспорт, рестарт | Всё работает в контейнерах |
| 4 | L-3 (чистый клон, `smoke.ps1`, чек-лист); T-010 (README); финальные правки | Готово к записи |

Вне вечеров: T-011 (сценарий видео, Routine, можно в любой момент после T-009), L-4 (запись).
До дедлайна ~20 дней, запас на перенос вечеров есть.

## Задачи

| ID | Задача | Размер | Маршрут | Зависит от | Ревью Bridge | Статус |
|---|---|---|---|---|---|---|
| T-001 | Разведка кода → `docs/recon.md` | S | Executor | — | нет | done |
| T-002 | `DATABASE_URL` из env, `psycopg` (2 файла) | S | Executor | T-001 | **да** (данные) | done |
| T-012 | Фронтенд: `config.ts` + Login/Registration без хардкода | S | Executor | T-001 | нет | done |
| T-013 | Фронтенд: ProfileDialog, GoogleCallback, SetupPage без хардкода + описание OAuth-потока на фронте | S | Executor | T-012 | нет | done |
| T-014 | Фронтенд: GradesPage, SchedulePage + финальный grep по хардкоду | S | Executor | T-013 | нет | done |
| T-003 | `.env.example`, `.gitignore`, `.dockerignore` ×2 | S | Routine | T-001 | нет | done |
| T-004 | `backend/Dockerfile` | S | Routine | T-002 | нет | done |
| T-005 | `frontend/Dockerfile` + `frontend/nginx.conf` | S | Routine | T-001 | **да** (прокси/пути) | done |
| T-006 | `docker-compose.yml` | M | Routine | T-003, T-004, T-005 | **да** (порты, секреты) | done |
| T-007 | Ключи `SECRET_KEY`/`ENCRYPTION_KEY`: fail-fast, описание redirect_uri (сужено: OAuth в контейнерах уже работает) | S | Executor | T-006 | **да** (безопасность) | review |
| T-009 | `scripts/smoke.ps1` + `docs/CHECKLIST.md` | S | Routine | T-006 | нет | todo |
| T-010 | `README.md` | S | Routine | T-007, T-009 | нет | todo |
| T-011 | `docs/VIDEO.md`: сценарий видео | S | Routine | T-009 | нет | todo |

## Ручные шаги Lead (не делегируются)
- **L-1** Google Cloud Console: добавить authorized redirect URI `http://localhost:8080/google-callback` (D-014). Не ждёт T-007, можно сделать сразу. Без этого экспорт в календарь не заработает в контейнерах. Адрес `http://localhost:5173/google-callback` для разработки на хосте должен быть в списке тоже.
- **L-2** Создать `.env` из `.env.example`: сгенерировать `SECRET_KEY`, `ENCRYPTION_KEY`, задать пароль Postgres, вписать Google client id/secret. Не коммитить.
- **L-3** Проверка на чистом клоне: `git clone` в новую папку → `.env` → `docker compose up --build` → `scripts/smoke.ps1` → ручной сценарий из `docs/CHECKLIST.md`.
- **L-4** Запись видео по `docs/VIDEO.md`. Перед записью проверить, что токены, client secret и пароли не попадают в кадр.
- **L-5** Подтвердить или отклонить решения D-008…D-014 в `docs/DECISIONS.md`.

## Известные риски
- Поток Google OAuth: redirect URI это маршрут фронтенда `/google-callback` (T-013). Осталось проверить в коде backend, что значение единое для ссылки и обмена кода, и откуда в recon взялся `:8000/auth/google/callback` (T-007).
- Список файлов фронтенда с хардкодом неполный (в recon «например»). Выяснится в T-012.
- Тестов нет: приёмка вручную по `docs/CHECKLIST.md`.
- `verify=False` в клиентах ЭИОС оставляем как есть (D-013).
