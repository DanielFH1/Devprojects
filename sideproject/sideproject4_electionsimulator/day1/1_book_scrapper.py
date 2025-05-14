import requests
from bs4 import BeautifulSoup

base_url = "https://books.toscrape.com/catalogue/page-{}.html"
first_page = "https://books.toscrape.com/"

all_books = []

def scrape_page(url):
    res = requests.get(url)
    if res.status_code != 200:
        return False
    soup = BeautifulSoup(res.text, 'html.parser')
    books = soup.select(".product_pod")
    for book in books:
        title = book.h3.a['title'] if book.h3 and book.h3.a else "제목없음"
        price_tag = book.select_one(".price_color")
        price = price_tag.text if price_tag else "가격없음"
        all_books.append((title,price))
    return True

scrape_page(first_page)

for i in range(2,51):
    url = base_url.format(i)
    success = scrape_page(url)
    if not success:
        break

for title,price in all_books:
    print(f"📘 {title} | 💰 {price}")

print(f"\n총 {len(all_books)}권 수집 완료 ✅")

