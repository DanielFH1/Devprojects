#!/usr/bin/env python3
"""
Render.com 배포용 시작 스크립트 - 최종 뉴스 수집 모드
"""

import os
import sys
from pathlib import Path

# 경로 설정
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# 환경 변수 설정
os.environ.setdefault('PYTHONPATH', str(current_dir))

print("🚀 2025 대선 시뮬레이터 서버 시작")
print("📊 모드: 최종 뉴스 수집 (200개 기사 목표)")
print("🚫 스케줄러: 비활성화 (한 번만 실행)")

# FastAPI 앱 import
try:
    from web.api_server import app
    print("✅ API 서버 모듈 로드 성공")
except Exception as e:
    print(f"❌ API 서버 모듈 로드 실패: {e}")
    # 기본 앱 생성
    from fastapi import FastAPI
    app = FastAPI()
    
    @app.get("/")
    async def root():
        return {"status": "error", "message": f"모듈 로드 실패: {str(e)}"}

# 서버 실행
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    print(f"🌐 서버 시작 - 포트: {port}")
    print(f"🔗 URL: http://0.0.0.0:{port}")
    uvicorn.run(app, host="0.0.0.0", port=port) 