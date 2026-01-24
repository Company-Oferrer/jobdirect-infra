# Guia CI/CD - JobDirect

Esta guia explica como funciona el sistema de Continuous Integration y Continuous Deployment.

## Que es CI/CD?

### Continuous Integration (CI)

Cada vez que alguien hace push de codigo:
1. Se ejecutan **tests automaticos**
2. Se ejecuta el **linter** (verifica estilo de codigo)
3. Se **compila** la aplicacion

**Beneficio:** Detectar errores rapidamente, antes de que lleguen a produccion.

### Continuous Deployment (CD)

Despues de que CI pasa exitosamente:
1. Se **construye** la imagen Docker
2. Se **sube** a DockerHub (registry)
3. Se **despliega** automaticamente a Kubernetes

**Beneficio:** Deployments rapidos y consistentes, sin intervencion manual.

---

## Arquitectura del CI/CD

### Flujo General

```
┌─────────────────────────────────────────────────────────────────────┐
│                    REPOSITORIOS DE APLICACIONES                      │
│                                                                      │
│   jobdirect-app                        jobdirect-backend             │
│   ┌──────────────────┐                ┌──────────────────┐          │
│   │ Push a main      │                │ Push a main      │          │
│   │       │          │                │       │          │          │
│   │       ▼          │                │       ▼          │          │
│   │ ┌────────────┐   │                │ ┌────────────┐   │          │
│   │ │ npm test   │   │                │ │ npm test   │   │          │
│   │ │ npm lint   │   │                │ │ npm lint   │   │          │
│   │ │ docker build│  │                │ │ docker build│  │          │
│   │ │ docker push │  │                │ │ docker push │  │          │
│   │ └──────┬─────┘   │                │ └──────┬─────┘   │          │
│   └────────┼─────────┘                └────────┼─────────┘          │
│            │                                   │                     │
│            │     repository_dispatch           │                     │
│            └───────────────┬───────────────────┘                    │
│                            │                                         │
└────────────────────────────┼─────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    REPOSITORIO DE INFRAESTRUCTURA                    │
│                                                                      │
│   jobdirect-infra                                                    │
│   ┌──────────────────────────────────────────────┐                  │
│   │ Recibe evento de app/backend                  │                  │
│   │       │                                       │                  │
│   │       ▼                                       │                  │
│   │ ┌────────────────────────────────────────┐   │                  │
│   │ │ az login (conectar a Azure)            │   │                  │
│   │ │ az aks get-credentials (conectar a K8s)│   │                  │
│   │ │ kubectl set image (actualizar pods)    │   │                  │
│   │ │ kubectl rollout status (esperar)       │   │                  │
│   │ └────────────────────────────────────────┘   │                  │
│   └──────────────────────────────────────────────┘                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    ┌──────────────┐
                    │  DEPLOYED!   │
                    └──────────────┘
```

### Por que esta separacion?

| Responsabilidad | Repositorio | Razon |
|-----------------|-------------|-------|
| Build + Tests | app/backend | Cada app conoce sus propios tests |
| Deploy a K8s | infra | Centraliza credenciales de Azure |

**Beneficios:**
- Las credenciales de Azure solo estan en `jobdirect-infra`
- Los repos de apps no necesitan acceso a Kubernetes
- Un solo lugar para configurar deployments

---

## Configuracion Inicial

### Paso 1: Crear Personal Access Token (PAT)

**Que es?** Un token que permite a los repos de apps disparar workflows en el repo de infra.

**Por que lo necesitamos?** GitHub no permite que un workflow dispare otro en un repo diferente sin autorizacion explicita.

#### Como crearlo:

1. Ir a GitHub > **Settings** (tu perfil, no el repo)
2. **Developer settings** > **Personal access tokens** > **Tokens (classic)**
3. Click **Generate new token (classic)**
4. Configurar:
   - **Note:** `jobdirect-infra-deploy`
   - **Expiration:** 90 days
   - **Scopes:**
     - ✅ `repo` (todos los sub-permisos)
     - ✅ `workflow`
5. Click **Generate token**
6. **COPIAR EL TOKEN** (no se vuelve a mostrar!)

### Paso 2: Configurar Secrets

Los secrets son variables encriptadas que los workflows pueden usar.

#### En jobdirect-app:

Ir a Settings > Secrets > Actions > New repository secret:

| Secret | Valor | Para que |
|--------|-------|----------|
| `DOCKERHUB_USERNAME` | Tu usuario | Push de imagenes |
| `DOCKERHUB_TOKEN` | Token de DockerHub | Autenticacion |
| `INFRA_DEPLOY_TOKEN` | PAT del paso 1 | Disparar deploy |

#### En jobdirect-backend:

Mismos secrets que arriba.

#### En jobdirect-infra:

| Secret | Valor | Para que |
|--------|-------|----------|
| `AZURE_CREDENTIALS` | JSON del Service Principal | Conectar a Azure |
| `AZURE_SUBSCRIPTION_ID` | Tu Subscription ID | Referencia |
| `DOCKERHUB_USERNAME` | Tu usuario | Saber que imagen bajar |

---

## Escenarios de Uso

### Escenario 1: Deploy Automatico a DEV

**Cuando ocurre:** Cada push a `main` en jobdirect-app o jobdirect-backend.

**Que hace:**

```bash
# El desarrollador hace cambios
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main

# Automaticamente se ejecuta:
# 1. Tests (npm test)
# 2. Linter (npm run lint)
# 3. Build Docker
# 4. Push a DockerHub con tags:
#    - companyoferrer/jobdirect-app:dev
#    - companyoferrer/jobdirect-app:abc1234 (git SHA)
# 5. Dispara deploy a AKS DEV
```

**Como verificar:**

1. Ver workflow en GitHub Actions (repo app/backend)
2. Ver workflow disparado en GitHub Actions (repo infra)
3. Ver pods actualizados:
   ```bash
   kubectl get pods
   ```

### Escenario 2: Deploy Manual a QA

**Cuando usarlo:** Cuando DEV esta estable y quieres probar en QA.

**Pasos:**

1. Ir a **GitHub > jobdirect-app > Actions**
2. Seleccionar **CD - Deploy to DockerHub (Manual QA/PROD)**
3. Click **Run workflow**
4. Configurar:
   - **Branch:** main
   - **ambiente:** qa
   - **Disparar deploy:** ✅ (checked)
5. Click **Run workflow**

### Escenario 3: Deploy Manual a PROD

**Cuando usarlo:** Cuando QA esta validado y listo para usuarios reales.

**Pasos:** Igual que QA, pero seleccionar `prod` como ambiente.

**IMPORTANTE:** En produccion, considera:
- Hacer deploy en horarios de bajo trafico
- Tener plan de rollback listo
- Notificar al equipo

### Escenario 4: Solo Build (Sin Deploy)

**Cuando usarlo:** Quieres crear la imagen pero no desplegarla aun.

**Pasos:**

1. Ejecutar workflow manual
2. **Disparar deploy:** ❌ (unchecked)

La imagen se sube a DockerHub pero no se despliega.

---

## Como funciona repository_dispatch?

### El problema

GitHub Actions no permite que un workflow en `repo-A` dispare un workflow en `repo-B` directamente.

### La solucion

Usamos `repository_dispatch`, un evento especial que:
1. Se dispara via API
2. Puede enviar datos (payload)
3. Puede cruzar repositorios (con un PAT)

### El codigo

**En jobdirect-app (emisor):**

```yaml
- name: Trigger deployment to AKS DEV
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.INFRA_DEPLOY_TOKEN }}      # PAT con permisos
    repository: Company-Oferrer/jobdirect-infra   # Repo destino
    event-type: deploy-frontend-dev               # Nombre del evento
    client-payload: |                             # Datos a enviar
      {
        "image_tag": "${{ steps.vars.outputs.SHORT_SHA }}",
        "triggered_by": "${{ github.actor }}"
      }
```

**En jobdirect-infra (receptor):**

```yaml
on:
  repository_dispatch:
    types:
      - deploy-frontend-dev    # Escucha este evento
      - deploy-backend-dev

jobs:
  deploy:
    steps:
      - name: Deploy
        run: |
          # Accede a los datos enviados
          echo "Image: ${{ github.event.client_payload.image_tag }}"
          echo "By: ${{ github.event.client_payload.triggered_by }}"
```

---

## Troubleshooting

### El workflow no se dispara

**Posibles causas:**

1. **Cambios solo en .md:** Los workflows ignoran cambios en markdown
   ```yaml
   paths-ignore:
     - '**.md'
   ```

2. **Push a branch incorrecto:** Solo `main` dispara CI/CD
   ```yaml
   on:
     push:
       branches:
         - main
   ```

### Error: "Resource not accessible by personal access token"

**Causa:** El PAT no tiene los permisos correctos.

**Solucion:**
1. Verificar que el PAT tiene scopes `repo` y `workflow`
2. Verificar que `INFRA_DEPLOY_TOKEN` esta configurado
3. Regenerar el PAT si expiro

### Error: "deployment not found"

**Causa:** El deployment no existe en Kubernetes.

**Solucion:**
```bash
# Crear los deployments primero
kubectl apply -f kubernetes/jobdirect-backend.yaml
kubectl apply -f kubernetes/jobdirect-app.yaml
```

### El pod no inicia (CrashLoopBackOff)

**Causa:** La aplicacion falla al iniciar.

**Solucion:**
```bash
# Ver logs del pod
kubectl logs deployment/jobdirect-backend

# Ver eventos del pod
kubectl describe pod NOMBRE_DEL_POD
```

Errores comunes:
- Falta variable de entorno (DATABASE_URL)
- Secret no existe (postgres-secret)
- Imagen no encontrada en DockerHub

### Rollout muy lento

**Causa:** El pod tarda en estar Ready.

**Solucion:**
```bash
# Ver estado del rollout
kubectl rollout status deployment/jobdirect-backend

# Ver pods
kubectl get pods -w  # -w = watch (actualiza en tiempo real)
```

---

## Verificacion de Deployments

### Ver estado actual

```bash
# Conectar a AKS
az aks get-credentials \
  --resource-group rg-jobdirect-dev-eastus-01 \
  --name aks-jobdirect-dev-eastus-01

# Ver pods
kubectl get pods

# Ver deployments
kubectl get deployments

# Ver servicios (IPs)
kubectl get svc
```

### Ver logs

```bash
# Logs del backend
kubectl logs deployment/jobdirect-backend -f

# Logs del frontend
kubectl logs deployment/jobdirect-app -f
```

### Ver imagen actual

```bash
# Ver que imagen esta corriendo
kubectl get deployment jobdirect-backend -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Resumen de Workflows

| Workflow | Ubicacion | Trigger | Ambiente | Automatico |
|----------|-----------|---------|----------|------------|
| CI/CD Auto DEV | app/backend | Push a main | DEV | Si |
| CD Manual QA/PROD | app/backend | Manual | QA, PROD | No |
| Auto Deploy DEV | infra | repository_dispatch | DEV | Si |
| Auto Deploy QA/PROD | infra | repository_dispatch | QA, PROD | Si |

---

## Checklist Pre-Deploy

Antes de usar el CI/CD, verifica:

- [ ] PAT creado con scopes `repo` y `workflow`
- [ ] `INFRA_DEPLOY_TOKEN` configurado en jobdirect-app
- [ ] `INFRA_DEPLOY_TOKEN` configurado en jobdirect-backend
- [ ] `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` en app/backend
- [ ] `AZURE_CREDENTIALS` configurado en jobdirect-infra
- [ ] Infraestructura creada (AKS corriendo)
- [ ] Deployments iniciales creados:
  ```bash
  kubectl apply -f kubernetes/jobdirect-backend.yaml
  kubectl apply -f kubernetes/jobdirect-app.yaml
  ```
- [ ] Secret de PostgreSQL creado:
  ```bash
  kubectl get secret postgres-secret
  ```
