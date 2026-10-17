#!/usr/bin/env bash
# Exporte toutes les données de production Firebase de parc-epique.fr dans export/.
# Prérequis : firebase-tools (npm i -g firebase-tools), gcloud SDK (gsutil), node.
# Voir docs/firebase-export.md.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT:-aires-de-jeux-e8525}"
OUT="${1:-export}"

mkdir -p "$OUT"

echo "==> Realtime Database"
firebase database:get / --project "$PROJECT" > "$OUT/database.json"

echo "==> Comptes (contient des e-mails, ne pas partager)"
firebase auth:export "$OUT/users.json" --format=json --project "$PROJECT"

echo "==> Photos"
BUCKET="${FIREBASE_BUCKET:-}"
if [ -z "$BUCKET" ]; then
  for candidate in "$PROJECT.appspot.com" "$PROJECT.firebasestorage.app"; do
    if gsutil ls "gs://$candidate" > /dev/null 2>&1; then
      BUCKET="$candidate"
      break
    fi
  done
fi
if [ -z "$BUCKET" ]; then
  echo "Bucket introuvable : relancer avec FIREBASE_BUCKET=<nom> (voir 'gsutil ls -p $PROJECT')." >&2
  exit 1
fi
mkdir -p "$OUT/photos"
gsutil -m cp -r "gs://$BUCKET/photos/*" "$OUT/photos/"

echo "==> Vérification"
node "$(dirname "$0")/check_export.js" "$OUT"
