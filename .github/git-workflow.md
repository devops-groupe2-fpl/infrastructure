# Workflow Git du groupe

Règles communes à tous les dépôts du projet (Mini-Projet DevOps II — Groupe 2).

## Les règles

1. Personne ne pousse directement sur `main`.
2. Chaque changement passe par une **Pull Request (PR)**.
3. Chaque PR doit être **relue et approuvée par un autre membre** avant le merge.
4. Les branches se nomment : `feature/<membre>/<description-courte>`
   - Exemples : `feature/zakaria/ingress`, `feature/ouzziki/schema-catalogue`
   - Pour une correction : `fix/<membre>/<description>`
5. Aucun secret (mot de passe, token, clé) n'est commité.

## Le cycle complet

```bash
# 1. Se mettre à jour
git checkout main
git pull

# 2. Créer sa branche
git checkout -b feature/<membre>/<description>

# 3. Travailler, puis commiter
git add <fichiers>
git commit -m "Message clair décrivant le changement"

# 4. Envoyer la branche
git push -u origin feature/<membre>/<description>
```

5. Sur GitHub, ouvrir la **Pull Request** vers `main` et remplir la checklist du modèle.
6. Demander une relecture à un autre membre.
7. Le relecteur commente ou approuve. Si des changements sont demandés, corriger sur la même branche et pousser à nouveau : la PR se met à jour.
8. Après approbation, **merge** la PR, puis supprimer la branche.

## Relire une PR (conseils)

- Lire le code et la description, pas seulement la checklist.
- Vérifier : pas de secret, les tests passent, la documentation suit.
- Être précis et poli dans les commentaires : proposer plutôt qu'imposer.
- Ne jamais approuver sa propre PR.

## Messages de commit

- Court et au présent : « Ajoute le Deployment du Panier », « Corrige le port du Catalogue ».
- Un commit = un changement logique.

## Erreurs fréquentes

| Problème | Solution |
|---|---|
| `git push` refusé sur `main` | Normal : créer une branche et ouvrir une PR |
| Conflit au merge | `git pull origin main` sur sa branche, résoudre les conflits, commiter, pousser |
| Secret commité par erreur | Prévenir le groupe : changer le secret tout de suite (il reste dans l'historique Git) |
