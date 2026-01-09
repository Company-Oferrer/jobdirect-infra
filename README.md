# JobDirect Infrastructure

Infraestructura como código (IaC) multi-entorno para el proyecto JobDirect del Diploma DevOps Engineer.

## Descripción del Proyecto

Este repositorio contiene la infraestructura necesaria para desplegar las aplicaciones **jobdirect-app** (frontend) y **jobdirect-backend** (API) en Azure Kubernetes Service (AKS) con soporte para tres ambientes: **dev**, **qa** y **prod**.

### Aplicaciones

- **jobdirect-app**: Frontend React + Vite + Tailwind CSS (puerto 80)
- **jobdirect-backend**: API Express + PostgreSQL (puerto 3000)

### Tecnologías Utilizadas

- **IaC**: Terraform 1.9.0
- **Cloud**: Microsoft Azure (AKS, PostgreSQL Flexible Server)
- **Contenedores**: Docker + Kubernetes
- **CI/CD**: GitHub Actions
- **Monitoreo**: Prometheus + Grafana (Helm)

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                  GITHUB ACTIONS CI/CD                    │
│  ├── terraform-dev.yml  → Deploy infra DEV              │
│  ├── terraform-qa.yml   → Deploy infra QA               │
│  ├── terraform-prod.yml → Deploy infra PROD             │
│  └── k8s-deploy.yml     → Deploy apps K8s               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                   AZURE CLOUD                            │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐       │
│  │    DEV    │    │     QA    │    │    PROD   │       │
│  │           │    │           │    │           │       │
│  │ AKS (1)   │    │ AKS (2)   │    │ AKS (3)   │       │
│  │ Postgres  │    │ Postgres  │    │ Postgres  │       │
│  │ Monitor   │    │ Monitor   │    │ Monitor   │       │
│  └───────────┘    └───────────┘    └───────────┘       │
└─────────────────────────────────────────────────────────┘
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
│   ├── terraform-dev.yml        # CI/CD para DEV
│   ├── terraform-qa.yml         # CI/CD para QA
│   ├── terraform-prod.yml       # CI/CD para PROD
│   └── k8s-deploy.yml           # Deploy apps K8s
│
├── PLAN_SIMPLE.md               # Plan detallado del proyecto
└── README.md                    # Este archivo
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

| Secret Name | Descripción | Valor |
|------------|-------------|-------|
| `AZURE_CREDENTIALS` | Service Principal JSON | Output del comando anterior |
| `AZURE_SUBSCRIPTION_ID` | ID de suscripción Azure | `YOUR_SUBSCRIPTION_ID` |

---

## 🎯 Opción A: Despliegue Manual (Terraform CLI)

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
  --from-literal=connection-string="postgresql://jobdirectadmin:P@ssw0rd123!@${POSTGRES_FQDN}:5432/jobdirect?sslmode=require"
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

## Despliegue Automatizado (GitHub Actions)

### Paso 1: Desplegar Infraestructura

1. Ir a **Actions → Deploy Infrastructure - DEV**
2. Click en **Run workflow**
3. Seleccionar branch `main`
4. Click en **Run workflow**
5. Esperar a que termine (5-10 minutos)

### Paso 2: Desplegar Aplicaciones

1. Ir a **Actions → Deploy Applications to Kubernetes**
2. Click en **Run workflow**
3. Seleccionar:
   - Environment: `dev`
   - Deploy monitoring: `true` (si quieres Prometheus/Grafana)
4. Click en **Run workflow**
5. Esperar a que termine (3-5 minutos)

### Paso 3: Verificar Despliegue

Ver el **Summary** del workflow para obtener:
- IPs de servicios
- Estado de pods
- Credenciales de Grafana

---

## Diferencias entre Ambientes

| Recurso | Dev | QA | Prod |
|---------|-----|-----|------|
| **AKS Nodos** | 1 | 2 | 3 |
| **VM Size** | standard_a2_v2 | standard_d2s_v3 | standard_d4s_v3 |
| **PostgreSQL Storage** | 32 GB | 64 GB | 128 GB |
| **PostgreSQL SKU** | B_Standard_B1ms | GP_Standard_D2s_v3 | GP_Standard_D4s_v3 |
| **Backup Days** | 7 | 14 | 35 |
| **Geo-Redundant Backup** | No | No | Sí |

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