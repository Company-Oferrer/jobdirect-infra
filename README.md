# JobDirect Infrastructure

Infraestructura como código (IaC) multi-entorno para el proyecto JobDirect del Diploma DevOps Engineer.

## Descripción del Proyecto

Este repositorio contiene la infraestructura necesaria para desplegar las aplicaciones **jobdirect-app** (frontend) y *
*jobdirect-backend** (API) en Azure Kubernetes Service (AKS) con soporte para tres ambientes: **dev**, **qa** y **prod
**.

### Aplicaciones

- **jobdirect-app**: Frontend React + Vite + Tailwind CSS (puerto 80)
- **jobdirect-backend**: API Express + PostgreSQL (puerto 3000)

### Tecnologías Utilizadas

- **IaC**: Terraform 1.9.0
- **Cloud**: Microsoft Azure (AKS, PostgreSQL Flexible Server)
- **Contenedores**: Docker + Kubernetes
- **CI/CD**: GitHub Actions con repository dispatch
- **Monitoreo**: Prometheus + Grafana (Helm)

---

## Integración CI/CD

Este proyecto incluye un sistema de CI/CD completamente integrado que conecta los tres repositorios (jobdirect-app,
jobdirect-backend, jobdirect-infra) mediante GitHub Actions.

### Flujo de Trabajo

**DEV - Automático:**

- Hacer push a `main` en jobdirect-app o jobdirect-backend
- Se ejecutan tests y linter automáticamente
- Se construye imagen Docker y se sube a DockerHub
- Se despliega automáticamente a AKS DEV mediante `repository_dispatch`

**QA/PROD - Manual:**

- Ejecutar workflow manual en jobdirect-app o jobdirect-backend
- Seleccionar ambiente (qa o prod)
- Opcionalmente activar deploy automático a Kubernetes

### Documentación de CI/CD

Para usar el sistema CI/CD, consultar en orden:

1. **[INIT_SETUP.md](CONFIGURACION_RAPIDA.md)** - Configuración inicial de secrets y Azure
2. **[CI_CD_USAGE.md](CI_CD_USAGE.md)** - Guía completa de uso del CI/CD
3. **[INTEGRACION_CICD.md](INTEGRACION_CICD.md)** - Detalles técnicos del patrón repository_dispatch

---

## Arquitectura

### Flujo CI/CD Completo

```
┌─────────────────────────────────────────────────────────────────────┐
│                        APLICACIONES                                  │
│  ┌─────────────────────┐           ┌─────────────────────┐          │
│  │  jobdirect-app      │           │  jobdirect-backend  │          │
│  │  (Frontend Repo)    │           │  (Backend Repo)     │          │
│  └─────────────────────┘           └─────────────────────┘          │
│           ↓                                    ↓                     │
│    Push to main                         Push to main                │
│           ↓                                    ↓                     │
│  ┌─────────────────────┐           ┌─────────────────────┐          │
│  │ CI/CD Auto DEV      │           │ CI/CD Auto DEV      │          │
│  │ - Test + Lint       │           │ - Test + Lint       │          │
│  │ - Build Docker      │           │ - Build Docker      │          │
│  │ - Push DockerHub    │           │ - Push DockerHub    │          │
│  │ - Trigger Deploy    │           │ - Trigger Deploy    │          │
│  └─────────────────────┘           └─────────────────────┘          │
└─────────────────────────────────────────────────────────────────────┘
                          ↓                      ↓
              repository_dispatch event     repository_dispatch event
                          ↓                      ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    jobdirect-infra (Este Repo)                       │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Auto Deploy to DEV                                        │      │
│  │ - Connect to AKS DEV                                      │      │
│  │ - kubectl set image (rolling update)                     │      │
│  │ - kubectl rollout status                                 │      │
│  └───────────────────────────────────────────────────────────┘      │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Auto Deploy to QA/PROD (Manual trigger)                  │      │
│  │ - Mismo flujo pero con workflow_dispatch                 │      │
│  └───────────────────────────────────────────────────────────┘      │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Deploy Infrastructure (Terraform)                         │      │
│  │ - terraform-dev.yml                                       │      │
│  │ - terraform-qa.yml                                        │      │
│  │ - terraform-prod.yml                                      │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         AZURE CLOUD                                  │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐       │
│  │      DEV      │    │       QA      │    │     PROD      │       │
│  │  (Auto Deploy)│    │   (Manual)    │    │   (Manual)    │       │
│  │               │    │               │    │               │       │
│  │ AKS (1 node)  │    │ AKS (2 nodes) │    │ AKS (3 nodes) │       │
│  │ PostgreSQL    │    │ PostgreSQL    │    │ PostgreSQL    │       │
│  │ Prometheus    │    │ Prometheus    │    │ Prometheus    │       │
│  │ Grafana       │    │ Grafana       │    │ Grafana       │       │
│  └───────────────┘    └───────────────┘    └───────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Estructura del Repositorio

```
jobdirect-infra/
├── terraform/
│   ├── dev/
│   │   ├── provider.tf     # Configuración Azure provider
│   │   ├── aks.tf          # Cluster AKS (1 nodo)
│   │   └── postgres.tf     # PostgreSQL (32GB, Basic)
│   ├── qa/
│   │   ├── provider.tf
│   │   ├── aks.tf          # Cluster AKS (2 nodos)
│   │   └── postgres.tf     # PostgreSQL (64GB, Standard)
│   └── prod/
│       ├── provider.tf
│       ├── aks.tf          # Cluster AKS (3 nodos)
│       └── postgres.tf     # PostgreSQL (128GB, Premium)
│
├── kubernetes/
│   ├── jobdirect-app.yaml       # Deployment + Service frontend
│   ├── jobdirect-backend.yaml   # Deployment + Service backend
│   └── setup-monitoring.sh      # Script instalación Prometheus/Grafana
│
├── .github/workflows/
│   ├── terraform-dev.yml           # Deploy infraestructura DEV
│   ├── terraform-qa.yml            # Deploy infraestructura QA
│   ├── terraform-prod.yml          # Deploy infraestructura PROD
│   ├── auto-deploy-dev.yml         # Auto-deploy apps a DEV (via dispatch)
│   └── auto-deploy-qa-prod.yml     # Auto-deploy apps a QA/PROD (via dispatch)
│
├── CONFIGURACION_RAPIDA.md         # Guía de configuración rápida
├── CI_CD_USAGE.md                  # Guía de uso CI/CD (IMPORTANTE)
├── INTEGRACION_CICD.md             # Detalles técnicos CI/CD
├── PLAN_SIMPLE.md                  # Plan detallado del proyecto
├── RESUMEN_EJECUTIVO.md            # Vista general del proyecto
├── ARQUITECTURA_VISUAL.md          # Diagramas para presentaciones
└── README.md                       # Este archivo
```

---

## Guía de Despliegue

### Requisitos Previos

1. **Cuenta Azure** con suscripción activa
2. **Azure CLI** instalado y configurado
3. **Terraform** 1.9.0 instalado
4. **kubectl** instalado
5. **Helm 3** instalado (para monitoreo)
6. **Acceso a GitHub** con permisos para GitHub Actions

### Configuración Inicial

#### 1. Clonar el repositorio

```bash
git clone https://github.com/Company-Oferrer/jobdirect-infra.git
cd jobdirect-infra
```

#### 2. Configurar Azure Service Principal

```bash
# Crear Service Principal para GitHub Actions
az ad sp create-for-rbac \
  --name "sp-jobdirect-infra" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# Copiar el output JSON para GitHub Secrets
```

#### 3. Configurar GitHub Secrets

Ir a **Settings → Secrets and variables → Actions** y crear:

| Secret Name             | Descripción              | Valor                                | Repositorio                 |
|-------------------------|--------------------------|--------------------------------------|-----------------------------|
| `AZURE_CREDENTIALS`     | Service Principal JSON   | Output del comando anterior          | jobdirect-infra             |
| `AZURE_SUBSCRIPTION_ID` | ID de suscripción Azure  | `YOUR_SUBSCRIPTION_ID`               | jobdirect-infra             |
| `DOCKERHUB_USERNAME`    | Usuario DockerHub        | `companyoferrer`                     | Todos (app, backend, infra) |
| `DOCKERHUB_TOKEN`       | Token DockerHub          | Crear en hub.docker.com              | app, backend                |
| `INFRA_DEPLOY_TOKEN`    | GitHub PAT para dispatch | Ver [CI_CD_USAGE.md](CI_CD_USAGE.md) | app, backend                |

**Nota:** Para configuración detallada del CI/CD y creación del Personal Access Token (PAT),
consultar [CI_CD_USAGE.md](CI_CD_USAGE.md).

---

## Opción A: Despliegue Manual (Terraform CLI)

### Paso 1: Desplegar Infraestructura DEV

```bash
cd terraform/dev

# Inicializar Terraform
terraform init

# Ver plan de cambios
terraform plan

# Aplicar cambios
terraform apply

# Guardar outputs importantes
terraform output -json > outputs.json
```

### Paso 2: Conectar a AKS

```bash
# Obtener credenciales del cluster
az aks get-credentials \
  --resource-group rg-jobdirect-dev-eastus-01 \
  --name aks-jobdirect-dev-eastus-01 \
  --overwrite-existing

# Verificar conexión
kubectl get nodes
```

### Paso 3: Crear Secret de PostgreSQL

```bash
# Obtener FQDN de PostgreSQL
POSTGRES_FQDN=$(terraform output -raw postgres_fqdn)

# Crear secret en Kubernetes
kubectl create secret generic postgres-secret \
  --from-literal=connection-string="postgresql://jobdirectadmin:P@ssw0rd123Proyecto${POSTGRES_FQDN}:5432/jobdirect?sslmode=require"
```

### Paso 4: Desplegar Aplicaciones

```bash
cd ../../kubernetes

# Desplegar backend
kubectl apply -f jobdirect-backend.yaml

# Desplegar frontend
kubectl apply -f jobdirect-app.yaml

# Verificar deployments
kubectl get pods
kubectl get svc
```

### Paso 5: Instalar Monitoreo (Opcional)

```bash
# Dar permisos al script
chmod +x setup-monitoring.sh

# Ejecutar instalación
./setup-monitoring.sh dev

# Obtener IP de Grafana
kubectl get svc -n monitoring
```

---

## Opción B: Despliegue Automatizado (GitHub Actions)

### CI/CD Multi-Ambiente

Este proyecto tiene **dos flujos CI/CD separados**:

1. **Infraestructura (Terraform)**: Deploy de AKS, PostgreSQL, etc.
2. **Aplicaciones (Kubernetes)**: Deploy de frontend y backend a K8s

---

### A. Despliegue de Infraestructura (Terraform)

Esta es una **operación única** para crear AKS, PostgreSQL, etc.

1. Ve a **GitHub → jobdirect-infra → Actions → Deploy Infrastructure - DEV**
2. Click en **Run workflow**
3. Seleccionar branch `main`
4. Click en **Run workflow**
5. Esperar a que termine (~5-10 minutos)

Esto crea:

- Resource Group
- AKS Cluster
- PostgreSQL Flexible Server

---

### B. Despliegue de Aplicaciones (Automático)

Una vez que la infraestructura está lista, el **deploy de aplicaciones es automático**:

#### Para DEV (Automático en cada push):

```bash
# Ejemplo: Actualizar frontend
cd jobdirect-app
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main

# Automáticamente:
# - Se ejecutan tests y linter
# - Se hace build de imagen Docker
# - Se sube a DockerHub con tags :dev y :SHA
# - Se dispara deploy automático a AKS DEV
```

El mismo flujo aplica para `jobdirect-backend`.

#### Para QA/PROD (Manual):

1. Ve a **GitHub → jobdirect-app → Actions → CD - Deploy Frontend to DockerHub (Manual QA/PROD)**
2. Selecciona:
    - **ambiente**: `qa` o `prod`
    - **¿Disparar deploy automático a K8s?**: `true`
3. Click en **Run workflow**

**Nota:** Para ejemplos detallados, troubleshooting y configuración completa, ver [CI_CD_USAGE.md](CI_CD_USAGE.md).

---

## Diferencias entre Ambientes

| Recurso                  | Dev             | QA                 | Prod               |
|--------------------------|-----------------|--------------------|--------------------|
| **AKS Nodos**            | 1               | 2                  | 3                  |
| **VM Size**              | standard_a2_v2  | standard_d2s_v3    | standard_d4s_v3    |
| **PostgreSQL Storage**   | 32 GB           | 64 GB              | 128 GB             |
| **PostgreSQL SKU**       | B_Standard_B1ms | GP_Standard_D2s_v3 | GP_Standard_D4s_v3 |
| **Backup Days**          | 7               | 14                 | 35                 |
| **Geo-Redundant Backup** | No              | No                 | Sí                 |

---

## Verificación y Testing

### Verificar Infraestructura

```bash
# Listar resource groups
az group list --query "[?contains(name, 'jobdirect')]" -o table

# Listar clusters AKS
az aks list --query "[?contains(name, 'jobdirect')]" -o table

# Listar PostgreSQL servers
az postgres flexible-server list --query "[?contains(name, 'jobdirect')]" -o table
```

### Verificar Aplicaciones

```bash
# Ver pods
kubectl get pods

# Ver logs del backend
kubectl logs deployment/jobdirect-backend

# Ver logs del frontend
kubectl logs deployment/jobdirect-app
```

### Acceder a las Aplicaciones

```bash
# Obtener IP externa del frontend
kubectl get svc frontend-service

# Acceder en el navegador: http://<EXTERNAL-IP>
```

### Acceder a Grafana

```bash
# Obtener IP de Grafana
kubectl get svc -n monitoring grafana

# Obtener password
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode

# Acceder en el navegador: http://<EXTERNAL-IP>
# Usuario: admin
```

---

## Limpieza de Recursos

### Eliminar aplicaciones K8s

```bash
kubectl delete -f kubernetes/jobdirect-backend.yaml
kubectl delete -f kubernetes/jobdirect-app.yaml

# Eliminar monitoreo (si se instaló)
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring
```

### Eliminar infraestructura Terraform

```bash
cd terraform/dev
terraform destroy

cd ../qa
terraform destroy

cd ../prod
terraform destroy
```

---

### Guía de Lectura Recomendada

Para nuevos miembros del equipo:

1. **README.md** (este archivo) - Entender la arquitectura general
2. **INIT_SETUP.md** - Configurar el entorno de trabajo
3. **CI_CD_USAGE.md** - Aprender a usar el sistema de despliegue
4. **INTEGRACION_CICD.md** - Comprender cómo se integran los repositorios

---
