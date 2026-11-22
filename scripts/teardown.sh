#!/bin/bash
# scripts/teardown.sh
# Supprime tout ce que deploy-all.sh a créé (dans l'ordre inverse).
# ATTENTION : supprime aussi la base PostgreSQL (volume) et les Secrets.
#
# Usage : ./scripts/teardown.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Suppression de l'Ingress..."
kubectl delete -f k8s/ingress.yaml --ignore-not-found

for svc in frontend commandes panier catalogue postgres; do
  if [ -d "k8s/${svc}" ]; then
    echo "==> Suppression de ${svc}..."
    kubectl delete -f "k8s/${svc}/" --ignore-not-found
  fi
done

echo "==> Suppression des Secrets..."
kubectl delete secret postgres-secret catalogue-secret --ignore-not-found

echo ""
kubectl get all
echo "Nettoyage terminé."
