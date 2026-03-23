# Azure Deployment

## 1. Azure CLI Setup
```bash
az extension add --name containerapp --upgrade

export LOCATION="eastus"
export RESOURCE_GROUP="re-hers-rg"
export ACA_ENV="re-hers-aca-env"
export ACR_NAME="<globallyuniquename>"
export API_APP="re-hers-api"
export WORKER_APP="re-hers-worker"
export REDIS_NAME="re-hers-redis"
export AUDIVERIS_VM="re-hers-audiveris"
export ADMIN_USERNAME="azureuser"

az login
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
az account set --subscription "${SUBSCRIPTION_ID}"

az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"
az containerapp env create \
  --name "${ACA_ENV}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}"
```

## 2. Build Images
```bash
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --sku Basic \
  --admin-enabled true

export ACR_SERVER="$(az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query loginServer -o tsv)"
export ACR_USERNAME="$(az acr credential show --name "${ACR_NAME}" --query username -o tsv)"
export ACR_PASSWORD="$(az acr credential show --name "${ACR_NAME}" --query passwords[0].value -o tsv)"

az acr build \
  --registry "${ACR_NAME}" \
  --image api:latest \
  --file Dockerfile.api \
  /Users/user30/Documents/Re-Hers/backend

az acr build \
  --registry "${ACR_NAME}" \
  --image worker:latest \
  --file Dockerfile.worker \
  /Users/user30/Documents/Re-Hers/backend
```

## 3. Redis
```bash
az redis create \
  --name "${REDIS_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Basic \
  --vm-size C0

export REDIS_HOST="$(az redis show --name "${REDIS_NAME}" --resource-group "${RESOURCE_GROUP}" --query hostName -o tsv)"
export REDIS_KEY="$(az redis list-keys --name "${REDIS_NAME}" --resource-group "${RESOURCE_GROUP}" --query primaryKey -o tsv)"
export REDIS_URL="rediss://:${REDIS_KEY}@${REDIS_HOST}:6380/0"
```

## 4. Audiveris VM
```bash
az vm create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AUDIVERIS_VM}" \
  --image Ubuntu2204 \
  --size Standard_D4s_v5 \
  --admin-username "${ADMIN_USERNAME}" \
  --generate-ssh-keys

az vm open-port \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AUDIVERIS_VM}" \
  --port 8080 \
  --priority 1001

export AUDIVERIS_VM_PUBLIC_IP="$(az vm show --show-details --resource-group "${RESOURCE_GROUP}" --name "${AUDIVERIS_VM}" --query publicIps -o tsv)"
export AUDIVERIS_API_URL="http://${AUDIVERIS_VM_PUBLIC_IP}:8080/api/omr"

az vm run-command invoke \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AUDIVERIS_VM}" \
  --command-id RunShellScript \
  --scripts \
    "sudo apt-get update" \
    "sudo apt-get install -y docker.io" \
    "sudo systemctl enable docker" \
    "sudo systemctl start docker" \
    "sudo docker pull <AUDIVERIS_IMAGE>" \
    "sudo docker rm -f audiveris || true" \
    "sudo docker run -d --name audiveris --restart unless-stopped -p 8080:8080 -e JAVA_OPTS='-Xmx2G' <AUDIVERIS_IMAGE>"
```

## 5. Service Principal
```bash
export SP_JSON="$(az ad sp create-for-rbac \
  --name "http://re-hers-worker-sp" \
  --role "Virtual Machine Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --sdk-auth)"

export AZURE_CLIENT_ID="$(printf '%s' "${SP_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["clientId"])')"
export AZURE_CLIENT_SECRET="$(printf '%s' "${SP_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["clientSecret"])')"
export AZURE_TENANT_ID="$(printf '%s' "${SP_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tenantId"])')"
```

## 6. API Container App
```bash
az containerapp create \
  --name "${API_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --environment "${ACA_ENV}" \
  --image "${ACR_SERVER}/api:latest" \
  --registry-server "${ACR_SERVER}" \
  --registry-username "${ACR_USERNAME}" \
  --registry-password "${ACR_PASSWORD}" \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 4 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    "REDIS_URL=${REDIS_URL}" \
    "AUDIVERIS_API_URL=${AUDIVERIS_API_URL}" \
    "SUPABASE_URL=<SUPABASE_URL>" \
    "SUPABASE_KEY=<SUPABASE_KEY>" \
    "ALLOWED_ORIGINS=<ALLOWED_ORIGINS>" \
    "ADMIN_USER_IDS=<ADMIN_USER_IDS>"
```

## 7. Worker Container App
```bash
az containerapp create \
  --name "${WORKER_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --environment "${ACA_ENV}" \
  --image "${ACR_SERVER}/worker:latest" \
  --registry-server "${ACR_SERVER}" \
  --registry-username "${ACR_USERNAME}" \
  --registry-password "${ACR_PASSWORD}" \
  --min-replicas 0 \
  --max-replicas 4 \
  --cpu 1.0 \
  --memory 2.0Gi \
  --secrets \
    "redis-password=${REDIS_KEY}" \
    "azure-client-secret=${AZURE_CLIENT_SECRET}" \
  --env-vars \
    "REDIS_URL=${REDIS_URL}" \
    "AUDIVERIS_API_URL=${AUDIVERIS_API_URL}" \
    "AUDIVERIS_VM_NAME=${AUDIVERIS_VM}" \
    "AZURE_RESOURCE_GROUP=${RESOURCE_GROUP}" \
    "AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}" \
    "AZURE_TENANT_ID=${AZURE_TENANT_ID}" \
    "AZURE_CLIENT_ID=${AZURE_CLIENT_ID}" \
    "AZURE_CLIENT_SECRET=secretref:azure-client-secret" \
    "SUPABASE_URL=<SUPABASE_URL>" \
    "SUPABASE_KEY=<SUPABASE_KEY>" \
  --scale-rule-name "redis-queue" \
  --scale-rule-type "redis" \
  --scale-rule-metadata \
    "address=${REDIS_HOST}:6380" \
    "listName=rq:queue:sheet_jobs" \
    "listLength=1" \
    "enableTLS=true" \
  --scale-rule-auth "password=redis-password"
```

## 8. curl Tests
```bash
export API_FQDN="$(az containerapp show --name "${API_APP}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv)"
export API_URL="https://${API_FQDN}"
export SUPABASE_JWT="<SUPABASE_JWT>"
export TEST_FILE="/absolute/path/to/test.pdf"

curl "${API_URL}/health"

JOB_ID="$(
  curl -s -X POST "${API_URL}/convert" \
    -H "Authorization: Bearer ${SUPABASE_JWT}" \
    -F "file=@${TEST_FILE};type=application/pdf" | python3 -c 'import json,sys; print(json.load(sys.stdin)["job_id"])'
)"

curl -s "${API_URL}/jobs/${JOB_ID}" \
  -H "Authorization: Bearer ${SUPABASE_JWT}"

curl -s -o /dev/null -w "%{http_code}\n" -X POST "${AUDIVERIS_API_URL}"
```
