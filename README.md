# MatchTracker

DEMO DESIGNED FOR WINDOWS OS DEV

A tiny Flask API for tracking casual game/match sessions, recording results, and keeping a win leaderboard — deployable locally or to AWS EC2 with OpenTofu/Terraform.

MatchTracker lets players join a session, submit match results (winners vs. losers), and see who's on top. It ships with a minimal in-memory backend, an Nginx + systemd production setup baked into EC2 user data, and helper scripts for both Windows (PowerShell) and Linux/macOS (Make).

## Features

- **Session tracking** — players join/leave a live session
- **Match recording** — submit winners/losers, results build a leaderboard automatically
- **Leaderboard** — top 10 players ranked by wins
- **Health/info endpoints** — for monitoring and deploy verification
- **One-command AWS deploy** — OpenTofu/Terraform spins up an EC2 instance behind Nginx
- **Cross-platform tooling** — `matchtracker.ps1` for Windows, `Makefile` for Linux/macOS

## Architecture

```
Client → Nginx (:80) → Flask/Gunicorn (127.0.0.1:5000) → in-memory store
```

- **`app/main.py`** — Flask application (all API routes)
- **`main.tf`** — OpenTofu/Terraform config: EC2 instance, security group, Elastic IP
- **`userdata.sh.tpl`** — EC2 bootstrap script: installs Python/Nginx, creates the `matchtracker` systemd service, configures Nginx as a reverse proxy
- **`matchtracker.ps1`** — Windows command runner (dev server, deploy, SSH, status, etc.)
- **`Makefile`** — Linux/macOS command runner for the *deployed* instance (status, logs, restart, health checks)
- **`terraform.tfvars.example`** — template for your deployment variables

> The in-memory store (sessions, matches, leaderboard) is for demo purposes only
> Please use dedicated database(s) for prod, this is just an example

## API Reference

| Method | Endpoint          | Description                                  |
|--------|-------------------|-----------------------------------------------|
| GET    | `/`               | Service status                                |
| GET    | `/health`         | Health check + uptime, session/match counts   |
| GET    | `/info`           | Hostname, region, environment                 |
| POST   | `/session/join`   | Join a session — `{"player_id": "..."}`       |
| POST   | `/session/leave`  | Leave a session — `{"player_id": "..."}`      |
| GET    | `/session/active` | List active session players                   |
| POST   | `/match/submit`   | Submit a result — `{"winners": [...], "losers": [...]}` |
| GET    | `/leaderboard`    | Top 10 players by wins                        |

## Getting Started

### Prerequisites

- Python 3.10 and up
- [OpenTofu](https://opentofu.org/) (or Terraform) — only needed for AWS deployment
- An AWS account with credentials configured (for deployment)
- Windows: PowerShell · Linux/macOS: `make`

### Run locally

```bash
cd app
pip install -r requirements.txt
python main.py
```

The app serves on `http://localhost:5000` (binds to `127.0.0.1` unless `FLASK_HOST` is set).

**Windows shortcut:**

```powershell
.\matchtracker.ps1 dev
```

This sets `FLASK_HOST=0.0.0.0`, `ENVIRONMENT=local`, `PORT=5000` and starts the app at `http://localhost:5000`.

### Run tests

```powershell
.\matchtracker.ps1 test
```

or directly:

```bash
pytest tests/ -v
```

## Deploying to AWS

Deployment provisions a single `t2.micro` EC2 instance (free-tier eligible) running Amazon Linux 2023, fronted by Nginx, with the Flask app managed by systemd.

1. **Configure variables**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars` and set your IP (`matchtracker.ps1 ip` will fetch it for you), AWS region, and an existing EC2 key pair name.

2. **Initialize and plan**

   ```powershell
   .\matchtracker.ps1 init
   .\matchtracker.ps1 plan
   ```

3. **Deploy infrastructure**

   ```powershell
   .\matchtracker.ps1 deploy
   ```

   This creates the EC2 instance, security group, and Elastic IP, and prints the instance IPs.

4. **Push the application code**

   The EC2 user-data script only installs a placeholder app so systemd has something to run on first boot — the real app is deployed separately:

   ```powershell
   .\matchtracker.ps1 codedeploy
   ```

   This copies `app/main.py` to each instance and restarts the `matchtracker` service.

5. **Verify**

   ```powershell
   .\matchtracker.ps1 check
   ```

   Or hit the printed `app_urls` / `health_urls` directly.

6. **Tear down**

   ```powershell
   .\matchtracker.ps1 destroy
   ```

### `matchtracker.ps1` commands (Windows)

| Command      | Description                                  |
|--------------|-----------------------------------------------|
| `dev`        | Run Flask locally                             |
| `test`       | Run tests                                     |
| `init`       | Initialize OpenTofu/Terraform                 |
| `plan`       | Create a deployment plan                      |
| `deploy`     | Apply the plan and provision AWS resources    |
| `codedeploy` | Push `app/main.py` to all instances & restart |
| `destroy`    | Tear down all AWS resources                   |
| `check`      | Hit `/health` on every deployed instance      |
| `ssh`        | SSH into a selected instance                  |
| `ip`         | Print your public IP for `terraform.tfvars`   |
| `dns`        | Print `/etc/hosts`-style entries              |
| `status`     | Show EC2 instance status via AWS CLI          |

### `Makefile` targets (on the EC2 instance, Linux/macOS)

| Target           | Description                          |
|------------------|----------------------------------------|
| `make status`    | systemd status for `matchtracker`      |
| `make logs`      | Tail service logs                      |
| `make restart`   | Restart the `matchtracker` service     |
| `make nginx-status` | Nginx status                        |
| `make nginx-restart` | Test config and restart Nginx      |
| `make health`    | Curl the `/health` endpoint             |
| `make sessions`  | Curl the `/leaderboard` endpoint        |

## Security notes

- Security group opens **port 80** to the world, **port 22** only to `your_ip`, and restricts **port 5000** (Flask) to localhost — Nginx is the only public entry point.

## Tech Stack

- **Backend:** Python, Flask
- **Infra:** OpenTofu/Terraform, AWS (EC2, Security Groups, Elastic IP)
- **Provisioning:** Nginx (reverse proxy), systemd, bash user-data script
- **Tooling:** PowerShell (`matchtracker.ps1`), Make
