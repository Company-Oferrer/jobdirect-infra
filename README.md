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
| **VM Size** | Standard_DC2ds_v3 | Standard_DC2ds_v3 | Standard_DC2ds_v3 | Confidential computing en todos los ambientes |
| **Region** | Central US | Central US | Central US | Region con disponibilidad de VMs requeridas |
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

## Como iniciar el flujo automatico (paso a paso)

Antes de que el CI/CD automatico funcione, hay **1 paso manual** que se ejecuta **una sola vez** por ambiente. Esto es necesario porque primero hay que crear la infraestructura donde se van a desplegar las aplicaciones.

### Paso 0: Configurar GitHub Secrets

Antes de ejecutar cualquier workflow, configura los secrets en el repo `jobdirect-infra`:

| Secret | Valor |
|--------|-------|
| `AZURE_CREDENTIALS` | JSON del Service Principal (ver [QUICK_START.md](QUICK_START.md)) |
| `AZURE_SUBSCRIPTION_ID` | Tu Subscription ID de Azure |
| `DOCKERHUB_USERNAME` | Tu usuario de DockerHub |
| `POSTGRES_ADMIN_PASSWORD_DEV` | Una password segura para la DB de DEV |
| `POSTGRES_ADMIN_PASSWORD_QA` | Una password segura para la DB de QA |
| `POSTGRES_ADMIN_PASSWORD_PROD` | Una password segura para la DB de PROD |

### Paso 1: Ejecutar `Deploy Infrastructure - DEV` (terraform-dev.yml)

**Donde:** GitHub > `jobdirect-infra` > Actions > `Deploy Infrastructure - DEV` > Run workflow

**Que hace:** Usa Terraform para crear en Azure:
- El **Resource Group** (contenedor de recursos)
- El **cluster AKS** (Kubernetes donde corren las apps)
- El **PostgreSQL** (base de datos)
- **Automaticamente** dispara `k8s-deploy.yml` que configura los manifiestos de Kubernetes (Deployments, Services, Secrets de PostgreSQL)

**Por que es manual:** La infraestructura se crea una sola vez. No tiene sentido recrear un cluster de Kubernetes en cada push. Solo se vuelve a ejecutar si cambias algo en los archivos `.tf` (por ejemplo, agregar mas nodos).

> **Nota:** Anteriormente se necesitaba ejecutar `k8s-deploy.yml` manualmente como segundo paso. Ahora se dispara automaticamente al finalizar el terraform apply.

### Paso 2: Listo - Todo automatico a partir de aqui

Ahora solo haces push en el repo de la app o del backend:

```bash
# En jobdirect-backend o jobdirect-app
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main
```

Y se dispara automaticamente:

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
│  2. Actualiza imagen del deployment │
│  3. Espera rollout completo         │
└─────────────────────────────────────┘
    │
    ▼
  NUEVA VERSION LIVE EN DEV
```

### Resumen visual por ambiente

```
                    MANUAL (una sola vez)              AUTOMATICO (cada push)
                 ┌──────────────────────────┐    ┌──────────────────────────────┐
  DEV            │ terraform-dev.yml        │    │ git push → CI/CD → deploy    │
                 │ (auto-dispara k8s-deploy)│ →  │ (se dispara solo)            │
                 └──────────────────────────┘    └──────────────────────────────┘

                 ┌──────────────────────────┐    ┌──────────────────────────────┐
  QA             │ terraform-qa.yml         │    │ dockerhub.yml (manual) →     │
                 │ (auto-dispara k8s-deploy)│ →  │ seleccionar "qa" → deploy    │
                 └──────────────────────────┘    └──────────────────────────────┘

                 ┌──────────────────────────┐    ┌──────────────────────────────┐
  PROD           │ terraform-prod.yml       │    │ dockerhub.yml (manual) →     │
                 │ (auto-dispara k8s-deploy)│ →  │ seleccionar "prod" → deploy  │
                 └──────────────────────────┘    └──────────────────────────────┘
```

**Nota:** Solo DEV es 100% automatico con cada push. QA y PROD requieren ejecutar manualmente el workflow `dockerhub.yml` en el repo de app/backend (seleccionando el ambiente). Esto es por seguridad: no queremos que un push accidental llegue a produccion.

### Promocion a QA/PROD

Cuando DEV esta estable y quieres promover a QA o PROD:

1. Ir a GitHub Actions en `jobdirect-app` o `jobdirect-backend`
2. Seleccionar workflow **CD - Deploy to DockerHub**
3. Click **Run workflow**
4. Seleccionar ambiente (`qa` o `prod`)
5. El workflow construye la imagen, la sube a DockerHub, y dispara el deploy en el cluster correspondiente

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
  --resource-group rg-jobdirect-dev-01 \
  --name aks-jobdirect-dev-01

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
