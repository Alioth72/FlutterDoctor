#!/usr/bin/env bash
echo "Starting FastAPI Backend on http://0.0.0.0:8000 ..."
/Library/Frameworks/Python.framework/Versions/3.12/bin/python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
