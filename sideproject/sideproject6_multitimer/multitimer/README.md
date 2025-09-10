# ShareTime

공유 타이머 앱 - Flutter와 Python FastAPI를 사용한 크로스 플랫폼 타이머 공유 애플리케이션

## 📱 앱 소개

ShareTime은 사용자가 타이머를 생성하고 QR 코드나 6자리 코드를 통해 다른 사람과 공유할 수 있는 앱입니다. 회의, 운동, 요리 등 다양한 상황에서 동기화된 타이머를 사용할 수 있습니다.

## ✨ 주요 기능

- **타이머 생성**: 이름, 설명, 시간을 설정하여 타이머 생성
- **QR 코드 공유**: 생성된 타이머를 QR 코드로 공유
- **코드 공유**: 6자리 알파벳 숫자 조합 코드로 공유
- **실시간 동기화**: 여러 기기에서 동일한 타이머 동기화
- **미니멀 디자인**: 깔끔하고 모던한 UI
- **크로스 플랫폼**: Android와 iOS 지원

## 🛠️ 기술 스택

### Frontend (Flutter)
- **Flutter**: 크로스 플랫폼 UI 프레임워크
- **Provider**: 상태 관리
- **qr_flutter**: QR 코드 생성
- **mobile_scanner**: QR 코드 스캔
- **http**: API 통신

### Backend (Python)
- **FastAPI**: 고성능 웹 프레임워크
- **Redis**: 데이터 저장소 (선택사항)
- **Pydantic**: 데이터 검증
- **Uvicorn**: ASGI 서버

## 🚀 설치 및 실행

### 1. Flutter 앱 실행

```bash
# 의존성 설치
flutter pub get

# 앱 실행
flutter run
```

### 2. Python 백엔드 실행

```bash
# 백엔드 디렉토리로 이동
cd backend

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
python main.py
```

또는 uvicorn 사용:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 📁 프로젝트 구조

```
sharetime/
├── lib/
│   ├── models/
│   │   └── timer_model.dart
│   ├── providers/
│   │   └── timer_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── create_timer_screen.dart
│   │   ├── join_timer_screen.dart
│   │   └── timer_view_screen.dart
│   ├── services/
│   │   └── api_service.dart
│   └── main.dart
├── backend/
│   ├── main.py
│   ├── requirements.txt
│   └── README.md
└── README.md
```

## 🎯 사용 방법

### 타이머 생성
1. 앱을 실행하고 "타이머 생성" 버튼 클릭
2. 타이머 이름, 설명, 시간 설정
3. "타이머 생성 및 공유" 버튼 클릭
4. 생성된 QR 코드나 6자리 코드를 다른 사람과 공유

### 타이머 참여
1. "타이머 참여" 버튼 클릭
2. QR 코드 스캔 또는 6자리 코드 입력
3. 타이머 정보 확인 후 동기화된 타이머 사용

## 🔧 개발 환경 설정

### Flutter 환경
- Flutter SDK 3.7.0 이상
- Dart SDK
- Android Studio / VS Code

### Python 환경
- Python 3.8 이상
- pip
- Redis (선택사항)

## 📝 API 문서

백엔드 서버 실행 후 다음 URL에서 API 문서를 확인할 수 있습니다:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해주세요.
