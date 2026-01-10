# 🔄 Integración CI/CD End-to-End

Plan completo para automatizar el flujo: **Code Push → Build → Test → Deploy a K8s**

---

## 🎯 Objetivo

Cuando se haga **push a main** en `jobdirect-app` o `jobdirect-backend`:
1. ✅ Build de imagen Docker
2. ✅ Push a DockerHub con tag `dev`
3. ✅ **Deploy automático a AKS DEV**

---

## 📋 Estado Actual vs Deseado

### Estado Actual

**jobdirect-app & jobdirect-backend:**
- ✅ Tienen workflow `dockerhub.yml`
- ❌ Es **manual** (workflow_dispatch)
- ❌ Solo hace build + push
- ❌ **NO despliega** a Kubernetes

**jobdirect-infra:**
- ✅ Tiene workflow `k8s-deploy.yml`
- ❌ Es **manual** (workflow_dispatch)
- ❌ **NO se dispara** automáticamente

### Estado Deseado

```
┌─────────────────────────────────────────────────────────────┐
│  DEVELOPER PUSH TO MAIN                                      │
│  (jobdirect-app o jobdirect-backend)                         │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: CI - Build & Push Docker Image                     │
│  (workflow en jobdirect-app/backend)                         │
│  - Run tests                                                 │
│  - Build Docker image                                        │
│  - Push to DockerHub with tag: dev + git-sha                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: CD - Trigger Deploy                                │
│  (repository_dispatch event a jobdirect-infra)               │
│  - Notificar que nueva imagen está lista                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Deploy to AKS DEV                                  │
│  (workflow en jobdirect-infra)                               │
│  - Conectar a AKS                                            │
│  - kubectl apply con nueva imagen                            │
│  - kubectl rollout status                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Solución: Workflows Mejorados

### 1. Nuevo workflow para jobdirect-app

**Archivo:** `jobdirect-app/.github/workflows/ci-cd-dev.yml` (NUEVO)

```yaml
name: CI/CD - Auto Deploy to DEV

on:
  push:
    branches:
      - main
    paths-ignore:
      - '**.md'
      - 'docs/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get short Git SHA
        id: vars
        run: echo "SHORT_SHA=${GITHUB_SHA::7}" >> $GITHUB_OUTPUT

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      # Run tests
      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run linter
        run: npm run lint

      # Build Docker image
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build & Push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-app:dev
            ${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-app:${{ steps.vars.outputs.SHORT_SHA }}

      # Trigger deploy to AKS
      - name: Trigger deployment to AKS DEV
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.INFRA_DEPLOY_TOKEN }}
          repository: Company-Oferrer/jobdirect-infra
          event-type: deploy-frontend-dev
          client-payload: |
            {
              "image_tag": "${{ steps.vars.outputs.SHORT_SHA }}",
              "triggered_by": "${{ github.actor }}",
              "commit_sha": "${{ github.sha }}"
            }
```

### 2. Nuevo workflow para jobdirect-backend

**Archivo:** `jobdirect-backend/.github/workflows/ci-cd-dev.yml` (NUEVO)

```yaml
name: CI/CD - Auto Deploy to DEV

on:
  push:
    branches:
      - main
    paths-ignore:
      - '**.md'
      - 'docs/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get short Git SHA
        id: vars
        run: echo "SHORT_SHA=${GITHUB_SHA::7}" >> $GITHUB_OUTPUT

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      # Run tests
      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run linter
        run: npm run lint

      # Build Docker image
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build & Push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-backend:dev
            ${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-backend:${{ steps.vars.outputs.SHORT_SHA }}

      # Trigger deploy to AKS
      - name: Trigger deployment to AKS DEV
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.INFRA_DEPLOY_TOKEN }}
          repository: Company-Oferrer/jobdirect-infra
          event-type: deploy-backend-dev
          client-payload: |
            {
              "image_tag": "${{ steps.vars.outputs.SHORT_SHA }}",
              "triggered_by": "${{ github.actor }}",
              "commit_sha": "${{ github.sha }}"
            }
```

### 3. Nuevo workflow receptor en jobdirect-infra

**Archivo:** `jobdirect-infra/.github/workflows/auto-deploy-dev.yml` (NUEVO)

```yaml
name: Auto Deploy to DEV (triggered by apps)

on:
  repository_dispatch:
    types:
      - deploy-frontend-dev
      - deploy-backend-dev

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev

    steps:
      - name: Checkout infra code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Get AKS Credentials
        run: |
          az aks get-credentials \
            --resource-group rg-jobdirect-dev-eastus-01 \
            --name aks-jobdirect-dev-eastus-01 \
            --overwrite-existing

      - name: Deploy Frontend (if triggered)
        if: github.event.action == 'deploy-frontend-dev'
        run: |
          echo "Deploying frontend with image tag: ${{ github.event.client_payload.image_tag }}"

          # Update image tag in deployment
          kubectl set image deployment/jobdirect-app \
            frontend=${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-app:${{ github.event.client_payload.image_tag }} \
            --record

          # Wait for rollout
          kubectl rollout status deployment/jobdirect-app --timeout=300s

      - name: Deploy Backend (if triggered)
        if: github.event.action == 'deploy-backend-dev'
        run: |
          echo "Deploying backend with image tag: ${{ github.event.client_payload.image_tag }}"

          # Update image tag in deployment
          kubectl set image deployment/jobdirect-backend \
            backend=${{ secrets.DOCKERHUB_USERNAME }}/jobdirect-backend:${{ github.event.client_payload.image_tag }} \
            --record

          # Wait for rollout
          kubectl rollout status deployment/jobdirect-backend --timeout=300s

      - name: Verify Deployment
        run: |
          echo "## Deployment Status" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Pods" >> $GITHUB_STEP_SUMMARY
          kubectl get pods >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Recent Events" >> $GITHUB_STEP_SUMMARY
          kubectl get events --sort-by='.lastTimestamp' | tail -10 >> $GITHUB_STEP_SUMMARY

      - name: Notify Deployment
        run: |
          echo "✅ Deployment completed!"
          echo "Triggered by: ${{ github.event.client_payload.triggered_by }}"
          echo "Image tag: ${{ github.event.client_payload.image_tag }}"
          echo "Source commit: ${{ github.event.client_payload.commit_sha }}"
```

---

## 🔑 Configuración de Secrets

### En jobdirect-app y jobdirect-backend (agregar):

| Secret Name | Valor | Descripción |
|------------|-------|-------------|
| `INFRA_DEPLOY_TOKEN` | Personal Access Token (PAT) | Token para disparar workflow en jobdirect-infra |
| `DOCKERHUB_USERNAME` | tu-usuario | Ya existe |
| `DOCKERHUB_TOKEN` | tu-token | Ya existe |

### En jobdirect-infra (ya existen):

| Secret Name | Valor |
|------------|-------|
| `AZURE_CREDENTIALS` | Service Principal JSON |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `DOCKERHUB_USERNAME` | tu-usuario |

---

## 📝 Pasos de Implementación

### Paso 1: Crear Personal Access Token (PAT)

```bash
# En GitHub:
1. Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Nombre: "jobdirect-infra-deploy"
4. Scopes:
   ✅ repo (all)
   ✅ workflow
5. Generate token
6. COPIAR EL TOKEN (no se volverá a mostrar)
```

### Paso 2: Agregar secrets en jobdirect-app

```bash
# GitHub → jobdirect-app → Settings → Secrets → Actions
# New repository secret:
Name: INFRA_DEPLOY_TOKEN
Value: (pegar el PAT del paso 1)
```

### Paso 3: Agregar secrets en jobdirect-backend

```bash
# GitHub → jobdirect-backend → Settings → Secrets → Actions
# New repository secret:
Name: INFRA_DEPLOY_TOKEN
Value: (pegar el PAT del paso 1)
```

### Paso 4: Agregar DOCKERHUB_USERNAME en jobdirect-infra

```bash
# GitHub → jobdirect-infra → Settings → Secrets → Actions
# New repository secret:
Name: DOCKERHUB_USERNAME
Value: tu-usuario-dockerhub
```

### Paso 5: Crear nuevos workflows

**En jobdirect-app:**
```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-app
# Crear archivo: .github/workflows/ci-cd-dev.yml
# (copiar contenido del workflow de arriba)

git add .github/workflows/ci-cd-dev.yml
git commit -m "feat: add auto-deploy to DEV workflow"
git push
```

**En jobdirect-backend:**
```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-backend
# Crear archivo: .github/workflows/ci-cd-dev.yml
# (copiar contenido del workflow de arriba)

git add .github/workflows/ci-cd-dev.yml
git commit -m "feat: add auto-deploy to DEV workflow"
git push
```

**En jobdirect-infra:**
```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-infra
# Crear archivo: .github/workflows/auto-deploy-dev.yml
# (copiar contenido del workflow de arriba)

git add .github/workflows/auto-deploy-dev.yml
git commit -m "feat: add auto-deploy receiver workflow"
git push
```

---

## 🧪 Prueba del Flujo Completo

### Test 1: Deploy automático del Frontend

```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-app

# Hacer un cambio pequeño
echo "// CI/CD test" >> src/App.tsx

# Commit y push a main
git add .
git commit -m "test: trigger auto-deploy"
git push origin main
```

**Resultado esperado:**
1. ✅ Workflow `CI/CD - Auto Deploy to DEV` se ejecuta en jobdirect-app
2. ✅ Build + tests + Docker push se completan
3. ✅ Se dispara workflow `Auto Deploy to DEV` en jobdirect-infra
4. ✅ Nueva imagen se despliega en AKS DEV
5. ✅ Pods se reinician con nueva versión

### Test 2: Deploy automático del Backend

```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-backend

# Hacer un cambio pequeño
echo "// CI/CD test" >> index.js

# Commit y push a main
git add .
git commit -m "test: trigger auto-deploy"
git push origin main
```

---

## 📊 Diagrama de Flujo Final

```
┌─────────────────────────────────────────────────────────────┐
│  DEV PUSH TO jobdirect-app/main                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  ci-cd-dev.yml (jobdirect-app)                               │
│  ├─ npm test                                                 │
│  ├─ npm run lint                                             │
│  ├─ docker build & push :dev                                 │
│  └─ repository_dispatch → jobdirect-infra                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  auto-deploy-dev.yml (jobdirect-infra)                       │
│  ├─ kubectl set image deployment/jobdirect-app               │
│  ├─ kubectl rollout status                                   │
│  └─ ✅ DEPLOYED                                              │
└─────────────────────────────────────────────────────────────┘

(El mismo flujo para jobdirect-backend)
```

---

## ✅ Ventajas de esta Solución

1. ✅ **Automático**: Push a main → deploy automático a DEV
2. ✅ **Separación de responsabilidades**:
   - App repos: Build + Test + Push imagen
   - Infra repo: Deploy a K8s
3. ✅ **Trazabilidad**: Cada deploy referencia el commit de origen
4. ✅ **Rollback fácil**: Tags por git-sha permiten volver atrás
5. ✅ **Workflow manual sigue existiendo**: `dockerhub.yml` para QA/PROD

---

## 🎯 Resumen de Cambios

### Archivos a CREAR:

1. `jobdirect-app/.github/workflows/ci-cd-dev.yml`
2. `jobdirect-backend/.github/workflows/ci-cd-dev.yml`
3. `jobdirect-infra/.github/workflows/auto-deploy-dev.yml`

### Secrets a AGREGAR:

1. En `jobdirect-app`: `INFRA_DEPLOY_TOKEN`
2. En `jobdirect-backend`: `INFRA_DEPLOY_TOKEN`
3. En `jobdirect-infra`: `DOCKERHUB_USERNAME`

### Workflows EXISTENTES:

- ✅ `dockerhub.yml` en app/backend: Mantener para deploys manuales QA/PROD
- ✅ `ci.yml` en app/backend: Mantener para PRs
- ✅ Workflows de infra: Mantener para despliegues manuales

---

¿Quieres que creemos estos archivos ahora?
