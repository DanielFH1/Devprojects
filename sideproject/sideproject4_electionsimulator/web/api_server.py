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

# assets 디렉토리가 없으면 생성
try:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"✅ assets 디렉토리 확인/생성 완료: {ASSETS_DIR}")
except Exception as e:
    logger.error(f"❌ assets 디렉토리 생성 실패: {str(e)}")

# 기본 데이터 파일 생성
DEFAULT_DATA_FILE = ASSETS_DIR / "trend_summary_default.json"
if not DEFAULT_DATA_FILE.exists():
    try:
        default_data = {
            "trend_summary": "데이터를 수집 중입니다...",
            "candidate_stats": {
                "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                "이준석": {"긍정": 0, "부정": 0, "중립": 0}
            },
            "total_articles": 0,
            "time_range": "데이터 수집 중",
            "news_list": []  # 빈 뉴스 리스트 추가
        }
        with open(DEFAULT_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(default_data, f, ensure_ascii=False, indent=2)
        logger.info("✅ 기본 데이터 파일 생성 완료")
    except Exception as e:
        logger.error(f"❌ 기본 데이터 파일 생성 실패: {str(e)}")

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
            logger.warning("뉴스 데이터 파일을 찾을 수 없어 기본 데이터를 사용합니다.")
            if DEFAULT_DATA_FILE.exists():
                with open(DEFAULT_DATA_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    news_cache.update(data)
                    logger.info("✅ 기본 데이터로 캐시 업데이트 완료")
            else:
                news_cache.record_error("뉴스 데이터 파일을 찾을 수 없습니다.")
            return

        try:
            with open(news_files[0], "r", encoding="utf-8") as f:
                data = json.load(f)
                # 기본값 설정으로 null 방지
                processed_data = {
                    "trend_summary": data.get("trend_summary", "데이터를 수집 중입니다..."),
                    "candidate_stats": data.get("candidate_stats", {
                        "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                        "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                        "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                    }),
                    "total_articles": data.get("total_articles", 0),
                    "time_range": data.get("time_range", "데이터 수집 중"),
                    "news_list": data.get("news_list", [])  # news_list 필드 추가
                }
                news_cache.update(processed_data)
                logger.info(f"✅ 뉴스 캐시 업데이트 완료: {news_files[0].name}")
        except json.JSONDecodeError as e:
            logger.error(f"JSON 파싱 오류: {str(e)}")
            news_cache.record_error(f"JSON 파싱 오류: {str(e)}")
        except Exception as e:
            logger.error(f"파일 읽기 오류: {str(e)}")
            news_cache.record_error(f"파일 읽기 오류: {str(e)}")
            
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
    try:
        if not news_cache.latest_data:
            update_news_cache()
            if not news_cache.latest_data:
                # 기본 데이터 반환
                if DEFAULT_DATA_FILE.exists():
                    with open(DEFAULT_DATA_FILE, "r", encoding="utf-8") as f:
                        default_data = json.load(f)
                else:
                    default_data = {
                        "trend_summary": "데이터를 수집 중입니다...",
                        "candidate_stats": {
                            "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                            "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                            "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                        },
                        "total_articles": 0,
                        "time_range": "데이터 수집 중",
                        "news_list": []  # 빈 뉴스 리스트 추가
                    }
                return {
                    "data": default_data,
                    "metadata": {
                        "last_updated": datetime.now().isoformat(),
                        "next_update": (datetime.now() + timedelta(hours=1)).isoformat(),
                        "status": "using_default"
                    }
                }
        
        # news_list 필드가 없으면 빈 배열 추가
        if "news_list" not in news_cache.latest_data:
            news_cache.latest_data["news_list"] = []
            
        return {
            "data": news_cache.latest_data,
            "metadata": {
                "last_updated": news_cache.last_update.isoformat(),
                "next_update": (news_cache.last_update + timedelta(hours=1)).isoformat() if news_cache.last_update else None,
                "status": "success"
            }
        }
    except Exception as e:
        logger.error(f"뉴스 데이터 조회 실패: {str(e)}")
        return {
            "data": {
                "trend_summary": "데이터를 불러오는 중 오류가 발생했습니다.",
                "candidate_stats": {
                    "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                    "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                    "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                },
                "total_articles": 0,
                "time_range": "오류 발생"
            },
            "metadata": {
                "last_updated": datetime.now().isoformat(),
                "next_update": (datetime.now() + timedelta(hours=1)).isoformat(),
                "status": "error",
                "error": str(e)
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
    try:
        logger.info("🔄 초기 데이터 로드 시작...")
        update_news_cache()  # 캐시 업데이트만 수행
        logger.info("✅ 초기 데이터 로드 완료")
    except Exception as e:
        logger.error(f"❌ 초기 데이터 로드 실패: {str(e)}")
    
    # 스케줄러 설정
    # 1시간마다 수행하던 뉴스 수집을 매일 오전 6시에만 수행하도록 변경
    schedule.every().day.at("06:00").do(run_news_pipeline)  # 매일 오전 6시에 뉴스 수집 및 분석
    schedule.every().day.at("06:10").do(lambda: news_cache.pipeline.analyzer.analyze_trends(news_cache.pipeline.temp_storage, "전일"))  # 매일 오전 6시 10분에 트렌드 분석
    schedule.every(5).minutes.do(update_news_cache)  # 캐시 업데이트는 5분마다 유지
    
    # 백그라운드 스레드에서 스케줄러 실행
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()
    logger.info("🕒 뉴스 수집 스케줄러가 백그라운드에서 시작되었습니다. 매일 오전 6시에 데이터가 갱신됩니다.")

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
        return FileResponse(str(FLUTTER_BUILD_DIR / "index.html"))

    # 정적 파일 제공 - 각 디렉토리가 존재하는 경우에만 마운트
    try:
        if (FLUTTER_BUILD_DIR / "assets").exists():
            app.mount("/assets", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "assets")), name="flutter_assets")
            logger.info(f"✅ Flutter assets 디렉토리 마운트 완료: {FLUTTER_BUILD_DIR / 'assets'}")
        else:
            logger.warning(f"⚠️ Flutter assets 디렉토리를 찾을 수 없습니다: {FLUTTER_BUILD_DIR / 'assets'}")
    except Exception as e:
        logger.error(f"❌ assets 디렉토리 마운트 실패: {str(e)}")
    
    try:
        if (FLUTTER_BUILD_DIR / "icons").exists():
            app.mount("/icons", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "icons")), name="flutter_icons")
            logger.info(f"✅ Flutter icons 디렉토리 마운트 완료: {FLUTTER_BUILD_DIR / 'icons'}")
        else:
            logger.warning(f"⚠️ Flutter icons 디렉토리를 찾을 수 없습니다: {FLUTTER_BUILD_DIR / 'icons'}")
    except Exception as e:
        logger.error(f"❌ icons 디렉토리 마운트 실패: {str(e)}")
    
    try:
        if (FLUTTER_BUILD_DIR / "canvaskit").exists():
            app.mount("/canvaskit", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "canvaskit")), name="flutter_canvaskit")
            logger.info(f"✅ Flutter canvaskit 디렉토리 마운트 완료: {FLUTTER_BUILD_DIR / 'canvaskit'}")
        else:
            logger.warning(f"⚠️ Flutter canvaskit 디렉토리를 찾을 수 없습니다: {FLUTTER_BUILD_DIR / 'canvaskit'}")
    except Exception as e:
        logger.error(f"❌ canvaskit 디렉토리 마운트 실패: {str(e)}")
    
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        file_path = FLUTTER_BUILD_DIR / path
        if file_path.exists():
            return FileResponse(str(file_path))
        return FileResponse(str(FLUTTER_BUILD_DIR / "index.html"))