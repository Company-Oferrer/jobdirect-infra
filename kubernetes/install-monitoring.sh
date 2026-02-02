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

echo "→ Limpiando webhooks residuales (si existen)"
kubectl delete validatingwebhookconfiguration monitoring-kube-prometheus-admission 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration monitoring-kube-prometheus-admission 2>/dev/null || true

echo "→ Instalando kube-prometheus-stack"
helm upgrade --install $RELEASE prometheus-community/kube-prometheus-stack \
  -n $NAMESPACE \
  -f values-dev.yaml \
  --set prometheusOperator.admissionWebhooks.enabled=false \
  --set prometheusOperator.tls.enabled=false \
  --wait --timeout 300s

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

echo "→ Exponiendo Grafana con IP pública..."
kubectl patch svc $RELEASE-grafana -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}'

echo ""
echo "=== Credenciales Grafana ==="
echo "Usuario: admin"
echo -n "Password: "

kubectl get secret $RELEASE-grafana -n $NAMESPACE \
  -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""

echo ""
echo "=== Esperando IP pública de Grafana (puede tomar 1-2 minutos) ==="
sleep 30
GRAFANA_IP=$(kubectl get svc $RELEASE-grafana -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana: http://$GRAFANA_IP"
echo ""
echo "=== Accesos por port-forward (Prometheus y Alertmanager) ==="
echo "Prometheus:"
echo " kubectl port-forward svc/$RELEASE-kube-prometheus-prometheus -n $NAMESPACE 9090:9090"
echo " → http://localhost:9090"
echo ""
echo "Alertmanager:"
echo " kubectl port-forward svc/$RELEASE-kube-prometheus-alertmanager -n $NAMESPACE 9093:9093"
echo " → http://localhost:9093"
echo ""
echo "✅ Instalación completada correctamente"
