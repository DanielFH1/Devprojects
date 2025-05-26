# 2025 대선 시뮬레이터

실시간 뉴스 분석을 통한 대선 트렌드 예측 시스템

## 📋 프로젝트 개요

이 프로젝트는 뉴스 기사의 감성 분석을 통해 2025년 대선 후보들의 지지율을 예측하는 AI 기반 시뮬레이터입니다. 매일 자동으로 뉴스를 수집하고 분석하여 실시간 트렌드를 제공합니다.

## 🏗️ 시스템 아키텍처

```
├── web/                    # 백엔드 API 서버
│   └── api_server.py      # FastAPI 기반 메인 서버
├── flutter_ui/            # 프론트엔드 웹 앱
│   ├── lib/
│   │   ├── main_page.dart     # 메인 대시보드
│   │   ├── prediction_page.dart # 예측 결과 페이지
│   │   └── news_page.dart     # 뉴스 분석 페이지
│   └── web/               # 웹 빌드 파일
├── news_scraper.py        # 뉴스 수집 및 분석 엔진
├── assets/                # 데이터 저장소
└── requirements.txt       # Python 의존성
```

## 🚀 주요 기능

### 📊 실시간 트렌드 분석

- 매일 오전 6시 자동 뉴스 수집
- OpenAI GPT를 활용한 감성 분석
- 후보자별 언론 동향 추적

### 📈 지지율 예측

- AI 기반 종합 예측 모델
- 뉴스 감성과 언급 빈도 분석
- 시간별 트렌드 변화 추적

### 📰 뉴스 분석

- 감성별/후보자별 필터링
- 상세 뉴스 목록 및 요약
- 원문 링크 제공

## 🛠️ 기술 스택

### 백엔드

- **FastAPI**: 고성능 웹 API 프레임워크
- **Python**: 메인 개발 언어
- **OpenAI API**: 뉴스 감성 분석
- **APScheduler**: 자동화된 작업 스케줄링
- **Gnews**: 뉴스 크롤링용 라이브러리

### 프론트엔드

- **Flutter Web**: 크로스 플랫폼 웹 앱
- **Dart**: 프론트엔드 개발 언어
- **Material Design**: UI/UX 디자인 시스템

### 배포 및 인프라

- **Render.com**: 클라우드 호스팅
- **GitHub**: 소스 코드 관리
- **환경변수**: API 키 및 설정 관리

## 📦 설치 및 실행

### 1. 저장소 클론

```bash
git clone <repository-url>
cd sideproject4_electionsimulator
```

### 2. Python 환경 설정

```bash
pip install -r requirements.txt
```

### 3. 환경변수 설정

```bash
export NEWS_API_KEY="your_news_api_key"
export OPENAI_API_KEY="your_openai_api_key"
```

### 4. Flutter 웹 빌드

```bash
cd flutter_ui
flutter build web
cd ..
```

### 5. 서버 실행

```bash
python web/api_server.py
```

## 🔧 API 엔드포인트

### 데이터 조회

- `GET /api/trend-summary`: 트렌드 요약 데이터
- `GET /api/prediction`: 지지율 예측 결과
- `GET /api/status`: 시스템 상태 확인

### 데이터 관리

- `POST /api/update-cache`: 캐시 업데이트
- `POST /api/force-today-collection`: 강제 뉴스 수집
- `POST /api/refresh`: 데이터 새로고침

### 정적 파일

- `GET /`: Flutter 웹 앱 서빙
- `GET /assets/*`: 정적 자산 파일

## 📊 데이터 구조

### 트렌드 요약 데이터

```json
{
  "trend_summary": "AI 분석 요약",
  "candidate_stats": {
    "이재명": {"긍정": 15, "중립": 10, "부정": 5},
    "김문수": {"긍정": 12, "중립": 8, "부정": 7},
    "이준석": {"긍정": 10, "중립": 12, "부정": 3}
  },
  "news_list": [...],
  "total_articles": 100,
  "time_range": "2025-01-26 06:00 ~ 2025-01-26 18:00"
}
```

### 예측 결과 데이터

```json
{
  "predictions": {
    "이재명": 42.5,
    "김문수": 35.2,
    "이준석": 22.3
  },
  "analysis": "예측 분석 설명",
  "total_articles": 100,
  "time_range": "분석 기간"
}
```

## 🔄 자동화 시스템

### 뉴스 수집 파이프라인

1. **스케줄링**: 매일 오전 6시 자동 실행
2. **데이터 수집**: NewsAPI를 통한 최신 뉴스 수집
3. **감성 분석**: OpenAI GPT를 활용한 감성 분석
4. **데이터 저장**: JSON 형태로 로컬 저장
5. **캐시 업데이트**: 실시간 데이터 반영

### 오류 처리 및 복구

- 네트워크 오류 시 재시도 로직
- API 한도 초과 시 백오프 전략
- 데이터 손실 방지를 위한 백업 시스템

## 🎨 UI/UX 특징

### 반응형 디자인

- 모바일, 태블릿, 데스크톱 최적화
- Material Design 3.0 적용
- 다크/라이트 테마 지원

### 사용자 경험

- 부드러운 애니메이션 효과
- 직관적인 네비게이션
- 실시간 데이터 업데이트
- 로딩 상태 및 오류 처리

## 🔒 보안 및 성능

### 보안

- API 키 환경변수 관리
- CORS 정책 적용
- 입력 데이터 검증

### 성능 최적화

- 데이터 캐싱 시스템
- 비동기 처리
- 압축된 정적 파일 서빙
- 효율적인 데이터 구조

## 📈 모니터링 및 로깅

### 로깅 시스템

- 구조화된 로그 포맷
- 레벨별 로그 분류
- 오류 추적 및 디버깅

### 상태 모니터링

- 시스템 헬스 체크
- API 응답 시간 측정
- 데이터 수집 상태 확인

## 🤝 기여 방법

1. Fork 프로젝트
2. Feature 브랜치 생성 (`git checkout -b feature/AmazingFeature`)
3. 변경사항 커밋 (`git commit -m 'Add some AmazingFeature'`)
4. 브랜치에 Push (`git push origin feature/AmazingFeature`)
5. Pull Request 생성

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 연락처

- 개발자: Daniel
- 이메일: daniel333@dgu.ac.kr
- 프로젝트 링크: [GitHub Repository]

## 🙏 감사의 말

- OpenAI: GPT API 제공
- NewsAPI: 뉴스 데이터 제공
- Flutter Team: 크로스 플랫폼 프레임워크
- Render.com: 클라우드 호스팅 서비스

---

**참고**: 이 시뮬레이터의 예측 결과는 참고용이며, 실제 선거 결과와 다를 수 있습니다.
