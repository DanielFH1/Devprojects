# ShareTime Backend

ShareTime 앱의 Python FastAPI 백엔드입니다.

## 설치 및 실행

### 1. 의존성 설치

```bash
cd backend
pip install -r requirements.txt
```

### 2. 환경 변수 설정 (선택사항)

Redis를 사용하려면 `.env` 파일을 생성하세요:

```env
REDIS_HOST=localhost
REDIS_PORT=6379
```

Redis가 없으면 메모리 저장소를 사용합니다.

### 3. 서버 실행

```bash
python main.py
```

또는 uvicorn을 직접 사용:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. API 문서 확인

서버 실행 후 다음 URL에서 API 문서를 확인할 수 있습니다:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API 엔드포인트

### 타이머 생성
```
POST /timers
```

### 타이머 조회
```
GET /timers/{timer_id}
```

### 타이머 업데이트
```
PUT /timers/{timer_id}
```

### 타이머 삭제
```
DELETE /timers/{timer_id}
```

### 헬스 체크
```
GET /health
```

## 기능

- 6자리 알파벳 숫자 조합의 고유 코드 생성
- Redis 또는 메모리 저장소 지원
- CORS 설정으로 Flutter 앱과 통신
- 자동 코드 중복 방지
- 1시간 후 자동 만료 (Redis 사용 시) 