#!/bin/bash

# Script de configuración de monitoreo para JobDirect
# Basado en los comandos de clase Clase_01_02

ENVIRONMENT=${1:-dev}

echo "=== Instalando stack de monitoreo para entorno: $ENVIRONMENT ==="

# 1. Crear namespace para monitoreo
echo "Creando namespace monitoring..."
kubectl create namespace monitoring

# 2. Instalar Prometheus
echo "Instalando Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus --namespace monitoring

# 3. Exponer Prometheus con LoadBalancer
echo "Exponiendo Prometheus..."
kubectl patch svc prometheus-server -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# 4. Instalar Grafana
echo "Instalando Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana --namespace monitoring

# 5. Exponer Grafana con LoadBalancer
echo "Exponiendo Grafana..."
kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# 6. Obtener contraseña de Grafana
echo ""
echo "=== Credenciales de Grafana ==="
echo "Usuario: admin"
echo "Password:"
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""

# 7. Esperar y mostrar IPs de servicios
echo ""
echo "=== Esperando asignación de IPs externas (esto puede tomar 2-3 minutos) ==="
sleep 30
kubectl get svc -n monitoring

echo ""
echo "=== Configuración completada ==="
echo ""
echo "Próximos pasos:"
echo "1. Accede a Grafana usando la IP externa del servicio 'grafana'"
echo "2. Configura Prometheus como data source:"
echo "   URL: http://prometheus-server.monitoring.svc.cluster.local:80"
echo "3. Importa dashboards de Kubernetes desde Grafana.com"
echo ""
