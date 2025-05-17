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
from typing import List, Dict, Any, Optional
import hashlib
from dataclasses import dataclass
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# .env 파일에서 환경 변수 로드
load_dotenv()

# API 키를 환경 변수에서 가져오기
openai.api_key = os.getenv('OPENAI_API_KEY')

# API 키가 없을 경우 에러 발생
if not openai.api_key:
    raise ValueError("OPENAI_API_KEY 환경 변수가 설정되지 않았습니다. .env 파일을 확인해주세요.")

@dataclass
class NewsArticle:
    """뉴스 기사 데이터 클래스"""
    title: str
    description: str
    url: str
    published_date: str
    source: str
    query: str  # 어떤 검색어로 찾았는지 기록
    
    @property
    def unique_id(self) -> str:
        """기사 고유 ID 생성 (URL 기반)"""
        return hashlib.md5(self.url.encode()).hexdigest()

class NewsCollector:
    """뉴스 수집기 클래스"""
    def __init__(self, period: str = "12h", max_results: int = 20):
        self.gnews = GNews(language="ko", country="KR", period=period, max_results=max_results)
        self.search_queries = [
            "대선", "이재명", "김문수", "이준석", 
            "TV토론", "공약", "여론조사", "후보", 
            "정책", "선거"
        ]
        self.collected_articles: Dict[str, NewsArticle] = {}
    
    def fetch_news(self, query: str) -> List[Dict[str, Any]]:
        """단일 쿼리로 뉴스 수집"""
        try:
            return self.gnews.get_news(query)
        except Exception as e:
            logger.error(f"뉴스 수집 실패 (쿼리: {query}): {str(e)}")
            return []
    
    def collect_all_news(self) -> List[NewsArticle]:
        """모든 쿼리로 뉴스 수집 및 중복 제거"""
        for query in self.search_queries:
            articles = self.fetch_news(query)
            for article in articles:
                news = NewsArticle(
                    title=article['title'],
                    description=article['description'],
                    url=article['url'],
                    published_date=article.get('published date', ''),
                    source=article.get('publisher', {}).get('title', ''),
                    query=query
                )
                self.collected_articles[news.unique_id] = news
        
        return list(self.collected_articles.values())

class NewsAnalyzer:
    """뉴스 분석기 클래스"""
    def __init__(self):
        self.candidate_list = ["이재명", "김문수", "이준석"]
    
    def summarize_news(self, title: str, description: str) -> str:
        """기사 요약"""
        system_msg = "당신은 똑똑한 뉴스 요약가입니다. 한국 정치뉴스를 간결하게 요약해줍니다."
        user_msg = f"""[뉴스 제목]: {title}\n[내용 요약 대상]: {description}\n\n이 기사를 3줄 이내로 요약해줘."""

        try:
            response = openai.chat.completions.create(
                model="gpt-4-turbo",
                messages=[
                    {"role": "system", "content": system_msg},
                    {"role": "user", "content": user_msg}
                ],
                temperature=0.5
            )
            return response.choices[0].message.content.strip()
        except Exception as e:
            logger.error(f"기사 요약 실패: {str(e)}")
            return ""

    def analyze_sentiment(self, title: str, description: str) -> str:
        """감성 분석"""
        system_msg = "당신은 뉴스 기사의 감성 분석가입니다."
        user_msg = f"""[뉴스 제목]: {title}\n[뉴스 설명]: {description}\n\n이 뉴스는 긍정적인가요, 부정적인가요, 중립적인가요? 아래 중 하나로만 대답하세요.\n- 긍정\n- 부정\n- 중립"""

        try:
            response = openai.chat.completions.create(
                model="gpt-4-turbo",
                messages=[
                    {"role": "system", "content": system_msg},
                    {"role": "user", "content": user_msg}
                ],
                temperature=0.3
            )
            result = response.choices[0].message.content.strip()
            return result.replace('-', '').replace(':', '').strip()
        except Exception as e:
            logger.error(f"감성 분석 실패: {str(e)}")
            return "중립"

    def analyze_trends(self, news_data: List[Dict[str, Any]], time_range: str) -> Dict[str, Any]:
        """트렌드 분석"""
        system_msg = "당신은 대선 뉴스를 분석하는 정치 전략가입니다."
        
        # 후보별 감성 통계 계산
        candidate_stats = defaultdict(lambda: {"긍정": 0, "부정": 0, "중립": 0})
        for news in news_data:
            for candidate in self.candidate_list:
                if candidate in news['title'] or candidate in news['summary']:
                    sentiment = news['sentiment']
                    candidate_stats[candidate][sentiment] += 1

        # 트렌드 요약 생성
        news_list_str = "\n\n".join([
            f"{i+1}. 제목: {news['title']}\n요약: {news['summary']}\n감성: {news['sentiment']}"
            for i, news in enumerate(news_data)
        ])

        user_msg = f"""아래는 {time_range} 동안 수집된 대선 관련 뉴스 요약과 감성 분석 결과입니다:\n\n{news_list_str}\n\n이 뉴스들을 종합해볼 때, 최근 여론 흐름을 분석해줘. 후보자별 이미지, 주요 이슈, 감성 트렌드 등을 알려줘."""

        try:
            response = openai.chat.completions.create(
                model="gpt-4-turbo",
                messages=[
                    {"role": "system", "content": system_msg},
                    {"role": "user", "content": user_msg}
                ],
                temperature=0.5
            )
            trend_summary = response.choices[0].message.content.strip()
        except Exception as e:
            logger.error(f"트렌드 분석 실패: {str(e)}")
            trend_summary = "트렌드 분석을 수행할 수 없습니다."

        return {
            "trend_summary": trend_summary,
            "candidate_stats": dict(candidate_stats),
            "total_articles": len(news_data),
            "time_range": time_range
        }

class NewsPipeline:
    """뉴스 파이프라인 관리 클래스"""
    def __init__(self):
        self.collector = NewsCollector()
        self.analyzer = NewsAnalyzer()
        self.assets_path = Path("assets")
        self.assets_path.mkdir(parents=True, exist_ok=True)
        self.temp_storage: List[Dict[str, Any]] = []
        self.last_trend_summary_time = None
    
    def process_articles(self, articles: List[NewsArticle]) -> List[Dict[str, Any]]:
        """기사 처리 (요약 및 감성 분석)"""
        processed_news = []
        for article in articles:
            summary = self.analyzer.summarize_news(article.title, article.description)
            sentiment = self.analyzer.analyze_sentiment(article.title, article.description)
            
            processed_news.append({
                "title": article.title,
                "description": article.description,
                "summary": summary,
                "sentiment": sentiment,
                "url": article.url,
                "published_date": article.published_date,
                "source": article.source,
                "query": article.query
            })
        return processed_news
    
    def save_trend_summary(self, trend_data: Dict[str, Any]):
        """트렌드 요약 저장"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M")
        filename = self.assets_path / f"trend_summary_{timestamp}.json"
        
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(trend_data, f, ensure_ascii=False, indent=2)
        logger.info(f"✅ 트렌드 요약 저장 완료: {filename}")
    
    def run_hourly_collection(self):
        """1시간마다 실행되는 뉴스 수집 및 처리"""
        logger.info("⏳ 뉴스 수집 및 분석 시작...")
        
        # 뉴스 수집
        articles = self.collector.collect_all_news()
        logger.info(f"📰 {len(articles)}개의 뉴스 기사 수집 완료")
        
        # 기사 처리
        processed_news = self.process_articles(articles)
        self.temp_storage.extend(processed_news)
        
        # 현재 시간이 마지막 트렌드 요약으로부터 3시간이 지났는지 확인
        current_time = datetime.datetime.now()
        if (self.last_trend_summary_time is None or 
            (current_time - self.last_trend_summary_time).total_seconds() >= 3 * 3600):
            
            # 트렌드 분석
            time_range = f"{self.last_trend_summary_time.strftime('%H:%M') if self.last_trend_summary_time else '시작'} ~ {current_time.strftime('%H:%M')}"
            trend_data = self.analyzer.analyze_trends(self.temp_storage, time_range)
            
            # 트렌드 요약 저장
            self.save_trend_summary(trend_data)
            
            # 임시 저장소 초기화 및 시간 업데이트
            self.temp_storage = []
            self.last_trend_summary_time = current_time

# 전역 파이프라인 인스턴스 생성
pipeline = NewsPipeline()

def run_news_pipeline():
    """스케줄러에서 호출될 함수"""
    pipeline.run_hourly_collection()

# 스케줄러 설정
#schedule.every(1).hours.do(run_news_pipeline)
schedule.every().day.at("11:41").do(run_news_pipeline)

if __name__ == "__main__":
    logger.info("🕒 자동 실행 시작. 종료하려면 Ctrl+C")
    while True:
        schedule.run_pending()
        time.sleep(1)
