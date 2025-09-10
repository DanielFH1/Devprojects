from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import uuid
import time
from datetime import datetime
import redis
import os
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

app = FastAPI(title="ShareTime API", version="1.0.0")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인으로 제한
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redis 연결 (선택사항, 없으면 메모리 저장소 사용)
try:
    redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", 6379)),
        db=0,
        decode_responses=True
    )
    redis_client.ping()
    use_redis = True
except:
    use_redis = False
    print("Redis connection failed, using memory storage")

# 메모리 저장소 (Redis가 없을 때 사용)
timers: Dict[str, Dict[str, Any]] = {}

# Pydantic 모델
class TimerCreate(BaseModel):
    name: str
    description: str
    total_seconds: int

class TimerUpdate(BaseModel):
    remaining_seconds: int

class TimerResponse(BaseModel):
    id: str
    name: str
    description: str
    total_seconds: int
    remaining_seconds: int
    created_at: str
    is_active: bool

def generate_short_code() -> str:
    """6자리 알파벳 숫자 조합 코드 생성"""
    import random
    import string
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

def get_timer(timer_id: str) -> Optional[Dict[str, Any]]:
    """타이머 조회"""
    if use_redis:
        timer_data = redis_client.get(f"timer:{timer_id}")
        if timer_data:
            import json
            return json.loads(timer_data)
    else:
        return timers.get(timer_id)
    return None

def save_timer(timer_id: str, timer_data: Dict[str, Any]):
    """타이머 저장"""
    if use_redis:
        import json
        redis_client.setex(
            f"timer:{timer_id}",
            3600,  # 1시간 후 만료
            json.dumps(timer_data)
        )
    else:
        timers[timer_id] = timer_data

@app.post("/timers", response_model=Dict[str, str])
async def create_timer(timer: TimerCreate):
    """타이머 생성"""
    if timer.total_seconds <= 0:
        raise HTTPException(status_code=400, detail="Time must be greater than 0")
    
    # 고유 ID 생성
    timer_id = generate_short_code()
    
    # 기존 ID와 중복되지 않도록 확인
    while get_timer(timer_id):
        timer_id = generate_short_code()
    
    timer_data = {
        "id": timer_id,
        "name": timer.name,
        "description": timer.description,
        "total_seconds": timer.total_seconds,
        "remaining_seconds": timer.total_seconds,
        "created_at": datetime.now().isoformat(),
        "is_active": True
    }
    
    save_timer(timer_id, timer_data)
    
    return {"id": timer_id, "message": "Timer created successfully"}

@app.get("/timers/{timer_id}", response_model=TimerResponse)
async def get_timer_by_id(timer_id: str):
    """타이머 조회"""
    timer = get_timer(timer_id)
    if not timer:
        raise HTTPException(status_code=404, detail="Timer not found")
    
    return TimerResponse(**timer)

@app.put("/timers/{timer_id}")
async def update_timer(timer_id: str, timer_update: TimerUpdate):
    """타이머 업데이트"""
    timer = get_timer(timer_id)
    if not timer:
        raise HTTPException(status_code=404, detail="Timer not found")
    
    timer["remaining_seconds"] = timer_update.remaining_seconds
    save_timer(timer_id, timer)
    
    return {"message": "Timer updated successfully"}

@app.delete("/timers/{timer_id}")
async def delete_timer(timer_id: str):
    """타이머 삭제"""
    if use_redis:
        redis_client.delete(f"timer:{timer_id}")
    else:
        if timer_id in timers:
            del timers[timer_id]
    
    return {"message": "Timer deleted successfully"}

@app.get("/health")
async def health_check():
    """헬스 체크"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "storage": "redis" if use_redis else "memory"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 