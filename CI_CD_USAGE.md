# 🚀 Guía de Uso: CI/CD Integrado

## 📋 Resumen del Flujo

### DEV (Automático)
```
Push a main → Build + Test → DockerHub → Deploy a K8s DEV
```

### QA/PROD (Manual)
```
Workflow Manual → Build → DockerHub → (Opcional) Deploy a K8s
```

---

## 🔧 Configuración Inicial (Una Sola Vez)

### 1. Crear Personal Access Token (PAT)

1. Ve a GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click en "Generate new token (classic)"
3. Configuración:
   - **Name:** `jobdirect-infra-deploy`
   - **Expiration:** 90 days (o más)
   - **Scopes:**
     - ✅ `repo` (all)
     - ✅ `workflow`
4. Click "Generate token"
5. **COPIAR EL TOKEN** (no se volverá a mostrar)

### 2. Configurar Secrets en Repositorios

#### En `jobdirect-app`:
```
Settings → Secrets and variables → Actions → New repository secret

Name: INFRA_DEPLOY_TOKEN
Value: [pegar el PAT del paso 1]
```

#### En `jobdirect-backend`:
```
Settings → Secrets and variables → Actions → New repository secret

Name: INFRA_DEPLOY_TOKEN
Value: [pegar el PAT del paso 1]
```

#### En `jobdirect-infra`:
```
Settings → Secrets and variables → Actions → New repository secret

Name: DOCKERHUB_USERNAME
Value: companyoferrer (o tu usuario de DockerHub)
```

### 3. Verificar Secrets Existentes

Asegúrate de que estos secrets YA EXISTEN en cada repositorio:

**jobdirect-app y jobdirect-backend:**
- ✅ `DOCKERHUB_USERNAME`
- ✅ `DOCKERHUB_TOKEN`

**jobdirect-infra:**
- ✅ `AZURE_CREDENTIALS`
- ✅ `AZURE_SUBSCRIPTION_ID`

---

## 🎯 Uso del CI/CD

### Escenario 1: Deploy Automático a DEV (Frontend)

**Acción:** Hacer push a `main` en `jobdirect-app`

```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-app

# Hacer un cambio
echo "// Updated" >> src/App.tsx

# Commit y push
git add .
git commit -m "feat: add new feature"
git push origin main
```

**Lo que sucede automáticamente:**

1. ✅ Se ejecuta workflow `CI/CD - Auto Deploy to DEV` en jobdirect-app
2. ✅ Corre tests y linter
3. ✅ Build de imagen Docker
4. ✅ Push a DockerHub con tags:
   - `companyoferrer/jobdirect-app:dev`
   - `companyoferrer/jobdirect-app:abc1234` (git SHA)
5. ✅ Dispara evento `deploy-frontend-dev` a jobdirect-infra
6. ✅ Se ejecuta workflow `Auto Deploy to DEV` en jobdirect-infra
7. ✅ Actualiza deployment en AKS DEV
8. ✅ Espera a que los pods estén listos (300s timeout)
9. ✅ Muestra status de deployment

**Monitoreo:**
```
GitHub → jobdirect-app → Actions → CI/CD - Auto Deploy to DEV
GitHub → jobdirect-infra → Actions → Auto Deploy to DEV
```

---

### Escenario 2: Deploy Automático a DEV (Backend)

**Acción:** Hacer push a `main` en `jobdirect-backend`

```bash
cd D:\PROYECTO_INTEGRADOR\jobdirect-backend

# Hacer un cambio
echo "// Updated" >> index.js

# Commit y push
git add .
git commit -m "fix: fix bug in API"
git push origin main
```

**Lo que sucede automáticamente:**

1. ✅ Se ejecuta workflow `CI/CD - Auto Deploy to DEV` en jobdirect-backend
2. ✅ Corre tests y linter
3. ✅ Build de imagen Docker
4. ✅ Push a DockerHub con tags:
   - `companyoferrer/jobdirect-backend:dev`
   - `companyoferrer/jobdirect-backend:abc1234`
5. ✅ Dispara evento `deploy-backend-dev` a jobdirect-infra
6. ✅ Se ejecuta workflow `Auto Deploy to DEV` en jobdirect-infra
7. ✅ Actualiza deployment en AKS DEV
8. ✅ Rolling update de pods

---

### Escenario 3: Deploy Manual a QA (Frontend)

**Acción:** Ejecutar workflow manualmente

1. Ve a: `GitHub → jobdirect-app → Actions → CD - Deploy Frontend to DockerHub (Manual QA/PROD)`
2. Click en "Run workflow"
3. Configuración:
   - **ambiente:** `qa`
   - **¿Disparar deploy automático a K8s?** `true` ✅ (checked)
4. Click "Run workflow"

**Lo que sucede:**

1. ✅ Build y push a DockerHub:
   - `companyoferrer/jobdirect-app:qa`
   - `companyoferrer/jobdirect-app:abc1234`
2. ✅ Dispara evento `deploy-frontend-qa` a jobdirect-infra
3. ✅ Se ejecuta workflow `Auto Deploy to QA/PROD` en jobdirect-infra
4. ✅ Actualiza deployment en AKS QA
5. ✅ Rolling update

---

### Escenario 4: Deploy Manual a PROD (Backend)

**Acción:** Ejecutar workflow manualmente

1. Ve a: `GitHub → jobdirect-backend → Actions → CD - Deploy Backend to DockerHub (Manual QA/PROD)`
2. Click en "Run workflow"
3. Configuración:
   - **ambiente:** `prod`
   - **¿Disparar deploy automático a K8s?** `true` ✅
4. Click "Run workflow"

**Lo que sucede:**

1. ✅ Build y push a DockerHub:
   - `companyoferrer/jobdirect-backend:prod`
   - `companyoferrer/jobdirect-backend:latest`
   - `companyoferrer/jobdirect-backend:abc1234`
2. ✅ Dispara evento `deploy-backend-prod` a jobdirect-infra
3. ✅ Se ejecuta workflow `Auto Deploy to QA/PROD` en jobdirect-infra
4. ✅ Actualiza deployment en AKS PROD

---

### Escenario 5: Solo Build (Sin Deploy)

Si quieres hacer build sin desplegar a K8s:

1. Ve al workflow manual (QA/PROD)
2. Configuración:
   - **ambiente:** `qa` o `prod`
   - **¿Disparar deploy automático a K8s?** `false` ❌ (unchecked)
3. Click "Run workflow"

**Resultado:** Solo se hace build y push a DockerHub, sin deploy a K8s.

---

## 🔍 Verificación de Deployments

### Ver Pods en AKS DEV

```bash
# Conectar a AKS DEV
az aks get-credentials \
  --resource-group rg-jobdirect-dev-eastus-01 \
  --name aks-jobdirect-dev-eastus-01 \
  --overwrite-existing

# Ver pods
kubectl get pods

# Ver deployments
kubectl get deployments

# Ver logs del frontend
kubectl logs deployment/jobdirect-app -f

# Ver logs del backend
kubectl logs deployment/jobdirect-backend -f

# Ver servicios y IPs externas
kubectl get svc
```

### Ver Status en GitHub

1. **jobdirect-app → Actions:**
   - `CI/CD - Auto Deploy to DEV` (se ejecuta en cada push a main)
   - `CD - Deploy Frontend to DockerHub (Manual QA/PROD)` (manual)

2. **jobdirect-backend → Actions:**
   - `CI/CD - Auto Deploy to DEV` (se ejecuta en cada push a main)
   - `CD - Deploy Backend to DockerHub (Manual QA/PROD)` (manual)

3. **jobdirect-infra → Actions:**
   - `Auto Deploy to DEV` (se dispara por eventos de app/backend)
   - `Auto Deploy to QA/PROD` (se dispara por eventos de app/backend)

---

## 🐛 Troubleshooting

### Error: "Resource not accessible by personal access token"

**Causa:** El PAT no tiene los permisos correctos o no está configurado.

**Solución:**
1. Verifica que el PAT tiene scopes `repo` y `workflow`
2. Verifica que `INFRA_DEPLOY_TOKEN` está configurado en jobdirect-app y jobdirect-backend

### Error: "deployment.apps \"jobdirect-app\" not found"

**Causa:** El deployment no existe en AKS.

**Solución:**
```bash
# Crear deployments manualmente primero
kubectl apply -f kubernetes/jobdirect-app.yaml
kubectl apply -f kubernetes/jobdirect-backend.yaml
```

### Error: Tests Failing

**Causa:** Los tests fallan en CI/CD, bloqueando el deploy.

**Solución temporal para testing:**
```yaml
# En ci-cd-dev.yml, comentar temporalmente:
# - name: Run tests
#   run: npm test
```

### Workflow No Se Dispara

**Causa:** Cambios solo en archivos .md

**Solución:** Los workflows ignoran cambios en:
- `**.md`
- `docs/**`

Si quieres forzar el workflow, haz un cambio en código real o elimina `paths-ignore`.

---

## 📊 Diagrama de Flujo Completo

```
┌─────────────────────────────────────────────────────────────┐
│  DEVELOPER PUSH TO MAIN (jobdirect-app)                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  CI/CD - Auto Deploy to DEV (jobdirect-app)                 │
│  ├─ npm ci                                                   │
│  ├─ npm test                                                 │
│  ├─ npm run lint                                             │
│  ├─ docker build & push :dev                                │
│  └─ repository_dispatch → jobdirect-infra                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Auto Deploy to DEV (jobdirect-infra)                       │
│  ├─ Azure Login                                              │
│  ├─ Get AKS Credentials                                      │
│  ├─ kubectl set image deployment/jobdirect-app              │
│  ├─ kubectl rollout status                                   │
│  └─ ✅ DEPLOYED                                              │
└─────────────────────────────────────────────────────────────┘
```

**Para QA/PROD:** Mismo flujo pero iniciado manualmente via workflow_dispatch.

---

## 🎯 Resumen de Workflows

| Workflow | Repositorio | Trigger | Deploy | Entornos |
|---------|-------------|---------|--------|----------|
| `CI/CD - Auto Deploy to DEV` | app/backend | Push a main | Automático | DEV |
| `CD - Deploy to DockerHub (Manual QA/PROD)` | app/backend | Manual | Opcional | QA, PROD |
| `Auto Deploy to DEV` | infra | repository_dispatch | Automático | DEV |
| `Auto Deploy to QA/PROD` | infra | repository_dispatch | Automático | QA, PROD |

---

## ✅ Checklist de Configuración

Antes de usar el CI/CD, verifica:

- [ ] PAT creado con scopes `repo` y `workflow`
- [ ] `INFRA_DEPLOY_TOKEN` configurado en jobdirect-app
- [ ] `INFRA_DEPLOY_TOKEN` configurado en jobdirect-backend
- [ ] `DOCKERHUB_USERNAME` configurado en jobdirect-infra
- [ ] `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` en app/backend
- [ ] `AZURE_CREDENTIALS` configurado en jobdirect-infra
- [ ] AKS DEV cluster creado y corriendo
- [ ] Deployments iniciales creados en K8s:
  ```bash
  kubectl apply -f kubernetes/jobdirect-app.yaml
  kubectl apply -f kubernetes/jobdirect-backend.yaml
  ```

---

## 🚀 ¡Listo para Usar!

Ahora puedes:

1. **Desarrollar en local** → hacer cambios
2. **Push a main** → deploy automático a DEV
3. **Cuando esté listo** → workflow manual para QA
4. **Cuando esté validado en QA** → workflow manual para PROD

El flujo está completamente automatizado para DEV, y controlado manualmente para QA/PROD.
