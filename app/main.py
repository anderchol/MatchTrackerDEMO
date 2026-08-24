import os, time, socket, json
from flask import Flask, jsonify, request
 
app = Flask(__name__)
START = time.time()

# In-memory store — replace with RDS PostgreSQL in production
sessions    = {}
matches     = []
leaderboard = {}


@app.route("/")
def index():
    return jsonify({"service": "MatchTracker", "status": "ok"})


@app.route("/health")
def health():
    return jsonify({
        "status":          "ok",
        "uptime_seconds":  int(time.time() - START),
        "hostname":        socket.gethostname(),
        "served_by":       "nginx -> flask",
        "active_sessions": len(sessions),
        "total_matches":   len(matches),
        "environment":     os.getenv("ENVIRONMENT", "local")
    })


@app.route("/info")
def info():
    return jsonify({
        "hostname": socket.gethostname(),
        "region":   os.getenv("AWS_REGION", "not-set"),
        "environment": os.getenv("ENVIRONMENT", "local")
    })


@app.route("/session/join", methods=["POST"])
def join():
    data = request.get_json()
    if not data or not data.get("player_id"):
        return jsonify({"error": "player_id required"}), 400
    player_id = data["player_id"]
    if player_id in sessions:
        return jsonify({"error": "player already in session"}), 409
    sessions[player_id] = {"joined": time.time(), "player_id": player_id}
    return jsonify({"status": "joined", "player_id": player_id}), 201


@app.route("/session/leave", methods=["POST"])
def leave():
    data = request.get_json()
    if not data or not data.get("player_id"):
        return jsonify({"error": "player_id required"}), 400
    player_id = data["player_id"]
    if player_id not in sessions:
        return jsonify({"error": "player not in session"}), 404
    sessions.pop(player_id)
    return jsonify({"status": "left", "player_id": player_id})


@app.route("/session/active")
def active_sessions():
    return jsonify({"active_sessions": list(sessions.keys()), "count": len(sessions)})


@app.route("/match/submit", methods=["POST"])
def submit_match():
    #  data : {"winners": [], "losers": []}
    data = request.get_json()
    if not data:
        return jsonify({"error": "request body required"}), 400
    for field in ["winners", "losers"]:
        field_list = data.get(field)
        if not isinstance(field_list, list) or len(field_list) <= 0:
            return jsonify({"error": f"Valid {field} list required"}), 400
    winners = data["winners"]
    losers = data["losers"]
    if set(winners) & set(losers):
        return jsonify({"error": "winners and losers must be different players"}), 400
    matches.append({**data, "recorded_at": time.time()})
    for winner in winners:
        leaderboard[winner] = leaderboard.get(winner, 0) +1
    return jsonify({"status": "recorded", "total_matches": len(matches)}), 201


@app.route("/leaderboard")
def get_leaderboard():
    ranked = sorted(leaderboard.items(), key=lambda x: x[1], reverse=True)
    return jsonify({
        "players": [{"player": p, "wins": w, "rank": i + 1}
                    for i, (p, w) in enumerate(ranked[:10])]
    })


if __name__ == "__main__":
    # Bind to localhost only — Nginx is the only thing that talks to Flask
    host = os.getenv("FLASK_HOST", "127.0.0.1")
    port = int(os.getenv("PORT", 5000))
    app.run(host=host, port=port, debug=True)