# Makefile — place in project root, deploys to EC2 via user_data
.PHONY: status logs restart nginx-status health
 
status:
@systemctl status matchtracker
 
logs:
@journalctl -u matchtracker -f
 
restart:
@systemctl restart matchtracker
@echo "MatchTracker restarted"
 
nginx-status:
@systemctl status nginx
 
nginx-restart:
@nginx -t && systemctl restart nginx
 
health:
@curl -s http://localhost/health | python3 -m json.tool
 
sessions:
@curl -s http://localhost/leaderboard | python3 -m json.tool
