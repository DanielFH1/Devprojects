from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import json
from pathlib import Path
from fastapi.responses import FileResponse

app = FastAPI()  # FastAPI 인스턴스 생성

# --- 경로 설정 ---
# api_server.py 파일의 위치를 기준으로 상대 경로를 계산합니다.
# __file__은 현재 파일(api_server.py)의 경로입니다.
# .resolve()는 심볼릭 링크 등을 해석하여 실제 경로를 얻습니다.
# .parent는 현재 파일이 있는 디렉토리 (web/)
# .parent.parent는 프로젝트 루트 디렉토리 (sideprojects4_electionsimulator/)
BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_BUILD_DIR = BASE_DIR / "flutter_ui" / "build" / "web"
ASSETS_DIR = BASE_DIR / "assets"

# --- CORS 미들웨어 설정 ---
# Flutter 웹 앱 (다른 포트 또는 도메인에서 실행될 수 있음)에서의 API 요청을 허용합니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 중에는 모든 출처 허용, 배포 시에는 특정 도메인으로 제한하는 것이 좋습니다.
    allow_credentials=True,
    allow_methods=["*"],  # 모든 HTTP 메소드 허용
    allow_headers=["*"],  # 모든 HTTP 헤더 허용
)

# --- API 엔드포인트 ---
@app.get("/news")
def get_news_data():
    # assets 폴더에서 최신 news_summary_*.json 파일을 찾도록 수정
    news_files = sorted(ASSETS_DIR.glob("news_summary_*.json"), key=lambda p: p.stat().st_mtime, reverse=True)

    if not news_files:
        raise HTTPException(
            status_code=404,
            detail=f"'assets' 폴더에서 'news_summary_YYYY-MM-DD_HH-MM.json' 형식의 뉴스 요약 파일을 찾을 수 없습니다. '!scrapper.py'를 실행하여 파일이 생성되었는지 확인하세요."
        )

    news_file_path = news_files[0] # 가장 최신 파일 사용

    try:
        with open(news_file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data
    except FileNotFoundError:
        # 이 경우는 glob에서 파일을 찾지 못했을 때 발생하지 않으므로, 위의 news_files 체크로 충분합니다.
        # 만약 특정 파일명을 고정으로 사용한다면 이 예외 처리가 유용합니다.
        raise HTTPException(status_code=404, detail=f"뉴스 파일 '{news_file_path.name}'을(를) 찾을 수 없습니다.")
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail=f"뉴스 파일 '{news_file_path.name}'의 JSON 형식이 잘못되었습니다.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"뉴스 데이터 로딩 중 오류 발생: {str(e)}")


# --- Flutter 웹 애플리케이션 제공 ---
# FLUTTER_BUILD_DIR이 실제로 존재하는지, index.html이 있는지 먼저 확인합니다.
if not FLUTTER_BUILD_DIR.exists() or not (FLUTTER_BUILD_DIR / "index.html").exists():
    print(f"경고: Flutter 빌드 디렉토리 또는 index.html을 찾을 수 없습니다: {FLUTTER_BUILD_DIR}")
    print(f"Flutter UI를 올바르게 제공하려면 'flutter_ui' 디렉토리 내에서 'flutter build web' 명령을 실행하여 웹 파일을 빌드해야 합니다.")
    # 기본적인 API 서버 역할만 하도록 루트 경로에 간단한 메시지를 반환할 수 있습니다.
    @app.get("/")
    async def fallback_root():
        return {
            "message": "Flutter UI 빌드 파일을 찾을 수 없습니다. API는 /news 에서 사용 가능합니다.",
            "flutter_build_path_expected": str(FLUTTER_BUILD_DIR)
        }
else:
    # Flutter 웹 앱의 정적 파일들을 제공하기 전에 API 라우트를 먼저 설정합니다.
    @app.get("/")
    async def root():
        return FileResponse(FLUTTER_BUILD_DIR / "index.html")

    # Flutter 웹 앱의 정적 파일들(JS, CSS, 이미지 등)을 제공합니다.
    app.mount("/assets", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "assets")), name="flutter_assets")
    app.mount("/icons", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "icons")), name="flutter_icons")
    app.mount("/canvaskit", StaticFiles(directory=str(FLUTTER_BUILD_DIR / "canvaskit")), name="flutter_canvaskit")
    
    # Flutter 웹 앱의 JavaScript 파일들을 제공합니다.
    @app.get("/{path:path}")
    async def serve_flutter_web(path: str):
        file_path = FLUTTER_BUILD_DIR / path
        if file_path.exists():
            return FileResponse(str(file_path))
        return FileResponse(str(FLUTTER_BUILD_DIR / "index.html"))