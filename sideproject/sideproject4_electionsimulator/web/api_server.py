"""
대선 시뮬레이터 API 서버
- 뉴스 데이터 수집 및 분석
- Flutter 웹 앱 서빙
- 실시간 데이터 캐싱
"""

import os
import sys
import json
import time
import shutil
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from contextlib import asynccontextmanager

# 상위 디렉토리를 Python 경로에 추가
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))

import uvicorn
from fastapi import FastAPI, BackgroundTasks, HTTPException, Request, Response
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# news_scraper 모듈 import (오류 처리 포함)
try:
    from news_scraper import NewsPipeline, rank_news_by_importance
    NEWS_SCRAPER_AVAILABLE = True
    logger.info("✅ news_scraper 모듈 로드 성공")
except ImportError as e:
    logger.error(f"❌ news_scraper 모듈 로드 실패: {e}")
    NEWS_SCRAPER_AVAILABLE = False
    
    # 더미 클래스 생성
    class NewsPipeline:
        def __init__(self):
            pass
        def run_daily_collection(self):
            logger.warning("⚠️ 뉴스 수집 기능이 비활성화되었습니다.")
    
    def rank_news_by_importance(news_data, limit=30):
        return news_data[:limit]

# === 상수 및 설정 ===
ASSETS_DIR = parent_dir / "assets"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_DATA_FILE = ASSETS_DIR / "trend_summary_default.json"

# Render.com 영구 저장소 설정
PERSISTENT_DIR = None
if os.environ.get('RENDER') == 'true':
    PERSISTENT_DIR = Path("/opt/render/project/src/persistent_data")
    PERSISTENT_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"📂 Render.com 영구 저장소 설정: {PERSISTENT_DIR}")

# Flutter 웹 앱 경로
FLUTTER_WEB_DIR = parent_dir / "flutter_ui/web"
logger.info(f"📂 Flutter 웹 디렉토리 경로: {FLUTTER_WEB_DIR}")
logger.info(f"📂 Flutter 웹 디렉토리 존재 여부: {FLUTTER_WEB_DIR.exists()}")

# 디렉토리 내용 확인
if FLUTTER_WEB_DIR.exists():
    files = list(FLUTTER_WEB_DIR.iterdir())
    logger.info(f"📂 Flutter 웹 디렉토리 파일 목록: {[f.name for f in files]}")
else:
    logger.error(f"❌ Flutter 웹 디렉토리가 존재하지 않습니다: {FLUTTER_WEB_DIR}")
    # 대안 경로들 확인
    alt_paths = [
        parent_dir / "flutter_ui/build/web",
        Path("flutter_ui/web"),
        Path("flutter_ui/build/web")
    ]
    for alt_path in alt_paths:
        if alt_path.exists():
            logger.info(f"✅ 대안 경로 발견: {alt_path}")
            FLUTTER_WEB_DIR = alt_path
            break

# === 뉴스 캐시 관리 클래스 ===
class NewsCache:
    """뉴스 데이터 캐시 관리"""
    
    def __init__(self):
        self.latest_data: Optional[Dict[str, Any]] = None
        self.last_update: Optional[datetime] = None
        self.update_count: int = 0
        self.error_count: int = 0
        self.last_error: Optional[str] = None
        self.pipeline = NewsPipeline()
        self.initial_fetch_done = False
        self.final_collection_completed = False  # 최종 수집 완료 플래그

    def update(self, data: Dict[str, Any]) -> None:
        """캐시 데이터 업데이트"""
        self.latest_data = data
        self.last_update = datetime.now()
        self.update_count += 1
        self.error_count = 0
        self.last_error = None
        logger.info(f"✅ 캐시 업데이트 완료 (#{self.update_count})")

    def record_error(self, error: str) -> None:
        """오류 기록"""
        self.error_count += 1
        self.last_error = error
        logger.error(f"❌ 캐시 오류 #{self.error_count}: {error}")

    def get_status(self) -> Dict[str, Any]:
        """캐시 상태 반환"""
        return {
            "last_update": self.last_update.isoformat() if self.last_update else None,
            "update_count": self.update_count,
            "error_count": self.error_count,
            "last_error": self.last_error,
            "is_healthy": self.error_count < 3 and self.last_update is not None,
            "initial_fetch_done": self.initial_fetch_done,
            "final_collection_completed": self.final_collection_completed
        }

    def is_today_data(self) -> bool:
        """현재 캐시 데이터가 오늘 것인지 확인"""
        if not self.latest_data:
            return False
        
        today = datetime.now().strftime("%Y-%m-%d")
        time_range = self.latest_data.get("time_range", "")
        return today in time_range

# === 파일 관리 유틸리티 ===
class FileManager:
    """파일 관리 유틸리티"""
    
    @staticmethod
    def extract_datetime_from_filename(filepath: Path) -> datetime:
        """파일명에서 날짜시간 추출"""
        try:
            # trend_summary_2025-05-26_13-03.json 형식에서 날짜시간 추출
            parts = filepath.stem.split('_')
            if len(parts) >= 3:
                date_str = parts[2]  # 2025-05-26
                time_str = parts[3] if len(parts) > 3 else "00-00"  # 13-03
                datetime_str = f"{date_str} {time_str.replace('-', ':')}"
                return datetime.strptime(datetime_str, "%Y-%m-%d %H:%M")
        except Exception:
            pass
        # 파싱 실패 시 파일 수정 시간 사용
        return datetime.fromtimestamp(filepath.stat().st_mtime)

    @staticmethod
    def find_latest_news_file() -> Optional[Path]:
        """최신 뉴스 데이터 파일 찾기"""
        # 기본 파일 제외하고 날짜가 포함된 파일들만 찾기
        news_files = [
            f for f in ASSETS_DIR.glob("trend_summary_*.json")
            if f.name != "trend_summary_default.json"
        ]
        
        if not news_files:
            return None
            
        try:
            # 날짜시간 기준으로 정렬하여 가장 최신 파일 선택
            latest_file = sorted(
                news_files,
                key=FileManager.extract_datetime_from_filename,
                reverse=True
            )[0]
            logger.info(f"📂 최신 날짜 파일 발견: {latest_file}")
            return latest_file
        except Exception as e:
            # 정렬 실패 시 수정 시간 기준으로 폴백
            latest_file = sorted(news_files, key=lambda p: p.stat().st_mtime, reverse=True)[0]
            logger.warning(f"⚠️ 날짜 기준 정렬 실패, 수정 시간 기준 사용: {str(e)}")
            return latest_file

    @staticmethod
    def get_today_files() -> List[Path]:
        """오늘 날짜의 파일들 반환"""
        today = datetime.now().strftime("%Y-%m-%d")
        return list(ASSETS_DIR.glob(f"trend_summary_{today}_*.json"))

    @staticmethod
    def load_json_file(filepath: Path) -> Optional[Dict[str, Any]]:
        """JSON 파일 로드"""
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"❌ 파일 로드 실패 {filepath}: {str(e)}")
            return None

# === 데이터 처리 유틸리티 ===
class DataProcessor:
    """데이터 처리 유틸리티"""
    
    @staticmethod
    def create_default_data(message: str = "데이터를 수집 중입니다...") -> Dict[str, Any]:
        """기본 데이터 구조 생성"""
        current_time = datetime.now()
        return {
            "trend_summary": message,
            "candidate_stats": {
                "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                "이준석": {"긍정": 0, "부정": 0, "중립": 0}
            },
            "total_articles": 0,
            "time_range": f"{current_time.strftime('%Y-%m-%d')} 업데이트",
            "news_list": []
        }

    @staticmethod
    def process_news_data(data: Dict[str, Any]) -> Dict[str, Any]:
        """뉴스 데이터 처리 및 정규화"""
        processed_data = {
            "trend_summary": data.get("trend_summary", "데이터를 수집 중입니다..."),
            "candidate_stats": data.get("candidate_stats", DataProcessor.create_default_data()["candidate_stats"]),
            "total_articles": data.get("total_articles", 0),
            "time_range": data.get("time_range", "데이터 수집 중"),
            "news_list": data.get("news_list", [])
        }
        
        # 뉴스 데이터가 있으면 중요도 기준으로 정렬
        if processed_data["news_list"]:
            try:
                sorted_news = rank_news_by_importance(processed_data["news_list"], limit=100)
                processed_data["news_list"] = sorted_news
                logger.info(f"✅ 뉴스 데이터 중요도 정렬 완료: {len(sorted_news)}개")
            except Exception as e:
                logger.error(f"❌ 뉴스 정렬 오류: {str(e)}")
        
        return processed_data

# === 전역 인스턴스 ===
news_cache = NewsCache()
file_manager = FileManager()
data_processor = DataProcessor()

# === 캐시 관리 함수 ===
def update_news_cache() -> None:
    """뉴스 캐시 업데이트"""
    try:
        # 최신 파일 찾기
        latest_file = file_manager.find_latest_news_file()
        
        # 영구 저장소에서 확인
        if not latest_file and PERSISTENT_DIR and PERSISTENT_DIR.exists():
            latest_link = PERSISTENT_DIR / "trend_summary_latest.json"
            if latest_link.exists():
                latest_file = latest_link
                logger.info(f"📂 영구 저장소에서 최신 파일 발견: {latest_file}")
                
                # 영구 저장소의 파일을 assets에 복사
                dest_file = ASSETS_DIR / f"trend_summary_{datetime.now().strftime('%Y-%m-%d_%H-%M')}.json"
                shutil.copy(latest_file, dest_file)
                logger.info(f"📋 영구 저장소의 파일을 assets에 복사: {dest_file.name}")
                latest_file = dest_file
        
        # 기본 파일 사용
        if not latest_file and DEFAULT_DATA_FILE.exists():
            latest_file = DEFAULT_DATA_FILE
            logger.warning("⚠️ 날짜가 포함된 뉴스 데이터 파일을 찾을 수 없어 기본 데이터를 사용합니다.")
        
        # 파일 처리
        if latest_file:
            data = file_manager.load_json_file(latest_file)
            if data:
                processed_data = data_processor.process_news_data(data)
                news_cache.update(processed_data)
                logger.info(f"✅ 뉴스 캐시 업데이트 완료: {latest_file.name}")
            else:
                news_cache.record_error(f"파일 읽기 실패: {latest_file}")
        else:
            news_cache.record_error("뉴스 데이터 파일을 찾을 수 없습니다.")
            
    except Exception as e:
        news_cache.record_error(str(e))
        logger.error(f"❌ 캐시 업데이트 실패: {str(e)}")

# === 뉴스 수집 함수 ===
def force_news_collection() -> bool:
    """최종 뉴스 수집 (한 번만 실행)"""
    if not NEWS_SCRAPER_AVAILABLE:
        logger.warning("⚠️ 뉴스 수집 기능이 비활성화되어 있습니다.")
        return False
        
    if news_cache.final_collection_completed:
        logger.info("🚫 최종 뉴스 수집이 이미 완료되었습니다.")
        return True
        
    try:
        logger.info("🔥 최종 뉴스 수집을 시작합니다... (200개 기사 목표)")
        
        # 강제 실행 모드 활성화
        os.environ['FORCE_NEWS_COLLECTION'] = 'true'
        
        # 상태 초기화
        news_cache.initial_fetch_done = False
        
        # 뉴스 수집 실행
        news_cache.pipeline.run_daily_collection()
        
        # 환경변수 해제
        os.environ.pop('FORCE_NEWS_COLLECTION', None)
        
        # 수집 후 캐시 업데이트
        today_files = file_manager.get_today_files()
        if today_files:
            newest_file = sorted(today_files, key=lambda p: p.stat().st_mtime, reverse=True)[0]
            logger.info(f"✅ 새로 생성된 오늘 파일 발견: {newest_file}")
        
        update_news_cache()
        
        # 상태 업데이트
        news_cache.initial_fetch_done = True
        news_cache.final_collection_completed = True
        
        logger.info("✅ 최종 뉴스 수집 완료 - 더 이상 수집하지 않습니다.")
        return True
        
    except Exception as e:
        logger.error(f"❌ 최종 뉴스 수집 실패: {str(e)}")
        os.environ.pop('FORCE_NEWS_COLLECTION', None)
        news_cache.final_collection_completed = True  # 실패해도 다시 시도하지 않음
        return False

# === 서버 시작 이벤트를 lifespan으로 변경 ===
@asynccontextmanager
async def lifespan(app: FastAPI):
    """서버 시작 시 초기화 - 딱 한번만 뉴스 수집"""
    try:
        logger.info("🚀 서버 시작 - 최종 뉴스 수집 초기화 중...")
        
        # 뉴스 수집 기능 상태 확인
        if not NEWS_SCRAPER_AVAILABLE:
            logger.warning("⚠️ 뉴스 수집 기능이 비활성화되었습니다. 기본 데이터만 제공됩니다.")
            # 기본 데이터로 캐시 초기화
            default_data = data_processor.create_default_data("뉴스 수집 기능이 일시적으로 비활성화되었습니다.")
            news_cache.update(default_data)
            yield
            return
        
        # 캐시 초기 업데이트
        update_news_cache()
        logger.info("✅ 초기 캐시 업데이트 완료")
        
        # 스케줄러 관련 코드 모두 제거
        # 대신 서버 시작시 딱 한번만 뉴스 수집 실행
        
        today = datetime.now().strftime("%Y-%m-%d")
        today_files = file_manager.get_today_files()
        
        logger.info(f"📅 오늘 날짜: {today}")
        logger.info(f"📂 오늘 생성된 파일 개수: {len(today_files)}")
        
        # 최종 수집이 완료되지 않았다면 실행
        if not news_cache.final_collection_completed:
            logger.info("🔄 최종 뉴스 수집 시작 (200개 기사 목표)")
            import threading
            collection_thread = threading.Thread(target=force_news_collection, daemon=False)
            collection_thread.start()
            
            # 수집이 완료될 때까지 최대 10분 대기
            logger.info("⏳ 뉴스 수집 완료를 기다리는 중... (최대 10분)")
            collection_thread.join(timeout=600)  # 10분 대기
            
            if collection_thread.is_alive():
                logger.warning("⚠️ 뉴스 수집이 10분 내에 완료되지 않았습니다.")
            else:
                logger.info("✅ 뉴스 수집이 완료되었습니다.")
        else:
            logger.info("🏁 최종 수집이 이미 완료되었습니다.")
        
        logger.info("✅ 서버 시작 이벤트 완료")
        logger.info("🚫 스케줄러는 비활성화되었습니다. 더 이상 자동 수집하지 않습니다.")
        
        yield  # 서버 실행
        
    except Exception as e:
        logger.error(f"❌ 서버 시작 이벤트 실패: {str(e)}")
        # 오류 발생 시에도 기본 데이터로 초기화
        try:
            default_data = data_processor.create_default_data(f"서버 초기화 중 오류 발생: {str(e)}")
            news_cache.update(default_data)
            news_cache.final_collection_completed = True
            logger.info("🔄 기본 데이터로 초기화 완료")
        except Exception as e2:
            logger.error(f"❌ 기본 데이터 초기화도 실패: {str(e2)}")
        
        yield  # 서버 실행

# === FastAPI 앱 설정 ===
app = FastAPI(
    title="대선 시뮬레이터 API",
    description="2025년 대선 뉴스 분석 및 예측 시뮬레이터",
    version="2.0.0",
    lifespan=lifespan
)

# CORS 설정 - 더 명시적으로 설정
allowed_origins = [
    "https://electionsimulatorwebservice.onrender.com",
    "https://sideproject4-electionsimulator.onrender.com",  # 이전 도메인도 허용
    "http://localhost:10000",
    "http://127.0.0.1:10000",
    "*"  # 모든 도메인 허용 (개발용)
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# CORS 헤더를 명시적으로 추가하는 미들웨어
@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    response = await call_next(request)
    
    # 명시적인 CORS 헤더 추가
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    response.headers["Access-Control-Expose-Headers"] = "*"
    response.headers["Access-Control-Allow-Credentials"] = "true"
    
    return response

# OPTIONS 요청 처리
@app.options("/{path:path}")
async def options_handler(path: str):
    return JSONResponse(
        content={"message": "OK"},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Expose-Headers": "*",
            "Access-Control-Allow-Credentials": "true",
        }
    )

# === API 엔드포인트 ===
@app.get("/api/status")
async def get_status():
    """서버 상태 확인"""
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    today_files = file_manager.get_today_files()
    cache_status = news_cache.get_status()
    
    return {
        "status": "healthy" if cache_status["is_healthy"] else "degraded",
        "server_time": now.isoformat(),
        "timezone": "UTC",
        "cache": cache_status,
        "scheduler_status": "DISABLED - 최종 수집 모드",
        "collection_mode": "ONE_TIME_FINAL",
        "files": {
            "today_files_count": len(today_files),
            "today_files": [f.name for f in today_files],
            "latest_file": file_manager.find_latest_news_file().name if file_manager.find_latest_news_file() else None,
        },
        "data_status": {
            "has_today_data": news_cache.is_today_data(),
            "news_count": len(news_cache.latest_data.get("news_list", [])) if news_cache.latest_data else 0,
            "time_range": news_cache.latest_data.get("time_range", "없음") if news_cache.latest_data else "없음",
            "final_collection_completed": news_cache.final_collection_completed
        }
    }

@app.get("/api/trend-summary")
async def get_news_data():
    """뉴스 데이터 조회"""
    try:
        # 캐시에 데이터가 없으면 업데이트
        if not news_cache.latest_data:
            update_news_cache()
        
        # 여전히 데이터가 없으면 기본 데이터 반환
        if not news_cache.latest_data:
            default_data = data_processor.create_default_data()
            
            # 백그라운드에서 데이터 수집 시작
            if not news_cache.initial_fetch_done:
                threading.Thread(target=force_news_collection, daemon=True).start()
                news_cache.initial_fetch_done = True
            
            return default_data
        
        # 오늘 데이터가 아니면 새로 수집
        if not news_cache.is_today_data():
            logger.warning("⚠️ 캐시의 데이터가 오늘 것이 아닙니다. 새로 수집합니다.")
            threading.Thread(target=force_news_collection, daemon=True).start()
        
        return news_cache.latest_data
        
    except Exception as e:
        logger.error(f"❌ 뉴스 데이터 조회 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/prediction")
async def get_prediction_data():
    """예측 데이터 조회"""
    try:
        # 캐시에 데이터가 없으면 업데이트
        if not news_cache.latest_data:
            update_news_cache()
        
        # 기본 예측 데이터 생성
        if not news_cache.latest_data:
            return {
                "predictions": {
                    "이재명": 35.0,
                    "김문수": 30.0,
                    "이준석": 25.0
                },
                "analysis": "데이터를 수집 중입니다. 잠시 후 다시 확인해주세요.",
                "total_articles": 0,
                "time_range": "데이터 수집 중"
            }
        
        # 뉴스 데이터를 기반으로 예측 생성
        candidate_stats = news_cache.latest_data.get("candidate_stats", {})
        total_articles = news_cache.latest_data.get("total_articles", 0)
        
        # 간단한 예측 알고리즘 (감성 분석 기반)
        predictions = {}
        base_score = 30.0  # 기본 점수
        
        for candidate, stats in candidate_stats.items():
            positive = stats.get("긍정", 0)
            negative = stats.get("부정", 0)
            neutral = stats.get("중립", 0)
            total = positive + negative + neutral
            
            if total > 0:
                sentiment_score = (positive - negative) / total * 10
                predictions[candidate] = max(10.0, min(50.0, base_score + sentiment_score))
            else:
                predictions[candidate] = base_score
        
        # 정규화 (총합 100%)
        total_pred = sum(predictions.values())
        if total_pred > 0:
            predictions = {k: (v / total_pred) * 100 for k, v in predictions.items()}
        
        return {
            "predictions": predictions,
            "analysis": news_cache.latest_data.get("trend_summary", "분석 중..."),
            "total_articles": total_articles,
            "time_range": news_cache.latest_data.get("time_range", "")
        }
        
    except Exception as e:
        logger.error(f"❌ 예측 데이터 조회 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/refresh")
async def force_refresh(background_tasks: BackgroundTasks):
    """수동 새로고침 - 최종 수집 완료 후에는 비활성화"""
    if news_cache.final_collection_completed:
        return {
            "message": "최종 수집이 완료되어 더 이상 새로고침할 수 없습니다.",
            "status": "disabled",
            "reason": "final_collection_completed"
        }
    
    logger.info("🔄 수동 새로고침 요청")
    background_tasks.add_task(force_news_collection)
    
    return {
        "message": "최종 뉴스 데이터 수집이 시작되었습니다.",
        "status": "started",
        "estimated_completion": (datetime.now() + timedelta(minutes=5)).isoformat()
    }

@app.post("/api/update-cache")
async def force_update_cache():
    """캐시 강제 업데이트"""
    try:
        logger.info("🔄 캐시 강제 업데이트 요청")
        update_news_cache()
        
        if news_cache.latest_data:
            return {
                "message": "캐시가 성공적으로 업데이트되었습니다.",
                "status": "success",
                "last_updated": news_cache.last_update.isoformat() if news_cache.last_update else None,
                "news_count": len(news_cache.latest_data.get("news_list", [])),
                "time_range": news_cache.latest_data.get("time_range", "알 수 없음")
            }
        else:
            return {
                "message": "캐시 업데이트는 완료되었지만 데이터가 없습니다.",
                "status": "no_data"
            }
    except Exception as e:
        logger.error(f"❌ 캐시 강제 업데이트 실패: {str(e)}")
        return {"message": f"캐시 업데이트 중 오류: {str(e)}", "status": "error"}

@app.post("/api/force-today-collection")
async def force_today_collection(background_tasks: BackgroundTasks):
    """오늘 데이터 강제 수집 - 최종 수집 완료 후에는 비활성화"""
    if news_cache.final_collection_completed:
        return {
            "message": "최종 수집이 완료되어 더 이상 수집할 수 없습니다.",
            "status": "disabled",
            "reason": "final_collection_completed"
        }
        
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        logger.info(f"🔥 오늘({today}) 최종 데이터 수집 요청")
        
        background_tasks.add_task(force_news_collection)
        
        return {
            "message": f"오늘({today}) 최종 뉴스 데이터 수집이 시작되었습니다.",
            "status": "started",
            "target_date": today,
            "estimated_completion": (datetime.now() + timedelta(minutes=5)).isoformat(),
            "note": "이것이 마지막 수집입니다."
        }
    except Exception as e:
        logger.error(f"❌ 오늘 데이터 강제 수집 요청 실패: {str(e)}")
        return {"message": f"오늘 데이터 수집 요청 중 오류: {str(e)}", "status": "error"}

# 기존 엔드포인트들도 유지 (하위 호환성)
@app.get("/status")
async def get_status_legacy():
    """서버 상태 확인 (레거시)"""
    return await get_status()

@app.get("/news")
async def get_news_data_legacy():
    """뉴스 데이터 조회 (레거시)"""
    result = await get_news_data()
    return {
        "data": result,
        "metadata": {
            "last_updated": news_cache.last_update.isoformat() if news_cache.last_update else datetime.now().isoformat(),
            "status": "success"
        }
    }

@app.post("/refresh")
async def force_refresh_legacy(background_tasks: BackgroundTasks):
    """수동 새로고침 (레거시)"""
    return await force_refresh(background_tasks)

@app.post("/update-cache")
async def force_update_cache_legacy():
    """캐시 강제 업데이트 (레거시)"""
    return await force_update_cache()

@app.post("/force-today-collection")
async def force_today_collection_legacy(background_tasks: BackgroundTasks):
    """오늘 데이터 강제 수집 (레거시)"""
    return await force_today_collection(background_tasks)

# === Flutter 웹 앱 서빙 ===
if FLUTTER_WEB_DIR.exists():
    # 정적 파일 서빙
    app.mount("/assets", StaticFiles(directory=str(FLUTTER_WEB_DIR / "assets")), name="assets")
    app.mount("/canvaskit", StaticFiles(directory=str(FLUTTER_WEB_DIR / "canvaskit")), name="canvaskit")
    app.mount("/icons", StaticFiles(directory=str(FLUTTER_WEB_DIR / "icons")), name="icons")
    
    # 개별 파일들 서빙
    @app.get("/main.dart.js")
    async def serve_main_dart_js():
        return FileResponse(str(FLUTTER_WEB_DIR / "main.dart.js"), media_type="application/javascript")
    
    @app.get("/flutter.js")
    async def serve_flutter_js():
        return FileResponse(str(FLUTTER_WEB_DIR / "flutter.js"), media_type="application/javascript")
    
    @app.get("/flutter_bootstrap.js")
    async def serve_flutter_bootstrap_js():
        return FileResponse(str(FLUTTER_WEB_DIR / "flutter_bootstrap.js"), media_type="application/javascript")
    
    @app.get("/flutter_service_worker.js")
    async def serve_flutter_service_worker():
        return FileResponse(str(FLUTTER_WEB_DIR / "flutter_service_worker.js"), media_type="application/javascript")
    
    @app.get("/manifest.json")
    async def serve_manifest():
        return FileResponse(str(FLUTTER_WEB_DIR / "manifest.json"), media_type="application/json")
    
    @app.get("/version.json")
    async def serve_version():
        return FileResponse(str(FLUTTER_WEB_DIR / "version.json"), media_type="application/json")
    
    @app.get("/favicon.png")
    async def serve_favicon():
        return FileResponse(str(FLUTTER_WEB_DIR / "favicon.png"), media_type="image/png")
    
    # 메인 페이지
    @app.get("/")
    async def root():
        return FileResponse(str(FLUTTER_WEB_DIR / "index.html"), media_type="text/html")
    
    # 모든 다른 경로는 Flutter 앱으로 라우팅 (SPA 지원)
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        # 파일이 실제로 존재하는지 확인
        file_path = FLUTTER_WEB_DIR / path
        if file_path.exists() and file_path.is_file():
            # 파일 확장자에 따른 MIME 타입 설정
            if path.endswith('.js'):
                return FileResponse(str(file_path), media_type="application/javascript")
            elif path.endswith('.css'):
                return FileResponse(str(file_path), media_type="text/css")
            elif path.endswith('.html'):
                return FileResponse(str(file_path), media_type="text/html")
            elif path.endswith('.json'):
                return FileResponse(str(file_path), media_type="application/json")
            elif path.endswith('.png'):
                return FileResponse(str(file_path), media_type="image/png")
            elif path.endswith('.ico'):
                return FileResponse(str(file_path), media_type="image/x-icon")
            else:
                return FileResponse(str(file_path))
        
        # 파일이 없으면 index.html로 리다이렉트 (SPA 라우팅)
        return FileResponse(str(FLUTTER_WEB_DIR / "index.html"), media_type="text/html")
    
    logger.info("✅ Flutter 웹 앱 서빙 설정 완료")
else:
    logger.warning(f"⚠️ Flutter 웹 디렉토리를 찾을 수 없습니다: {FLUTTER_WEB_DIR}")
    
    @app.get("/")
    async def fallback_root():
        return {
            "message": "대선 시뮬레이터 API 서버가 실행 중입니다.", 
            "status": "running",
            "flutter_web_dir": str(FLUTTER_WEB_DIR),
            "flutter_web_exists": FLUTTER_WEB_DIR.exists()
        }

# === 서버 실행 ===
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)