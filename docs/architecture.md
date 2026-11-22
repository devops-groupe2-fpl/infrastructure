# Architecture du projet

Mini-Projet DevOps II — Groupe 2 · Faculté Polydisciplinaire de Larache

Ce document est la référence technique du groupe : il décrit les services, leur communication et leur déploiement sur Kubernetes.

> Les valeurs marquées **(à confirmer)** dépendent d'éléments pas encore écrits (service Commandes, Dockerfiles). Elles seront mises à jour dès leur disponibilité.

## 1. Vue d'ensemble

L'application e-commerce est composée de 4 services et d'une base de données, déployés sur un cluster Kubernetes local (Minikube).

| Composant | Rôle | Technologie | Responsable |
|---|---|---|---|
| Frontend | Pages web : catalogue, panier, historique des commandes | HTML/CSS/JS statique servi par nginx | Ouzziki |
| Catalogue | API des produits | Node.js (Express) + PostgreSQL | Ouzziki |
| Panier | API du panier d'achat | Node.js 22 (Express) | Zineb |
| Commandes | API des commandes | À confirmer | Hasna |
| Infrastructure | Cluster, Ingress, déploiement, supervision | Kubernetes, Nagios | Zakaria |

Le trafic externe entre uniquement par l'Ingress nginx. Tous les services sont de type `ClusterIP` (accessibles seulement dans le cluster).

## 2. Diagramme du cluster

```
                         Utilisateur (navigateur)
                                   │
                                   │ HTTP  (http://<minikube ip>)
                                   ▼
   ┌────────────────────────────────────────────────────────────────┐
   │                   Cluster Kubernetes (Minikube)                │
   │                                                                │
   │              ┌─────────────────────────────┐                   │
   │              │   Ingress nginx             │                   │
   │              └──────────────┬──────────────┘                   │
   │   /                         │                                  │
   │   /api/catalogue            │                                  │
   │   /api/panier              ─┤                                  │
   │   /api/commandes            │                                  │
   │       ┌───────────┬─────────┴──┬──────────────┐                │
   │       ▼           ▼            ▼              ▼                │
   │  frontend-    catalogue-    panier-        commandes-          │
   │  service:80   service:3000  service:3001   service:3002        │
   │       │           │            │              │                │
   │       ▼           ▼            ▼              ▼                │
   │  [pod         [pod         [pod           [pod                 │
   │   frontend]    catalogue]   panier]        commandes]          │
   │                   │            │              │                │
   │                   │            ├─ GET /products/:id ─► catalogue│
   │                   │            └─ POST /orders ──────► commandes│
   │                   ▼                                            │
   │            postgres-service:5432                               │
   │            [pod postgres]  (base "catalogue")                  │
   └────────────────────────────────────────────────────────────────┘

   Supervision : Nagios (conteneur Docker, hors cluster)
                 ──► vérifie la santé de chaque service via l'Ingress
```

## 3. Flux de communication

**Du navigateur vers l'application**

1. Le navigateur charge le Frontend sur `http://<minikube ip>/`.
2. Le Frontend appelle l'API avec des URLs relatives :
   - `/api/catalogue/products` pour la liste des produits ;
   - `/api/panier/cart/:userId` pour le panier ;
   - `/api/commandes/orders/:userId` pour l'historique des commandes.
3. L'Ingress retire le préfixe (`/api/catalogue`, `/api/panier`, `/api/commandes`) et transmet la requête au Service correspondant.
4. Le Service répartit la requête vers un Pod du Deployment.

Le Frontend utilise provisoirement `user1` comme identifiant utilisateur (pas d'authentification).

**Entre services (dans le cluster)**

| De | Vers | Appel | Usage |
|---|---|---|---|
| Panier | Catalogue | `GET /products/:id` | Vérifier un produit lors de l'ajout au panier |
| Panier | Commandes | `POST /orders` | Valider le panier (checkout, à implémenter) |
| Catalogue | PostgreSQL | requêtes SQL | Lire les produits |

Les adresses des autres services ne sont jamais écrites en dur : elles viennent de variables d'environnement (`CATALOGUE_URL`, `COMMANDES_URL`, `DATABASE_URL`).

**Données** : le Panier ne semble pas utiliser de base de données (aucune connexion trouvée, panier gardé en mémoire : à confirmer avec Zineb). La base de données de Commandes est à confirmer avec Hasna.

## 4. Ports exposés

| Service K8s | Port du service | containerPort | Chemin Ingress | Endpoint de santé |
|---|---|---|---|---|
| frontend-service | 80 | 80 | `/` | `/` (pas de `/health`, voir §8) |
| catalogue-service | 3000 | 3000 | `/api/catalogue` | `/health` |
| panier-service | 3001 | 3001 | `/api/panier` | `/health` |
| commandes-service | 3002 | 3002 (à confirmer) | `/api/commandes` | `/health` (à confirmer) |
| postgres-service | 5432 | 5432 | non exposé | n/a |
| Nagios | 8080 (hôte) | 80 | `http://localhost:8080/nagios` | n/a |

## 5. Dépôts Git

| Dépôt | Contenu | Technologie | Responsable |
|---|---|---|---|
| `catalogue-service` | API Catalogue (`src/`, `db/`) et frontend statique (`frontend/`) | Node.js, PostgreSQL, nginx | Ouzziki |
| `panier-service` | API Panier, tests Jest, Dockerfile, contrat d'API | Node.js 22 | Zineb |
| `commandes-service` | API Commandes (pas encore créé) | À confirmer | Hasna |
| `infrastructure` | Manifests Kubernetes, scripts, documentation, Nagios | YAML, Bash | Zakaria |

Structure du dépôt `infrastructure` :

```
.
├── .github/pull_request_template.md
├── docs/
│   ├── architecture.md
│   ├── setup-minikube.md
│   └── nagios-setup.md
├── k8s/
│   ├── postgres/    (deployment.yaml, service.yaml, secret, init SQL)
│   ├── catalogue/   (deployment.yaml, service.yaml)
│   ├── panier/
│   ├── commandes/
│   ├── frontend/
│   └── ingress.yaml
├── nagios/conf.d/   (hosts.cfg, services.cfg, contacts.cfg)
└── scripts/         (start-cluster.sh, deploy-all.sh, teardown.sh)
```

Workflow Git : une branche par fonctionnalité nommée `feature/<membre>/<description>` (par exemple `feature/ouzziki/schema-catalogue`), Pull Request obligatoire, relue par un autre membre avant le merge.

Intégration continue : chaque service a son propre pipeline Jenkins, indépendant des autres. Chaque build produit une image `<compte-dockerhub>/<service>:v<numéro de build>`, déployée avec `kubectl set image deployment/<service> ...`. Les Deployments doivent donc s'appeler `catalogue`, `panier`, `commandes` et `frontend`.

## 6. Variables d'environnement

### Catalogue

| Variable | Description | Valeur par défaut / exemple | Source K8s |
|---|---|---|---|
| `PORT` | Port du serveur | `3000` | ConfigMap |
| `DATABASE_URL` | Connexion PostgreSQL (contient le mot de passe) | `postgresql://catalogue:<mot de passe>@postgres-service:5432/catalogue` | **Secret** |
| `DB_POOL_SIZE` | Taille du pool de connexions (optionnelle) | `10` | ConfigMap |

### Panier

| Variable | Description | Valeur par défaut / exemple | Source K8s |
|---|---|---|---|
| `PORT` | Port du serveur | `3001` | ConfigMap |
| `CATALOGUE_URL` | Adresse du Catalogue | `http://catalogue-service:3000` | ConfigMap |
| `COMMANDES_URL` | Adresse de Commandes | `http://commandes-service:3002` | ConfigMap |

### Commandes (à confirmer avec Hasna)

| Variable | Description | Valeur par défaut / exemple | Source K8s |
|---|---|---|---|
| `PORT` | Port du serveur | `3002` | ConfigMap |
| À compléter | Base de données éventuelle | | Secret |

### Frontend

Aucune variable : les appels utilisent des URLs relatives (`/api/...`) résolues par l'Ingress.

### PostgreSQL

| Variable | Description | Exemple | Source K8s |
|---|---|---|---|
| `POSTGRES_DB` | Nom de la base | `catalogue` | ConfigMap |
| `POSTGRES_USER` | Utilisateur | `catalogue` | ConfigMap |
| `POSTGRES_PASSWORD` | Mot de passe | à définir | **Secret** |

Règle : les valeurs sensibles (mots de passe, `DATABASE_URL`) vont dans un Secret et ne sont jamais commitées.

## 7. Déploiement

Voir `docs/setup-minikube.md` pour créer le cluster, puis :

```bash
./scripts/deploy-all.sh     # déploie la base, les services et l'Ingress
./scripts/teardown.sh       # supprime tout
```

Le schéma et les données de test du Catalogue (`db/schema.sql`, `db/seed.sql`) sont chargés au premier démarrage de PostgreSQL via un ConfigMap monté dans `/docker-entrypoint-initdb.d`.

## 8. Supervision

Nagios vérifie la santé de chaque service toutes les 2 minutes et envoie une alerte quand un service passe DOWN. Voir `docs/nagios-setup.md`.

Le frontend (nginx statique) n'a pas d'endpoint `/health` : la vérification utilise `/` en attendant l'ajout éventuel d'un `location /health` dans `nginx.conf`.

## 9. Points ouverts

| Sujet | À faire | Avec |
|---|---|---|
| Dockerfiles Catalogue et Frontend | Pas encore écrits ; noms d'images à fixer | Ouzziki |
| Service Commandes | Pas encore démarré : port, santé, base de données | Hasna |
| Base de données du Panier | Confirmer que le panier est gardé en mémoire | Zineb |
| Endpoint `/health` du Frontend | Ajouter un `location /health` dans nginx.conf | Ouzziki |
| Nom du compte Docker Hub | Fixer le compte utilisé par les pipelines | Groupe |
| Mot de passe PostgreSQL | Définir et stocker dans un Secret | Zakaria |
