"""
대선 뉴스 수집 및 분석 시스템
- 뉴스 수집 (GNews)
- 감성 분석 (OpenAI GPT)
- 트렌드 분석 및 요약
"""

import os
import json
import time
import hashlib
import logging
from pathlib import Path
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

import openai
import backoff
import requests
from gnews import GNews

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# === 설정 및 상수 ===
ASSETS_DIR = Path("assets")
CACHE_DIR = Path("cache")
ASSETS_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# API 키 설정
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

if not OPENAI_API_KEY:
    logger.error("❌ OPENAI_API_KEY 환경변수가 설정되지 않았습니다.")
    logger.error("   뉴스 분석 기능이 제한됩니다.")
else:
    logger.info("✅ OpenAI API 키 확인됨")

# OpenAI 클라이언트 초기화
openai_client = None
if OPENAI_API_KEY:
    try:
        openai_client = openai.OpenAI(api_key=OPENAI_API_KEY)
        logger.info("✅ OpenAI 클라이언트 초기화 완료")
    except Exception as e:
        logger.error(f"❌ OpenAI 클라이언트 초기화 실패: {e}")
        openai_client = None

# 검색 키워드 설정
SEARCH_QUERIES = [
    "이재명 대선",
    "김문수 대선", 
    "이준석 대선",
    "2025 대선",
    "21대 대선"
]

# === 데이터 클래스 ===
@dataclass
class NewsArticle:
    """뉴스 기사 데이터 클래스"""
    title: str
    description: str
    url: str
    published_date: str
    source: str
    query: str
    
    @property
    def unique_id(self) -> str:
        """기사 고유 ID 생성 (URL 기반)"""
        return hashlib.md5(self.url.encode()).hexdigest()

# === 뉴스 수집 클래스 ===
class NewsCollector:
    """뉴스 수집 담당 클래스 (GNews 사용)"""
    
    def __init__(self, period: str = "12h", max_results: int = 20):
        self.period = period
        self.max_results = max_results
        self.gnews = GNews(
            language='ko',
            country='KR',
            max_results=max_results,
            period=period
        )
        logger.info("✅ GNews 클라이언트 초기화 완료")

    def fetch_news(self, query: str) -> List[Dict[str, Any]]:
        """특정 키워드로 뉴스 검색"""
        try:
            logger.info(f"🔍 뉴스 검색 중: '{query}'")
            
            # GNews로 뉴스 검색
            articles = self.gnews.get_news(query)
            
            # 결과 포맷 변환
            formatted_articles = []
            for article in articles:
                formatted_article = {
                    'title': article.get('title', ''),
                    'description': article.get('description', ''),
                    'url': article.get('url', ''),
                    'publishedAt': article.get('published date', ''),
                    'source': {'name': article.get('publisher', {}).get('title', '') if isinstance(article.get('publisher'), dict) else str(article.get('publisher', ''))}
                }
                formatted_articles.append(formatted_article)
            
            logger.info(f"✅ '{query}' 검색 결과: {len(formatted_articles)}개 기사")
            return formatted_articles
            
        except Exception as e:
            logger.error(f"❌ 뉴스 검색 실패 '{query}': {str(e)}")
            return []

    def collect_all_news(self) -> List[NewsArticle]:
        """모든 키워드로 뉴스 수집"""
        all_articles = []
        seen_urls = set()
        
        logger.info(f"📰 뉴스 수집 시작 - 키워드: {SEARCH_QUERIES}")
        
        for query in SEARCH_QUERIES:
            articles = self.fetch_news(query)
            
            for article in articles:
                url = article.get('url', '')
                if url and url not in seen_urls:
                    seen_urls.add(url)
                    
                    news_article = NewsArticle(
                        title=article.get('title', ''),
                        description=article.get('description', ''),
                        url=url,
                        published_date=article.get('publishedAt', ''),
                        source=article.get('source', {}).get('name', ''),
                        query=query
                    )
                    all_articles.append(news_article)
        
        logger.info(f"✅ 총 {len(all_articles)}개의 고유 기사 수집 완료")
        return all_articles

# === 뉴스 중요도 평가 함수 ===
def rank_news_by_importance(news_data: List[Dict[str, Any]], limit: int = 30) -> List[Dict[str, Any]]:
    """뉴스 중요도 기준으로 정렬"""
    try:
        logger.info(f"📊 뉴스 중요도 평가 시작: {len(news_data)}개 기사")
        
        for article in news_data:
            score = 0
            title = article.get('title', '').lower()
            summary = article.get('summary', '').lower()
            
            # 후보자 언급 점수
            candidates = ['이재명', '김문수', '이준석']
            for candidate in candidates:
                if candidate in title or candidate in summary:
                    score += 10
            
            # 키워드 점수
            important_keywords = ['대선', '선거', '후보', '정치', '여론조사', '지지율']
            for keyword in important_keywords:
                if keyword in title:
                    score += 5
                if keyword in summary:
                    score += 3
            
            # 감성 점수
            sentiment = article.get('sentiment', '중립')
            if sentiment in ['긍정', '부정']:
                score += 3
            
            # 제목 길이 점수 (너무 짧거나 긴 제목은 감점)
            title_length = len(title)
            if 10 <= title_length <= 50:
                score += 2
            
            article['importance_score'] = score
        
        # 중요도 순으로 정렬
        sorted_news = sorted(news_data, key=lambda x: x.get('importance_score', 0), reverse=True)
        result = sorted_news[:limit]
        
        logger.info(f"✅ 중요도 평가 완료: 상위 {len(result)}개 기사 선별")
        return result
        
    except Exception as e:
        logger.error(f"❌ 뉴스 중요도 평가 실패: {str(e)}")
        return news_data[:limit]

# === 뉴스 분석 클래스 ===
class NewsAnalyzer:
    """뉴스 분석 담당 클래스 (OpenAI GPT 사용)"""
    
    def __init__(self):
        self.api_usage_count = 0
        self.daily_limit = 100
        self.cache_enabled = True

    def _get_cache_path(self, article_id: str, analysis_type: str) -> Path:
        """캐시 파일 경로 생성"""
        return CACHE_DIR / f"{analysis_type}_{article_id}.json"

    def _load_from_cache(self, article_id: str, analysis_type: str) -> Optional[str]:
        """캐시에서 분석 결과 로드"""
        if not self.cache_enabled:
            return None
            
        cache_path = self._get_cache_path(article_id, analysis_type)
        if cache_path.exists():
            try:
                with open(cache_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    # 캐시가 24시간 이내인지 확인
                    cache_time = datetime.fromisoformat(data['timestamp'])
                    if datetime.now() - cache_time < timedelta(hours=24):
                        logger.debug(f"📋 캐시에서 로드: {analysis_type}_{article_id}")
                        return data['result']
                    else:
                        cache_path.unlink()  # 오래된 캐시 삭제
            except Exception as e:
                logger.warning(f"⚠️ 캐시 로드 실패: {str(e)}")
        return None

    def _save_to_cache(self, article_id: str, analysis_type: str, result: str):
        """분석 결과를 캐시에 저장"""
        if not self.cache_enabled:
            return
            
        cache_path = self._get_cache_path(article_id, analysis_type)
        try:
            cache_data = {
                'timestamp': datetime.now().isoformat(),
                'result': result
            }
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump(cache_data, f, ensure_ascii=False, indent=2)
            logger.debug(f"💾 캐시에 저장: {analysis_type}_{article_id}")
        except Exception as e:
            logger.warning(f"⚠️ 캐시 저장 실패: {str(e)}")

    def _track_api_usage(self):
        """API 사용량 추적"""
        self.api_usage_count += 1
        if self.api_usage_count >= self.daily_limit:
            logger.warning(f"⚠️ 일일 API 사용 한도 도달: {self.api_usage_count}/{self.daily_limit}")
            return False
        return True

    @backoff.on_exception(
        backoff.expo,
        (openai.RateLimitError, openai.APIError, openai.AuthenticationError),
        max_tries=3,
        max_time=30
    )
    def summarize_news(self, article_id: str, title: str, description: str) -> str:
        """뉴스 요약"""
        # 캐시 확인
        cached_result = self._load_from_cache(article_id, 'summary')
        if cached_result:
            return cached_result

        if not openai_client:
            return description[:200] + "..." if len(description) > 200 else description

        if not self._track_api_usage():
            return description[:200] + "..."

        try:
            prompt = f"""
다음 뉴스 기사를 한국어로 간결하게 요약해주세요. 2-3문장으로 핵심 내용만 정리해주세요.

제목: {title}
내용: {description}

요약:"""

            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=150,
                temperature=0.3
            )
            
            summary = response.choices[0].message.content.strip()
            
            # 캐시에 저장
            self._save_to_cache(article_id, 'summary', summary)
            
            logger.debug(f"✅ 뉴스 요약 완료: {article_id}")
            return summary
            
        except Exception as e:
            logger.error(f"❌ 뉴스 요약 실패: {str(e)}")
            return description[:200] + "..." if len(description) > 200 else description

    @backoff.on_exception(
        backoff.expo,
        (openai.RateLimitError, openai.APIError, openai.AuthenticationError),
        max_tries=3,
        max_time=30
    )
    def analyze_sentiment(self, article_id: str, title: str, description: str) -> str:
        """감성 분석"""
        # 캐시 확인
        cached_result = self._load_from_cache(article_id, 'sentiment')
        if cached_result:
            return cached_result

        if not openai_client:
            return "중립"

        if not self._track_api_usage():
            return "중립"

        try:
            prompt = f"""
다음 뉴스 기사의 감성을 분석해주세요. 정치적 후보자나 정당에 대한 전반적인 톤을 기준으로 판단해주세요.

제목: {title}
내용: {description}

감성을 다음 중 하나로 분류해주세요:
- 긍정: 후보자나 정당에 대해 호의적이거나 긍정적인 내용
- 부정: 후보자나 정당에 대해 비판적이거나 부정적인 내용  
- 중립: 객관적이거나 중립적인 보도

답변은 "긍정", "부정", "중립" 중 하나만 답해주세요."""

            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=10,
                temperature=0.1
            )
            
            sentiment = response.choices[0].message.content.strip()
            
            # 유효한 감성인지 확인
            valid_sentiments = ["긍정", "부정", "중립"]
            if sentiment not in valid_sentiments:
                sentiment = "중립"
            
            # 캐시에 저장
            self._save_to_cache(article_id, 'sentiment', sentiment)
            
            logger.debug(f"✅ 감성 분석 완료: {article_id} -> {sentiment}")
            return sentiment
            
        except Exception as e:
            logger.error(f"❌ 감성 분석 실패: {str(e)}")
            return "중립"

    def _summarize_news_batch(self, news_batch: List[Dict[str, Any]], batch_num: int, total_batches: int) -> str:
        """뉴스 배치 요약"""
        if not openai_client:
            return f"배치 {batch_num}: 총 {len(news_batch)}개의 뉴스가 수집되었습니다."

        try:
            # 뉴스 제목들을 하나의 텍스트로 결합
            news_titles = []
            for news in news_batch:
                title = news.get('title', '')
                sentiment = news.get('sentiment', '중립')
                news_titles.append(f"- {title} ({sentiment})")
            
            news_text = "\n".join(news_titles[:10])  # 최대 10개만 사용
            
            prompt = f"""
다음은 대선 관련 뉴스 제목들입니다. 이를 바탕으로 현재 정치 상황과 트렌드를 간결하게 요약해주세요.

뉴스 목록:
{news_text}

요약 (2-3문장):"""

            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=200,
                temperature=0.5
            )
            
            summary = response.choices[0].message.content.strip()
            logger.info(f"✅ 배치 {batch_num}/{total_batches} 요약 완료")
            return summary
            
        except Exception as e:
            logger.error(f"❌ 배치 요약 실패: {str(e)}")
            return f"배치 {batch_num}: 총 {len(news_batch)}개의 뉴스가 분석되었습니다."

    def _create_final_summary(self, batch_summaries: List[str], time_range: str) -> str:
        """최종 트렌드 요약 생성"""
        if not openai_client or not batch_summaries:
            return f"{time_range} 기간 동안의 대선 관련 뉴스를 분석했습니다."

        try:
            combined_summaries = "\n\n".join(batch_summaries)
            
            prompt = f"""
다음은 {time_range} 기간 동안의 대선 관련 뉴스 분석 결과입니다. 
이를 종합하여 현재 대선 상황의 주요 트렌드와 이슈를 요약해주세요.

분석 결과:
{combined_summaries}

종합 요약 (3-4문장으로 핵심 트렌드 정리):"""

            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=300,
                temperature=0.4
            )
            
            final_summary = response.choices[0].message.content.strip()
            logger.info("✅ 최종 트렌드 요약 생성 완료")
            return final_summary
            
        except Exception as e:
            logger.error(f"❌ 최종 요약 생성 실패: {str(e)}")
            return f"{time_range} 기간 동안의 대선 관련 뉴스를 종합 분석했습니다."

    def analyze_trends(self, news_data: List[Dict[str, Any]], time_range: str) -> Dict[str, Any]:
        """뉴스 트렌드 분석"""
        logger.info(f"📈 트렌드 분석 시작: {len(news_data)}개 기사")
        
        # 후보별 통계 계산
        candidate_stats = {
            "이재명": {"긍정": 0, "부정": 0, "중립": 0},
            "김문수": {"긍정": 0, "부정": 0, "중립": 0},
            "이준석": {"긍정": 0, "부정": 0, "중립": 0}
        }
        
        for article in news_data:
            title = article.get('title', '')
            summary = article.get('summary', '')
            sentiment = article.get('sentiment', '중립')
            
            # 후보자별 감성 통계
            for candidate in candidate_stats.keys():
                if candidate in title or candidate in summary:
                    candidate_stats[candidate][sentiment] += 1
        
        # 배치별 요약 생성
        batch_size = 10
        batches = [news_data[i:i + batch_size] for i in range(0, len(news_data), batch_size)]
        batch_summaries = []
        
        for i, batch in enumerate(batches, 1):
            if len(batch_summaries) >= 5:  # 최대 5개 배치만 처리
                break
            summary = self._summarize_news_batch(batch, i, len(batches))
            batch_summaries.append(summary)
        
        # 최종 트렌드 요약
        trend_summary = self._create_final_summary(batch_summaries, time_range)
        
        result = {
            "trend_summary": trend_summary,
            "candidate_stats": candidate_stats,
            "total_articles": len(news_data),
            "time_range": time_range,
            "news_list": news_data
        }
        
        logger.info("✅ 트렌드 분석 완료")
        return result

# === 뉴스 파이프라인 클래스 ===
class NewsPipeline:
    """뉴스 수집 및 분석 파이프라인"""
    
    def __init__(self):
        self.collector = NewsCollector()
        self.analyzer = NewsAnalyzer()
        self.last_run_date = None

    def _should_run_today(self) -> bool:
        """오늘 실행해야 하는지 확인"""
        today = datetime.now().date()
        
        # 강제 실행 모드 확인
        if os.environ.get('FORCE_NEWS_COLLECTION') == 'true':
            logger.info("🔥 강제 실행 모드 - 오늘 실행 여부 무시")
            return True
        
        # 오늘 이미 실행했는지 확인
        if self.last_run_date == today:
            logger.info(f"⏭️ 오늘({today})은 이미 실행했습니다.")
            return False
        
        return True

    def process_articles(self, articles: List[NewsArticle]) -> List[Dict[str, Any]]:
        """기사 처리 (요약 및 감성 분석)"""
        processed_articles = []
        
        logger.info(f"🔄 기사 처리 시작: {len(articles)}개")
        
        for i, article in enumerate(articles, 1):
            try:
                logger.info(f"📝 기사 처리 중 ({i}/{len(articles)}): {article.title[:50]}...")
                
                # 요약 생성
                summary = self.analyzer.summarize_news(
                    article.unique_id, 
                    article.title, 
                    article.description
                )
                
                # 감성 분석
                sentiment = self.analyzer.analyze_sentiment(
                    article.unique_id,
                    article.title,
                    article.description
                )
                
                processed_article = {
                    "title": article.title,
                    "summary": summary,
                    "url": article.url,
                    "published_date": article.published_date,
                    "source": article.source,
                    "sentiment": sentiment,
                    "query": article.query
                }
                
                processed_articles.append(processed_article)
                
            except Exception as e:
                logger.error(f"❌ 기사 처리 실패: {str(e)}")
                continue
        
        logger.info(f"✅ 기사 처리 완료: {len(processed_articles)}개")
        return processed_articles

    def save_trend_summary(self, trend_data: Dict[str, Any]):
        """트렌드 요약 저장"""
        try:
            # 타임스탬프 파일명 생성
            timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
            filename = f"trend_summary_{timestamp}.json"
            filepath = ASSETS_DIR / filename
            
            # 파일 저장
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(trend_data, f, ensure_ascii=False, indent=2)
            
            logger.info(f"💾 트렌드 요약 저장 완료: {filename}")
            
            # 영구 저장소에도 복사 (Render.com 환경)
            if os.environ.get('RENDER') == 'true':
                persistent_dir = Path("/opt/render/project/src/persistent_data")
                if persistent_dir.exists():
                    import shutil
                    # 최신 파일로 복사
                    latest_file = persistent_dir / "trend_summary_latest.json"
                    shutil.copy(filepath, latest_file)
                    
                    # 원본 파일도 복사
                    perm_file = persistent_dir / filename
                    shutil.copy(filepath, perm_file)
                    
                    logger.info(f"📋 영구 저장소에 복사 완료: {filename}")
            
        except Exception as e:
            logger.error(f"❌ 트렌드 요약 저장 실패: {str(e)}")

    def run_daily_collection(self):
        """일일 뉴스 수집 및 분석 실행"""
        try:
            start_time = datetime.now()
            logger.info(f"🚀 일일 뉴스 수집 시작: {start_time}")
            
            # 실행 여부 확인
            if not self._should_run_today():
                return
            
            # 1. 뉴스 수집
            articles = self.collector.collect_all_news()
            if not articles:
                logger.warning("⚠️ 수집된 뉴스가 없습니다.")
                # 빈 데이터라도 오늘 날짜로 저장
                empty_data = {
                    "trend_summary": "오늘 수집된 뉴스가 없습니다.",
                    "candidate_stats": {
                        "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                        "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                        "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                    },
                    "total_articles": 0,
                    "time_range": f"{start_time.strftime('%Y-%m-%d')} 수집",
                    "news_list": []
                }
                self.save_trend_summary(empty_data)
                self.last_run_date = start_time.date()
                return
            
            # 2. 기사 처리 (요약 및 감성 분석)
            processed_articles = self.process_articles(articles)
            
            # 3. 트렌드 분석
            time_range = f"{start_time.strftime('%Y-%m-%d')} 수집"
            trend_data = self.analyzer.analyze_trends(processed_articles, time_range)
            
            # 4. 결과 저장
            self.save_trend_summary(trend_data)
            
            # 5. 실행 상태 업데이트
            self.last_run_date = start_time.date()
            
            end_time = datetime.now()
            duration = end_time - start_time
            logger.info(f"✅ 일일 뉴스 수집 완료: {duration.total_seconds():.1f}초 소요")
            
        except Exception as e:
            logger.error(f"❌ 일일 뉴스 수집 실패: {str(e)}")
            # 오류 발생 시에도 오늘 날짜로 기본 데이터 저장
            try:
                error_data = {
                    "trend_summary": f"뉴스 수집 중 오류가 발생했습니다: {str(e)}",
                    "candidate_stats": {
                        "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                        "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                        "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                    },
                    "total_articles": 0,
                    "time_range": f"{datetime.now().strftime('%Y-%m-%d')} 오류",
                    "news_list": []
                }
                self.save_trend_summary(error_data)
                self.last_run_date = datetime.now().date()
            except Exception as e2:
                logger.error(f"❌ 오류 데이터 저장도 실패: {str(e2)}")

# === 전역 인스턴스 ===
pipeline = NewsPipeline()

# === 메인 실행 함수 ===
def run_news_pipeline():
    """뉴스 파이프라인 실행 (외부 호출용)"""
    pipeline.run_daily_collection()

# === 메인 실행 ===
if __name__ == "__main__":
    logger.info("🎯 뉴스 스크래퍼 직접 실행")
    run_news_pipeline()
