#!/bin/bash
# scripts/create-secrets.sh
# Crée les Secrets Kubernetes (mots de passe) SANS les écrire dans Git.
#
# Usage :
#   ./scripts/create-secrets.sh                        # mot de passe aléatoire
#   POSTGRES_PASSWORD='monmotdepasse' ./scripts/create-secrets.sh
#
# Si les Secrets existent déjà, le script ne fait rien.

set -euo pipefail

DB_USER="catalogue"
DB_NAME="catalogue"

if kubectl get secret postgres-secret >/dev/null 2>&1; then
  echo "Les Secrets existent déjà : rien à faire."
  exit 0
fi

PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 12)}"

kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD="${PASSWORD}"

kubectl create secret generic catalogue-secret \
  --from-literal=DATABASE_URL="postgresql://${DB_USER}:${PASSWORD}@postgres-service:5432/${DB_NAME}"

echo "Secrets créés : postgres-secret, catalogue-secret."
