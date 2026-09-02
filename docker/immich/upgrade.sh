#!/bin/bash
# Mise à jour d'Immich par paliers, avec vérification avant et après.
#
#   ./upgrade.sh v2      # premier palier depuis 1.140.1
#   ./upgrade.sh v3      # second palier, une fois v2 vérifié
#
# Immich refuse de sauter une version majeure ("Invalid upgrade path"), d'où le
# passage obligé par v2. Ne jamais utiliser le tag "release" : il suit la
# dernière version et provoquerait exactement ce saut interdit.
set -euo pipefail

cd "$(dirname "$0")"

CIBLE="${1:-}"
PG=NEXTCLOUD_IMMICH_immich_postgres
SRV=NEXTCLOUD_IMMICH_IMMICH_SERVER
SAUVEGARDE_MIN_MO=100

# Délai laissé au serveur pour finir sa rafale de démarrage avant de juger les
# erreurs. La mise en file des travaux ML démarre avant que le conteneur de
# machine learning ait chargé ses modèles, ce qui produit une salve d'erreurs
# transitoires de quelques secondes — bénigne, mais indiscernable d'une panne
# si on compte les erreurs sur tout l'historique du conteneur.
REPOS_S=60
FENETRE_S=30

# Erreurs connues pour être transitoires au démarrage : signalées, jamais
# bloquantes.
TRANSITOIRES='Machine learning repository not been setup'

if [ -z "$CIBLE" ]; then
  echo "Usage : $0 <v2|v3>" >&2
  exit 1
fi
case "$CIBLE" in
  v2|v3) ;;
  *) echo "ERREUR : cible '$CIBLE' inattendue. Utiliser v2 ou v3." >&2; exit 1 ;;
esac

sql() { docker exec "$PG" psql -U postgres -d immich -t -A -c "$1" 2>/dev/null || echo "?"; }

# Les dérivées ont changé de table en v2 : asset_job_status.thumbnailAt a été
# remplacé par asset_file. On interroge la forme disponible.
compter_vignettes() {
  local n
  n=$(sql "select count(*) from asset_file where type='thumbnail';")
  if [ "$n" = "?" ]; then
    n=$(sql "select count(*) from asset_job_status where \"thumbnailAt\" is not null;")
  fi
  echo "$n"
}

echo "════ Contrôles avant mise à jour ════"

DERNIERE=$(ls -t /home/yves/backups/immich-db-*.sql 2>/dev/null | head -1 || true)
if [ -z "$DERNIERE" ]; then
  echo "ERREUR : aucune sauvegarde dans /home/yves/backups/. Arrêt." >&2
  echo "  docker exec $PG pg_dump -U postgres -d immich --no-owner --clean --if-exists > /home/yves/backups/immich-db-\$(date +%Y%m%d).sql" >&2
  exit 1
fi
TAILLE_MO=$(( $(stat -c %s "$DERNIERE") / 1048576 ))
if [ "$TAILLE_MO" -lt "$SAUVEGARDE_MIN_MO" ]; then
  echo "ERREUR : $DERNIERE ne fait que ${TAILLE_MO} Mo, seuil ${SAUVEGARDE_MIN_MO} Mo. Sauvegarde suspecte." >&2
  exit 1
fi
grep -q "PostgreSQL database dump complete" "$DERNIERE" \
  || { echo "ERREUR : $DERNIERE est tronquée (marqueur de fin absent)." >&2; exit 1; }
echo "  sauvegarde   : $(basename "$DERNIERE") — ${TAILLE_MO} Mo, complète"

LIBRE_GO=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
[ "$LIBRE_GO" -ge 15 ] \
  || { echo "ERREUR : ${LIBRE_GO} Go libres, 15 Go minimum requis." >&2; exit 1; }
echo "  disque       : ${LIBRE_GO} Go libres"

AVANT_ASSETS=$(sql "select count(*) from asset;")
AVANT_BIBLIO=$(sql "select count(*) from library;")
AVANT_USERS=$(sql "select count(*) from \"user\";")
AVANT_VIGN=$(compter_vignettes)
echo "  référence    : $AVANT_ASSETS assets, $AVANT_BIBLIO bibliothèques, $AVANT_USERS utilisateurs, $AVANT_VIGN vignettes"
echo "  version      : $(curl -s http://localhost:2283/api/server/version || echo inconnue)"

echo
echo "════ Mise à jour vers $CIBLE ════"

if grep -qE '^IMMICH_VERSION=' .env; then
  sed -i "s|^IMMICH_VERSION=.*|IMMICH_VERSION=$CIBLE|" .env
else
  printf '\nIMMICH_VERSION=%s\n' "$CIBLE" >> .env
fi
echo "  .env         : IMMICH_VERSION=$CIBLE"

docker compose pull immich-server immich-machine-learning
docker compose up -d

echo
echo "════ Vérification ════"

echo -n "  démarrage    : "
for _ in $(seq 1 100); do
  etat=$(docker inspect "$SRV" --format '{{.State.Health.Status}}' 2>/dev/null || echo absent)
  [ "$etat" = "starting" ] || break
  sleep 6
done
echo "$etat"

if [ "$etat" != "healthy" ]; then
  echo >&2
  echo "ÉCHEC : le serveur n'est pas sain. Journal :" >&2
  docker logs --tail 40 "$SRV" 2>&1 | grep -viE "RouterExplorer|RoutesResolver|Mapped" >&2
  echo >&2
  echo "Pour revenir en arrière : remettre l'ancienne valeur dans .env," >&2
  echo "puis restaurer la base depuis $DERNIERE." >&2
  exit 1
fi

APRES_ASSETS=$(sql "select count(*) from asset;")
APRES_BIBLIO=$(sql "select count(*) from library;")
APRES_USERS=$(sql "select count(*) from \"user\";")
APRES_VIGN=$(compter_vignettes)

ecart() { [ "$1" = "$2" ] && echo "" || echo "   <-- ÉCART"; }
printf "  assets       : %s -> %s%s\n" "$AVANT_ASSETS" "$APRES_ASSETS" "$(ecart "$AVANT_ASSETS" "$APRES_ASSETS")"
printf "  bibliothèques: %s -> %s%s\n" "$AVANT_BIBLIO" "$APRES_BIBLIO" "$(ecart "$AVANT_BIBLIO" "$APRES_BIBLIO")"
printf "  utilisateurs : %s -> %s%s\n" "$AVANT_USERS" "$APRES_USERS" "$(ecart "$AVANT_USERS" "$APRES_USERS")"
printf "  vignettes    : %s -> %s%s\n" "$AVANT_VIGN" "$APRES_VIGN" "$(ecart "$AVANT_VIGN" "$APRES_VIGN")"

echo -n "  API          : "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:2283/api/server/ping || echo injoignable
echo "  version      : $(curl -s http://localhost:2283/api/server/version || echo inconnue)"

# Les erreurs se jugent sur une fenêtre récente, après un temps de repos, et non
# sur tout l'historique : sinon la salve de démarrage fait toujours échouer.
echo "  repos        : ${REPOS_S}s avant de juger les erreurs"
sleep "$REPOS_S"

filtre_bruit() { grep -viE "RouterExplorer|RoutesResolver|Mapped|Websocket"; }

TOTAL=$(docker logs "$SRV" 2>&1 | filtre_bruit | grep -icE "error|exception" || true)
TRANS=$(docker logs "$SRV" 2>&1 | filtre_bruit | grep -cE "$TRANSITOIRES" || true)
RECENTES=$(docker logs --since "${FENETRE_S}s" "$SRV" 2>&1 | filtre_bruit \
             | grep -iE "error|exception" | grep -vcE "$TRANSITOIRES" || true)

echo "  erreurs      : $RECENTES sur les ${FENETRE_S} dernières secondes"
echo "                 ($TOTAL depuis le démarrage, dont $TRANS transitoires ML)"

if [ "$TRANS" -gt 0 ]; then
  echo "  note         : les travaux ML échoués au démarrage ne sont pas rejoués"
  echo "                 automatiquement — les relancer dans Administration > Tâches."
fi

echo
if [ "$AVANT_ASSETS" = "$APRES_ASSETS" ] && [ "$AVANT_BIBLIO" = "$APRES_BIBLIO" ] \
   && [ "$AVANT_USERS" = "$APRES_USERS" ] && [ "$AVANT_VIGN" = "$APRES_VIGN" ] \
   && [ "$RECENTES" -eq 0 ]; then
  echo "Palier $CIBLE réussi. Rien n'a été perdu."
  [ "$CIBLE" = "v2" ] && echo "Palier suivant, quand tu veux : $0 v3"
  exit 0
else
  echo "Palier $CIBLE appliqué MAIS des écarts subsistent — vérifier avant d'enchaîner." >&2
  exit 1
fi
