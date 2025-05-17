from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import json
from pathlib import Path
from fastapi.responses import FileResponse, JSONResponse
import threading
import schedule
import time
from datetime import datetime, timedelta
import sys
import os
import logging
from typing import Dict, Any, Optional
from collections import defaultdict

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 프로젝트 루트 디렉토리를 Python 경로에 추가
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(BASE_DIR))

# !scrapper.py의 함수들을 임포트
from news_scraper import run_news_pipeline, NewsPipeline

app = FastAPI()

# --- 경로 설정 ---
BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_BUILD_DIR = BASE_DIR / "flutter_ui" / "build" / "web"
ASSETS_DIR = BASE_DIR / "assets"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

# --- CORS 미들웨어 설정 ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 전역 변수 및 캐시 관리 ---
class NewsCache:
    def __init__(self):
        self.latest_data: Optional[Dict[str, Any]] = None
        self.last_update: Optional[datetime] = None
        self.update_count: int = 0
        self.error_count: int = 0
        self.last_error: Optional[str] = None
        self.pipeline = NewsPipeline()

    def update(self, data: Dict[str, Any]):
        self.latest_data = data
        self.last_update = datetime.now()
        self.update_count += 1
        self.error_count = 0
        self.last_error = None

    def record_error(self, error: str):
        self.error_count += 1
        self.last_error = error
        logger.error(f"캐시 업데이트 오류: {error}")

    def get_status(self) -> Dict[str, Any]:
        return {
            "last_update": self.last_update.isoformat() if self.last_update else None,
            "update_count": self.update_count,
            "error_count": self.error_count,
            "last_error": self.last_error,
            "is_healthy": self.error_count < 3 and self.last_update is not None
        }

news_cache = NewsCache()

def update_news_cache():
    """assets 폴더에서 최신 뉴스 데이터를 읽어와 캐시를 업데이트"""
    try:
        news_files = sorted(
            ASSETS_DIR.glob("trend_summary_*.json"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )
        
        if not news_files:
            news_cache.record_error("뉴스 데이터 파일을 찾을 수 없습니다.")
            return

        with open(news_files[0], "r", encoding="utf-8") as f:
            data = json.load(f)
            # 기본값 설정으로 null 방지
            processed_data = {
                "trend_summary": data.get("trend_summary", ""),
                "candidate_stats": data.get("candidate_stats", {
                    "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                    "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                    "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                }),
                "total_articles": data.get("total_articles", 0),
                "time_range": data.get("time_range", "")
            }
            news_cache.update(processed_data)
            logger.info(f"✅ 뉴스 캐시 업데이트 완료: {news_files[0].name}")
            
    except Exception as e:
        news_cache.record_error(str(e))
        logger.error(f"캐시 업데이트 실패: {str(e)}")

def run_scheduler():
    """백그라운드에서 스케줄러 실행"""
    while True:
        try:
            schedule.run_pending()
            time.sleep(1)
        except Exception as e:
            logger.error(f"❌ 스케줄러 오류: {str(e)}")
            time.sleep(60)

# --- API 엔드포인트 ---
@app.get("/status")
async def get_status():
    """서버 상태 확인 엔드포인트"""
    return {
        "status": "healthy" if news_cache.get_status()["is_healthy"] else "degraded",
        "cache": news_cache.get_status(),
        "server_time": datetime.now().isoformat(),
        "uptime": str(datetime.now() - news_cache.last_update) if news_cache.last_update else None
    }

@app.get("/news")
async def get_news_data():
    """뉴스 데이터 조회 엔드포인트"""
    if not news_cache.latest_data:
        update_news_cache()
        if not news_cache.latest_data:
            # 기본 데이터 반환
            default_data = {
                "trend_summary": "데이터를 수집 중입니다...",
                "candidate_stats": {
                    "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                    "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                    "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                },
                "total_articles": 0,
                "time_range": "데이터 수집 중"
            }
            return {
                "data": default_data,
                "metadata": {
                    "last_updated": datetime.now().isoformat(),
                    "next_update": (datetime.now() + timedelta(hours=1)).isoformat()
                }
            }
    
    return {
        "data": news_cache.latest_data,
        "metadata": {
            "last_updated": news_cache.last_update.isoformat(),
            "next_update": (news_cache.last_update + timedelta(hours=1)).isoformat() if news_cache.last_update else None
        }
    }

@app.post("/refresh")
async def force_refresh(background_tasks: BackgroundTasks):
    """수동으로 뉴스 데이터 새로고침"""
    background_tasks.add_task(run_news_pipeline)
    return {"message": "뉴스 데이터 새로고침이 시작되었습니다."}

# --- 서버 시작 이벤트 ---
@app.on_event("startup")
async def startup_event():
    # 초기 뉴스 데이터 로드
    update_news_cache()
    
    # 스케줄러 설정
    schedule.every(1).hours.do(run_news_pipeline)
    schedule.every(5).minutes.do(update_news_cache)
    
    # 백그라운드 스레드에서 스케줄러 실행
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()
    logger.info("🕒 뉴스 수집 스케줄러가 백그라운드에서 시작되었습니다.")

# --- Flutter 웹 앱 제공 ---
if not FLUTTER_BUILD_DIR.exists() or not (FLUTTER_BUILD_DIR / "index.html").exists():
    logger.warning(f"Flutter 빌드 디렉토리를 찾을 수 없습니다: {FLUTTER_BUILD_DIR}")
    
    @app.get("/")
    async def fallback_root():
        return JSONResponse({
            "status": "warning",
            "message": "Flutter UI 빌드 파일을 찾을 수 없습니다. API는 /news 에서 사용 가능합니다.",
            "endpoints": {
                "/news": "뉴스 데이터 조회",
                "/status": "서버 상태 확인",
                "/refresh": "수동 데이터 새로고침"
            }
        })
else:
    @app.get("/")
    async def root():
        return FileResponse(FLUTTER_BUILD_DIR / "index.html")

    # 정적 파일 제공
    app.mount("/assets", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "assets")), name="flutter_assets")
    app.mount("/icons", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "icons")), name="flutter_icons")
    app.mount("/canvaskit", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "canvaskit")), name="flutter_canvaskit")
    
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        file_path = FLUTTER_BUILD_DIR / path
        if file_path.exists():
            return FileResponse(str(file_path))
        return FileResponse(str(FLUTTER_BUILD_DIR / "index.html"))