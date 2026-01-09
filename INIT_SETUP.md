# Configuración Rápida - Azure 

Guía breve para configurar el proyecto con cuenta Azure gratuita.

---

##  1. Actualizar Subscription ID

### Archivos a modificar (9 archivos):

**Cambiar en TODOS los archivos `provider.tf`:**

```bash
# Buscar en estos archivos:
terraform/dev/provider.tf
terraform/qa/provider.tf
terraform/prod/provider.tf
```

**Reemplazar esta línea:**
```hcl
subscription_id = "b497fd69-266c-46a9-b55b-8be0cd579667"
```

**Por tu nueva Subscription ID:**
```hcl
subscription_id = "TU_NUEVA_SUBSCRIPTION_ID"
```

### ¿Cómo obtener tu Subscription ID?

```bash
# Login en Azure
az login

# Ver tu Subscription ID
az account show --query id -o tsv

# Copiar el ID que aparece
```

---

## 2. Configurar GitHub Secrets

### Paso 1: Crear Service Principal

```bash
# Reemplaza TU_SUBSCRIPTION_ID con el valor real
az ad sp create-for-rbac \
  --name "sp-jobdirect-infra" \
  --role Contributor \
  --scopes /subscriptions/TU_SUBSCRIPTION_ID \
  --sdk-auth
```

**Copiar TODO el output JSON** (se verá así):
```json
{
  "clientId": "xxxxx",
  "clientSecret": "xxxxx",
  "subscriptionId": "xxxxx",
  "tenantId": "xxxxx",
  ...
}
```

### Paso 2: Agregar a GitHub

1. Ir a tu repositorio: https://github.com/Company-Oferrer/jobdirect-infra
2. Click en **Settings** (⚙️)
3. Click en **Secrets and variables** → **Actions**
4. Click en **New repository secret**

**Crear 2 secretos:**

| Name | Value |
|------|-------|
| `AZURE_CREDENTIALS` | Pegar TODO el JSON del paso 1 |
| `AZURE_SUBSCRIPTION_ID` | Tu Subscription ID |

---

## 3. Ajustes para Tier Gratuito (si es necesario)

### Archivo a modificar: `terraform/dev/aks.tf`

**Cambiar de:**
```hcl
default_node_pool {
  name       = "default"
  node_count = 1
  vm_size    = "standard_a2_v2"  # ❌ Puede no estar disponible en gratuito
}
```

**A:**
```hcl
default_node_pool {
  name       = "default"
  node_count = 1
  vm_size    = "Standard_B2s"  # ✅ Disponible en tier gratuito
}
```

### Archivo a modificar: `terraform/dev/postgres.tf`

**Cambiar de:**
```hcl
storage_mb = 32768 # 32 GB
sku_name   = "B_Standard_B1ms"
```

**A:**
```hcl
storage_mb = 32768 # 32 GB - Mínimo permitido
sku_name   = "B_Standard_B1ms"  # ✅ Tier más económico (OK para gratuito)
```

**IMPORTANTE:** Para QA y PROD, mejor NO crear por ahora (costos). Solo crear DEV.

---

## 4. Resumen de Cambios Necesarios

### Archivos a editar:

1. ✏️ `terraform/dev/provider.tf` → Cambiar `subscription_id`
2. ✏️ `terraform/qa/provider.tf` → Cambiar `subscription_id`
3. ✏️ `terraform/prod/provider.tf` → Cambiar `subscription_id`
4. ✏️ `terraform/dev/aks.tf` → Cambiar `vm_size` a `Standard_B2s`

### GitHub Secrets a crear:

1. 🔑 `AZURE_CREDENTIALS` → JSON completo del Service Principal
2. 🔑 `AZURE_SUBSCRIPTION_ID` → Tu Subscription ID

---

##  5. Pasos para Ejecutar (en orden)

### Actualizar Subscription ID:

### Actualizar VM Size en DEV si es necesario:

### Crear Service Principal:

```bash
az login
az account show --query id -o tsv  # Copiar este ID

# Usar el ID copiado:
az ad sp create-for-rbac \
  --name "sp-jobdirect-infra" \
  --role Contributor \
  --scopes /subscriptions/TU_ID_COPIADO \
  --sdk-auth
```

### Configurar GitHub Secrets:

```
1. GitHub → Settings → Secrets → Actions
2. New secret: AZURE_CREDENTIALS (pegar JSON)
3. New secret: AZURE_SUBSCRIPTION_ID (pegar ID)
```

---

## 6. Verificar Configuración

```bash
# 1. Verificar que tienes los 3 provider.tf actualizados
grep "subscription_id" terraform/*/provider.tf

# 2. Verificar que estás usando vm_size correcto
grep "vm_size" terraform/dev/aks.tf

# 3. Verificar login en Azure
az account show
```


---
