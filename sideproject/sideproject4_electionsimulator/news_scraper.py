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
import shutil   # 파일 복사를 위한 모듈 추가

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

# 뉴스 중요도 정렬 전역 함수 - 클래스 밖으로 이동
def rank_news_by_importance(news_data: List[Dict[str, Any]], limit: int = 30) -> List[Dict[str, Any]]:
    """뉴스를 중요도순으로 정렬하고 상위 N개만 반환"""
    if not news_data:
        return []
        
    # 후보자 및 키워드 정의
    candidates = ["이재명", "김문수", "이준석"]
    important_keywords = ["대선", "TV토론", "공약", "여론조사", "정책", "지지율", "선거", "당선", "투표"]
    
    # 중요도 점수 계산
    for news in news_data:
        importance_score = 0
        
        # 후보자 언급 점수
        for candidate in candidates:
            if candidate in news['title']:
                importance_score += 15  # 제목에 후보자가 있으면 높은 점수
            elif candidate in news['summary']:
                importance_score += 8   # 요약에 후보자가 있으면 중간 점수
                
        # 감성 강도 점수 (중립보다 긍정/부정이 더 중요할 수 있음)
        if news['sentiment'] == "긍정":
            importance_score += 10
        elif news['sentiment'] == "부정":
            importance_score += 12  # 부정 뉴스가 보통 더 주목받음
            
        # 주요 키워드 점수
        for keyword in important_keywords:
            if keyword in news['title']:
                importance_score += 8
            elif keyword in news['summary']:
                importance_score += 4
        
        # 제목 길이 보너스 (보통 중요한 기사는 제목이 길다)
        title_length = len(news['title'])
        if title_length > 30:
            importance_score += 5
        
        # 최신 기사 보너스
        try:
            if '2025' in news['published_date']:  # 최신 연도 기사
                importance_score += 10
        except:
            pass
            
        news['importance_score'] = importance_score
    
    # 중요도 순으로 정렬하고 상위 N개만 반환
    sorted_news = sorted(news_data, key=lambda x: x.get('importance_score', 0), reverse=True)
    logger.info(f"✅ 뉴스 {len(news_data)}개 중 중요도순으로 상위 {limit}개 선별 완료")
    return sorted_news[:limit]

class NewsAnalyzer:
    """뉴스 분석기 클래스"""
    def __init__(self):
        self.candidate_list = ["이재명", "김문수", "이준석"]
        self.cache_dir = Path("cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        # API 사용량 모니터링을 위한 카운터 추가
        self.api_calls_count = 0
        self.last_reset_time = datetime.datetime.now()
    
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
                    # 캐시 만료 시간을 24시간에서 7일로 연장
                    if datetime.datetime.now().timestamp() - data.get("timestamp", 0) < 7 * 86400:
                        logger.info(f"캐시에서 {analysis_type} 결과 로드: {article_id}")
                        return data.get("result")
                    else:
                        logger.info(f"캐시 만료됨: {article_id}_{analysis_type}")
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
            logger.info(f"캐시에 저장 완료: {article_id}_{analysis_type}")
        except Exception as e:
            logger.error(f"캐시 저장 실패: {str(e)}")

    def _track_api_usage(self):
        """API 사용량 추적"""
        self.api_calls_count += 1
        
        # 일일 사용량 리셋 (매일 자정)
        now = datetime.datetime.now()
        if now.date() > self.last_reset_time.date():
            logger.info(f"일일 API 사용량 리셋: 이전 카운트 {self.api_calls_count}")
            self.api_calls_count = 1
            self.last_reset_time = now
            
        # 사용량 로깅
        if self.api_calls_count % 10 == 0:
            logger.warning(f"주의: OpenAI API 호출 횟수가 {self.api_calls_count}회 도달했습니다")

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

        # 내용이 너무 짧은 경우 API 호출 방지
        if len(description) < 50:
            simple_summary = f"{title}에 대한 간략한 내용."
            self._save_to_cache(article_id, "summary", simple_summary)
            return simple_summary

        system_msg = "당신은 똑똑한 뉴스 요약가입니다. 한국 정치뉴스를 간결하게 요약해줍니다."
        user_msg = f"""[뉴스 제목]: {title}\n[내용 요약 대상]: {description}\n\n이 기사를 3줄 이내로 요약해줘."""

        try:
            # API 사용량 추적
            self._track_api_usage()
            
            logger.info(f"OpenAI API 호출: summarize_news - {article_id}")
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
            return f"{title}의 요약 정보를 가져올 수 없습니다."

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

        # 내용이 너무 짧은 경우 API 호출 방지
        if len(description) < 50:
            default_sentiment = "중립"
            self._save_to_cache(article_id, "sentiment", default_sentiment)
            return default_sentiment

        system_msg = "당신은 뉴스 기사의 감성 분석가입니다."
        user_msg = f"""[뉴스 제목]: {title}\n[뉴스 설명]: {description}\n\n이 뉴스는 긍정적인가요, 부정적인가요, 중립적인가요? 아래 중 하나로만 대답하세요.\n- 긍정\n- 부정\n- 중립"""

        try:
            # API 사용량 추적
            self._track_api_usage()
            
            logger.info(f"OpenAI API 호출: analyze_sentiment - {article_id}")
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
        # 배치가 비어있으면 처리하지 않음
        if not news_batch:
            return "배치에 뉴스가 없습니다."
            
        # 캐시 키 생성
        batch_key = hashlib.md5(
            json.dumps(
                [(n['title'], n['url']) for n in news_batch], 
                sort_keys=True
            ).encode()
        ).hexdigest()
        
        # 캐시 확인
        cached_result = self._load_from_cache(batch_key, "batch_summary")
        if cached_result:
            return cached_result
        
        system_msg = "당신은 대선 뉴스를 분석하는 정치 전략가입니다. 주어진 뉴스들을 상세하게 분석해주세요."
        
        news_list_str = "\n\n".join([
            f"{i+1}. 제목: {news['title']}\n요약: {news['summary']}\n감성: {news['sentiment']}"
            for i, news in enumerate(news_batch)
        ])

        user_msg = f"""아래는 전체 {total_batches}개 배치 중 {batch_num}번째 배치의 뉴스입니다:\n\n{news_list_str}\n\n이 뉴스들을 상세하게 분석해주세요. 다음 항목들을 포함해주세요:\n1. 주요 이슈와 키워드\n2. 후보자별 언급 빈도와 이미지\n3. 긍정/부정/중립 기사의 비율\n4. 특이사항이나 주목할 만한 트렌드"""

        try:
            # API 사용량 추적
            self._track_api_usage()
            
            logger.info(f"OpenAI API 호출: batch_summary - 배치 {batch_num}/{total_batches}")
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
            self._save_to_cache(batch_key, "batch_summary", result)
            return result
        except Exception as e:
            logger.error(f"배치 {batch_num} 요약 실패: {str(e)}")
            return f"배치 {batch_num} 분석 실패"

    def _create_final_summary(self, batch_summaries: List[str], time_range: str) -> str:
        """최종 요약 생성 (Reduce 단계)"""
        # 배치 요약이 비어있으면 처리하지 않음
        if not batch_summaries:
            return "분석할 데이터가 충분하지 않습니다."
            
        # 캐시 키 생성
        summary_key = hashlib.md5(
            json.dumps(
                [s[:100] for s in batch_summaries], 
                sort_keys=True
            ).encode()
        ).hexdigest()
        
        # 캐시 확인
        cached_result = self._load_from_cache(summary_key, "final_summary")
        if cached_result:
            return cached_result
            
        system_msg = "당신은 대선 뉴스를 종합 분석하는 정치 전략가입니다. 여러 배치의 분석 결과를 종합하여 최종 트렌드를 도출해주세요."
        
        summaries_str = "\n\n=== 배치별 분석 ===\n\n" + "\n\n".join([
            f"[배치 {i+1} 분석]\n{summary}"
            for i, summary in enumerate(batch_summaries)
        ])

        user_msg = f"""아래는 {time_range} 동안 수집된 뉴스를 여러 배치로 나누어 분석한 결과입니다:\n\n{summaries_str}\n\n이 분석 결과들을 종합하여 다음 항목들을 포함한 최종 트렌드 분석을 제공해주세요:\n1. 전체적인 여론 동향\n2. 후보자별 이미지와 지지율 변화 추이\n3. 주요 이슈와 키워드의 변화\n4. 향후 전망"""

        try:
            # API 사용량 추적
            self._track_api_usage()
            
            logger.info(f"OpenAI API 호출: final_summary - {time_range}")
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
            self._save_to_cache(summary_key, "final_summary", result)
            return result
        except Exception as e:
            logger.error(f"최종 요약 생성 실패: {str(e)}")
            return "최종 트렌드 분석을 수행할 수 없습니다."

    def analyze_trends(self, news_data: List[Dict[str, Any]], time_range: str) -> Dict[str, Any]:
        """트렌드 분석 (Map-Reduce 방식)"""
        # 뉴스 데이터가 없으면 분석하지 않음
        if not news_data:
            logger.warning("분석할 뉴스 데이터가 없습니다.")
            return {
                "trend_summary": "현재 분석할 뉴스 데이터가 충분하지 않습니다.",
                "candidate_stats": {candidate: {"긍정": 0, "부정": 0, "중립": 0} for candidate in self.candidate_list},
                "total_articles": 0,
                "time_range": time_range
            }
            
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
        
        # 분석할 데이터가 너무 적으면 배치 처리 생략
        if len(news_data) < 10:
            logger.info(f"뉴스 데이터가 너무 적어 간단한 분석만 수행: {len(news_data)}개")
            return {
                "trend_summary": "현재 분석할 뉴스 데이터가 충분하지 않습니다. 더 많은 데이터가 수집되면 상세한 분석이 제공됩니다.",
                "candidate_stats": dict(candidate_stats),
                "total_articles": len(news_data),
                "time_range": time_range,
                "news_list": news_data[:20]  # 최대 20개만 포함
            }
        
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
        
        # 전역 함수로 뉴스 중요도 순으로 정렬
        important_news = rank_news_by_importance(news_data, limit=30)
        
        return {
            "trend_summary": final_summary,
            "candidate_stats": dict(candidate_stats),
            "total_articles": len(news_data),
            "time_range": time_range,
            "news_list": important_news  # 중요도순으로 정렬된 뉴스 목록
        }

class NewsPipeline:
    """뉴스 파이프라인 관리 클래스"""
    def __init__(self):
        self.collector = NewsCollector()
        self.analyzer = NewsAnalyzer()
        
        # 경로 설정 - Render.com 호환성 추가
        self.assets_path = Path("assets")
        self.assets_path.mkdir(parents=True, exist_ok=True)
        
        # Render.com 영구 저장 디렉토리 설정
        # Render.com은 /opt/render/project/src/ 경로가 영구적으로 유지됨
        self.render_persistent_dir = None
        if os.environ.get('RENDER') == 'true':  # Render.com 환경 감지
            self.render_persistent_dir = Path("/opt/render/project/src/persistent_data")
            self.render_persistent_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"📂 Render.com 영구 저장소 경로 설정: {self.render_persistent_dir}")
            
            # 이미 저장된 데이터가 있다면 assets로 복사
            if self.render_persistent_dir.exists():
                for json_file in self.render_persistent_dir.glob("trend_summary_*.json"):
                    dest_file = self.assets_path / json_file.name
                    if not dest_file.exists():
                        shutil.copy(json_file, dest_file)
                        logger.info(f"📋 영구 저장소에서 복원된 파일: {json_file.name}")
        
        self.temp_storage: List[Dict[str, Any]] = []
        self.last_trend_summary_time = None
        self.last_run_date = None
    
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
        
        # 로컬 assets 디렉토리에 저장
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(trend_data, f, ensure_ascii=False, indent=2)
        logger.info(f"✅ 트렌드 요약 저장 완료: {filename}")
        
        # Render.com 환경이라면 영구 저장소에도 저장
        if self.render_persistent_dir:
            persistent_file = self.render_persistent_dir / f"trend_summary_{timestamp}.json"
            try:
                with open(persistent_file, "w", encoding="utf-8") as f:
                    json.dump(trend_data, f, ensure_ascii=False, indent=2)
                logger.info(f"✅ 영구 저장소에 트렌드 요약 저장 완료: {persistent_file}")
                
                # 최신 파일을 가리키는 링크 파일 생성 (latest.json)
                latest_link = self.render_persistent_dir / "trend_summary_latest.json"
                with open(latest_link, "w", encoding="utf-8") as f:
                    json.dump(trend_data, f, ensure_ascii=False, indent=2)
                logger.info(f"✅ 최신 트렌드 요약 링크 생성 완료: {latest_link}")
            except Exception as e:
                logger.error(f"❌ 영구 저장소 저장 실패: {str(e)}")
    
    def run_daily_collection(self):
        """매일 실행되는 뉴스 수집 (오전 6시)"""
        # 오늘 이미 실행되었는지 확인
        today = datetime.datetime.now().date()
        if self.last_run_date == today:
            logger.info(f"⏭️ 오늘({today})은 이미 뉴스 수집을 실행했습니다. 건너뜁니다.")
            return
            
        logger.info("⏳ 뉴스 수집 시작...")
        
        # 뉴스 수집
        articles = self.collector.collect_all_news()
        logger.info(f"📰 {len(articles)}개의 뉴스 기사 수집 완료")
        
        # 기사 처리
        processed_news = self.process_articles(articles)
        self.temp_storage.extend(processed_news)
        
        # 트렌드 분석
        current_time = datetime.datetime.now()
        time_range = f"{current_time.strftime('%Y-%m-%d')} 업데이트"
        trend_data = self.analyzer.analyze_trends(self.temp_storage, time_range)
        
        # 트렌드 요약 저장
        self.save_trend_summary(trend_data)
        
        # 임시 저장소 초기화 및 시간 업데이트
        self.temp_storage = []
        self.last_trend_summary_time = current_time
        self.last_run_date = today
        
        logger.info(f"✅ 오늘의 뉴스 수집 및 분석 완료: {today}")

# 전역 파이프라인 인스턴스 생성
pipeline = NewsPipeline()

def run_news_pipeline():
    """스케줄러에서 호출될 함수"""
    pipeline.run_daily_collection()

# 직접 실행 시 (api_server.py에서 스케줄러 설정함)
if __name__ == "__main__":
    logger.info("🛑 주의: 이 스크립트는 직접 실행하지 말고 api_server.py를 통해 실행하세요.")
    logger.info("🕒 테스트 목적으로 한 번의 뉴스 수집을 실행합니다.")
    run_news_pipeline()
