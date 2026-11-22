# Бэк   
python(FastAPI, Uvicorn (сервер для запуска FastAPI), Pydantic (для валидации данных) и SQLAlchemy (для работы с базой данных))   
инициализация виртуального окружения `python3 -m venv venv`   
вход в виртуальное окружение `.\venv\Scripts\Activate`   
**работать с бэком только находясь в виртуальном окружении папки бэкенд!**   
сохранить зависимости `pip freeze > requirements.txt` (после подключения новых библиотек)   
   
запуск сервера  `uvicorn main:app --reload --port 8000`    
   
команды для быстого запуска в консоли из папки chronella
```
cd backend
.\venv\Scripts\Activate
uvicorn main:app --reload --port 8000
```

проверить зависимости
python -m pip list

восстановить библиотеки
python -m pip install -r requirements.txt
