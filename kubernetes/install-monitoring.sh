#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
NAMESPACE="monitoring"
RELEASE="monitoring"

echo "=============================================="
echo " Instalando monitoreo JobDirect - $ENVIRONMENT"
echo "=============================================="

echo "→ Creando namespace $NAMESPACE (si no existe)"
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE

echo "→ Configurando Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

echo "→ FASE 1: instalar kube-prometheus-stack SIN webhooks"
helm upgrade --install $RELEASE prometheus-community/kube-prometheus-stack \
  -n $NAMESPACE \
  -f alertmanager-values.yaml \
  --set prometheusOperator.admissionWebhooks.enabled=false \
  --wait=false

echo "→ Esperando kube-prometheus-operator..."
kubectl rollout status deployment/$RELEASE-kube-prometheus-operator \
  -n $NAMESPACE \
  --timeout=300s

echo "→ FASE 2: habilitando webhooks (upgrade limpio)"
helm upgrade $RELEASE prometheus-community/kube-prometheus-stack \
  -n $NAMESPACE \
  -f alertmanager-values.yaml

echo "→ Esperando Prometheus..."
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=prometheus \
  -n $NAMESPACE \
  --timeout=300s

echo "→ Esperando Alertmanager..."
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=alertmanager \
  -n $NAMESPACE \
  --timeout=300s

echo "→ Aplicando alertas JobDirect"
kubectl apply -f jobdirect-alerts.yaml

echo ""
echo "=== Credenciales Grafana ==="
echo "Usuario: admin"
echo -n "Password: "
kubectl get secret $RELEASE-grafana -n $NAMESPACE \
  -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""

echo ""
echo "=== Accesos locales ==="
echo "Grafana:"
echo " kubectl port-forward svc/$RELEASE-grafana -n $NAMESPACE 3000:80"
echo " → http://localhost:3000"
echo ""
echo "Prometheus:"
echo " kubectl port-forward svc/$RELEASE-kube-prometheus-prometheus -n $NAMESPACE 9090:9090"
echo " → http://localhost:9090"
echo ""
echo "Alertmanager:"
echo " kubectl port-forward svc/$RELEASE-kube-prometheus-alertmanager -n $NAMESPACE 9093:9093"
echo " → http://localhost:9093"
echo ""
echo "✅ Instalación completada correctamente"
dasd
