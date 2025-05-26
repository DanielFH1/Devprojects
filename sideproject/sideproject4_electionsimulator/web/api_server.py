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
import shutil  # 파일 복사를 위한 모듈 추가

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 프로젝트 루트 디렉토리를 Python 경로에 추가
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(BASE_DIR))

# OpenAI API 키 검사 추가
openai_api_key = os.getenv('OPENAI_API_KEY')
if not openai_api_key:
    logger.error("❌ OPENAI_API_KEY 환경 변수가 설정되지 않았습니다. 뉴스 분석 기능이 작동하지 않을 수 있습니다.")
else:
    logger.info("✅ OPENAI_API_KEY 환경 변수가 설정되어 있습니다.")

# !scrapper.py의 함수들을 임포트
from news_scraper import run_news_pipeline, NewsPipeline, rank_news_by_importance, pipeline

app = FastAPI()

# --- 경로 설정 ---
BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_BUILD_DIR = BASE_DIR / "flutter_ui" / "build" / "web"
ASSETS_DIR = BASE_DIR / "assets"
# 정적 파일 디렉토리 설정 - Flutter 빌드 파일용
STATIC_DIR = Path(__file__).resolve().parent / "static"

# Render.com 영구 저장소 경로 설정
PERSISTENT_DIR = None
if os.environ.get('RENDER') == 'true':
    PERSISTENT_DIR = Path("/opt/render/project/src/persistent_data")
    PERSISTENT_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"📂 Render.com 영구 저장소 경로 설정: {PERSISTENT_DIR}")
    
    # assets 폴더가 비어있고 영구 저장소에 데이터가 있으면 복사
    if PERSISTENT_DIR.exists():
        assets_files = list(ASSETS_DIR.glob("trend_summary_*.json"))
        if not assets_files:
            for json_file in PERSISTENT_DIR.glob("trend_summary_*.json"):
                dest_file = ASSETS_DIR / json_file.name
                if not dest_file.exists():
                    shutil.copy(json_file, dest_file)
                    logger.info(f"📋 영구 저장소에서 복원된 파일: {json_file.name}")

# assets 디렉토리가 없으면 생성
try:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"✅ assets 디렉토리 확인/생성 완료: {ASSETS_DIR}")
except Exception as e:
    logger.error(f"❌ assets 디렉토리 생성 실패: {str(e)}")

# static 디렉토리가 없으면 생성
try:
    STATIC_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"✅ static 디렉토리 확인/생성 완료: {STATIC_DIR}")
except Exception as e:
    logger.error(f"❌ static 디렉토리 생성 실패: {str(e)}")

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
        # 스케줄러 실행 상태 추적
        self.scheduler_running = False
        self.daily_task_last_run = None
        # 강제 초기화 상태 추적
        self.initial_fetch_done = False

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
            "is_healthy": self.error_count < 3 and self.last_update is not None,
            "scheduler_running": self.scheduler_running,
            "daily_task_last_run": self.daily_task_last_run.isoformat() if self.daily_task_last_run else None,
            "initial_fetch_done": self.initial_fetch_done
        }

news_cache = NewsCache()

def update_news_cache():
    """assets 폴더에서 최신 뉴스 데이터를 읽어와 캐시를 업데이트"""
    try:
        # 최신 뉴스 데이터 파일 찾기 - 기본 파일 제외하고 날짜 파일 우선
        latest_file = None
        
        # 먼저 assets 디렉토리에서 날짜가 포함된 파일들만 찾기 (기본 파일 제외)
        news_files = [
            f for f in ASSETS_DIR.glob("trend_summary_*.json")
            if f.name != "trend_summary_default.json"  # 기본 파일 제외
        ]
        
        if news_files:
            try:
                # 파일명에서 날짜와 시간 추출하여 정렬
                def extract_datetime_from_filename(filepath):
                    """파일명에서 날짜시간 추출"""
                    try:
                        # trend_summary_2025-05-26_13-03.json 형식에서 날짜시간 추출
                        parts = filepath.stem.split('_')
                        if len(parts) >= 3:
                            date_str = parts[2]  # 2025-05-26
                            time_str = parts[3] if len(parts) > 3 else "00-00"  # 13-03
                            datetime_str = f"{date_str} {time_str.replace('-', ':')}"
                            return datetime.strptime(datetime_str, "%Y-%m-%d %H:%M")
                    except:
                        pass
                    # 파싱 실패 시 파일 수정 시간 사용
                    return datetime.fromtimestamp(filepath.stat().st_mtime)
                
                # 날짜시간 기준으로 정렬하여 가장 최신 파일 선택
                latest_file = sorted(
                    news_files,
                    key=extract_datetime_from_filename,
                    reverse=True
                )[0]
                logger.info(f"📂 assets 폴더에서 최신 날짜 파일 발견: {latest_file}")
                
            except Exception as e:
                # 정렬 실패 시 수정 시간 기준으로 폴백
                latest_file = sorted(news_files, key=lambda p: p.stat().st_mtime, reverse=True)[0]
                logger.warning(f"⚠️ 날짜 기준 정렬 실패, 수정 시간 기준 사용: {str(e)}")
                logger.info(f"📂 assets 폴더에서 최신 파일 발견 (수정 시간 기준): {latest_file}")
        
        # 날짜 파일이 없으면 영구 저장소 검사
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
        
        # 어디에도 날짜 파일이 없으면 기본 파일 사용
        if not latest_file and DEFAULT_DATA_FILE.exists():
            latest_file = DEFAULT_DATA_FILE
            logger.warning("⚠️ 날짜가 포함된 뉴스 데이터 파일을 찾을 수 없어 기본 데이터를 사용합니다.")
            
        # 파일을 찾았으면 처리
        if latest_file:
            try:
                with open(latest_file, "r", encoding="utf-8") as f:
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
                    
                    # 뉴스 데이터가 있으면 중요도 기준으로 정렬
                    if "news_list" in processed_data and processed_data["news_list"]:
                        try:
                            sorted_news = rank_news_by_importance(processed_data["news_list"], limit=30)
                            processed_data["news_list"] = sorted_news
                            logger.info(f"✅ 뉴스 데이터 중요도 정렬 완료: {len(sorted_news)}개")
                        except Exception as e:
                            logger.error(f"뉴스 정렬 오류: {str(e)}")
                            # 정렬 실패 시 원본 데이터 유지
                    
                    news_cache.update(processed_data)
                    logger.info(f"✅ 뉴스 캐시 업데이트 완료: {latest_file.name}")
                    
                    # 데이터가 비어있거나 오래된 경우 (3일 이상) 새로운 데이터 수집 트리거
                    if not processed_data["news_list"] or (
                        latest_file != DEFAULT_DATA_FILE and 
                        (datetime.now() - datetime.fromtimestamp(latest_file.stat().st_mtime)).days >= 3
                    ):
                        logger.warning("⚠️ 데이터가 비어있거나 오래되어 새 데이터 수집이 필요합니다.")
                        if not news_cache.initial_fetch_done:
                            import threading
                            initial_fetch_thread = threading.Thread(target=run_initial_fetch, daemon=True)
                            initial_fetch_thread.start()
                            logger.info("🔄 백그라운드에서 데이터 수집을 시작합니다.")
                            news_cache.initial_fetch_done = True
            except json.JSONDecodeError as e:
                logger.error(f"JSON 파싱 오류: {str(e)}")
                news_cache.record_error(f"JSON 파싱 오류: {str(e)}")
            except Exception as e:
                logger.error(f"파일 읽기 오류: {str(e)}")
                news_cache.record_error(f"파일 읽기 오류: {str(e)}")
        else:
            news_cache.record_error("뉴스 데이터 파일을 찾을 수 없습니다.")
            logger.error("뉴스 데이터 파일을 찾을 수 없습니다.")
            
            # 파일이 없을 경우 초기 데이터 수집 트리거
            if not news_cache.initial_fetch_done:
                import threading
                initial_fetch_thread = threading.Thread(target=run_initial_fetch, daemon=True)
                initial_fetch_thread.start()
                logger.info("🔄 백그라운드에서 초기 뉴스 수집을 시작합니다.")
                news_cache.initial_fetch_done = True
            
    except Exception as e:
        news_cache.record_error(str(e))
        logger.error(f"캐시 업데이트 실패: {str(e)}")

def run_scheduled_news_pipeline():
    """매일 오전 6시에 실행되는 뉴스 수집 함수"""
    try:
        # 오늘 이미 실행되었는지 확인
        now = datetime.now()
        
        if news_cache.daily_task_last_run:
            last_run_date = news_cache.daily_task_last_run.date()
            if last_run_date == now.date():
                logger.info(f"⏭️ 오늘({now.date()})은 이미 뉴스 수집을 실행했습니다. 건너뜁니다.")
                return
        
        logger.info(f"🔔 예정된 일일 뉴스 수집 시작: {now}")
        run_news_pipeline()  # 뉴스 수집 및 분석 실행
        news_cache.daily_task_last_run = now
        news_cache.initial_fetch_done = True
        logger.info(f"✅ 일일 뉴스 수집 완료: {now}")
    except Exception as e:
        logger.error(f"❌ 예정된 뉴스 수집 실패: {str(e)}")

def run_scheduler():
    """백그라운드에서 스케줄러 실행"""
    news_cache.scheduler_running = True
    logger.info("🕒 스케줄러가 시작되었습니다.")
    
    # 스케줄 상태 로깅
    logger.info(f"📅 설정된 스케줄: {schedule.jobs}")
    
    while True:
        try:
            # 현재 시간과 다음 실행 시간 로깅
            now = datetime.now()
            next_run = schedule.next_run()
            if next_run:
                logger.info(f"⏰ 현재 시간: {now.strftime('%Y-%m-%d %H:%M:%S')}, 다음 실행: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")
            
            schedule.run_pending()
            time.sleep(60)  # 1분마다 확인
        except Exception as e:
            logger.error(f"❌ 스케줄러 오류: {str(e)}")
            time.sleep(300)  # 오류 발생 시 5분 대기

def run_news_pipeline():
    """스케줄러에서 호출될 함수"""
    logger.info("🔔 run_news_pipeline 함수가 호출되었습니다.")
    try:
        pipeline.run_daily_collection()
        # 수집 후 캐시 강제 업데이트
        update_news_cache()
        logger.info("✅ 뉴스 파이프라인 실행 완료 및 캐시 업데이트")
    except Exception as e:
        logger.error(f"❌ 뉴스 파이프라인 실행 실패: {str(e)}")

# 초기 데이터 수집 함수 추가
def run_initial_fetch():
    """서버 시작 시 호출되는 초기 데이터 수집 함수"""
    try:
        logger.info("🚀 서버 시작 시 초기 뉴스 수집을 시작합니다...")
        
        # 뉴스 수집 실행 - 직접 pipeline 객체의 메서드 호출
        pipeline.run_daily_collection()
        
        # 수집 후 생성된 최신 파일을 즉시 찾기
        current_timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
        expected_file = ASSETS_DIR / f"trend_summary_{current_timestamp}.json"
        
        # 정확한 타임스탬프 파일이 없다면 오늘 날짜의 최신 파일 찾기
        today = datetime.now().strftime("%Y-%m-%d")
        today_files = list(ASSETS_DIR.glob(f"trend_summary_{today}_*.json"))
        
        if expected_file.exists():
            # 예상 파일이 존재하면 이 파일 사용
            newest_file = expected_file
            logger.info(f"✅ 새로 생성된 파일 발견: {newest_file}")
        elif today_files:
            # 오늘 생성된 파일 중 가장 최신 파일 사용
            newest_file = sorted(today_files, key=lambda p: p.stat().st_mtime, reverse=True)[0]
            logger.info(f"✅ 오늘 생성된 최신 파일 발견: {newest_file}")
        else:
            # 그래도 없으면 일반 업데이트 로직 사용
            logger.warning("⚠️ 새로 생성된 파일을 찾을 수 없습니다. 일반 캐시 업데이트를 수행합니다.")
            update_news_cache()
            
            # 상태 업데이트
            news_cache.initial_fetch_done = True
            news_cache.daily_task_last_run = datetime.now()
            
            logger.info("✅ 초기 뉴스 수집 완료")
            return
            
        # 찾은 파일 직접 로드
        try:
            with open(newest_file, "r", encoding="utf-8") as f:
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
                    "news_list": data.get("news_list", [])
                }
                
                # 뉴스 데이터가 있으면 중요도 기준으로 정렬
                if "news_list" in processed_data and processed_data["news_list"]:
                    try:
                        sorted_news = rank_news_by_importance(processed_data["news_list"], limit=30)
                        processed_data["news_list"] = sorted_news
                        logger.info(f"✅ 뉴스 데이터 중요도 정렬 완료: {len(sorted_news)}개")
                    except Exception as e:
                        logger.error(f"뉴스 정렬 오류: {str(e)}")
                
                # 캐시 직접 업데이트
                news_cache.update(processed_data)
                logger.info(f"✅ 뉴스 캐시 직접 업데이트 완료: {newest_file.name}")
        except Exception as e:
            logger.error(f"❌ 최신 파일 로드 실패: {str(e)}")
            # 실패 시 기본 업데이트 로직 사용
            update_news_cache()
        
        # 상태 업데이트
        news_cache.initial_fetch_done = True
        news_cache.daily_task_last_run = datetime.now()
        
        logger.info("✅ 초기 뉴스 수집 완료")
        
        # 영구 저장소에 최신 파일 복사 (Render.com 환경에서만)
        if os.environ.get('RENDER') == 'true' and PERSISTENT_DIR:
            # 방금 찾은 최신 파일 사용
            latest_file = newest_file
            dest_file = PERSISTENT_DIR / "trend_summary_latest.json"
            shutil.copy(latest_file, dest_file)
            logger.info(f"📋 최신 데이터 파일을 영구 저장소에 복사: {latest_file.name} -> trend_summary_latest.json")
            
            # 원본 파일도 영구 저장소에 복사
            perm_file = PERSISTENT_DIR / latest_file.name
            shutil.copy(latest_file, perm_file)
            logger.info(f"📋 데이터 파일을 영구 저장소에 복사: {latest_file.name}")
    except Exception as e:
        logger.error(f"❌ 초기 뉴스 수집 실패: {str(e)}")

# 강제 뉴스 수집 함수 추가
def force_news_collection():
    """강제로 뉴스 수집을 실행하는 함수"""
    try:
        logger.info("🔥 강제 뉴스 수집을 시작합니다...")
        
        # 기존 상태 초기화
        news_cache.initial_fetch_done = False
        news_cache.daily_task_last_run = None
        
        # 뉴스 수집 실행
        pipeline.run_daily_collection()
        
        # 캐시 업데이트
        update_news_cache()
        
        # 상태 업데이트
        news_cache.initial_fetch_done = True
        news_cache.daily_task_last_run = datetime.now()
        
        logger.info("✅ 강제 뉴스 수집 완료")
        return True
    except Exception as e:
        logger.error(f"❌ 강제 뉴스 수집 실패: {str(e)}")
        return False

# --- API 엔드포인트 ---
@app.get("/status")
async def get_status():
    """서버 상태 확인 엔드포인트"""
    # 현재 시간
    now = datetime.now()
    
    # 오늘 날짜의 파일 확인
    today = now.strftime("%Y-%m-%d")
    today_files = list(ASSETS_DIR.glob(f"trend_summary_{today}_*.json"))
    
    # 다음 스케줄 실행 시간
    next_run = schedule.next_run() if schedule.jobs else None
    
    # 캐시 상태
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
            "time_until_next_run": str(next_run - now) if next_run else None
        },
        "files": {
            "today_files_count": len(today_files),
            "today_files": [f.name for f in today_files],
            "assets_dir_exists": ASSETS_DIR.exists(),
            "persistent_dir_exists": PERSISTENT_DIR.exists() if PERSISTENT_DIR else False
        },
        "environment": {
            "render": os.environ.get('RENDER') == 'true',
            "openai_api_key_set": bool(os.getenv('OPENAI_API_KEY')),
            "assets_dir": str(ASSETS_DIR),
            "persistent_dir": str(PERSISTENT_DIR) if PERSISTENT_DIR else None
        },
        "uptime": str(now - cache_status.get("last_update", now)) if cache_status.get("last_update") else None
    }

@app.get("/news")
async def get_news_data():
    """뉴스 데이터 조회 엔드포인트"""
    try:
        # 캐시에 데이터가 없으면 업데이트
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
                
                # 백그라운드에서 데이터 수집 시작
                if not news_cache.initial_fetch_done:
                    import threading
                    initial_fetch_thread = threading.Thread(target=run_initial_fetch, daemon=True)
                    initial_fetch_thread.start()
                    logger.info("🔄 백그라운드에서 초기 뉴스 수집을 시작합니다.")
                    news_cache.initial_fetch_done = True
                
                return {
                    "data": default_data,
                    "metadata": {
                        "last_updated": datetime.now().isoformat(),
                        "next_update": (datetime.now() + timedelta(hours=1)).isoformat(),
                        "status": "using_default",
                        "message": "뉴스 데이터를 수집 중입니다. 잠시 후 다시 확인해주세요."
                    }
                }
        
        # news_list 필드가 없거나 비어있으면 최신 파일 강제 확인
        if "news_list" not in news_cache.latest_data or not news_cache.latest_data["news_list"]:
            logger.warning("⚠️ news_list가 비어있습니다. 최신 파일을 강제로 확인합니다.")
            
            # 오늘 날짜의 파일을 찾아서 직접 로드
            today = datetime.now().strftime("%Y-%m-%d")
            today_files = list(ASSETS_DIR.glob(f"trend_summary_{today}_*.json"))
            
            if today_files:
                # 오늘 생성된 파일 중 가장 최신 파일 사용
                newest_file = sorted(today_files, key=lambda p: p.stat().st_mtime, reverse=True)[0]
                logger.info(f"✅ 오늘 생성된 최신 파일 발견: {newest_file}")
                
                try:
                    with open(newest_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        
                        # 뉴스 데이터 확인
                        if "news_list" in data and data["news_list"]:
                            # 중요도로 정렬
                            sorted_news = rank_news_by_importance(data["news_list"], limit=30)
                            data["news_list"] = sorted_news
                            
                            # 캐시 업데이트
                            news_cache.update(data)
                            logger.info(f"✅ 최신 파일에서 뉴스 {len(sorted_news)}개 로드 완료")
                        else:
                            logger.warning(f"⚠️ 최신 파일에도 news_list가 비어 있습니다: {newest_file}")
                except Exception as e:
                    logger.error(f"❌ 최신 파일 로드 실패: {str(e)}")
            
            # 여전히 뉴스 목록이 없으면 데이터 수집 시작
            if not news_cache.latest_data or "news_list" not in news_cache.latest_data or not news_cache.latest_data["news_list"]:
                logger.warning("⚠️ news_list가 여전히 비어있어 기본 데이터를 사용합니다. 데이터 수집이 필요합니다.")
                
                # 강제로 뉴스 데이터 수집 시작 (백그라운드)
                if not news_cache.initial_fetch_done:
                    import threading
                    initial_fetch_thread = threading.Thread(target=run_initial_fetch, daemon=True)
                    initial_fetch_thread.start()
                    logger.info("🔄 백그라운드에서 초기 뉴스 수집을 시작합니다.")
                    news_cache.initial_fetch_done = True
                
                # news_list 필드가 없으면 빈 배열 추가
                if "news_list" not in news_cache.latest_data:
                    news_cache.latest_data["news_list"] = []
                
                # 사용자에게 데이터 수집 중임을 알리는 메시지 추가
                return {
                    "data": news_cache.latest_data,
                    "metadata": {
                        "last_updated": news_cache.last_update.isoformat() if news_cache.last_update else datetime.now().isoformat(),
                        "next_update": (datetime.now() + timedelta(hours=1)).isoformat(),
                        "status": "collecting",
                        "message": "뉴스 데이터를 수집 중입니다. 잠시 후 다시 확인해주세요."
                    }
                }
        
        # 뉴스 기사가 있지만 아직 중요도 정렬이 안된 경우
        elif news_cache.latest_data["news_list"] and not any("importance_score" in news for news in news_cache.latest_data["news_list"]):
            try:
                # 직접 함수 호출
                sorted_news = rank_news_by_importance(news_cache.latest_data["news_list"], limit=30)
                news_cache.latest_data["news_list"] = sorted_news
                logger.info(f"✅ API 요청 시 뉴스 데이터 중요도 정렬 완료: {len(sorted_news)}개")
            except Exception as e:
                logger.error(f"뉴스 정렬 오류: {str(e)}")
            
        return {
            "data": news_cache.latest_data,
            "metadata": {
                "last_updated": news_cache.last_update.isoformat() if news_cache.last_update else datetime.now().isoformat(),
                "next_update": (news_cache.last_update + timedelta(hours=24)).isoformat() if news_cache.last_update else (datetime.now() + timedelta(hours=24)).isoformat(),
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
                "time_range": "오류 발생",
                "news_list": []  # 빈 배열 추가
            },
            "metadata": {
                "last_updated": datetime.now().isoformat(),
                "next_update": (datetime.now() + timedelta(hours=24)).isoformat(),
                "status": "error",
                "error": str(e)
            }
        }

@app.post("/refresh")
async def force_refresh(background_tasks: BackgroundTasks):
    """수동으로 뉴스 데이터 새로고침"""
    # 마지막 새로고침으로부터 최소 30분이 지났는지 확인 (남용 방지, 1시간에서 30분으로 단축)
    if news_cache.daily_task_last_run:
        time_since_last_run = datetime.now() - news_cache.daily_task_last_run
        if time_since_last_run.total_seconds() < 1800:  # 30분 = 1800초
            return {
                "message": f"새로고침 요청이 너무 빈번합니다. {1800 - int(time_since_last_run.total_seconds())}초 후에 다시 시도해주세요.",
                "status": "rate_limited",
                "last_run": news_cache.daily_task_last_run.isoformat(),
                "next_available": (news_cache.daily_task_last_run + timedelta(minutes=30)).isoformat()
            }
    
    logger.info("🔄 수동 새로고침 요청을 받았습니다.")
    
    # 백그라운드에서 강제 뉴스 수집 실행
    background_tasks.add_task(force_news_collection)
    
    return {
        "message": "뉴스 데이터 새로고침이 시작되었습니다. 약 2-3분 후에 새로운 데이터를 확인할 수 있습니다.",
        "status": "started",
        "estimated_completion": (datetime.now() + timedelta(minutes=3)).isoformat()
    }

@app.post("/update-cache")
async def force_update_cache():
    """캐시를 강제로 업데이트하는 엔드포인트"""
    try:
        logger.info("🔄 캐시 강제 업데이트 요청을 받았습니다.")
        
        # 캐시 업데이트 실행
        update_news_cache()
        
        # 업데이트 후 상태 확인
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
                "status": "no_data",
                "last_updated": news_cache.last_update.isoformat() if news_cache.last_update else None
            }
    except Exception as e:
        logger.error(f"❌ 캐시 강제 업데이트 실패: {str(e)}")
        return {
            "message": f"캐시 업데이트 중 오류가 발생했습니다: {str(e)}",
            "status": "error"
        }

# --- 서버 시작 이벤트 ---
@app.on_event("startup")
async def startup_event():
    # 초기 뉴스 데이터 로드
    try:
        logger.info("�� 초기 데이터 로드 시작...")
        
        # 먼저 캐시 강제 업데이트
        update_news_cache()
        logger.info("✅ 초기 캐시 업데이트 완료")
        
        # 스케줄러 설정 - 명확하게 하나의 작업만 지정
        schedule.clear()  # 기존 스케줄 초기화
        schedule.every().day.at("06:00").do(run_scheduled_news_pipeline)  # 매일 오전 6시에 뉴스 수집 및 분석
        schedule.every(30).minutes.do(update_news_cache)  # 캐시 업데이트는 30분마다 유지
        
        logger.info("📅 스케줄 설정 완료:")
        for job in schedule.jobs:
            logger.info(f"  - {job}")
        
        # 스케줄러가 이미 실행 중인지 확인
        if not news_cache.scheduler_running:
            # 백그라운드 스레드에서 스케줄러 실행
            scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
            scheduler_thread.start()
            logger.info("🕒 백그라운드 스케줄러 시작됨")
        
        # 오늘 날짜의 파일이 있는지 확인
        today = datetime.now().strftime("%Y-%m-%d")
        today_files = list(ASSETS_DIR.glob(f"trend_summary_{today}_*.json"))
        
        # 오늘 데이터가 없거나 기본 데이터만 있으면 강제로 새로 수집
        if not today_files:
            logger.info("🔄 오늘 생성된 데이터가 없어 강제로 새로 수집합니다.")
            # 백그라운드에서 강제 뉴스 수집 시작
            import threading
            force_fetch_thread = threading.Thread(target=force_news_collection, daemon=True)
            force_fetch_thread.start()
            logger.info("🔄 백그라운드에서 강제 뉴스 수집을 시작합니다.")
        else:
            logger.info(f"✅ 오늘 생성된 데이터 파일이 이미 있습니다: {today_files[0].name}")
            # 그래도 캐시에 데이터가 없으면 강제 수집
            if not news_cache.latest_data or "news_list" not in news_cache.latest_data or not news_cache.latest_data["news_list"]:
                logger.warning("⚠️ 캐시에 뉴스 목록이 없습니다. 강제 데이터 수집을 시작합니다.")
                import threading
                force_fetch_thread = threading.Thread(target=force_news_collection, daemon=True)
                force_fetch_thread.start()
                logger.info("🔄 백그라운드에서 강제 뉴스 수집을 시작합니다.")
            
        # 캐시에 데이터가 있는지, news_list가 비어있는지 확인
        if not news_cache.latest_data or "news_list" not in news_cache.latest_data or not news_cache.latest_data["news_list"]:
            logger.warning("⚠️ 캐시에 뉴스 목록이 없습니다. 기본 데이터를 로드합니다.")
            # 기본 데이터 파일에서 다시 로드 시도
            default_data_path = ASSETS_DIR / "trend_summary_default.json"
            if default_data_path.exists():
                try:
                    with open(default_data_path, "r", encoding="utf-8") as f:
                        default_data = json.load(f)
                        if "news_list" in default_data and default_data["news_list"]:
                            logger.info("✅ 기본 데이터 파일에서 뉴스 목록을 로드했습니다.")
                            news_cache.update(default_data)
                except Exception as e:
                    logger.error(f"❌ 기본 데이터 파일 로드 실패: {str(e)}")
                    
        # 서버 시작 후 5분 뒤에 한 번 더 강제 수집 시도 (보험용)
        def delayed_force_collection():
            time.sleep(300)  # 5분 대기
            if not news_cache.latest_data or "news_list" not in news_cache.latest_data or not news_cache.latest_data["news_list"]:
                logger.warning("⚠️ 5분 후에도 뉴스 데이터가 없습니다. 다시 강제 수집을 시도합니다.")
                force_news_collection()
        
        delayed_thread = threading.Thread(target=delayed_force_collection, daemon=True)
        delayed_thread.start()
        logger.info("⏰ 5분 후 추가 데이터 수집 체크가 예약되었습니다.")
        
        logger.info("✅ 서버 시작 이벤트 완료")
        
    except Exception as e:
        logger.error(f"❌ 서버 시작 이벤트 실패: {str(e)}")
        # 실패해도 서버는 계속 실행되도록 함

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
    # 1. Flutter 웹 빌드 파일을 static 디렉토리로 제공
    if STATIC_DIR.exists():
        try:
            app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")
            logger.info(f"✅ 정적 파일 디렉토리 마운트 완료: {STATIC_DIR}")
        except Exception as e:
            logger.error(f"❌ 정적 파일 디렉토리 마운트 실패: {str(e)}")
    else:
        logger.warning(f"⚠️ 정적 파일 디렉토리를 찾을 수 없습니다: {STATIC_DIR}")
        # 2. 대안으로 Flutter 빌드 디렉토리 직접 마운트 시도
        try:
            app.mount("/", StaticFiles(directory=str(FLUTTER_BUILD_DIR), html=True), name="flutter_web")
            logger.info(f"✅ Flutter 웹 루트 디렉토리 마운트 완료: {FLUTTER_BUILD_DIR}")
        except Exception as e:
            logger.error(f"❌ Flutter 웹 루트 디렉토리 마운트 실패: {str(e)}")
    
    # 3. 개별 디렉토리 마운트 (여전히 유효하지만 위의 전체 마운트가 먼저 시도됨)
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
    
    # 4. 모든 파일에 대한 명시적인 MIME 타입 설정이 있는 catch-all 라우트
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        # 먼저 static 디렉토리에서 찾기
        static_path = STATIC_DIR / path
        if static_path.exists():
            # 파일의 MIME 타입을 명시적으로 설정
            mime_type = None
            if path.endswith('.js'):
                mime_type = 'application/javascript'
            elif path.endswith('.css'):
                mime_type = 'text/css'
            elif path.endswith('.html'):
                mime_type = 'text/html'
            elif path.endswith('.json'):
                mime_type = 'application/json'
            return FileResponse(str(static_path), media_type=mime_type)
            
        # 다음으로 Flutter 빌드 디렉토리에서 찾기
        flutter_path = FLUTTER_BUILD_DIR / path
        if flutter_path.exists():
            # 파일의 MIME 타입을 명시적으로 설정
            mime_type = None
            if path.endswith('.js'):
                mime_type = 'application/javascript'
            elif path.endswith('.css'):
                mime_type = 'text/css'
            elif path.endswith('.html'):
                mime_type = 'text/html'
            elif path.endswith('.json'):
                mime_type = 'application/json'
            return FileResponse(str(flutter_path), media_type=mime_type)
            
        # 파일이 존재하지 않으면 index.html 반환
        if (STATIC_DIR / "index.html").exists():
            return FileResponse(str(STATIC_DIR / "index.html"))
        return FileResponse(str(FLUTTER_BUILD_DIR / "index.html"))