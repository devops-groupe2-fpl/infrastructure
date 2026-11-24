#!/bin/bash
# nagios/notify-groupe2.sh
# Appelé par Nagios pour chaque notification (service DOWN, retour UP).
# Copié dans le conteneur par scripts/start-nagios.sh
#   -> /opt/nagios/libexec/notify-groupe2.sh
#
# Arguments : TYPE NOTIFICATIONTYPE HOST DESC STATE OUTPUT DATE

KIND="$1"
NTYPE="$2"
HOST="$3"
DESC="$4"
STATE="$5"
OUTPUT="$6"
WHEN="$7"

LOG="/opt/nagios/var/groupe2-alerts.log"
WEBHOOK_FILE="/opt/nagios/var/slack_webhook.url"

if [ "$KIND" = "SERVICE" ]; then
  MSG="[${NTYPE}] Service ${DESC} sur ${HOST} : ${STATE} - ${OUTPUT} (${WHEN})"
else
  MSG="[${NTYPE}] Hote ${HOST} : ${STATE} - ${OUTPUT} (${WHEN})"
fi

# 1) Toujours écrire dans le journal
echo "${MSG}" >> "${LOG}"

# 2) Envoyer sur Slack si un webhook est configuré
if [ -s "${WEBHOOK_FILE}" ] && command -v curl >/dev/null 2>&1; then
  URL="$(cat "${WEBHOOK_FILE}")"
  SAFE="${MSG//\\/\\\\}"
  SAFE="${SAFE//\"/\\\"}"
  curl -s -m 10 -X POST -H 'Content-type: application/json' \
       --data "{\"text\":\"${SAFE}\"}" "${URL}" >/dev/null 2>&1
fi

exit 0
