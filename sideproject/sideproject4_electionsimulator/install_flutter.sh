#!/bin/bash

# Flutter 설치 디렉토리 (Render.com 환경에 맞게 수정)
FLUTTER_HOME="$HOME/flutter"

# 영구 저장소 디렉토리 생성
PERSISTENT_DIR="/opt/render/project/src/persistent_data"
echo "Creating persistent directory for data storage: $PERSISTENT_DIR"
mkdir -p $PERSISTENT_DIR
chmod 777 $PERSISTENT_DIR
echo "✅ Persistent directory created successfully"

# 환경 변수 설정
export RENDER=true
echo 'export RENDER=true' >> $HOME/.bashrc
echo "✅ Set RENDER environment variable to true"

# Flutter가 이미 설치되어 있는지 확인
if [ ! -d "$FLUTTER_HOME" ]; then
    echo "Installing Flutter..."
    
    # Flutter SDK 다운로드
    git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
    
    # PATH에 Flutter 추가
    export PATH="$FLUTTER_HOME/bin:$PATH"
    
    # Flutter 의존성 설치
    flutter precache
    flutter doctor
    
    echo "Flutter installation completed"
else
    echo "Flutter is already installed"
fi

# PATH에 Flutter 추가 (이미 설치된 경우에도)
export PATH="$FLUTTER_HOME/bin:$PATH"

# PATH를 확인하고 echo 해보기
echo "Current PATH: $PATH"
echo "Flutter binary location: $(which flutter 2>/dev/null || echo 'flutter not found in PATH')"

# Render.com의 .bashrc에 PATH 추가 (영구적으로)
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> $HOME/.bashrc

# Flutter 빌드 파일을 static 디렉토리로 복사
echo "Copying Flutter build files to static directory..."
mkdir -p web/static
if [ -d "flutter_ui/build/web" ]; then
    cp -r flutter_ui/build/web/* web/static/
    echo "✅ Flutter build files copied to web/static/"
else
    echo "❌ Flutter build directory not found. Build might have failed."
fi 