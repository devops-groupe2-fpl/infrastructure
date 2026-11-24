#!/bin/bash
# scripts/start-nagios.sh
# Démarre Nagios dans un conteneur Docker et charge la configuration du dépôt
# (nagios/conf.d/*.cfg). Peut être relancé à chaque modification de la configuration.
#
# Usage :
#   ./scripts/start-nagios.sh
#   SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...' ./scripts/start-nagios.sh
#
# Interface : http://localhost:8080/nagios   (identifiants par défaut : nagiosadmin / nagios)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NAME="nagios"
NAGIOS_PORT="${NAGIOS_PORT:-8080}"
IMAGE="jasonrivers/nagios:latest"
ETC="/opt/nagios/etc"

for cmd in docker minikube; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERREUR : '$cmd' est introuvable." >&2; exit 1; }
done

MINIKUBE_IP="$(minikube ip)"
echo "==> IP de Minikube : ${MINIKUBE_IP}"

echo "==> Démarrage du conteneur Nagios..."
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
else
  docker run -d --name "$NAME" -p "${NAGIOS_PORT}:80" "$IMAGE" >/dev/null
fi

echo "==> Attente de l'initialisation de Nagios..."
for _ in $(seq 1 30); do
  if docker exec "$NAME" test -f "${ETC}/nagios.cfg" 2>/dev/null; then break; fi
  sleep 2
done
docker exec "$NAME" test -f "${ETC}/nagios.cfg" || { echo "ERREUR : Nagios ne démarre pas (docker logs ${NAME})." >&2; exit 1; }

echo "==> Connexion de Nagios au réseau Docker de Minikube..."
docker network connect minikube "$NAME" 2>/dev/null || true

echo "==> Copie de la configuration..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp nagios/conf.d/*.cfg "$TMP/"
sed -i "s/MINIKUBE_IP/${MINIKUBE_IP}/g" "$TMP"/*.cfg

docker exec -u root "$NAME" rm -rf "${ETC}/groupe2"
docker exec -u root "$NAME" mkdir -p "${ETC}/groupe2"
docker cp "$TMP/." "${NAME}:${ETC}/groupe2/"
docker cp nagios/notify-groupe2.sh "${NAME}:/opt/nagios/libexec/notify-groupe2.sh"
docker exec -u root "$NAME" chmod 755 /opt/nagios/libexec/notify-groupe2.sh
docker exec -u root "$NAME" chown -R nagios:nagios "${ETC}/groupe2" /opt/nagios/libexec/notify-groupe2.sh

# Ajouter le dossier à nagios.cfg (une seule fois)
if ! docker exec "$NAME" grep -q "^cfg_dir=${ETC}/groupe2" "${ETC}/nagios.cfg"; then
  docker exec -u root "$NAME" sh -c "echo 'cfg_dir=${ETC}/groupe2' >> ${ETC}/nagios.cfg"
fi

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "==> Enregistrement du webhook Slack (non stocké dans Git)..."
  printf '%s' "$SLACK_WEBHOOK_URL" | docker exec -i -u root "$NAME" sh -c \
    "cat > /opt/nagios/var/slack_webhook.url && chown nagios:nagios /opt/nagios/var/slack_webhook.url && chmod 600 /opt/nagios/var/slack_webhook.url"
fi

echo "==> Vérification de la configuration..."
docker exec "$NAME" /opt/nagios/bin/nagios -v "${ETC}/nagios.cfg" | tail -n 12

echo "==> Redémarrage de Nagios pour charger la configuration..."
docker restart "$NAME" >/dev/null

echo ""
echo "Nagios est lancé : http://localhost:${NAGIOS_PORT}/nagios  (nagiosadmin / nagios)"
echo "Test manuel d'un check : docker exec ${NAME} /opt/nagios/libexec/check_http -I ${MINIKUBE_IP} -p 80 -u /api/panier/health -e 200"
echo "Journal des alertes   : docker exec ${NAME} cat /opt/nagios/var/groupe2-alerts.log"
