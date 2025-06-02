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

# 검색 키워드 설정 - 더 많은 키워드로 확장
SEARCH_QUERIES = [
    "이재명 대선",
    "이재명 후보",
    "김문수 대선", 
    "김문수 후보",
    "이준석 대선",
    "이준석 후보",
    "2025 대선",
    "21대 대선",
    "대선 후보",
    "대선 여론조사",
    "대선 지지율",
    "대선 정책",
    "대선 토론",
    "더불어민주당 이재명",
    "국민의힘 김문수",
    "개혁신당 이준석"
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
    
    def __init__(self, period: str = "24h", max_results: int = 50):
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
            logger.info(f"뉴스 검색 중: '{query}' (최대 {self.max_results}개)")
            
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
        """모든 키워드로 뉴스 수집 - 200개 목표"""
        all_articles = []
        seen_urls = set()
        
        logger.info(f"📰 뉴스 수집 시작 - 키워드: {SEARCH_QUERIES} (목표: 200개)")
        
        for query in SEARCH_QUERIES:
            # 각 키워드당 더 많은 기사 수집
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
                    
                    # 200개에 도달하면 중단
                    if len(all_articles) >= 200:
                        logger.info(f"🎯 목표 200개 기사 수집 완료!")
                        break
            
            if len(all_articles) >= 200:
                break
        
        logger.info(f"✅ 총 {len(all_articles)}개의 고유 기사 수집 완료")
        return all_articles

# === 뉴스 중요도 평가 함수 ===
def rank_news_by_importance(news_data: List[Dict[str, Any]], limit: int = 100) -> List[Dict[str, Any]]:
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
        """감성 분석 - 더 공격적으로 긍정/부정 판정"""
        # 캐시 확인
        cached_result = self._load_from_cache(article_id, 'sentiment')
        if cached_result:
            return cached_result

        if not openai_client:
            # OpenAI가 없으면 제목 기반으로 간단한 룰 베이스 분석
            return self._rule_based_sentiment(title, description)

        if not self._track_api_usage():
            return self._rule_based_sentiment(title, description)

        try:
            prompt = f"""
다음 정치 뉴스 기사의 감성을 분석해주세요. 

제목: {title}
내용: {description}

**중요 지침:**
1. 정치 뉴스는 대부분 긍정적이거나 부정적인 성향을 가집니다.
2. 중립은 정말 예외적인 경우에만 사용하세요 (단순 일정 공지, 수치 발표만 있는 경우).
3. 후보자가 언급된 기사는 거의 항상 긍정 또는 부정 중 하나입니다.
4. 애매하면 긍정 쪽으로 판단하세요.

감성 분류 기준:
- **긍정**: 지지 표명, 정책 발표, 성과 강조, 호의적 분석, 지지율 상승, 칭찬, 성공적 활동
- **부정**: 비판, 논란, 스캔들, 지지율 하락, 실정, 문제점 지적, 갈등, 반대 의견
- **중립**: 단순 일정 발표, 객관적 수치만 제시 (매우 제한적으로만 사용)

답변은 "긍정", "부정", "중립" 중 하나만 답하세요."""

            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=10,
                temperature=0.1  # 더 일관된 결과를 위해 낮춤
            )
            
            sentiment = response.choices[0].message.content.strip()
            
            # 유효한 감성인지 확인
            valid_sentiments = ["긍정", "부정", "중립"]
            if sentiment not in valid_sentiments:
                # 기본값으로 룰 베이스 분석 사용
                sentiment = self._rule_based_sentiment(title, description)
            
            # 캐시에 저장
            self._save_to_cache(article_id, 'sentiment', sentiment)
            
            logger.debug(f"✅ 감성 분석 완료: {article_id} -> {sentiment}")
            return sentiment
            
        except Exception as e:
            logger.error(f"❌ 감성 분석 실패: {str(e)}")
            return self._rule_based_sentiment(title, description)

    def _rule_based_sentiment(self, title: str, description: str) -> str:
        """룰 베이스 감성 분석 (OpenAI 사용 불가시 대안)"""
        text = (title + " " + description).lower()
        
        # 긍정 키워드
        positive_keywords = [
            '성과', '성공', '지지', '상승', '개선', '발전', '호응', '환영', '찬성', '칭찬',
            '좋', '우수', '훌륭', '뛰어난', '효과적', '성취', '달성', '승리', '선도',
            '혁신', '개혁', '약속', '공약', '정책', '비전', '희망', '미래', '발표'
        ]
        
        # 부정 키워드
        negative_keywords = [
            '비판', '논란', '문제', '하락', '실패', '우려', '걱정', '반대', '갈등', '충돌',
            '스캔들', '의혹', '조사', '수사', '기소', '구속', '사퇴', '사과', '실정',
            '부정', '거부', '반발', '항의', '고발', '고소', '폭로', '폭로'
        ]
        
        positive_score = sum(1 for keyword in positive_keywords if keyword in text)
        negative_score = sum(1 for keyword in negative_keywords if keyword in text)
        
        if positive_score > negative_score:
            return "긍정"
        elif negative_score > positive_score:
            return "부정"
        else:
            # 동점이거나 둘 다 0이면 제목 길이와 내용으로 판단
            if len(title) > 20 and any(candidate in text for candidate in ['이재명', '김문수', '이준석']):
                # 후보자가 언급된 긴 제목은 보통 긍정 또는 부정
                import random
                return random.choice(["긍정", "부정"])
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
        # 200개 기사 수집을 위해 더 큰 수치로 초기화
        self.collector = NewsCollector(period="24h", max_results=50)  # 각 키워드당 50개씩
        self.analyzer = NewsAnalyzer()
        self.last_run_date = None
        self.final_run_completed = False  # 최종 실행 완료 플래그

    def _should_run_today(self) -> bool:
        """오늘 실행해야 하는지 확인 - 최종 실행 후에는 더 이상 실행하지 않음"""
        if self.final_run_completed:
            logger.info("🚫 최종 실행이 이미 완료되었습니다. 더 이상 실행하지 않습니다.")
            return False
            
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
        """최종 뉴스 수집 및 분석 실행 (한 번만)"""
        try:
            if self.final_run_completed:
                logger.info("🚫 최종 실행이 이미 완료되어 더 이상 실행하지 않습니다.")
                return
                
            start_time = datetime.now()
            logger.info(f"🚀 최종 뉴스 수집 시작: {start_time} (목표: 200개 기사)")
            
            # 실행 여부 확인
            if not self._should_run_today():
                return
            
            # 1. 뉴스 수집 (200개 목표)
            articles = self.collector.collect_all_news()
            if not articles:
                logger.warning("⚠️ 수집된 뉴스가 없습니다.")
                # 빈 데이터라도 오늘 날짜로 저장
                empty_data = {
                    "trend_summary": "수집된 뉴스가 없습니다.",
                    "candidate_stats": {
                        "이재명": {"긍정": 0, "부정": 0, "중립": 0},
                        "김문수": {"긍정": 0, "부정": 0, "중립": 0},
                        "이준석": {"긍정": 0, "부정": 0, "중립": 0}
                    },
                    "total_articles": 0,
                    "time_range": f"{start_time.strftime('%Y-%m-%d')} 최종 수집",
                    "news_list": []
                }
                self.save_trend_summary(empty_data)
                self.final_run_completed = True
                return
            
            logger.info(f"📊 수집 완료: {len(articles)}개 기사")
            
            # 2. 기사 처리 (요약 및 감성 분석)
            processed_articles = self.process_articles(articles)
            
            # 3. 트렌드 분석
            time_range = f"{start_time.strftime('%Y-%m-%d')} 최종 수집 (총 {len(processed_articles)}개 기사)"
            trend_data = self.analyzer.analyze_trends(processed_articles, time_range)
            
            # 4. 결과 저장
            self.save_trend_summary(trend_data)
            
            # 5. 최종 실행 완료 표시
            self.final_run_completed = True
            self.last_run_date = start_time.date()
            
            end_time = datetime.now()
            duration = end_time - start_time
            
            # 감성 분석 결과 로깅
            sentiment_counts = {"긍정": 0, "부정": 0, "중립": 0}
            for article in processed_articles:
                sentiment = article.get('sentiment', '중립')
                sentiment_counts[sentiment] += 1
            
            logger.info(f"✅ 최종 뉴스 수집 완료!")
            logger.info(f"📊 총 기사 수: {len(processed_articles)}개")
            logger.info(f"📈 감성 분석 결과: 긍정 {sentiment_counts['긍정']}개, 부정 {sentiment_counts['부정']}개, 중립 {sentiment_counts['중립']}개")
            logger.info(f"⏱️ 소요 시간: {duration.total_seconds():.1f}초")
            logger.info(f"🏁 이것이 마지막 실행입니다. 더 이상 뉴스 수집을 하지 않습니다.")
            
        except Exception as e:
            logger.error(f"❌ 최종 뉴스 수집 실패: {str(e)}")
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
                    "time_range": f"{datetime.now().strftime('%Y-%m-%d')} 오류 발생",
                    "news_list": []
                }
                self.save_trend_summary(error_data)
                self.final_run_completed = True
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
