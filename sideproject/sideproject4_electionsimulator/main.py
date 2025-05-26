#!/usr/bin/env python3
"""
대선 시뮬레이터 메인 실행 스크립트
Render.com 배포용
"""

import os
import sys
from pathlib import Path

# 현재 디렉토리를 Python 경로에 추가
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# web 디렉토리의 api_server 모듈 import
from web.api_server import app

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port) 