import requests
from bs4 import BeautifulSoup

url = "https://quotes.toscrape.com/"
res = requests.get(url)
soup = BeautifulSoup(res.text, "html.parser")

quotes_data = []

quotes = soup.select(".quote")

for quote in quotes:
    text_tag = quote.select_one(".text") # select_one은 태그 반환
    author_tag = quote.select_one(".author")
    tags = [tag.text for tag in quote.select(".tags .tag")] # select는 리스트를 반환 공백으로 자손선택자 

    text = text_tag.text if text_tag else "내용없음"
    author = author_tag.text if author_tag else "작자미상"

    quotes_data.append((text,author,tags))

for q in quotes_data:
    print(f"\n📝 {q[0]} \n👤 {q[1]}\n🏷️  Tags: {', '.join(q[2])}") # join메소드는 리스트의 요소를 문자열로 연결
