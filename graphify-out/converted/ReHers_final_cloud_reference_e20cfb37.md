<!-- converted from ReHers_final_cloud_reference.docx -->

Re-Hers Infrastructure
Complete Reference Document
Generated: 27 March 2026
Owner: Devansh Singh  |  devanshsingh05 (Docker Hub)  |  Azure Region: West US 2

# 1. Architecture Overview
The Re-Hers backend is a PDF-to-sheet-music processing pipeline hosted on Microsoft Azure. It consists of four main components: a FastAPI REST API, an RQ job queue backed by Redis, a Python worker that manages an Azure VM lifecycle, and an Audiveris OMR engine running inside Docker containers on that VM.



# 2. Azure Resources
## 2.1 Resource Group
Name: re-hers-rg
Region: West US 2 (westus2)
Subscription ID: 347dcf40-ead3-40a1-9588-c5dfb198a1b2

## 2.2 Container Apps
API — re-hers-api
Image: rehers0a91cd9d.azurecr.io/api:latest
CPU: 0.25 cores
Memory: 0.5 GB
Ephemeral Storage: 1 GB
Min Replicas: 1  (always on — prevents cold-start 503 errors on iOS)
Max Replicas: 2

Worker — re-hers-worker
Image: rehers0a91cd9d.azurecr.io/worker:latest
CPU: 0.5 cores
Memory: 1 GB
Ephemeral Storage: 2 GB
Min Replicas: 0  (scales to zero when queue is empty)
Max Replicas: 2
Scale Trigger: KEDA Redis scaler — watches rq:queue:sheet_jobs
Scale Rule Name: redis-queue
List Length Threshold: 1  (scales up when 1+ jobs in queue)
Polling Interval: 30 seconds
Cooldown Period: 360 seconds  (6 minutes — must exceed VM_IDLE_SECONDS=300)
KEDA Secret: redis-conn  (Redis password for KEDA authentication)

## 2.3 Container Registry — rehers0a91cd9d
Registry Name: rehers0a91cd9d
Full URL: rehers0a91cd9d.azurecr.io


## 2.4 Audiveris VM — re-hers-audiveris
VM Name: re-hers-audiveris
SKU: Standard_D2as_v7
vCPUs: 2
RAM: 8 GB
OS: Ubuntu 22.04 LTS
Public IP: 20.98.64.247  (static — may change if VM is deleted and recreated)
Private IP: 10.0.0.4
SSH User: azureuser
SSH Key: ~/.ssh/id_rsa  (id_rsa / id_rsa.pub on Devansh's Mac)
Normal State: Deallocated  (only starts when a job arrives, saves cost)

Two Audiveris containers run on this VM simultaneously:
- Container 1: port 8080 — http://20.98.64.247:8080/api/omr
- Container 2: port 8081 — http://20.98.64.247:8081/api/omr
- Image used: rehers0a91cd9d.azurecr.io/worker:stable-v1 (pulled from ACR)

## 2.5 Redis — re-hers-redis
Host: re-hers-redis.redis.cache.windows.net
Port: 6380 (TLS)
Redis URL format: rediss://:PASSWORD@re-hers-redis.redis.cache.windows.net:6380/0
Password: Iuh8YPwlc38KkzgCORcCemdICVAPv3N2IAzCaBZGfpg=
Key: Queue: rq:queue:sheet_jobs
Key: Active Jobs: active_jobs  (shared counter across all worker replicas)
Key: Last Job TS: last_job_ts  (timestamp of last completed job)
Key: VM Lock: audiveris_vm_lock  (distributed lock, 60s TTL)
Key: Port Lock: audiveris_port_8080 / audiveris_port_8081  (960s TTL)


# 3. Docker Hub Backup
Docker Hub Username: devanshsingh05
Docker Hub URL: https://hub.docker.com/u/devanshsingh05


## How to retrieve images from Docker Hub
On any machine with Docker installed:
docker pull devanshsingh05/omr:stable-v1
docker pull devanshsingh05/rehers-api:latest
docker pull devanshsingh05/rehers-worker:latest


# 4. Worker Configuration (worker.py)


# 5. Bug Fix History (27 March 2026)
All fixes applied to worker.py during the debugging session on 27 March 2026:



# 6. Expected Idle State

## Commands to verify idle state
az containerapp replica list --name re-hers-worker --resource-group re-hers-rg --query "[].{name:name, state:properties.runningState}" -o table
az containerapp replica list --name re-hers-api --resource-group re-hers-rg --query "[].{name:name, state:properties.runningState}" -o table
az vm show --name re-hers-audiveris --resource-group re-hers-rg --show-details --query "powerState" -o tsv


# 7. Redeployment Guide (After Azure Credit Expires)
When Azure credit expires or you want to move to a different provider, follow these steps:

## Step 1 — New VM for Audiveris
- Spin up any Linux VM (Ubuntu 22.04, 2 vCPU, 8GB RAM minimum) on any cloud or VPS
- Install Docker on the VM
- Pull the Audiveris image: docker pull devanshsingh05/omr:stable-v1
- Run two containers: docker run -d -p 8080:8080 devanshsingh05/omr:stable-v1
- docker run -d -p 8081:8080 devanshsingh05/omr:stable-v1
- Note the new VM's public IP — update AUDIVERIS_API_URL env var

## Step 2 — New Redis
- Upstash (https://upstash.com) has a free tier Redis with TLS support
- Create a Redis database, copy the connection URL (rediss://... format)
- Update REDIS_URL env var on both API and worker

## Step 3 — Deploy API and Worker
- Any container hosting works: Railway, Render, Fly.io, new Azure subscription
- API image: docker pull devanshsingh05/rehers-api:latest
- Worker image: docker pull devanshsingh05/rehers-worker:latest
- Set all environment variables (see Section 8)
- API min replicas: 1. Worker min replicas: 0 with Redis-based autoscaling

## Step 4 — Supabase
- Supabase is independent of Azure — no migration needed
- Just update SUPABASE_URL and SUPABASE_KEY in the new deployment's env vars


# 8. Required Environment Variables
## API (re-hers-api)

## Worker (re-hers-worker)


# 9. Useful Commands
## VM Management
az vm start --name re-hers-audiveris --resource-group re-hers-rg
az vm deallocate --name re-hers-audiveris --resource-group re-hers-rg --no-wait
az vm show --name re-hers-audiveris --resource-group re-hers-rg --show-details --query "powerState" -o tsv
ssh -i ~/.ssh/id_rsa azureuser@20.98.64.247

## Worker Logs
az containerapp logs show --name re-hers-worker --resource-group re-hers-rg --tail 100
az containerapp logs show --name re-hers-api --resource-group re-hers-rg --tail 50

## Rebuild and Deploy Worker
az acr build --registry rehers0a91cd9d --image worker:latest --file Dockerfile.worker /Users/user30/Documents/Re-Hers/backend
az containerapp update --name re-hers-worker --resource-group re-hers-rg --image rehers0a91cd9d.azurecr.io/worker:latest

## Rebuild and Deploy API
az acr build --registry rehers0a91cd9d --image api:latest --file Dockerfile.api /Users/user30/Documents/Re-Hers/backend
az containerapp update --name re-hers-api --resource-group re-hers-rg --image rehers0a91cd9d.azurecr.io/api:latest

## Check Redis Queue
az containerapp exec --name re-hers-api --resource-group re-hers-rg --command "python -c \"import redis, os; r=redis.from_url(os.environ['REDIS_URL']); print('queue:', r.llen('rq:queue:sheet_jobs')); print('active:', r.get('active_jobs'))\""


# 10. Application Limits
Max PDF upload size: 10 MB  (enforced in iOS app + API)
RQ job timeout: 900 seconds (15 minutes)
Audiveris typical processing time: Under 2 minutes
VM cold start time: ~70 seconds (VM boot) + ~22 seconds (Audiveris processing) = ~90-95s total
Port lock TTL: 960 seconds (must exceed job timeout of 900s)


End of Document  —  Re-Hers Infrastructure Reference  —  27 March 2026
| Component | Role | Hosting |
| --- | --- | --- |
| re-hers-api | FastAPI — receives PDF uploads, enqueues jobs, serves job status | Azure Container Apps |
| re-hers-worker | RQ worker — picks up jobs, starts VM, calls Audiveris, uploads results | Azure Container Apps |
| re-hers-redis | Redis queue (sheet_jobs) + distributed locks + active job counter | Azure Cache for Redis |
| re-hers-audiveris VM | Ubuntu 22.04 VM running 2 Audiveris Docker containers | Azure Virtual Machine |
| Supabase | PostgreSQL database + object storage (PDFs, JSON, labeled PDFs) | Supabase (independent) |
| Repository | Tag | Description | Size |
| --- | --- | --- | --- |
| worker | latest | RQ worker (Python) — current production with all fixes | 82.83 MB |
| api | latest | FastAPI backend — current production | 59.3 MB |
| worker | stable-v1 | Audiveris OMR engine — runs inside VM on ports 8080/8081 | 340 MB |
| Docker Hub Image | Tag | Source (ACR) | Description | Backed Up |
| --- | --- | --- | --- | --- |
| devanshsingh05/omr | stable-v1 | worker:stable-v1 | Audiveris OMR engine for VM | 27 Mar 2026 |
| devanshsingh05/rehers-api | latest | api:latest | FastAPI backend | 27 Mar 2026 |
| devanshsingh05/rehers-worker | latest | worker:latest | RQ worker with all bug fixes | 27 Mar 2026 |
| Constant | Value | Purpose |
| --- | --- | --- |
| QUEUE_NAME | sheet_jobs | RQ queue name |
| VM_IDLE_SECONDS | 300 | Grace period before VM deallocates (5 min). Must be < KEDA cooldownPeriod (360s) |
| VM_LOCK_TIMEOUT | 60s | Max time to hold the distributed VM start/stop lock |
| VM_READY_TIMEOUT_SECONDS | 300s | Max time to wait for Audiveris to become reachable after VM boot |
| PORT_LOCK_TTL | 960s | How long a port lock is held (must exceed RQ job timeout of 900s) |
| MAX_AUDIVERIS_RETRIES | 3 | Retry attempts on transient Audiveris failures |
| AUDIVERIS_PORTS | 8080, 8081 | Two Audiveris containers per VM for concurrency |
| Bug | Root Cause | Fix Applied |
| --- | --- | --- |
| Audiveris call timeout / frontend timeout | ensure_audiveris_ready() had a guard: if queue=0 and active=0 → skip VM start. By the time worker dequeues the job, queue is already 0, so VM was never started. Connection to 20.98.64.247 timed out. | Removed the 4-line guard entirely. VM start is now always attempted if Audiveris is not reachable. |
| VM never deallocated | begin_deallocate() called without .result() — Azure SDK returns a poller, nothing executes unless .result() is called. | Added .result() to all begin_deallocate() and begin_start() calls. |
| Stale active_jobs counter | If worker crashed mid-job, ACTIVE_JOBS_KEY stayed at 1 forever in Redis, preventing deallocation indefinitely. | Reset counter to 0 on every worker startup inside __main__ guard. |
| Worker blocked for 10 min after each job | Old stop_vm_if_idle() called time.sleep(600) synchronously in perform_job's finally block, freezing the worker. | stop_vm_if_idle() now spawns a daemon=False background thread. perform_job returns immediately. |
| VM lock held during 300s readiness poll | Lock was not released before polling, serialising all workers behind a 5-minute cold start. | Lock released immediately after begin_start() is issued, before polling begins. |
| KEDA not scaling worker up | redis-conn secret in KEDA scale rule had wrong/stale value. KEDA could not authenticate to Redis, saw queue=0 always. | Overwrote secret: az containerapp secret set with correct Redis password. |
| API cold-start 503 errors on iOS | min-replicas was 0, Azure returned raw HTML error page before any container started. | Set min-replicas to 1 on re-hers-api. |
| KEDA race with VM idle-stop thread | KEDA cooldownPeriod=300 and VM_IDLE_SECONDS=300 were equal. KEDA killed the container at same time idle thread fired. | Increased KEDA cooldownPeriod to 360s, giving idle thread a 60s buffer to complete deallocation. |
| Component | Expected Idle State | Why |
| --- | --- | --- |
| re-hers-worker | NotRunning / 0 replicas | KEDA scales to zero after 360s of empty queue |
| re-hers-api | Running / 1 replica | min-replicas=1, always on |
| re-hers-audiveris VM | VM deallocated | idle-stop thread deallocates after 300s of no jobs |
| Redis | Running | Managed service, always on |
| Supabase | Running | Independent of Azure, always on |
| Variable | Description |
| --- | --- |
| REDIS_URL | rediss://:PASSWORD@HOST:6380/0 |
| SUPABASE_URL | https://your-project.supabase.co |
| SUPABASE_KEY | Service role key from Supabase dashboard |
| Variable | Description |
| --- | --- |
| REDIS_URL | Same as API |
| SUPABASE_URL | Same as API |
| SUPABASE_KEY | Same as API |
| AUDIVERIS_API_URL | http://VM_IP:8080/api/omr  (port 8080 base URL) |
| AZURE_TENANT_ID | 5dbead07-c6b4-4624-aa15-8185606b546c |
| AZURE_CLIENT_ID | Service principal client ID |
| AZURE_CLIENT_SECRET | Service principal client secret |
| AZURE_SUBSCRIPTION_ID | 347dcf40-ead3-40a1-9588-c5dfb198a1b2 |
| AZURE_RESOURCE_GROUP | re-hers-rg |
| AUDIVERIS_VM_NAME | re-hers-audiveris |