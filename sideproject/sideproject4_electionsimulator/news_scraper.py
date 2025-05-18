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
import backoff  # 백오프 재시도 라이브러리 추가

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
        self.cache_dir = Path("cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    def _get_cache_path(self, article_id: str, analysis_type: str) -> Path:
        """캐시 파일 경로 생성"""
        return self.cache_dir / f"{article_id}_{analysis_type}.json"
    
    def _load_from_cache(self, article_id: str, analysis_type: str) -> Optional[str]:
        """캐시에서 분석 결과 로드"""
        cache_path = self._get_cache_path(article_id, analysis_type)
        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    # 캐시가 24시간 이내인지 확인
                    if datetime.datetime.now().timestamp() - data.get("timestamp", 0) < 86400:
                        return data.get("result")
            except Exception as e:
                logger.error(f"캐시 로드 실패: {str(e)}")
        return None
    
    def _save_to_cache(self, article_id: str, analysis_type: str, result: str):
        """분석 결과를 캐시에 저장"""
        cache_path = self._get_cache_path(article_id, analysis_type)
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump({
                    "result": result,
                    "timestamp": datetime.datetime.now().timestamp()
                }, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"캐시 저장 실패: {str(e)}")

    @backoff.on_exception(
        backoff.expo,
        (openai.RateLimitError, openai.APIError, openai.AuthenticationError),
        max_tries=3,
        max_time=30
    )
    def summarize_news(self, article_id: str, title: str, description: str) -> str:
        """기사 요약 (캐시 사용)"""
        # 캐시 확인
        cached_result = self._load_from_cache(article_id, "summary")
        if cached_result:
            return cached_result

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
            result = response.choices[0].message.content.strip()
            # 결과 캐시에 저장
            self._save_to_cache(article_id, "summary", result)
            return result
        except Exception as e:
            logger.error(f"기사 요약 실패: {str(e)}")
            return ""

    @backoff.on_exception(
        backoff.expo,
        (openai.RateLimitError, openai.APIError, openai.AuthenticationError),
        max_tries=3,
        max_time=30
    )
    def analyze_sentiment(self, article_id: str, title: str, description: str) -> str:
        """감성 분석 (캐시 사용)"""
        # 캐시 확인
        cached_result = self._load_from_cache(article_id, "sentiment")
        if cached_result:
            return cached_result

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
            result = result.replace('-', '').replace(':', '').strip()
            # 결과 캐시에 저장
            self._save_to_cache(article_id, "sentiment", result)
            return result
        except Exception as e:
            logger.error(f"감성 분석 실패: {str(e)}")
            return "중립"

    def _summarize_news_batch(self, news_batch: List[Dict[str, Any]], batch_num: int, total_batches: int) -> str:
        """뉴스 배치 요약 (Map 단계)"""
        system_msg = "당신은 대선 뉴스를 분석하는 정치 전략가입니다. 주어진 뉴스들을 상세하게 분석해주세요."
        
        news_list_str = "\n\n".join([
            f"{i+1}. 제목: {news['title']}\n요약: {news['summary']}\n감성: {news['sentiment']}"
            for i, news in enumerate(news_batch)
        ])

        user_msg = f"""아래는 전체 {total_batches}개 배치 중 {batch_num}번째 배치의 뉴스입니다:\n\n{news_list_str}\n\n이 뉴스들을 상세하게 분석해주세요. 다음 항목들을 포함해주세요:\n1. 주요 이슈와 키워드\n2. 후보자별 언급 빈도와 이미지\n3. 긍정/부정/중립 기사의 비율\n4. 특이사항이나 주목할 만한 트렌드"""

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
            logger.error(f"배치 {batch_num} 요약 실패: {str(e)}")
            return f"배치 {batch_num} 분석 실패"

    def _create_final_summary(self, batch_summaries: List[str], time_range: str) -> str:
        """최종 요약 생성 (Reduce 단계)"""
        system_msg = "당신은 대선 뉴스를 종합 분석하는 정치 전략가입니다. 여러 배치의 분석 결과를 종합하여 최종 트렌드를 도출해주세요."
        
        summaries_str = "\n\n=== 배치별 분석 ===\n\n" + "\n\n".join([
            f"[배치 {i+1} 분석]\n{summary}"
            for i, summary in enumerate(batch_summaries)
        ])

        user_msg = f"""아래는 {time_range} 동안 수집된 뉴스를 여러 배치로 나누어 분석한 결과입니다:\n\n{summaries_str}\n\n이 분석 결과들을 종합하여 다음 항목들을 포함한 최종 트렌드 분석을 제공해주세요:\n1. 전체적인 여론 동향\n2. 후보자별 이미지와 지지율 변화 추이\n3. 주요 이슈와 키워드의 변화\n4. 향후 전망"""

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
            logger.error(f"최종 요약 생성 실패: {str(e)}")
            return "최종 트렌드 분석을 수행할 수 없습니다."

    def analyze_trends(self, news_data: List[Dict[str, Any]], time_range: str) -> Dict[str, Any]:
        """트렌드 분석 (Map-Reduce 방식)"""
        # 후보별 감성 통계 계산
        candidate_stats = defaultdict(lambda: {"긍정": 0, "부정": 0, "중립": 0})
        for news in news_data:
            for candidate in self.candidate_list:
                if candidate in news['title'] or candidate in news['summary']:
                    sentiment = news['sentiment']
                    candidate_stats[candidate][sentiment] += 1

        # 뉴스 데이터를 50개씩 배치로 나누기
        batch_size = 50
        batches = [news_data[i:i + batch_size] for i in range(0, len(news_data), batch_size)]
        total_batches = len(batches)
        
        logger.info(f"📊 {total_batches}개 배치로 나누어 분석 시작...")
        
        # Map 단계: 각 배치별 요약
        batch_summaries = []
        for i, batch in enumerate(batches, 1):
            logger.info(f"🔄 배치 {i}/{total_batches} 분석 중...")
            summary = self._summarize_news_batch(batch, i, total_batches)
            batch_summaries.append(summary)
        
        # Reduce 단계: 최종 요약 생성
        logger.info("🔄 최종 요약 생성 중...")
        final_summary = self._create_final_summary(batch_summaries, time_range)
        
        return {
            "trend_summary": final_summary,
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
            summary = self.analyzer.summarize_news(article.unique_id, article.title, article.description)
            sentiment = self.analyzer.analyze_sentiment(article.unique_id, article.title, article.description)
            
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
        """1시간마다 실행되는 뉴스 수집"""
        logger.info("⏳ 뉴스 수집 시작...")
        
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
schedule.every(1).hours.do(run_news_pipeline)  # 1시간마다 뉴스 수집
schedule.every().day.at("06:00").do(lambda: pipeline.analyzer.analyze_trends(pipeline.temp_storage, "전일"))  # 매일 오전 6시에 트렌드 분석

if __name__ == "__main__":
    logger.info("🕒 자동 실행 시작. 종료하려면 Ctrl+C")
    while True:
        schedule.run_pending()
        time.sleep(1)
