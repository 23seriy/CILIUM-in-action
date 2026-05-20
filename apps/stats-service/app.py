"""
NBA Stats Service — internal microservice.
Provides player statistics per game. Only scoreboard-api should call this.
"""

import os
import logging
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("stats-service")

# Simulated player stats by game
GAME_STATS = {
    1: {
        "game_id": 1,
        "matchup": "Lakers vs Celtics",
        "leaders": [
            {"player": "LeBron James", "team": "Lakers", "points": 32, "rebounds": 8, "assists": 11},
            {"player": "Jayson Tatum", "team": "Celtics", "points": 28, "rebounds": 6, "assists": 5},
            {"player": "Anthony Davis", "team": "Lakers", "points": 24, "rebounds": 14, "assists": 3},
        ]
    },
    2: {
        "game_id": 2,
        "matchup": "Warriors vs Nuggets",
        "leaders": [
            {"player": "Stephen Curry", "team": "Warriors", "points": 26, "rebounds": 4, "assists": 8},
            {"player": "Nikola Jokic", "team": "Nuggets", "points": 31, "rebounds": 12, "assists": 9},
            {"player": "Andrew Wiggins", "team": "Warriors", "points": 18, "rebounds": 5, "assists": 2},
        ]
    },
    3: {
        "game_id": 3,
        "matchup": "Bucks vs Heat",
        "leaders": [
            {"player": "Giannis Antetokounmpo", "team": "Bucks", "points": 35, "rebounds": 11, "assists": 5},
            {"player": "Jimmy Butler", "team": "Heat", "points": 22, "rebounds": 7, "assists": 6},
            {"player": "Damian Lillard", "team": "Bucks", "points": 20, "rebounds": 3, "assists": 9},
        ]
    },
    4: {
        "game_id": 4,
        "matchup": "Suns vs Mavericks",
        "leaders": [
            {"player": "Kevin Durant", "team": "Suns", "points": 29, "rebounds": 6, "assists": 4},
            {"player": "Luka Doncic", "team": "Mavericks", "points": 38, "rebounds": 9, "assists": 10},
            {"player": "Devin Booker", "team": "Suns", "points": 25, "rebounds": 3, "assists": 7},
        ]
    }
}


@app.route("/")
def index():
    return jsonify({
        "service": "stats-service",
        "version": "v1",
        "description": "Internal NBA player statistics service",
        "endpoints": [
            "GET /api/stats — all game stats",
            "GET /api/stats/game/<id> — stats for a specific game",
            "GET /api/stats/player/<name> — stats for a specific player",
            "POST /api/stats/update — update player stats (admin)",
            "DELETE /api/stats/game/<id> — delete game stats (admin)",
            "GET /health — health check",
        ]
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "stats-service"})


@app.route("/api/stats")
def all_stats():
    logger.info("Serving all game stats")
    return jsonify({"games": list(GAME_STATS.values())})


@app.route("/api/stats/game/<int:game_id>")
def game_stats(game_id):
    logger.info(f"Serving stats for game {game_id}")
    stats = GAME_STATS.get(game_id)
    if not stats:
        return jsonify({"error": "Game not found"}), 404
    return jsonify(stats)


@app.route("/api/stats/player/<name>")
def player_stats(name):
    logger.info(f"Searching stats for player: {name}")
    results = []
    for game_id, game in GAME_STATS.items():
        for leader in game["leaders"]:
            if name.lower() in leader["player"].lower():
                results.append({**leader, "game_id": game_id, "matchup": game["matchup"]})
    if not results:
        return jsonify({"error": f"No stats found for '{name}'"}), 404
    return jsonify({"player": name, "stats": results})


@app.route("/api/stats/update", methods=["POST"])
def update_stats():
    logger.info("POST /api/stats/update called")
    return jsonify({"message": "Stats update received", "method": "POST"}), 200


@app.route("/api/stats/game/<int:game_id>", methods=["DELETE"])
def delete_stats(game_id):
    logger.info(f"DELETE /api/stats/game/{game_id} called")
    return jsonify({"message": f"Game {game_id} stats deleted", "method": "DELETE"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
