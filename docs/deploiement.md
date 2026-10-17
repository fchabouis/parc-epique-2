# Déploiement sur un VPS

La pile tourne avec Docker Compose (dossier `deploy/`) : PostgreSQL/PostGIS, l'application (une release Elixir dans une image Docker) et Caddy, qui sert le site en HTTPS et renouvelle seul les certificats.

## Installer le serveur (une fois)

Un VPS Linux avec Docker (et son plugin Compose), les ports 80 et 443 ouverts, et un enregistrement DNS `A`/`AAAA` du domaine vers le serveur. Pour une version de test, un sous-domaine suffit (`test.parc-epique.fr`).

```bash
sudo mkdir -p /srv/parc-epique && sudo chown $USER /srv/parc-epique
# depuis le dépôt : copier le dossier deploy/
scp -r deploy/. user@serveur:/srv/parc-epique/
ssh user@serveur
cd /srv/parc-epique
cp .env.example .env && nano .env      # domaine, mots de passe, SECRET_KEY_BASE
docker login ghcr.io                   # nom GitHub + jeton avec le droit read:packages
./deploy.sh
```

`deploy.sh` télécharge l'image, applique les migrations (`bin/migrate`) puis redémarre. `./uploads` reçoit les photos et l'export public (le dossier appartient à l'uid 1000, celui de l'application).

Le fichier `.env` n'est jamais dans le dépôt. L'image est publiée sur `ghcr.io/fchabouis/parc-epique-2` ; si le paquet est rendu public dans les réglages GitHub, `docker login` n'est plus nécessaire.

## Déployer depuis GitHub Actions

Le workflow `Deploy` construit l'image, la publie, copie le dossier `deploy/` sur le serveur et lance `deploy.sh`. Il ne fait rien tant que la variable de dépôt `DEPLOY_ENABLED` n'est pas `true` (Settings, Secrets and variables, Actions, Variables). Secrets à créer :

| Secret | Contenu |
|---|---|
| `DEPLOY_HOST` | nom ou IP du serveur |
| `DEPLOY_USER` | utilisateur SSH (membre du groupe `docker`) |
| `DEPLOY_SSH_KEY` | clé privée SSH dédiée (une paire créée pour ça, clé publique dans `~/.ssh/authorized_keys` du serveur) |
| `DEPLOY_KNOWN_HOSTS` | résultat de `ssh-keyscan -t ed25519 serveur` |

La CI construit aussi l'image à chaque PR et vérifie qu'elle démarre (migrations, `/health`, page À propos, manifest).

## Opérations courantes

Toutes les commandes se lancent depuis `/srv/parc-epique` ; `bin/` est celui de la release.

```bash
docker compose logs -f app                       # journaux
docker compose run --rm app bin/migrate          # migrations
docker compose exec app bin/parc_epique remote   # console IEx sur l'application en marche

# Donner le rôle administrateur (le compte doit exister : s'inscrire d'abord sur le site)
docker compose exec app bin/parc_epique eval 'ParcEpique.Release.set_admin("moi@exemple.fr")'

# Générer tout de suite l'export public (sinon, chaque nuit à 3 h)
docker compose exec app bin/parc_epique eval 'ParcEpique.Release.export()'
```

### Importer les données Firebase

Copier les exports dans `./uploads/import/` (le dossier est vu comme `/data/uploads/import/` dans le conteneur), puis :

```bash
docker compose exec app bin/parc_epique eval 'ParcEpique.Release.import_firebase("/data/uploads/import/database.json")'
docker compose exec app bin/parc_epique eval 'ParcEpique.Release.import_photos("/data/uploads/import/photos")'
```

Les deux sont rejouables sans doublons. Supprimer `./uploads/import/` ensuite : il contient des données personnelles (uid, éventuellement e-mails) qui n'ont pas à rester sur le serveur ni dans les sauvegardes.

## Sauvegardes

`backup.sh` envoie chaque nuit, hors du serveur, avec [restic](https://restic.net) (chiffré, dédupliqué) :

- un `pg_dump` de la base ;
- le dossier `uploads/` (photos, miniatures, export). Seuls les fichiers modifiés sont envoyés.

Mise en place :

```bash
sudo apt install restic
cp backup.env.example backup.env && nano backup.env   # dépôt restic hors serveur + mot de passe
./backup.sh                                           # première sauvegarde, crée le dépôt restic
crontab -e   # 0 4 * * * /srv/parc-epique/backup.sh >> /var/log/parc-epique-backup.log 2>&1
```

**Garder le mot de passe restic ailleurs que sur le serveur** (gestionnaire de mots de passe) : sans lui, les sauvegardes sont illisibles. `HEALTHCHECK_PING_URL` (par exemple un moniteur gratuit sur healthchecks.io) prévient quand la sauvegarde ne s'est pas exécutée.

### Vérifier qu'une restauration fonctionne

```bash
./restore-check.sh
```

Le script restaure le dernier `pg_dump` dans une base temporaire, compare le nombre d'aires, de photos, d'avis, de détails et de comptes avec la base en service, compte les photos sauvegardées, puis supprime la base temporaire. À lancer après la première sauvegarde, puis régulièrement. **C'est le test de restauration demandé par l'issue #16 : il reste à le lancer sur le VPS.**

### Restaurer pour de bon (serveur perdu ou base abîmée)

1. Installer Docker et copier `deploy/` comme ci-dessus, recréer `.env` et `backup.env` (mêmes valeurs, en particulier `POSTGRES_*` et le mot de passe restic).
2. `docker compose up -d db`
3. La base : `restic restore latest --tag db --target /tmp/restore`, puis  
   `docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner < /tmp/restore/parc_epique.dump`
4. Les photos : `restic restore latest --tag photos --target /tmp/restore-photos`, puis copier le contenu de `/tmp/restore-photos/.../uploads/` dans `./uploads/` (`chown -R 1000:1000 uploads`).
5. `./deploy.sh`

## Surveillance

- `GET /health` répond 200 quand l'application joint la base, 503 sinon. Docker le teste toutes les 30 s et redémarre le conteneur si besoin (`restart: unless-stopped` relance aussi après un redémarrage du serveur).
- Pour être prévenu quand le site tombe : un moniteur externe gratuit (UptimeRobot, healthchecks.io...) sur `https://<domaine>/health`, avec une alerte par e-mail.

## Ce qui n'est pas testé

Les fichiers de ce dossier n'ont pas pu être essayés sur un vrai serveur : la CI vérifie que l'image se construit et démarre, mais le déploiement par SSH, Caddy, les sauvegardes et la restauration sont à valider sur le VPS.
