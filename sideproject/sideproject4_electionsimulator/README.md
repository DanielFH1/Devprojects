# 🗳️ 2025 Presidential Election AI Simulator

An interactive and data-driven simulation web app that collects and analyzes real-time news about the 2025 Korean presidential election.  
Hosted live at 👉 [electionsimulatorwebservice.onrender.com](https://electionsimulatorwebservice.onrender.com)

---

## 📌 Overview

This project aims to gather all publicly available news related to the 2025 presidential election in South Korea, analyze the sentiment of each article, and provide a visualized prediction of the final election outcome based on trend analysis.

It leverages **AI models** for summarization, sentiment classification, and public opinion trend analysis.

---

## 💡 Motivation

The 2025 presidential election is a pivotal moment in Korean politics. However, public opinion is fragmented across various platforms and news sources.  
This project brings them together in one place and utilizes AI to interpret the data in meaningful ways:

- 📥 **News Aggregation** from major Korean media
- ✨ **Summarization & Sentiment Analysis** with GPT-4
- 📊 **Trend-Based Prediction** of final election results

---

## 🔧 Tech Stack

| Layer          | Technology                               |
| -------------- | ---------------------------------------- |
| Frontend       | Flutter (Web)                            |
| Backend        | Python 🐍 (with OpenAI API, GNews)       |
| Infrastructure | [Render](https://render.com) for hosting |
| LLM            | OpenAI GPT-4 Turbo                       |

---

## 🚀 Features

- 🔍 Real-time news crawling using GNews
- 🧠 Summarization and sentiment analysis using GPT-4
- 📈 Sentiment-based candidate support visualization
- 🧩 Clickable candidate profiles and policy viewer
- 📅 Automatic hourly updates with trend summary JSON export

---

## 📂 Architecture Overview

```bash
sideproject4_electionsimulator/
├── news_scraper.py                     # Python script: scraping, summarization, sentiment
├── web/
│   └── api_server.py                    # Backend API server
├── assets/
│   └── news_summary_YYYY-MM-DD_HH-MM.json   # Hourly trend summaries
└── flutter_ui/
    └── lib/
        ├── main.dart                    # Entry point for the Flutter app
        ├── news_model.dart              # Data model for news items
        ├── news_page.dart               # News viewer page
        ├── prediction_page.dart         # Election result prediction UI
        ├── candidate_detail_page.dart   # Candidate info and pledges
        └── candidate_pie_chart.dart     # Pie chart visualization of sentiment
```

## 🚀 Local Development

### Backend Setup

1. Install required Python packages:

```bash
pip install -r requirements.txt
python -m uvicorn web.api_server:app --host 0.0.0.0 --port 3000 --reload
```

2. Environment Variables:

- Create a `.env` file in the project root
- Add your OpenAI API key:
