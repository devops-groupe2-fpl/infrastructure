# Setup Minikube & cluster Kubernetes

Ce document explique comment installer et démarrer le cluster Kubernetes local utilisé par le projet (Mini-Projet DevOps II, Groupe 2).

## 1. Prérequis

| Ressource | Minimum | Recommandé |
|---|---|---|
| CPU | 2 cœurs | 4 cœurs |
| RAM libre | 4 Go | 8 Go |
| Disque libre | 20 Go | 30 Go |
| OS | Linux, macOS ou Windows 10/11 | |

Logiciels requis (versions testées : **à compléter avec vos versions**) :

| Outil | Version testée | Vérification |
|---|---|---|
| Docker | `29.9.1` | `docker --version` |
| Minikube | `1.39.0` | `minikube version` |
| kubectl | `1.37.2` | `kubectl version --client` |



## 2. Installation

- Docker : https://docs.docker.com/get-docker/
- Minikube : https://minikube.sigs.k8s.io/docs/start/
- kubectl : https://kubernetes.io/docs/tasks/tools/

Sous Linux, ajoutez votre utilisateur au groupe docker pour éviter `sudo` :

```bash
sudo usermod -aG docker $USER
# puis fermer et rouvrir la session
```

## 3. Démarrer le cluster

Méthode recommandée (script du dépôt) :

```bash
chmod +x scripts/start-cluster.sh
./scripts/start-cluster.sh
```

Méthode manuelle (équivalente) :

```bash
minikube start --driver=docker --cpus=2 --memory=4096
minikube addons enable ingress
minikube addons enable metrics-server
```

Rôle des addons :
- `ingress` : installe le contrôleur nginx qui reçoit le trafic HTTP et le route vers les services.
- `metrics-server` : permet `kubectl top pods` / `kubectl top nodes` (CPU et RAM).

## 4. Vérifier que tout fonctionne

```bash
kubectl config current-context      # doit afficher : minikube
kubectl get nodes                   # STATUS = Ready
kubectl get pods -n ingress-nginx   # le pod "controller" est Running
kubectl top nodes                   # fonctionne après ~1 min
minikube ip                         # IP du cluster (utilisée pour les tests curl)
```

## 5. Utiliser des images Docker locales

Pour que Minikube trouve une image construite en local (sans la pousser sur Docker Hub) :

```bash
eval $(minikube docker-env)         # Linux / macOS
docker build -t catalogue:v1.0 .
```

Ou charger une image déjà construite :

```bash
minikube image load catalogue:v1.0
```

Dans le manifest, utiliser alors `imagePullPolicy: IfNotPresent`.

## 6. Commandes utiles

| Action | Commande |
|---|---|
| Arrêter le cluster | `minikube stop` |
| Redémarrer | `minikube start` |
| Tout supprimer (repartir de zéro) | `minikube delete` |
| Voir l'état | `minikube status` |
| Dashboard web | `minikube dashboard` |

## 7. Problèmes fréquents

| Problème | Cause probable | Solution |
|---|---|---|
| `RSRC_INSUFFICIENT_CONTAINER_MEMORY` | Docker n'a pas assez de RAM | Augmenter la RAM dans les paramètres de Docker, ou baisser `--memory` |
| `Cannot connect to the Docker daemon` | Docker n'est pas lancé | Démarrer Docker Desktop / `sudo systemctl start docker` |
| `permission denied` sur docker.sock | Utilisateur hors du groupe docker | Voir section 2 |
| Pod ingress en `Pending` | Ressources insuffisantes | `minikube delete` puis relancer avec plus de RAM |
| `ImagePullBackOff` | Image introuvable dans le cluster | Voir section 5 |
| `minikube ip` injoignable (macOS/Windows) | Limite du driver Docker | Lancer `minikube tunnel` et utiliser `127.0.0.1` |

## 8. Repartir de zéro

```bash
minikube delete
./scripts/start-cluster.sh
```
