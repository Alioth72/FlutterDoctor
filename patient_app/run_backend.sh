#!/usr/bin/env bash
echo "Starting FastAPI Backend on http://0.0.0.0:8000 ..."
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    PYTHON_CMD="python"
fi
$PYTHON_CMD -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

