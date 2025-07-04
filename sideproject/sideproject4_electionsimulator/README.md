# 2025 대선 시뮬레이터 - 최종 버전

실시간 뉴스 분석을 통한 대선 트렌드 예측 시스템 (최종 선거 직전 버전)

## 📋 프로젝트 개요

이 프로젝트는 뉴스 기사의 감성 분석을 통해 2025년 대선 후보들의 지지율을 예측하는 AI 기반 시뮬레이터입니다. **선거 직전 최종 버전으로 서버 시작 시 200개 기사를 수집·분석한 후 더 이상 자동 수집하지 않습니다.**

## ⚡ 최종 버전 특징

- 🔥 **서버 시작 시 200개 기사 수집**: 더 많은 데이터로 정확한 분석
- 🎯 **개선된 감성 분석**: 중립 판정을 줄이고 긍정/부정을 명확히 분류
- 🚫 **스케줄러 비활성화**: 선거 당일이므로 반복 수집 중단
- 📊 **한 번의 완전한 분석**: 최종 예측 결과 제공

## 예측 정확도 분석

**최종 수집 결과 (200개 기사 분석 기준)**

서버 시작 시 자동으로 최신 뉴스 200개를 수집하여 감성 분석을 통한 예측을 제공합니다.

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

### 📊 최종 트렌드 분석

- **서버 시작 시 200개 기사 자동 수집**
- OpenAI GPT를 활용한 개선된 감성 분석
- 후보자별 언론 동향 최종 분석

### 📈 지지율 예측 (최종 버전)

- AI 기반 종합 예측 모델
- 200개 기사의 감성과 언급 빈도 분석
- **최종 예측 결과 제공 (더 이상 업데이트 안 됨)**

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
export OPENAI_API_KEY="your_openai_api_key"
```

### 4. Flutter 웹 빌드

```bash
cd flutter_ui
flutter build web
cd ..
```

### 5. 서버 실행 (최종 수집 모드)

```bash
python start.py
```

**⚠️ 주의**: 서버 시작 시 자동으로 200개 기사를 수집·분석합니다. 완료까지 약 5-10분 소요될 수 있습니다.

## 🔧 API 엔드포인트

### 데이터 조회

- `GET /api/trend-summary`: 최종 트렌드 요약 데이터
- `GET /api/prediction`: 최종 지지율 예측 결과
- `GET /api/status`: 시스템 상태 확인

### 데이터 관리 (제한적)

- `POST /api/update-cache`: 캐시 업데이트
- ~~`POST /api/force-today-collection`: 강제 뉴스 수집~~ (최종 수집 완료 후 비활성화)
- ~~`POST /api/refresh`: 데이터 새로고침~~ (최종 수집 완료 후 비활성화)

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

## 🔄 최종 수집 시스템

### 뉴스 수집 파이프라인 (최종 버전)

1. **서버 시작**: 자동으로 뉴스 수집 시작
2. **대량 수집**: 16개 키워드로 200개 기사 수집
3. **개선된 감성 분석**: OpenAI GPT + 룰 베이스 하이브리드 분석
4. **최종 저장**: JSON 형태로 영구 저장
5. **수집 완료**: 더 이상 자동 수집하지 않음

### 감성 분석 개선사항

- 중립 판정 최소화
- 정치 뉴스 특성 반영
- 후보자 언급 기사의 명확한 긍정/부정 분류
- OpenAI 장애 시 룰 베이스 대안 분석

## 🎨 UI/UX 특징

### 최종 버전 UI

- **실시간 수집 상태 표시**
- **200개 기사 분석 결과 시각화**
- **최종 예측 결과 강조**
- **수집 완료 안내**

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

### 최종 수집 로깅

- 수집 진행률 실시간 표시
- 감성 분석 결과 통계
- 최종 완료 상태 확인
- 오류 추적 및 복구

### 상태 모니터링

- 최종 수집 완료 여부
- 분석된 기사 수 확인
- 감성별 분포 통계

## ⚠️ 중요 안내

- **한 번만 실행**: 서버 시작 시 200개 기사를 수집한 후 더 이상 자동 수집하지 않습니다.
- **최종 예측**: 제공된 예측 결과가 최종 결과입니다.
- **스케줄러 비활성화**: 오전 6시 자동 수집 등의 스케줄링 기능이 비활성화되었습니다.

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
- GNews: 뉴스 데이터 제공
- Flutter Team: 크로스 플랫폼 프레임워크
- Render.com: 클라우드 호스팅 서비스

---

**참고**: 이 시뮬레이터의 예측 결과는 참고용이며, 실제 선거 결과와 다를 수 있습니다.

**최종 버전**: 선거 직전 한 번의 완전한 분석을 통한 최종 예측 제공
