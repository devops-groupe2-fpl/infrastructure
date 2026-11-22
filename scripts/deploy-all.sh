#!/bin/bash
# scripts/deploy-all.sh
# Déploie toute l'application sur le cluster Minikube, dans l'ordre :
#   secrets -> postgres -> catalogue -> panier -> commandes -> frontend -> ingress
# puis vérifie que chaque Deployment est prêt.
#
# Usage : ./scripts/deploy-all.sh
# Variable optionnelle : TIMEOUT (secondes d'attente par service, défaut 120)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TIMEOUT="${TIMEOUT:-120}"
FAILED=()
SKIPPED=()
DEPLOYED=()

echo "==> Vérification du cluster..."
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERREUR : cluster injoignable. Lancer d'abord ./scripts/start-cluster.sh" >&2
  exit 1
fi

echo "==> 1/7 Secrets..."
./scripts/create-secrets.sh || { echo "ERREUR : création des secrets" >&2; exit 1; }

# deploy_service <dossier> : applique k8s/<dossier>/ sauf si le dossier manque
# ou si l'image est encore le texte à remplacer (DOCKERHUB_USER).
deploy_service() {
  local svc="$1"
  local dir="k8s/${svc}"

  if [ ! -d "$dir" ]; then
    echo "    - ${svc} : dossier absent, ignoré"
    SKIPPED+=("${svc} (dossier absent)")
    return
  fi
  if grep -rq "DOCKERHUB_USER" "$dir"; then
    echo "    - ${svc} : image à définir (DOCKERHUB_USER), ignoré"
    SKIPPED+=("${svc} (image non définie)")
    return
  fi

  echo "    - ${svc} : kubectl apply"
  if kubectl apply -f "${dir}/"; then
    DEPLOYED+=("${svc}")
  else
    FAILED+=("${svc} (apply)")
  fi
}

echo "==> 2/7 PostgreSQL..."
deploy_service postgres
echo "==> 3/7 Catalogue..."
deploy_service catalogue
echo "==> 4/7 Panier..."
deploy_service panier
echo "==> 5/7 Commandes..."
deploy_service commandes
echo "==> 6/7 Frontend..."
deploy_service frontend

echo "==> 7/7 Ingress..."
if kubectl apply -f k8s/ingress.yaml; then
  :
else
  FAILED+=("ingress (apply)")
fi

echo "==> Vérification des déploiements (attente max ${TIMEOUT}s par service)..."
for svc in "${DEPLOYED[@]}"; do
  if kubectl rollout status "deploy/${svc}" --timeout="${TIMEOUT}s"; then
    echo "    OK : ${svc}"
  else
    echo "    ÉCHEC : ${svc}" >&2
    FAILED+=("${svc} (rollout)")
  fi
done

echo ""
echo "================ Résumé ================"
kubectl get pods
echo ""
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "Ignorés :"
  printf '  - %s\n' "${SKIPPED[@]}"
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "ÉCHECS :" >&2
  printf '  - %s\n' "${FAILED[@]}" >&2
  exit 1
fi
echo "Déploiement terminé."
echo "Tester les routes : ./scripts/test-routes.sh"
