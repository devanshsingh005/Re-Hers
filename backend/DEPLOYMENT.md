# Deployment Guide — Redis + RQ + Supervisor

## Local Development (macOS)

### 1. Install Dependencies
```bash
brew install redis supervisor
```

### 2. Start Services
```bash
brew services start redis
brew services start supervisor
```

### 3. Install Python Packages
```bash
.venv/bin/pip install -r requirements.txt
```

### 4. Configure Supervisor
Copy [supervisor.conf](supervisor.conf) to the Supervisor config directory:
```bash
mkdir -p /opt/homebrew/etc/supervisor.d/
cp supervisor.conf /opt/homebrew/etc/supervisor.d/backend.ini
```

### 5. Start All Processes
```bash
supervisorctl reread
supervisorctl update
supervisorctl start all
```

### 6. Verify Status
```bash
supervisorctl status          # Should show 5 RUNNING processes
.venv/bin/rq info             # Should show 4 workers on sheet_jobs queue
curl http://localhost:8000/health  # Should return {"status":"healthy"}
```

---

## Production Deployment (Ubuntu)

### 1. Install Dependencies
```bash
sudo apt-get update
sudo apt-get install redis-server supervisor python3.11 python3.11-venv
```

### 2. Start Services
```bash
sudo systemctl start redis-server
sudo systemctl start supervisor
```

### 3. Create Virtual Environment & Install Packages
```bash
cd /home/ubuntu/Re-Hers/backend
python3.11 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 4. Configure Supervisor
Update [supervisor.conf](supervisor.conf) with Ubuntu paths:
```bash
# Change all:
#   /Users/user30/Documents/Re-Hers/backend → /home/ubuntu/Re-Hers/backend
#   /opt/homebrew/etc → /etc/supervisor/conf.d

cp supervisor.conf /etc/supervisor/conf.d/backend.conf
```

### 5. Set Permissions
```bash
sudo chown -R ubuntu:ubuntu /home/ubuntu/Re-Hers/backend/logs
sudo chmod 755 /home/ubuntu/Re-Hers/backend/logs
```

### 6. Start All Processes
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

### 7. Verify Status
```bash
sudo supervisorctl status
.venv/bin/rq info --url redis://localhost:6379
curl http://localhost:8000/health
```

### 8. Enable Auto-Start on Reboot
```bash
sudo systemctl enable redis-server
sudo systemctl enable supervisor
```

---

## What's Running

**FastAPI Server** (port 8000):
- `/health` — Health check
- `/convert` — Upload & queue PDF for processing

**RQ Workers** (4 processes):
- Listen on `sheet_jobs` queue
- Process one PDF at a time
- Auto-restart on crash via Supervisor

**Redis**:
- Stores job queue
- Port: 6379
- No authentication (local dev; add in production)

---

## Environment Variables

Create `.env` in project root:
```bash
REDIS_URL=redis://localhost:6379
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-api-key
AUDIVERIS_API_URL=http://audiveris:8080
```

---

## Scaling Workers

Add more workers by adding entries to `supervisor.conf`:
```ini
[program:worker5]
directory=/home/ubuntu/Re-Hers/backend
command=/home/ubuntu/Re-Hers/backend/.venv/bin/python worker.py
autostart=true
autorestart=true
stderr_logfile=/home/ubuntu/Re-Hers/backend/logs/worker5.err.log
```

Then reload:
```bash
supervisorctl reread && supervisorctl update
```

---

## Files Modified for Deployment

| File | Change |
|------|--------|
| `app/queue.py` | Redis queue implementation |
| `app/dispatcher.py` | Worker function (RQ entry point) |
| `app/main.py` | Redis startup check + enqueue |
| `app/config.py` | Settings class with REDIS_URL |
| `app/database.py` | Python timestamps (not SQL "now()") |
| `requirements.txt` | Added rq==1.16.2 |
| `worker.py` | New: Worker process entry point |
| `supervisor.conf` | New: Process manager config |
| `.env` | Added REDIS_URL |

---

## Monitoring

### Check Queue Depth
```bash
.venv/bin/rq info --url redis://localhost:6379
```

### Watch Jobs in Real-Time
```bash
watch -n 1 '.venv/bin/rq info --url redis://localhost:6379'
```

### View Worker Logs
```bash
tail -f logs/worker1.err.log logs/worker2.err.log logs/worker3.err.log logs/worker4.err.log
```

### Check FastAPI Logs
```bash
tail -f logs/fastapi.err.log
```

### Query Redis Directly
```bash
redis-cli
> KEYS *                    # See all keys
> HGETALL rq:job:xyz...    # Inspect job details
```

---

## Troubleshooting

### Workers Not Processing Jobs
```bash
# Check if workers are running
supervisorctl status worker1 worker2 worker3 worker4

# Check if Redis is reachable
redis-cli ping  # Should respond PONG

# Check queue status
.venv/bin/rq info

# View worker logs for errors
tail logs/worker*.err.log
```

### FastAPI Not Starting
```bash
# Check Redis connection
.venv/bin/python -c "import redis; redis.from_url('redis://localhost:6379').ping()"

# View error logs
tail logs/fastapi.err.log

# Check if port 8000 is in use
lsof -i :8000
```

### Stuck Jobs
Jobs automatically marked failed if processing >15 minutes. Check logs:
```bash
tail logs/worker*.err.log | grep -i error
```

---

## Backup & Recovery

### Backup Redis Data
```bash
redis-cli BGSAVE  # Creates dump.rdb
cp /path/to/dump.rdb /backup/location/
```

### Restore from Backup
```bash
cp /backup/location/dump.rdb /var/lib/redis/  # or Homebrew Redis path
redis-cli shutdown
redis-server  # Restart
```

---

## Security Notes

- **Local Dev**: No authentication needed
- **Production**: 
  - Enable Redis password: `requirepass` in redis.conf
  - Update REDIS_URL: `redis://:password@host:6379`
  - Use HTTPS for FastAPI (nginx/HAProxy reverse proxy)
  - Restrict Redis to localhost or private network

---

## Next Steps

1. **Test locally** with load testing tools (`hey`)
2. **Integration test** with real Supabase + Audiveris API
3. **Deploy to production** following Ubuntu steps above
4. **Monitor queue** using commands in Monitoring section
5. **Scale workers** as needed using Scaling section
