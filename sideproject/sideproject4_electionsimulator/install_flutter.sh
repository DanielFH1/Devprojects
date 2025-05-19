#!/bin/bash

# Flutter 설치 디렉토리
FLUTTER_HOME="/opt/flutter"

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