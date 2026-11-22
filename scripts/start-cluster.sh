#!/bin/bash
# scripts/start-cluster.sh
# Démarre un cluster Minikube prêt pour le projet (Ingress + metrics-server).
# Usage : ./scripts/start-cluster.sh

set -euo pipefail

CPUS="${MINIKUBE_CPUS:-2}"
MEMORY="${MINIKUBE_MEMORY:-4096}"

echo "==> Vérification des prérequis..."
for cmd in docker minikube kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERREUR : '$cmd' n'est pas installé." >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERREUR : Docker n'est pas démarré (ou permission refusée)." >&2
  exit 1
fi

echo "==> Démarrage de Minikube (driver=docker, cpus=${CPUS}, memory=${MEMORY}MB)..."
minikube start --driver=docker --cpus="${CPUS}" --memory="${MEMORY}"

echo "==> Activation des addons..."
minikube addons enable ingress
minikube addons enable metrics-server

echo "==> Attente du contrôleur Ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "==> Vérification de la connexion kubectl..."
kubectl config use-context minikube >/dev/null
kubectl get nodes

echo ""
echo "Cluster prêt."
echo "IP du cluster : $(minikube ip)"
