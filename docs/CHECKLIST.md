# Чек-лист приёмки развёртывания (PowerShell)

## 1. Чистый клон и настройка окружения

- [ ] Клонировать репозиторий и перейти в каталог проекта:

```powershell
git clone <URL-репозитория>
cd <папка-проекта>
```

- [ ] Скопировать шаблон переменных окружения:

```powershell
Copy-Item .env.example .env
```

- [ ] Заполнить значения в `.env`:
  - `POSTGRES_PASSWORD`: латиница и цифры, без спецсимволов (пароль попадает в URL подключения);
  - `SECRET_KEY`: `python -c "import secrets; print(secrets.token_hex(32))"`;
  - `ENCRYPTION_KEY`: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`;
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`: из Google Cloud Console;
  - `GOOGLE_REDIRECT_URI`: `http://localhost:8080/google-callback` (этот же адрес добавлен в Google Cloud Console).

Без валидных `SECRET_KEY` и `ENCRYPTION_KEY` backend не стартует, это ожидаемое поведение.

## 2. Запуск и автоматическая проверка

- [ ] Собрать и поднять контейнеры:

```powershell
docker compose up --build -d
```

- [ ] Запустить smoke-тест:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke.ps1
```

Ожидаемо: все проверки `PASS`, `$LASTEXITCODE` равен `0`. Проверки: сервисы работают и БД `healthy`, `http://localhost:8080` и `http://localhost:8080/api/` отвечают 200, порты 5432 и 8000 с хоста закрыты, опубликован только порт 8080.

## 3. Ручной сценарий проверки приложения

Открыть `http://localhost:8080` в браузере и выполнить:

- [ ] Регистрация и логин в приложение.
- [ ] Подтяжка расписания из ЭИОС.
- [ ] Правка события в расписании.
- [ ] Google-авторизация и экспорт в Google Calendar.

## 4. Проверка сохранности данных

- [ ] Создать тестовое событие в приложении.
- [ ] Остановить и удалить контейнеры **без** удаления томов (без флага `-v`):

```powershell
docker compose down
```

- [ ] Повторно запустить систему:

```powershell
docker compose up -d
```

- [ ] Убедиться, что созданное событие сохранилось и отображается в приложении.

## 5. Проверка таблиц в PostgreSQL

- [ ] Проверить наличие таблиц (значения берутся из переменных окружения контейнера):

```powershell
docker compose exec db sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB -c "\dt"'
```

Ожидаемо: таблицы `users`, `events`, `disciplines`, `control_points`.

## 6. Старт на пустом томе

Проверка, что backend не падает при первом запуске, когда БД ещё инициализируется. Команда `-v` удаляет данные БД, выполнять только на тестовом стенде:

- [ ] Удалить контейнеры вместе с томом и запустить заново:

```powershell
docker compose down -v
docker compose up -d
```

- [ ] Дождаться готовности и проверить логи backend на ошибки подключения:

```powershell
docker compose ps
docker compose logs backend | Select-String "OperationalError|could not connect"
```

Ожидаемо: `db` в состоянии `healthy`, поиск по логам ничего не находит.
