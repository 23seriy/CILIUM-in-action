"""
NBA Scoreboard API — public-facing service.
Calls stats-service and news-service internally.
"""

import os
import json
import logging
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scoreboard-api")

STATS_SERVICE = os.environ.get("STATS_SERVICE_URL", "http://stats-service:8080")
NEWS_SERVICE = os.environ.get("NEWS_SERVICE_URL", "http://news-service:8080")

# Simulated live NBA scores
LIVE_SCORES = [
    {"game_id": 1, "home": "Lakers", "away": "Celtics", "home_score": 108, "away_score": 102, "quarter": "4th", "time": "2:34", "arena": "Crypto.com Arena"},
    {"game_id": 2, "home": "Warriors", "away": "Nuggets", "home_score": 96, "away_score": 99, "quarter": "3rd", "time": "8:15", "arena": "Chase Center"},
    {"game_id": 3, "home": "Bucks", "away": "Heat", "home_score": 88, "away_score": 85, "quarter": "3rd", "time": "4:02", "arena": "Fiserv Forum"},
    {"game_id": 4, "home": "Suns", "away": "Mavericks", "home_score": 112, "away_score": 115, "quarter": "OT", "time": "1:47", "arena": "Footprint Center"},
]


@app.route("/")
def index():
    return jsonify({
        "service": "scoreboard-api",
        "version": "v1",
        "description": "NBA Live Scoreboard — powered by Cilium eBPF networking",
        "endpoints": [
            "GET /scores — live game scores",
            "GET /scores/<game_id> — single game detail with stats",
            "GET /headlines — top NBA news",
            "GET /health — health check",
        ]
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "scoreboard-api"})


@app.route("/scores")
def scores():
    logger.info("Serving live scores")
    return jsonify({"games": LIVE_SCORES, "count": len(LIVE_SCORES)})


@app.route("/scores/<int:game_id>")
def game_detail(game_id):
    game = next((g for g in LIVE_SCORES if g["game_id"] == game_id), None)
    if not game:
        return jsonify({"error": "Game not found"}), 404

    # Fetch player stats from stats-service
    stats = None
    try:
        resp = requests.get(f"{STATS_SERVICE}/api/stats/game/{game_id}", timeout=3)
        if resp.status_code == 200:
            stats = resp.json()
        else:
            logger.warning(f"stats-service returned {resp.status_code}")
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to reach stats-service: {e}")
        stats = {"error": "stats-service unavailable"}

    return jsonify({"game": game, "player_stats": stats})


@app.route("/headlines")
def headlines():
    # Fetch news from news-service
    try:
        resp = requests.get(f"{NEWS_SERVICE}/api/news", timeout=3)
        if resp.status_code == 200:
            return jsonify(resp.json())
        else:
            logger.warning(f"news-service returned {resp.status_code}")
            return jsonify({"error": "news-service returned an error"}), 502
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to reach news-service: {e}")
        return jsonify({"error": "news-service unavailable"}), 503


@app.route("/metrics")
def metrics():
    return "scoreboard_api_requests_total 1\n", 200, {"Content-Type": "text/plain"}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
