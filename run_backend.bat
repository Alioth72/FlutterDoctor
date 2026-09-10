@echo off
echo Starting FastAPI Backend on http://0.0.0.0:8000 ...
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Could not start with 'python'. Trying 'py'...
    py -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
)
pause
