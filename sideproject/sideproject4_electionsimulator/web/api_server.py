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
import schedule
import threading
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List

# 상위 디렉토리를 Python 경로에 추가
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))

import uvicorn
from fastapi import FastAPI, BackgroundTasks, HTTPException
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
        self.scheduler_running = False
        self.daily_task_last_run = None
        self.initial_fetch_done = False

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
            "scheduler_running": self.scheduler_running,
            "daily_task_last_run": self.daily_task_last_run.isoformat() if self.daily_task_last_run else None,
            "initial_fetch_done": self.initial_fetch_done
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
                sorted_news = rank_news_by_importance(processed_data["news_list"], limit=30)
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
    """강제 뉴스 수집"""
    if not NEWS_SCRAPER_AVAILABLE:
        logger.warning("⚠️ 뉴스 수집 기능이 비활성화되어 있습니다.")
        return False
        
    try:
        logger.info("🔥 강제 뉴스 수집을 시작합니다...")
        
        # 강제 실행 모드 활성화
        os.environ['FORCE_NEWS_COLLECTION'] = 'true'
        
        # 상태 초기화
        news_cache.initial_fetch_done = False
        news_cache.daily_task_last_run = None
        
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
        news_cache.daily_task_last_run = datetime.now()
        
        logger.info("✅ 강제 뉴스 수집 완료")
        return True
        
    except Exception as e:
        logger.error(f"❌ 강제 뉴스 수집 실패: {str(e)}")
        os.environ.pop('FORCE_NEWS_COLLECTION', None)
        return False

def run_scheduled_news_pipeline() -> None:
    """예정된 뉴스 수집"""
    try:
        now = datetime.now()
        
        if news_cache.daily_task_last_run:
            last_run_date = news_cache.daily_task_last_run.date()
            if last_run_date == now.date():
                logger.info(f"⏭️ 오늘({now.date()})은 이미 뉴스 수집을 실행했습니다.")
                return
        
        logger.info(f"🔔 예정된 일일 뉴스 수집 시작: {now}")
        force_news_collection()
        logger.info(f"✅ 일일 뉴스 수집 완료: {now}")
        
    except Exception as e:
        logger.error(f"❌ 예정된 뉴스 수집 실패: {str(e)}")

def run_scheduler() -> None:
    """백그라운드 스케줄러 실행"""
    news_cache.scheduler_running = True
    logger.info("🕒 스케줄러가 시작되었습니다.")
    
    while True:
        try:
            now = datetime.now()
            next_run = schedule.next_run()
            if next_run:
                logger.info(f"⏰ 현재: {now.strftime('%Y-%m-%d %H:%M:%S')}, 다음 실행: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")
            
            schedule.run_pending()
            time.sleep(60)  # 1분마다 확인
        except Exception as e:
            logger.error(f"❌ 스케줄러 오류: {str(e)}")
            time.sleep(300)  # 오류 발생 시 5분 대기

# === FastAPI 앱 설정 ===
app = FastAPI(
    title="대선 시뮬레이터 API",
    description="2025년 대선 뉴스 분석 및 예측 시뮬레이터",
    version="2.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# === API 엔드포인트 ===
@app.get("/api/status")
async def get_status():
    """서버 상태 확인"""
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    today_files = file_manager.get_today_files()
    next_run = schedule.next_run() if schedule.jobs else None
    cache_status = news_cache.get_status()
    
    return {
        "status": "healthy" if cache_status["is_healthy"] else "degraded",
        "server_time": now.isoformat(),
        "timezone": "UTC",
        "cache": cache_status,
        "scheduler": {
            "running": news_cache.scheduler_running,
            "jobs_count": len(schedule.jobs),
            "jobs": [str(job) for job in schedule.jobs],
            "next_run": next_run.isoformat() if next_run else None,
        },
        "files": {
            "today_files_count": len(today_files),
            "today_files": [f.name for f in today_files],
            "latest_file": file_manager.find_latest_news_file().name if file_manager.find_latest_news_file() else None,
        },
        "data_status": {
            "has_today_data": news_cache.is_today_data(),
            "news_count": len(news_cache.latest_data.get("news_list", [])) if news_cache.latest_data else 0,
            "time_range": news_cache.latest_data.get("time_range", "없음") if news_cache.latest_data else "없음"
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
    """수동 새로고침"""
    # 레이트 리미팅
    if news_cache.daily_task_last_run:
        time_since_last_run = datetime.now() - news_cache.daily_task_last_run
        if time_since_last_run.total_seconds() < 1800:  # 30분
            return {
                "message": f"새로고침 요청이 너무 빈번합니다. {1800 - int(time_since_last_run.total_seconds())}초 후에 다시 시도해주세요.",
                "status": "rate_limited"
            }
    
    logger.info("🔄 수동 새로고침 요청")
    background_tasks.add_task(force_news_collection)
    
    return {
        "message": "뉴스 데이터 새로고침이 시작되었습니다.",
        "status": "started",
        "estimated_completion": (datetime.now() + timedelta(minutes=3)).isoformat()
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
    """오늘 데이터 강제 수집"""
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        logger.info(f"🔥 오늘({today}) 데이터 강제 수집 요청")
        
        background_tasks.add_task(force_news_collection)
        
        return {
            "message": f"오늘({today}) 뉴스 데이터 수집이 시작되었습니다.",
            "status": "started",
            "target_date": today,
            "estimated_completion": (datetime.now() + timedelta(minutes=5)).isoformat()
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

# === 서버 시작 이벤트 ===
@app.on_event("startup")
async def startup_event():
    """서버 시작 시 초기화"""
    try:
        logger.info("🚀 서버 시작 - 초기화 중...")
        
        # 뉴스 수집 기능 상태 확인
        if not NEWS_SCRAPER_AVAILABLE:
            logger.warning("⚠️ 뉴스 수집 기능이 비활성화되었습니다. 기본 데이터만 제공됩니다.")
            # 기본 데이터로 캐시 초기화
            default_data = data_processor.create_default_data("뉴스 수집 기능이 일시적으로 비활성화되었습니다.")
            news_cache.update(default_data)
            return
        
        # 캐시 초기 업데이트
        update_news_cache()
        logger.info("✅ 초기 캐시 업데이트 완료")
        
        # 스케줄러 설정
        schedule.clear()
        schedule.every().day.at("06:00").do(run_scheduled_news_pipeline)
        schedule.every(30).minutes.do(update_news_cache)
        
        logger.info("📅 스케줄 설정 완료:")
        for job in schedule.jobs:
            logger.info(f"  - {job}")
        
        # 스케줄러 시작
        if not news_cache.scheduler_running:
            scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
            scheduler_thread.start()
            logger.info("🕒 백그라운드 스케줄러 시작됨")
        
        # 오늘 데이터 확인 및 수집
        today = datetime.now().strftime("%Y-%m-%d")
        today_files = file_manager.get_today_files()
        
        logger.info(f"📅 오늘 날짜: {today}")
        logger.info(f"📂 오늘 생성된 파일 개수: {len(today_files)}")
        
        # 오늘 데이터가 없거나 캐시가 오늘 것이 아니면 수집
        if not today_files or not news_cache.is_today_data():
            logger.info("🔄 오늘 데이터 수집 시작")
            force_fetch_thread = threading.Thread(target=force_news_collection, daemon=True)
            force_fetch_thread.start()
        
        # 지연된 체크 (2분 후)
        def delayed_check():
            time.sleep(120)
            if not news_cache.is_today_data():
                logger.warning(f"⚠️ 2분 후에도 오늘({today}) 데이터가 없습니다. 재시도합니다.")
                force_news_collection()
        
        threading.Thread(target=delayed_check, daemon=True).start()
        logger.info("⏰ 2분 후 추가 데이터 수집 체크 예약됨")
        
        logger.info("✅ 서버 시작 이벤트 완료")
        
    except Exception as e:
        logger.error(f"❌ 서버 시작 이벤트 실패: {str(e)}")
        # 오류 발생 시에도 기본 데이터로 초기화
        try:
            default_data = data_processor.create_default_data(f"서버 초기화 중 오류 발생: {str(e)}")
            news_cache.update(default_data)
            logger.info("🔄 기본 데이터로 초기화 완료")
        except Exception as e2:
            logger.error(f"❌ 기본 데이터 초기화도 실패: {str(e2)}")

# === Flutter 웹 앱 서빙 ===
if FLUTTER_WEB_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(FLUTTER_WEB_DIR)), name="static")
    
    @app.get("/")
    async def root():
        return FileResponse(str(FLUTTER_WEB_DIR / "index.html"))
    
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        file_path = FLUTTER_WEB_DIR / path
        if file_path.exists() and file_path.is_file():
            return FileResponse(str(file_path))
        return FileResponse(str(FLUTTER_WEB_DIR / "index.html"))
else:
    @app.get("/")
    async def fallback_root():
        return {"message": "대선 시뮬레이터 API 서버가 실행 중입니다.", "status": "running"}

# === 서버 실행 ===
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)