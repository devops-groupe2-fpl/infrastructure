# Nagios : installation, checks et alertes

Supervision des 4 services (Catalogue, Panier, Commandes, Frontend) du projet DevOps II — Groupe 2.

## 1. Principe

Nagios tourne dans un conteneur Docker, **hors du cluster**. Toutes les 2 minutes, il envoie une requête HTTP à chaque service **à travers l'Ingress** (`http://<minikube ip>/api/<service>/health`). Si le service ne répond pas `200`, il passe en CRITICAL et une alerte est envoyée.

```
Conteneur Nagios ──► Ingress (minikube ip :80) ──► service ──► pod
```

## 2. Image utilisée

Il n'existe pas d'image officielle `nagios/nagios` : on utilise l'image communautaire **`jasonrivers/nagios`**.

- Interface web : `http://localhost:8080/nagios`
- Identifiants par défaut : `nagiosadmin` / `nagios` (à changer en dehors d'un usage de démonstration)
- Configuration dans le conteneur : `/opt/nagios/etc`

## 3. Fichiers du dépôt

| Fichier | Rôle |
|---|---|
| `nagios/conf.d/hosts.cfg` | L'hôte supervisé (le cluster Minikube) |
| `nagios/conf.d/services.cfg` | Les 4 checks HTTP (intervalle 2 min) |
| `nagios/conf.d/contacts.cfg` | Contacts, commandes de notification |
| `nagios/notify-groupe2.sh` | Script de notification : journal + Slack |
| `scripts/start-nagios.sh` | Lance Nagios et charge la configuration |

## 4. Prérequis

- Le cluster tourne (`./scripts/start-cluster.sh`) et l'application est déployée (`./scripts/deploy-all.sh`).
- Docker est démarré.

## 5. Démarrage

```bash
./scripts/start-nagios.sh
```

Avec alertes Slack (voir §8) :

```bash
SLACK_WEBHOOK_URL='https://hooks.slack.com/services/XXX/YYY/ZZZ' ./scripts/start-nagios.sh
```

Le script :
1. lance le conteneur `nagios` (port 8080) ;
2. le connecte au réseau Docker de Minikube, pour qu'il atteigne l'Ingress ;
3. copie `nagios/conf.d/` dans le conteneur en remplaçant `MINIKUBE_IP` par `minikube ip` ;
4. vérifie la configuration (`nagios -v`) puis redémarre Nagios.

Après chaque modification de `nagios/conf.d/`, relancer simplement le script.

## 6. Vérifier que ça fonctionne

1. Ouvrir `http://localhost:8080/nagios` et se connecter.
2. Menu **Services** : les 4 services doivent passer à **OK** (vert) après quelques minutes. Au début ils sont « PENDING ».
3. Test manuel d'un check, sans attendre :
   ```bash
   docker exec nagios /opt/nagios/libexec/check_http -I $(minikube ip) -p 80 -u /api/panier/health -e 200
   ```
   Résultat attendu : `HTTP OK: HTTP/1.1 200 OK ...`

Les services pas encore déployés (par exemple Commandes) sont affichés en rouge : c'est normal.

## 7. Paramètres des checks

| Paramètre | Valeur | Effet |
|---|---|---|
| `check_interval` | 2 | un check toutes les 2 minutes |
| `retry_interval` | 1 | après un échec, nouveau check 1 minute plus tard |
| `max_check_attempts` | 1 | un échec = CRITICAL immédiat |
| `first_notification_delay` | 1 | l'alerte part 1 minute après le passage en CRITICAL |
| `notification_options` | c,u,r | alerte DOWN **et** retour UP |

Frontend : testé sur `/` (nginx statique sans endpoint `/health`).

## 8. Alertes

Chaque notification est :

1. **toujours** écrite dans le journal du conteneur :
   ```bash
   docker exec nagios cat /opt/nagios/var/groupe2-alerts.log
   ```
2. **envoyée sur Slack** si un webhook est configuré.

### Configurer Slack (optionnel)

1. Dans Slack : *Apps* → *Incoming Webhooks* → créer un webhook pour un canal. Copier l'URL.
2. Relancer `SLACK_WEBHOOK_URL='<url>' ./scripts/start-nagios.sh`.

**L'URL du webhook est un secret : ne jamais la commiter** (le dépôt est public). Elle est stockée uniquement dans le conteneur.

### Email (alternative)

Il faut configurer un serveur SMTP dans le conteneur ; non utilisé ici. La notification par journal et Slack suffit pour la démonstration.

## 9. Scénario de démonstration

Cet exemple utilise le Panier.

```bash
# 1. État initial : Panier est OK (vert) dans Nagios
kubectl scale deploy panier --replicas=0
# 2. Attendre l'alerte Nagios
```

Résultat attendu : le service Panier passe en **CRITICAL** (rouge), puis l'alerte `[PROBLEM] Service Panier ... CRITICAL` apparaît dans Slack et dans le journal.

```bash
kubectl scale deploy panier --replicas=1
```

Résultat attendu : le service repasse en **OK** (vert) et une alerte `[RECOVERY]` est envoyée.

**Délai :** Nagios vérifie toutes les 2 minutes, plus 1 minute de délai avant alerte. Dans le pire cas l'alerte arrive donc après environ 3 minutes. Pour une démonstration rapide, ouvrir le service dans l'interface Nagios et utiliser **Re-schedule the next check of this service** (Forcer le check) juste après `scale ... --replicas=0`.

### Checklist du test

- [ ] Panier vert avant le test
- [ ] Après `--replicas=0` : Panier rouge, alerte reçue (heure : ____)
- [ ] Après `--replicas=1` : Panier vert, alerte de retour reçue (heure : ____)
- [ ] Captures d'écran jointes (Nagios rouge, alerte, Nagios vert)

## 10. Problèmes fréquents

| Problème | Cause probable | Solution |
|---|---|---|
| Tous les services en CRITICAL « Connection timed out » | Nagios n'atteint pas l'Ingress | `docker network connect minikube nagios`, vérifier `minikube ip` puis relancer `start-nagios.sh` |
| `nagios -v` affiche des erreurs | Faute dans un fichier `.cfg` | Lire l'erreur (fichier et ligne), corriger, relancer le script |
| `Could not find a contactgroup / template` | Les modèles par défaut de l'image sont absents | Vérifier `docker exec nagios ls /opt/nagios/etc/objects` |
| Pas de message Slack | Webhook absent ou incorrect | Voir le journal `groupe2-alerts.log` (toujours rempli) ; relancer le script avec `SLACK_WEBHOOK_URL` |
| Les checks sont en « PENDING » | Les premiers checks n'ont pas eu lieu | Attendre 1 à 2 minutes ou forcer le check depuis l'interface |
| Après `minikube delete`, tout est rouge | L'IP de Minikube a changé | Relancer `./scripts/start-nagios.sh` (met à jour l'IP) |

## 11. Arrêt et nettoyage

```bash
docker stop nagios
docker rm nagios        # supprime aussi la configuration chargée
```
