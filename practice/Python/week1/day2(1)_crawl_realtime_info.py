import requests
from bs4 import BeautifulSoup
import pyttsx3

# 1. 페이지 요청
url = "https://news.ycombinator.com/"
response = requests.get(url)
soup = BeautifulSoup(response.text, "html.parser")

# 2. 뉴스 링크들 추출
title_links = soup.select("span.titleline > a")

# 3. 키워드 정의
keywords = ["Python", "AI", "ChatGPT"]  # 이 키워드를 포함하는 뉴스만 골라낼 거야

# 4. 텍스트 파일에 저장 (필터링된 뉴스만)
with open("filtered_headlines.txt", "w", encoding="utf-8") as f:
    for idx, link in enumerate(title_links, 1):
        title = link.text.strip()
        
        # 5. 키워드를 포함한 뉴스만 필터링
        if any(keyword.lower() in title.lower() for keyword in keywords):
            line = f"{idx}. {title}\n"
            f.write(line)

# 6. 파일 읽어서 출력 (필터링된 뉴스만)
with open("filtered_headlines.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

# 7. 음성 합성 엔진 초기화
engine = pyttsx3.init()

# 8. 음성 속도 조절 (선택 사항)
engine.setProperty('rate', 150)  # 음성 속도 조절

# 9. 음성으로 뉴스 제목 읽기
for line in lines:
    print("📰", line.strip())  # 콘솔에 출력
    engine.say(line.strip())  # 음성으로 읽어줌

# 10. 음성 읽기 완료되도록 기다리기
engine.runAndWait()
