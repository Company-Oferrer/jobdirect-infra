# Quick Start - Configuracion Inicial

Esta guia te lleva paso a paso para configurar el proyecto desde cero.

## Requisitos Previos

Antes de empezar, necesitas tener instalado:

| Herramienta | Para que sirve | Como verificar |
|-------------|----------------|----------------|
| **Azure CLI** | Conectar a Azure desde terminal | `az --version` |
| **Terraform** | Crear infraestructura | `terraform --version` |
| **kubectl** | Administrar Kubernetes | `kubectl version --client` |
| **Git** | Control de versiones | `git --version` |

---

## Paso 1: Configurar Azure

### 1.1 Iniciar sesion en Azure

```bash
az login
```

Esto abrira el navegador para autenticarte. Una vez logueado, veras tus suscripciones.

### 1.2 Obtener tu Subscription ID

```bash
az account show --query id -o tsv
```

**Ejemplo de output:**
```
b497fd69-266c-46a9-b55b-8be0cd579667
```

**Guarda este ID**, lo necesitaras en varios lugares.

### 1.3 Verificar que estas en la suscripcion correcta

```bash
az account show --query name -o tsv
```

Si tienes multiples suscripciones, cambia con:
```bash
az account set --subscription "TU_SUBSCRIPTION_ID"
```

---

## Paso 2: Configurar Variables de Terraform

### Por que necesitamos esto?

Terraform necesita saber **a cual suscripcion de Azure conectarse** y las **credenciales de la base de datos**. Estos valores sensibles se configuran en archivos `terraform.tfvars` que **nunca se suben al repositorio** (estan en `.gitignore`).

### 2.1 Crear archivos terraform.tfvars

Cada ambiente tiene un archivo de ejemplo (`terraform.tfvars.example`). Copia y completa:

```bash
# Para DEV
cp terraform/dev/terraform.tfvars.example terraform/dev/terraform.tfvars

# Para QA
cp terraform/qa/terraform.tfvars.example terraform/qa/terraform.tfvars

# Para PROD
cp terraform/prod/terraform.tfvars.example terraform/prod/terraform.tfvars
```

### 2.2 Editar cada terraform.tfvars

Abri cada archivo y completa con tus valores reales:

```hcl
subscription_id         = "TU_SUBSCRIPTION_ID"
postgres_admin_password = "UNA_PASSWORD_SEGURA"
```

**IMPORTANTE:** Usa passwords diferentes para cada ambiente y nunca subas estos archivos a git.

### 2.3 Verificar

```bash
cat terraform/dev/terraform.tfvars
```

Deberia mostrar tu subscription ID y password (solo localmente).

---

## Paso 3: Crear Service Principal

### Que es un Service Principal?

Es una "cuenta de servicio" que GitHub Actions usara para conectarse a Azure. En lugar de usar tu cuenta personal, creamos una cuenta especifica con permisos limitados.

### 3.1 Crear el Service Principal

```bash
az ad sp create-for-rbac \
  --name "sp-jobdirect-infra" \
  --role Contributor \
  --scopes /subscriptions/TU_SUBSCRIPTION_ID \
  --sdk-auth
```

**Reemplaza** `TU_SUBSCRIPTION_ID` con tu ID real.

### 3.2 Guardar el output

El comando genera un JSON como este:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  ...
}
```

**COPIA TODO EL JSON** - lo necesitaras para GitHub Secrets.

### Por que estos campos?

| Campo | Que es                               |
|-------|--------------------------------------|
| `clientId` | ID de la "cuenta de servicio"        |
| `clientSecret` | "Contraseña" de la cuenta (SECRETO!) |
| `subscriptionId` | Tu suscripcion Azure                 |
| `tenantId` | Tu directorio Azure AD               |

---

## Paso 4: Configurar GitHub Secrets

### Que son los Secrets?

Son variables encriptadas que GitHub Actions puede usar. Nunca aparecen en logs ni en el codigo.

### 4.1 Ir a Settings del repositorio

1. Abre https://github.com/Company-Oferrer/jobdirect-infra
2. Click en **Settings** (icono engranaje)
3. En el menu izquierdo: **Secrets and variables** > **Actions**
4. Click en **New repository secret**

### 4.2 Crear los secrets necesarios

Crea estos secrets:

| Name | Value | Descripcion |
|------|-------|-------------|
| `AZURE_CREDENTIALS` | (pegar todo el JSON del paso 3) | Credenciales del Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Tu Subscription ID | Usado por Terraform en los workflows |
| `DOCKERHUB_USERNAME` | Tu usuario de DockerHub | Para push de imagenes |
| `INFRA_DEPLOY_TOKEN` | PAT con scopes `repo` + `workflow` | Disparar workflows desde/ hacia el repo de infra |
| `POSTGRES_ADMIN_PASSWORD_DEV` | Password segura para DEV | Usada por Terraform para crear PostgreSQL DEV |
| `POSTGRES_ADMIN_PASSWORD_QA` | Password segura para QA | Usada por Terraform para crear PostgreSQL QA |
| `POSTGRES_ADMIN_PASSWORD_PROD` | Password segura para PROD | Usada por Terraform para crear PostgreSQL PROD |

**IMPORTANTE:** Usa passwords diferentes para cada ambiente. Los workflows de Terraform pasan estos valores via `-var` flags, asi que nunca quedan en el codigo.

**IMPORTANTE 2:** Nuestra organizacion no permite habilitar `Read and write permissions` para `GITHUB_TOKEN`.  
Por eso el **PAT (`INFRA_DEPLOY_TOKEN`) es obligatorio**.

### 4.3 Verificar

Deberia verse asi en GitHub:

```
Repository secrets (7)
* AZURE_CREDENTIALS
* AZURE_SUBSCRIPTION_ID
* DOCKERHUB_USERNAME
* INFRA_DEPLOY_TOKEN
* POSTGRES_ADMIN_PASSWORD_DEV
* POSTGRES_ADMIN_PASSWORD_QA
* POSTGRES_ADMIN_PASSWORD_PROD
```

### 4.4 Configurar el mismo token en app y backend

Este mismo PAT debe guardarse como `INFRA_DEPLOY_TOKEN` en:

- `jobdirect-app`
- `jobdirect-backend`

------|-------|-------------|
| `AZURE_CREDENTIALS` | (pegar todo el JSON del paso 3) | Credenciales del Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Tu Subscription ID | Usado por Terraform en los workflows |
| `DOCKERHUB_USERNAME` | Tu usuario de DockerHub | Para push de imagenes |
| `POSTGRES_ADMIN_PASSWORD_DEV` | Password segura para DEV | Usada por Terraform para crear PostgreSQL DEV |
| `POSTGRES_ADMIN_PASSWORD_QA` | Password segura para QA | Usada por Terraform para crear PostgreSQL QA |
| `POSTGRES_ADMIN_PASSWORD_PROD` | Password segura para PROD | Usada por Terraform para crear PostgreSQL PROD |

**IMPORTANTE:** Usa passwords diferentes para cada ambiente. Los workflows de Terraform pasan estos valores via `-var` flags, asi que nunca quedan en el codigo.

### 4.3 Verificar

Deberia verse asi en GitHub:

```
Repository secrets (6)
â”œâ”€â”€ AZURE_CREDENTIALS
â”œâ”€â”€ AZURE_SUBSCRIPTION_ID
â”œâ”€â”€ DOCKERHUB_USERNAME
â”œâ”€â”€ POSTGRES_ADMIN_PASSWORD_DEV
â”œâ”€â”€ POSTGRES_ADMIN_PASSWORD_QA
â””â”€â”€ POSTGRES_ADMIN_PASSWORD_PROD
```

---

## Paso 5: Desplegar Infraestructura

Ahora podemos crear la infraestructura en Azure.

### Opcion A: Desde GitHub Actions (Recomendado)

1. Ir a **Actions** en el repositorio
2. Seleccionar **Deploy Infrastructure - DEV**
3. Click en **Run workflow**
4. Seleccionar branch `main`
5. Click en **Run workflow** (boton verde)

Esperar ~5-10 minutos. El workflow creara:
- Resource Group
- Cluster AKS
- PostgreSQL Database

### Opcion B: Desde Terminal (Manual)

```bash
cd terraform/dev

# Descargar providers de Terraform
terraform init

# Ver que se va a crear (sin crear nada)
terraform plan

# Crear la infraestructura
terraform apply
# Escribir "yes" cuando pregunte
```

---

## Paso 6: Verificar Infraestructura

### 6.1 Ver recursos creados

```bash
# Listar resource groups
az group list --query "[?contains(name, 'jobdirect')]" -o table

# Listar clusters AKS
az aks list --query "[?contains(name, 'jobdirect')]" -o table

# Listar PostgreSQL
az postgres flexible-server list --query "[?contains(name, 'jobdirect')]" -o table
```

### 6.2 Conectar a Kubernetes

```bash
az aks get-credentials \
  --resource-group rg-jobdirect-dev-01 \
  --name aks-jobdirect-dev-01

# Verificar conexion
kubectl get nodes
```

Deberia mostrar 1 nodo en estado `Ready`.

---

## Paso 7: Desplegar Aplicaciones

### 7.1 Crear el Secret de PostgreSQL

Las aplicaciones necesitan conectarse a la base de datos. Creamos un Secret en Kubernetes:

```bash
# Obtener el FQDN de PostgreSQL (desde Terraform o Azure Portal)
# Ejemplo: psql-jobdirect-dev-01.postgres.database.azure.com

POSTGRES_FQDN=psql-jobdirect-dev-01.postgres.database.azure.com (Could change)

kubectl create secret generic postgres-secret \
  --from-literal=connection-string="postgresql://jobdirectadmin:TU_PASSWORD@pg-jobdirect-dev.postgres.database.azure.com:5432/jobdirect"
```

### 7.2 Desplegar las aplicaciones

```bash
cd kubernetes/

# Desplegar backend
kubectl apply -f jobdirect-backend.yaml

# Desplegar frontend
kubectl apply -f jobdirect-app.yaml

# Verificar que estan corriendo
kubectl get pods
kubectl get svc
```

### 7.3 Obtener IP externa

```bash
kubectl get svc frontend-service
```

La columna `EXTERNAL-IP` es donde puedes acceder a la aplicacion.

---

## Resumen de lo que hicimos

1. **Configuramos Azure CLI** - Conexion a nuestra cuenta
2. **Actualizamos Terraform** - Con nuestro Subscription ID
3. **Creamos Service Principal** - Cuenta para GitHub Actions
4. **Configuramos GitHub Secrets** - Credenciales seguras
5. **Desplegamos infraestructura** - AKS + PostgreSQL
6. **Desplegamos aplicaciones** - Frontend + Backend

---

## Troubleshooting

### Error: "subscription not found"

Verifica que el Subscription ID es correcto:
```bash
az account show --query id -o tsv
```

### Error: "authorization failed"

El Service Principal no tiene permisos. Recrealo con:
```bash
az ad sp delete --id "sp-jobdirect-infra"
# Luego vuelve a crear con el comando del paso 3
```

### Error: "quota exceeded"

Tu suscripcion Azure no tiene suficiente cuota. Opciones:
- Usar VMs mas pequenas (Standard_B2s)
- Solicitar aumento de cuota en Azure Portal
- Usar una suscripcion diferente

### Los pods no inician

Ver logs del pod:
```bash
kubectl describe pod NOMBRE_DEL_POD
kubectl logs NOMBRE_DEL_POD
```

---

## Siguiente paso

Una vez que la infraestructura esta lista, configura el CI/CD siguiendo **[CI_CD_GUIDE.md](CI_CD_GUIDE.md)**.

