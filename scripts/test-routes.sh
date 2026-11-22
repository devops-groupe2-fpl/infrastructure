#!/bin/bash
# scripts/test-routes.sh
# Teste chaque route de l'Ingress avec curl et affiche OK / ÉCHEC.
#
# Sous WSL, 'minikube ip' n'est pas joignable. Ouvrir un autre terminal et lancer :
#   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
# puis :
#   ./scripts/test-routes.sh                       # utilise http://127.0.0.1:8081
#
# Sous Linux natif, on peut tester directement l'IP de Minikube :
#   BASE_URL=http://$(minikube ip) ./scripts/test-routes.sh

set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8081}"
FAIL=0

check() {
  local label="$1" path="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${BASE_URL}${path}" || true)
  if [ "$code" = "200" ]; then
    printf "OK      %-12s %-28s HTTP %s\n" "$label" "$path" "$code"
  else
    printf "ÉCHEC   %-12s %-28s HTTP %s\n" "$label" "$path" "${code:-000}"
    FAIL=1
  fi
}

echo "Test des routes sur ${BASE_URL}"
echo "---------------------------------------------------------------"
check "catalogue" "/api/catalogue/health"
check "catalogue" "/api/catalogue/products"
check "panier"    "/api/panier/health"
check "panier"    "/api/panier/cart/user1"
check "commandes" "/api/commandes/health"
check "frontend"  "/"
echo "---------------------------------------------------------------"

if [ "$FAIL" -eq 0 ]; then
  echo "Toutes les routes répondent."
else
  echo "Certaines routes échouent (service non déployé ou en erreur)."
  exit 1
fi
