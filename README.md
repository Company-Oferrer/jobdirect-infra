# JobDirect Infrastructure

Infraestructura como Codigo (IaC) para el proyecto JobDirect - Diploma DevOps Engineer.

## Que es este repositorio?

Este repositorio contiene **toda la infraestructura** necesaria para ejecutar JobDirect en la nube de Azure. En lugar de crear recursos manualmente desde el portal de Azure, usamos **Terraform** para definir la infraestructura como codigo.

### Por que Infraestructura como Codigo (IaC)?

| Sin IaC (Manual) | Con IaC (Terraform) |
|------------------|---------------------|
| Crear recursos clickeando en Azure Portal | Definir recursos en archivos `.tf` |
| Dificil de replicar en otro ambiente | Un `terraform apply` crea todo igual |
| No hay historial de cambios | Git trackea cada cambio |
| Propenso a errores humanos | Automatizado y consistente |
| Documentacion separada | El codigo ES la documentacion |

---

## Arquitectura del Proyecto

### Vision General

```
┌─────────────────────────────────────────────────────────────────────┐
│                         REPOSITORIOS                                 │
├─────────────────────────────────────────────────────────────────────┤
│  jobdirect-app        jobdirect-backend       jobdirect-infra       │
│  (Frontend React)     (API Node.js)           (Este repo)           │
│        │                    │                       │               │
│        └────────────────────┴───────────────────────┘               │
│                             │                                        │
│                    GitHub Actions CI/CD                              │
│                             │                                        │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AZURE CLOUD                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐        │
│   │     DEV     │      │     QA      │      │    PROD     │        │
│   │             │      │             │      │             │        │
│   │ ┌─────────┐ │      │ ┌─────────┐ │      │ ┌─────────┐ │        │
│   │ │   AKS   │ │      │ │   AKS   │ │      │ │   AKS   │ │        │
│   │ │ 1 nodo  │ │      │ │ 2 nodos │ │      │ │ 3 nodos │ │        │
│   │ └────┬────┘ │      │ └────┬────┘ │      │ └────┬────┘ │        │
│   │      │      │      │      │      │      │      │      │        │
│   │ ┌────┴────┐ │      │ ┌────┴────┐ │      │ ┌────┴────┐ │        │
│   │ │PostgreSQL│ │     │ │PostgreSQL│ │     │ │PostgreSQL│ │       │
│   │ │  32 GB  │ │      │ │  64 GB  │ │      │ │ 128 GB  │ │        │
│   │ └─────────┘ │      │ └─────────┘ │      │ └─────────┘ │        │
│   └─────────────┘      └─────────────┘      └─────────────┘        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Por que 3 ambientes?

| Ambiente | Proposito | Quien lo usa |
|----------|-----------|--------------|
| **DEV** | Desarrollo y pruebas rapidas | Desarrolladores |
| **QA** | Testing de calidad antes de produccion | QA Team |
| **PROD** | Usuarios reales | Clientes |

**Beneficios:**
- Los errores se detectan en DEV/QA antes de llegar a usuarios reales
- Cada ambiente puede tener configuraciones diferentes (mas recursos en PROD)
- Los desarrolladores pueden experimentar sin afectar produccion

---

## Tecnologias Utilizadas

### Terraform (IaC)

**Que es?** Herramienta para crear infraestructura usando codigo.

**Por que Terraform?**
- Es el estandar de la industria
- Soporta multiples nubes (Azure, AWS, GCP)
- Tiene estado (`terraform.tfstate`) que trackea lo que existe
- Planifica cambios antes de aplicarlos (`terraform plan`)

**Archivos principales:**
```
provider.tf           → Configura la conexion a Azure
aks.tf                → Define el cluster de Kubernetes
postgres.tf           → Define la base de datos
variables.tf          → Define variables sensibles (subscription_id, passwords)
terraform.tfvars      → Valores locales de las variables (gitignored)
terraform.tfvars.example → Plantilla de ejemplo para las variables
```

### Azure Kubernetes Service (AKS)

**Que es?** Kubernetes administrado por Azure.

**Por que Kubernetes?**
- Orquesta contenedores automaticamente
- Escala aplicaciones segun demanda
- Reinicia contenedores que fallan
- Balancea carga entre replicas

**Por que AKS (y no instalar Kubernetes manualmente)?**
- Azure administra el control plane (masters)
- Actualizaciones automaticas de seguridad
- Integrado con Azure AD y monitoreo
- Menos trabajo operativo

### PostgreSQL Flexible Server

**Que es?** Base de datos PostgreSQL administrada por Azure.

**Por que PostgreSQL administrado?**
- Backups automaticos
- Alta disponibilidad
- Patches de seguridad automaticos
- Escalado sin downtime

### GitHub Actions (CI/CD)

**Que es?** Automatizacion de pipelines en GitHub.

**Por que GitHub Actions?**
- Integrado con nuestros repositorios
- Gratis para repositorios publicos
- Facil de configurar con YAML
- Soporta secretos para credenciales

---

## Estructura del Repositorio

```
jobdirect-infra/
│
├── terraform/                    # Infraestructura como codigo
│   ├── dev/                      # Ambiente de desarrollo
│   │   ├── provider.tf           # Conexion a Azure
│   │   ├── aks.tf                # Cluster Kubernetes (1 nodo)
│   │   ├── postgres.tf           # Base de datos (32GB)
│   │   ├── variables.tf          # Variables sensibles
│   │   ├── terraform.tfvars.example  # Plantilla de variables
│   │   └── terraform.tfvars      # Valores locales (gitignored)
│   ├── qa/                       # Ambiente de QA
│   │   ├── provider.tf
│   │   ├── aks.tf                # Cluster Kubernetes (2 nodos)
│   │   ├── postgres.tf           # Base de datos (64GB)
│   │   ├── variables.tf          # Variables sensibles
│   │   └── terraform.tfvars.example
│   └── prod/                     # Ambiente de produccion
│       ├── provider.tf
│       ├── aks.tf                # Cluster Kubernetes (3 nodos)
│       ├── postgres.tf           # Base de datos (128GB)
│       ├── variables.tf          # Variables sensibles
│       └── terraform.tfvars.example
│
├── kubernetes/                   # Manifiestos de Kubernetes
│   ├── jobdirect-app.yaml        # Deployment del frontend
│   ├── jobdirect-backend.yaml    # Deployment del backend
│   └── setup-monitoring.sh       # Instalacion de Prometheus/Grafana
│
├── .github/workflows/            # Pipelines CI/CD
│   ├── terraform-dev.yml         # Deploy infra DEV
│   ├── terraform-qa.yml          # Deploy infra QA
│   ├── terraform-prod.yml        # Deploy infra PROD
│   ├── auto-deploy-dev.yml       # Auto-deploy apps a DEV
│   └── auto-deploy-qa-prod.yml   # Deploy apps a QA/PROD
│
├── README.md                     # Este archivo
├── QUICK_START.md                # Guia de configuracion inicial
└── CI_CD_GUIDE.md                # Guia del sistema CI/CD
```

---

## Diferencias entre Ambientes

### Por que diferentes configuraciones?

| Recurso | DEV | QA | PROD | Razon |
|---------|-----|-----|------|-------|
| **Nodos AKS** | 1 | 2 | 3 | PROD necesita alta disponibilidad |
| **VM Size** | Standard_B2s | Standard_D2s_v3 | Standard_D4s_v3 | Mas CPU/RAM para mas usuarios |
| **PostgreSQL** | 32 GB | 64 GB | 128 GB | Mas datos en produccion |
| **Backups** | 7 dias | 14 dias | 35 dias | Mas retencion para compliance |
| **Geo-Backup** | No | No | Si | Disaster recovery en PROD |

### Costos Estimados (mensual)

| Ambiente | Costo Aprox | Justificacion |
|----------|-------------|---------------|
| DEV | ~$50 | Minimo para desarrollo |
| QA | ~$150 | Simula produccion |
| PROD | ~$500 | Alta disponibilidad |

---

## Como funciona el flujo de trabajo?

### 1. Desarrollo Local

```bash
# El desarrollador trabaja en su maquina
cd jobdirect-backend
npm run dev

# Hace cambios y los prueba localmente
```

### 2. Push a GitHub

```bash
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main
```

### 3. CI/CD Automatico (DEV)

```
Push a main
    │
    ▼
┌─────────────────────────────────────┐
│  GitHub Actions (en app/backend)    │
│  1. Ejecuta tests                   │
│  2. Ejecuta linter                  │
│  3. Build imagen Docker             │
│  4. Push a DockerHub                │
│  5. Notifica a jobdirect-infra      │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  GitHub Actions (en infra)          │
│  1. Conecta a AKS                   │
│  2. Actualiza deployment            │
│  3. Espera rollout                  │
└─────────────────────────────────────┘
    │
    ▼
  DEPLOYED EN DEV
```

### 4. Promocion a QA/PROD (Manual)

Cuando DEV esta estable, se promueve manualmente:

1. Ir a GitHub Actions
2. Ejecutar workflow manual
3. Seleccionar ambiente (qa/prod)
4. Confirmar deploy

---

## Documentacion Adicional

| Documento | Contenido | Cuando usarlo |
|-----------|-----------|---------------|
| **[QUICK_START.md](QUICK_START.md)** | Configuracion inicial de Azure y GitHub | Primera vez configurando el proyecto |
| **[CI_CD_GUIDE.md](CI_CD_GUIDE.md)** | Uso del sistema CI/CD | Cuando necesites hacer deploys |

---

## Comandos Utiles

### Ver estado de infraestructura

```bash
# Listar clusters AKS
az aks list -o table

# Listar bases de datos
az postgres flexible-server list -o table

# Listar resource groups
az group list --query "[?contains(name, 'jobdirect')]" -o table
```

### Ver estado de aplicaciones

```bash
# Conectar a AKS DEV
az aks get-credentials \
  --resource-group rg-jobdirect-dev-eastus-01 \
  --name aks-jobdirect-dev-eastus-01

# Ver pods
kubectl get pods

# Ver servicios (obtener IP externa)
kubectl get svc

# Ver logs del backend
kubectl logs deployment/jobdirect-backend -f
```

### Limpiar recursos (importante para no gastar dinero)

```bash
# Eliminar infraestructura DEV
cd terraform/dev
terraform destroy

# Confirmar con "yes"
```

---

## Glosario

| Termino | Definicion |
|---------|------------|
| **IaC** | Infrastructure as Code - Infraestructura definida en codigo |
| **AKS** | Azure Kubernetes Service - Kubernetes administrado |
| **Terraform** | Herramienta para crear infraestructura con codigo |
| **CI/CD** | Continuous Integration / Continuous Deployment |
| **Pod** | Unidad minima en Kubernetes (1+ contenedores) |
| **Deployment** | Objeto K8s que maneja replicas de pods |
| **Service** | Objeto K8s que expone pods a la red |
| **Secret** | Objeto K8s para guardar datos sensibles |
| **Rollout** | Proceso de actualizar pods gradualmente |
