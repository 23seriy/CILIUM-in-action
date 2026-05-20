"""
NBA News Service — internal microservice.
Provides NBA headlines and breaking news. Only scoreboard-api should call this.
"""

import os
import logging
from flask import Flask, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("news-service")

HEADLINES = [
    {"id": 1, "headline": "LeBron James Records Triple-Double in Lakers Victory", "category": "game-recap", "breaking": False},
    {"id": 2, "headline": "Jokic Edges Curry in MVP-Caliber Showdown", "category": "highlights", "breaking": False},
    {"id": 3, "headline": "Giannis Drops 35 as Bucks Take 3-1 Series Lead", "category": "playoffs", "breaking": True},
    {"id": 4, "headline": "Luka Doncic Forces OT with Clutch Three-Pointer", "category": "highlights", "breaking": True},
    {"id": 5, "headline": "Trade Deadline: Three Blockbuster Deals Expected", "category": "trades", "breaking": False},
]


@app.route("/")
def index():
    return jsonify({
        "service": "news-service",
        "version": "v1",
        "description": "Internal NBA news and headlines service",
        "endpoints": [
            "GET /api/news — all headlines",
            "GET /api/news/breaking — breaking news only",
            "GET /api/news/<id> — single headline",
            "GET /health — health check",
        ]
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "news-service"})


@app.route("/api/news")
def all_news():
    logger.info("Serving all headlines")
    return jsonify({"headlines": HEADLINES, "count": len(HEADLINES)})


@app.route("/api/news/breaking")
def breaking_news():
    logger.info("Serving breaking news")
    breaking = [h for h in HEADLINES if h["breaking"]]
    return jsonify({"headlines": breaking, "count": len(breaking)})


@app.route("/api/news/<int:news_id>")
def single_headline(news_id):
    headline = next((h for h in HEADLINES if h["id"] == news_id), None)
    if not headline:
        return jsonify({"error": "Headline not found"}), 404
    return jsonify(headline)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
