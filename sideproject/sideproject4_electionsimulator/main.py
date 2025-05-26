#!/usr/bin/env python3
"""
대선 시뮬레이터 메인 실행 스크립트
Render.com 배포용
"""

import os
import sys
from pathlib import Path

# 현재 디렉토리와 하위 디렉토리들을 Python 경로에 추가
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))
sys.path.insert(0, str(current_dir / "web"))

try:
    # web 디렉토리의 api_server 모듈 import
    from web.api_server import app
except ImportError as e:
    print(f"Import error: {e}")
    # 직접 import 시도
    try:
        import api_server
        app = api_server.app
    except ImportError as e2:
        print(f"Direct import also failed: {e2}")
        # 최후의 수단으로 기본 FastAPI 앱 생성
        from fastapi import FastAPI
        app = FastAPI()
        
        @app.get("/")
        async def root():
            return {"message": "서버가 시작되었지만 모듈 로딩에 문제가 있습니다.", "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    print(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port) 