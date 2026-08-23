import os, time, socket
from flask import Flask, jsonify
 
app = Flask(__name__)
START = time.time()
 
@app.route("/")
def index():
    return jsonify({"service": "MatchTracker", "status": "ok"})
 
@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "uptime_seconds": int(time.time() - START),
        "hostname": socket.gethostname(),
        "served_by": "nginx -> flask",
        "environment": os.getenv("ENVIRONMENT", "local")
    })
 
@app.route("/info")
def info():
    return jsonify({
        "hostname":      socket.gethostname(),
        "region":        os.getenv("AWS_REGION", "not-set"),
        "instance_type": os.getenv("INSTANCE_TYPE", "unknown"),
    })
 
if __name__ == "__main__":
    # Bind to localhost only — Nginx is the only thing that talks to Flask
    host = os.getenv("FLASK_HOST", "127.0.0.1")
    port = int(os.getenv("PORT", 5000))
    app.run(host=host, port=port)