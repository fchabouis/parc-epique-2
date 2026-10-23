# Bascule de parc-epique.fr vers la nouvelle application

À suivre une fois la version de test validée sur le VPS (voir `deploiement.md`). Les outils d'export et d'import sont déjà là ; ce document donne l'ordre et les vérifications.

## Avant (quelques jours)

1. **Parité** : parcourir la liste ci-dessous sur la version de test, sur ordinateur et sur téléphone (Android et iOS).
2. **Données d'essai** : faire une répétition complète (export Firebase, import, photos) sur la version de test, et noter les chiffres du rapport d'import.
3. **DNS** : baisser le TTL de l'enregistrement de `parc-epique.fr` à 5 minutes, au moins 24 h avant, pour que le retour en arrière soit rapide.
4. **Google** : le client OAuth doit avoir `https://parc-epique.fr/auth/google/callback` comme URI de redirection, et `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` doivent être dans `.env`.
5. **Administrateur** : s'inscrire sur la nouvelle version, puis `ParcEpique.Release.set_admin/1`.

## Le jour J

1. **Geler l'ancien site** pour ne rien perdre pendant l'export : passer la Realtime Database et Storage en écriture interdite (`".write": false` dans les règles), puis publier les règles. Les visiteurs voient encore l'ancien site, sans pouvoir contribuer.
2. **Export final** : `./scripts/firebase_export.sh`, puis `node scripts/check_export.js export` et comparer avec la répétition (au moins autant d'entrées).
3. **Import** sur le serveur de production (voir « Importer les données Firebase » dans `deploiement.md`) : `import_firebase`, puis `import_photos`. Les deux sont rejouables sans doublons. Vérifier le rapport : aires importées, photos manquantes (`missing`) ou en échec (`failed`), fichiers `.gstmp` (téléchargements inachevés à refaire).
4. **Supprimer** `./uploads/import/` du serveur.
5. **Générer l'export public** : `ParcEpique.Release.export()`.
6. **DNS** : faire pointer `parc-epique.fr` (et `www`) vers le VPS. Caddy obtient le certificat dès que le DNS répond.
7. **Vérifier** : `https://parc-epique.fr/health`, la carte, une fiche avec photos, la connexion Google, l'envoi d'une photo, `/fr/a-propos`, `/export/aires.geojson`, l'installation en PWA.
8. Lancer une sauvegarde (`./backup.sh`) puis `./restore-check.sh`.

## Anciennes URLs et anciens visiteurs

- `/#/`, `/#/apropos` et `/#/login` sont redirigés vers leur équivalent par un petit script de la page (un `#` n'atteint jamais le serveur). `/apropos`, `/login` et `/index.html` (page de démarrage de l'ancienne application installée) sont redirigés côté serveur.
- L'ancien site enregistrait un service worker sous `/service-worker.js`, qui continue à servir l'ancienne application depuis son cache. La nouvelle application sert un fichier à cette URL qui vide les caches, se désinscrit et recharge la page : dès que le navigateur revérifie le fichier (à la prochaine visite), l'ancien site disparaît. Ce nom de fichier est confirmé (`https://parc-epique.fr/service-worker.js` est bien un worker sw-precache de portée `/`). Au premier passage après la bascule, un visiteur de l'ancien site voit encore l'ancienne application, puis la page se recharge toute seule sur la nouvelle.
- Les URLs de photos de l'ancien Storage ne sont plus utilisées : les photos sont servies depuis `/uploads/`.

## Retour en arrière

Tant que Firebase Hosting est en place, remettre l'ancien enregistrement DNS suffit (TTL court). Les contributions faites sur la nouvelle version entre-temps ne sont pas reportées sur Firebase : au-delà de quelques heures, il vaut mieux corriger en avant.

## Après

1. Garder Firebase en lecture seule quelques semaines.
2. Vérifier dans la console Firebase que plus aucune requête n'arrive (Hosting, Realtime Database, Storage, Functions).
3. Fermer les services : Hosting, Functions, Database, Storage. Garder une dernière copie de l'export dans un endroit sûr (il contient des e-mails et des uid : chiffré, hors dépôt).
4. Supprimer `users.json` de tous les ordinateurs une fois la copie archivée.

## Liste de parité avec l'ancien site

| Fonction | Où |
|---|---|
| Carte des aires (un pin par aire, sans regroupement), ma position | `/fr` |
| Fiche d'une aire (nom, notes, avis, détails, photos) et page propre à chaque aire | `/fr/aires/:id` |
| Donner un avis (sans compte ou connecté) | fiche |
| Proposer des détails (équipements, gratuit, ouvert la nuit, privé) | fiche |
| Envoyer une photo | fiche |
| Signaler qu'une aire n'existe plus | fiche |
| Ajouter une aire (clic droit ou appui long) | carte |
| Compte : e-mail (lien magique) ou Google | `/users/log-in` |
| Modération | `/fr/admin` |
| Page À propos et export ODbL | `/fr/a-propos` |
| Application installable | manifest et service worker |

Connexion Facebook : abandonnée volontairement.
