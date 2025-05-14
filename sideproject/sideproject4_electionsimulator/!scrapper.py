from gnews import GNews
import openai
import datetime
import json
import schedule
import time
from collections import defaultdict
from pathlib import Path
import os
from dotenv import load_dotenv

# .env 파일에서 환경 변수 로드
load_dotenv()

# API 키를 환경 변수에서 가져오기
openai.api_key = os.getenv('OPENAI_API_KEY')

# API 키가 없을 경우 에러 발생
if not openai.api_key:
    raise ValueError("OPENAI_API_KEY 환경 변수가 설정되지 않았습니다. .env 파일을 확인해주세요.")

def summarize_news(title, description):
    system_msg = "당신은 똑똑한 뉴스 요약가입니다. 한국 정치뉴스를 간결하게 요약해줍니다."
    user_msg = f"""[뉴스 제목]: {title}\n[내용 요약 대상]: {description}\n\n이 기사를 3줄 이내로 요약해줘."""

    response = openai.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_msg}
        ],
        temperature=0.5
    )
    summary = response.choices[0].message.content
    return summary.strip() if summary else ""

def analyze_sentiment(title, description):
    system_msg = "당신은 뉴스 기사의 감성 분석가입니다."
    user_msg = f"""[뉴스 제목]: {title}\n[뉴스 설명]: {description}\n\n이 뉴스는 긍정적인가요, 부정적인가요, 중립적인가요? 아래 중 하나로만 대답하세요.\n- 긍정\n- 부정\n- 중립"""

    response = openai.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_msg}
        ],
        temperature=0.3
    )
    result = response.choices[0].message.content.strip() if response.choices and response.choices[0].message.content else "None"
    # 하이픈, 콜론, 공백 등 앞뒤 불필요한 문자 제거
    result = result.replace('-', '').replace(':', '').strip()
    return result

def summarize_news_trend(news_data):
    system_msg = "당신은 대선 뉴스를 분석하는 정치 전략가입니다."

    news_list_str = ""
    for i, news in enumerate(news_data, 1):
        news_list_str += f"{i}. 제목: {news['title']}\n요약: {news['summary']}\n감성: {news['sentiment']}\n\n"

    user_msg = f"""아래는 최근 대선 관련 뉴스 요약과 감성 분석 결과입니다:\n\n{news_list_str}\n\n이 뉴스들을 종합해볼 때, 최근 여론 흐름을 분석해줘. 후보자별 이미지, 주요 이슈, 감성 트렌드 등을 알려줘."""

    response = openai.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_msg}
        ],
        temperature=0.5
    )

    return response.choices[0].message.content.strip() if response.choices and response.choices[0].message.content else "None"

def extract_candidate_names(text, known_candidates):
    return [name for name in known_candidates if name in text]

def run_news_pipeline():
    print("⏳ 뉴스 수집 및 분석 시작...")

    gnews = GNews(language="ko",country="KR",max_results=20,period="1d")
    news_items = gnews.get_news("대선")
    news_data=[]

    # 후보 리스트 (수동 정의)
    candidate_list = ["이재명", "김문수", "이준석"]
    candidate_sentiment_stats = defaultdict(lambda: {"긍정": 0, "부정": 0, "중립": 0})

    if news_items:
        for item in news_items:
            title = item['title']
            desc = item["description"]
            url = item["url"]

            summary = summarize_news(title, desc)
            sentiment = analyze_sentiment(title, desc)
            sentiment = sentiment.replace('-', '').replace(':', '').strip()

            news_data.append({
                "title": title,
                "description": desc,
                "summary": summary,
                "sentiment": sentiment,
                "url": url
            })

            # 후보별 감성 통계 누적
            mentioned_candidates = extract_candidate_names(title + summary, candidate_list)
            for candidate in mentioned_candidates:
                if sentiment in candidate_sentiment_stats[candidate]:
                    candidate_sentiment_stats[candidate][sentiment] += 1

        trend_summary = summarize_news_trend(news_data)

        today = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M")
        assets_path = Path("assets")
        assets_path.mkdir(parents=True, exist_ok=True)
        filename = assets_path / f"news_summary_{today}.json"

        with open(filename, "w", encoding="utf-8") as f:
            json.dump({
                "date": today,
                "news": news_data,
                "trend_summary": trend_summary,
                "candidate_stats": candidate_sentiment_stats
            }, f, ensure_ascii=False, indent=2)

        print(f"✅ 분석 완료. '{filename}' 파일에 저장됨.")
    else:
        print("❌ 뉴스가 없습니다.")

# 🔁 일정 설정 (예시)
schedule.every().day.at("01:07").do(run_news_pipeline)

print("🕒 자동 실행 시작. 종료하려면 Ctrl+C")
while True:
    schedule.run_pending()
    time.sleep(1)
