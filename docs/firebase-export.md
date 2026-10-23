# Exporter les données Firebase

L'ancien site utilise le projet Firebase `aires-de-jeux-e8525`. Cette procédure en récupère une copie complète dans `export/` (ignoré par git, car il contient des données personnelles).

| Fichier | Contenu |
|---|---|
| `export/database.json` | toute la Realtime Database : `aires`, `aires_enrichies`, `aires_infos`, `comments`, `images`, `nouvelle_aire`, `aires_suppression`, `geofire` |
| `export/photos/{aire}/` | les photos (`{aire}_{uid}_{id}`) et leurs miniatures (`thumb_…`) |
| `export/users.json` | les comptes Firebase Auth (e-mails, fournisseurs, hash des mots de passe) |

## Prérequis

Il faut être propriétaire du projet Firebase.

```bash
npm install -g firebase-tools
firebase login
# Google Cloud SDK, pour gsutil : https://cloud.google.com/sdk/docs/install
gcloud auth login
```

## Export

```bash
./scripts/firebase_export.sh            # écrit dans export/
```

Le script cherche le bucket Storage (`aires-de-jeux-e8525.appspot.com` ou `aires-de-jeux-e8525.firebasestorage.app`). S'il ne le trouve pas, liste les buckets avec `gsutil ls -p aires-de-jeux-e8525` et relance avec `FIREBASE_BUCKET=<nom> ./scripts/firebase_export.sh`.

Si `firebase database:get` échoue parce que la base est trop grosse, exporte-la depuis la console (Realtime Database → ⋮ → Exporter le JSON), enregistre-la sous `export/database.json` (la console la nomme `aires-de-jeux-e8525-export.json` : renomme-la, ou passe son chemin tel quel à `mix parc_epique.import_firebase`) et lance les autres étapes à la main.

## Vérifier

```bash
node scripts/check_export.js export
```

La commande affiche le nombre d'entrées par nœud, le nombre de photos et de miniatures, et le nombre de comptes. À titre de repère, l'export public d'août 2022 contenait 16 914 aires (`aires_enrichies`), 686 avis sur 660 aires, 427 fiches de détails (`aires_infos`) et 408 aires ajoutées (`nouvelle_aire`). Un export récent doit avoir au moins autant d'entrées, plus les nœuds `images` et `aires_suppression`, qui n'étaient pas publiés.

`users.json` ne doit pas être commité ni partagé.
