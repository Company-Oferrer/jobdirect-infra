#!/bin/bash
set -e

################################################################################
# Script de Instalación de Monitoreo AKS/K8s
# Instala Prometheus + Alertmanager + Grafana con dashboards básicos
# Las credenciales sensibles se toman de variables de entorno
# Uso: 
#   export SMTP_USER="correo@gmail.com"
#   export SMTP_PASS="clave_app"
#   export ALERT_TO="destino@gmail.com"
#   bash setup-monitoring.sh
################################################################################

NAMESPACE="monitoring"
PROM_RELEASE="prometheus"
GRAFANA_RELEASE="grafana"
GRAFANA_PORT=3000

# Verificar variables sensibles
: "${SMTP_USER:?Debe definir SMTP_USER}"
: "${SMTP_PASS:?Debe definir SMTP_PASS}"
: "${ALERT_TO:?Debe definir ALERT_TO}"

echo "=== SETUP MONITOREO K8S ==="

echo "==> Creando namespace (si no existe)"
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

echo "==> Agregando repos Helm"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> Creando values.yaml para Prometheus + Alertmanager"
cat <<EOF > values.yaml
serverFiles:
  alerts:
    groups:
    - name: disk-alerts
      rules:
      - alert: DiskUsageHigh
        expr: (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"})
              / node_filesystem_size_bytes{mountpoint="/"} * 100 > 0.1
        for: 10s
        labels:
          severity: critical
        annotations:
          summary: "Disco alto en {{ \$labels.instance }}"
          description: "El nodo {{ \$labels.instance }} superó 0.1% de uso de disco en / durante 10s."
    - name: memory-alerts
      rules:
      - alert: MemoryUsageHigh
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
              / node_memory_MemTotal_bytes * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Memoria alta en {{ \$labels.instance }}"
          description: "El nodo {{ \$labels.instance }} superó 80% de uso de memoria durante 2m."

alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: '${SMTP_USER}'
      smtp_auth_username: '${SMTP_USER}'
      smtp_auth_password: '${SMTP_PASS}'
      smtp_require_tls: true
    route:
      receiver: 'correo'
    receivers:
    - name: 'correo'
      email_configs:
      - to: '${ALERT_TO}'
EOF

echo "==> Instalando / Actualizando Prometheus (ClusterIP)"
helm upgrade --install $PROM_RELEASE prometheus-community/prometheus \
  --namespace $NAMESPACE \
  -f values.yaml

kubectl patch svc prometheus-server -n $NAMESPACE -p '{"spec":{"type":"ClusterIP"}}'

echo "==> Instalando / Actualizando Grafana (LoadBalancer)"
helm upgrade --install $GRAFANA_RELEASE grafana/grafana \
  --namespace $NAMESPACE

kubectl patch svc grafana -n $NAMESPACE -p '{"spec":{"type":"LoadBalancer"}}'

echo "==> Esperando que Grafana esté listo"
kubectl rollout status deployment/grafana -n $NAMESPACE

echo "==> Obteniendo credenciales de Grafana"
GRAFANA_PASS=$(kubectl get secret grafana -n $NAMESPACE \
  -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "Usuario Grafana : admin"
echo "Password Grafana: $GRAFANA_PASS"

echo "==> Esperando IP externa de Grafana"
until kubectl get svc grafana -n $NAMESPACE \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .
do
  sleep 5
done

GRAFANA_IP=$(kubectl get svc grafana -n $NAMESPACE \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "IP externa Grafana: http://$GRAFANA_IP:$GRAFANA_PORT"

echo "==> Creando dashboard"
cat <<'EOF' > dashboard.json
{
  "dashboard": {
    "id": null,
    "title": "AKS - Dashboard Corregido",
    "tags": ["aks", "monitoring", "prometheus"],
    "timezone": "browser",
    "schemaVersion": 30,
    "version": 1,
    "refresh": "10s",
    "panels": [
      {
        "type": "timeseries",
        "title": "Uso de CPU (%) por nodo",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": { "defaults": { "unit": "percent" } },
        "gridPos": { "x": 0, "y": 0, "w": 8, "h": 6 }
      },
      {
        "type": "timeseries",
        "title": "Uso de Memoria (%) por nodo",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": { "defaults": { "unit": "percent" } },
        "gridPos": { "x": 8, "y": 0, "w": 8, "h": 6 }
      }
    ]
  },
  "overwrite": true
}
EOF

echo "==> Importando dashboard en Grafana"
curl -s -X POST \
  http://$GRAFANA_IP:$GRAFANA_PORT/api/dashboards/db \
  -H "Content-Type: application/json" \
  -u admin:$GRAFANA_PASS \
  -d @dashboard.json >/dev/null

echo "==> Ejecutando test rápido de disco (100MB)"
kubectl run disk-test --rm -i --tty --image=ubuntu -- bash -c \
  "dd if=/dev/zero of=file1 bs=1M count=100 && rm file1"

echo ""
echo "======================================"
echo "✅ MONITOREO LISTO"
echo "Grafana URL : http://$GRAFANA_IP:$GRAFANA_PORT"
echo "Usuario     : admin"
echo "Password    : $GRAFANA_PASS"
echo "Prometheus  : ClusterIP"
echo "Alertas     : Disco + Memoria + Email"
echo "Test disco  : ✔ ejecutado"
echo "======================================"
