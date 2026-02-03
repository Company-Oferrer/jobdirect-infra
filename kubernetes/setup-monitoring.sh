#!/bin/bash
set -e

################################################################################
# Script de Instalación de Monitoreo AKS/K8s (PRODUCCIÓN)
# Prometheus + Alertmanager + Grafana con provisioning
#   export SMTP_USER="correo@gmail.com"


#   export SMTP_PASS="clave_app"


#   export ALERT_TO="destino@gmail.com"


#   bash setup-monitoring.sh

################################################################################

NAMESPACE="monitoring"
PROM_RELEASE="prometheus"
GRAFANA_RELEASE="grafana"

# Variables sensibles
: "${SMTP_USER:?Debe definir SMTP_USER}"
: "${SMTP_PASS:?Debe definir SMTP_PASS}"
: "${ALERT_TO:?Debe definir ALERT_TO}"

echo "=== SETUP MONITOREO K8S ==="

kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

###############################################################################
# PROMETHEUS + ALERTMANAGER
###############################################################################
cat <<EOF > values-prometheus.yaml
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
    - name: memory-alerts
      rules:
      - alert: MemoryUsageHigh
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
              / node_memory_MemTotal_bytes * 100 > 80
        for: 2m
        labels:
          severity: warning

alertmanager:
  config:
    global:
      smtp_smarthost: smtp.gmail.com:587
      smtp_from: '${SMTP_USER}'
      smtp_auth_username: '${SMTP_USER}'
      smtp_auth_password: '${SMTP_PASS}'
      smtp_require_tls: true
    route:
      receiver: correo
    receivers:
    - name: correo
      email_configs:
      - to: '${ALERT_TO}'
EOF

helm upgrade --install $PROM_RELEASE prometheus-community/prometheus \
  -n $NAMESPACE -f values-prometheus.yaml

kubectl patch svc prometheus-server -n $NAMESPACE -p '{"spec":{"type":"ClusterIP"}}'

###############################################################################
# GRAFANA (DATASOURCE + DASHBOARD AUTOMÁTICO)
###############################################################################
cat <<'EOF' > values-grafana.yaml
adminUser: admin

service:
  type: LoadBalancer

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus-server.monitoring.svc.cluster.local
      isDefault: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: default
      orgId: 1
      folder: ""
      type: file
      editable: true
      options:
        path: /var/lib/grafana/dashboards

dashboards:
  default:
    aks-dashboard:
      json: |
        {
          "id": null,
          "title": "AKS - Dashboard",
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
                { "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)" }
              ],
              "fieldConfig": { "defaults": { "unit": "percent" } },
              "gridPos": { "x": 0, "y": 0, "w": 8, "h": 6 }
            },
            {
              "type": "timeseries",
              "title": "Uso de Memoria (%) por nodo",
              "targets": [
                { "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100" }
              ],
              "fieldConfig": { "defaults": { "unit": "percent" } },
              "gridPos": { "x": 8, "y": 0, "w": 8, "h": 6 }
            },
            {
              "type": "timeseries",
              "title": "Uso de Disco (%) en /",
              "targets": [
                { "expr": "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\",mountpoint=\"/\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\",mountpoint=\"/\"})) * 100" }
              ],
              "fieldConfig": { "defaults": { "unit": "percent" } },
              "gridPos": { "x": 0, "y": 6, "w": 8, "h": 6 }
            },
            {
              "type": "bargauge",
              "title": "Cantidad de Pods por Namespace",
              "targets": [
                { "expr": "count(kube_pod_info) by (namespace)" }
              ],
              "gridPos": { "x": 8, "y": 6, "w": 8, "h": 6 }
            },
            {
              "type": "stat",
              "title": "Pods Running",
              "targets": [
                { "expr": "count(kube_pod_status_phase{phase=\"Running\"})" }
              ],
              "gridPos": { "x": 0, "y": 12, "w": 4, "h": 4 }
            },
            {
              "type": "stat",
              "title": "Pods Pending",
              "targets": [
                { "expr": "count(kube_pod_status_phase{phase=\"Pending\"})" }
              ],
              "gridPos": { "x": 4, "y": 12, "w": 4, "h": 4 }
            },
            {
              "type": "stat",
              "title": "Pods Failed",
              "targets": [
                { "expr": "count(kube_pod_status_phase{phase=\"Failed\"})" }
              ],
              "gridPos": { "x": 8, "y": 12, "w": 4, "h": 4 }
            },
            {
              "type": "timeseries",
              "title": "Tráfico de Red (Rx / Tx)",
              "targets": [
                { "expr": "rate(node_network_receive_bytes_total[5m])" },
                { "expr": "rate(node_network_transmit_bytes_total[5m])" }
              ],
              "fieldConfig": { "defaults": { "unit": "bytes" } },
              "gridPos": { "x": 0, "y": 16, "w": 16, "h": 6 }
            }
          ]
        }
EOF

helm upgrade --install $GRAFANA_RELEASE grafana/grafana \
  -n $NAMESPACE -f values-grafana.yaml



echo "==> Ejecutando test rápido de disco (100MB)" kubectl run disk-test --rm -i --tty --image=ubuntu -- bash -c \ "dd if=/dev/zero of=file1 bs=1M count=100 && rm file1"


###############################################################################
# OUTPUT FINAL
###############################################################################
kubectl rollout status deployment/grafana -n $NAMESPACE

PASS=$(kubectl get secret grafana -n $NAMESPACE -o jsonpath="{.data.admin-password}" | base64 --decode)
IP=$(kubectl get svc grafana -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "======================================"
echo "MONITOREO LISTO"
echo "Grafana URL : http://$IP"
echo "Usuario     : admin"
echo "Password    : $PASS"
echo "Dashboard   : AKS - Dashboard"
echo "======================================"
