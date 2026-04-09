#!/usr/bin/env bash
# Usage: bash seed-databases.sh [dev|prod]   (defaults to dev)
# Must be run on the bastion host, not your laptop.
set -euo pipefail

ENV="${1:-dev}"
REGION="us-east-2"
log() { echo "[$(date +%H:%M:%S)] $*"; }

# Pulls credentials from Secrets Manager and runs the .sql file for a service.
# The secret path matches what Terraform wrote: pokeshop/{env}/{service}-db
run_migration() {
  local SERVICE=$1
  log "Migrating ${SERVICE} (${ENV})..."

  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/${SERVICE}-db" \
    --query SecretString --output text)

  # RDS returns the host as hostname:5432 — cut strips the port
  DB_HOST=$(echo "$SECRET" | jq -r '.host' | cut -d: -f1)
  DB_USER=$(echo "$SECRET" | jq -r '.username')
  DB_PASS=$(echo "$SECRET" | jq -r '.password')
  DB_NAME=$(echo "$SECRET" | jq -r '.dbname')

  # PGPASSWORD lets psql authenticate without an interactive prompt
  export PGPASSWORD="$DB_PASS"
  psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f /tmp/migrate-${SERVICE}.sql
  log "${SERVICE} migration done ✓"
}

# Calls PokeAPI for each of the 151 original Pokémon and upserts them.
# ON CONFLICT DO NOTHING makes it safe to re-run — duplicates are skipped.
seed_pokemon() {
  log "Seeding 151 Pokémon (${ENV})..."

  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/pokemon-db" \
    --query SecretString --output text)

  DB_HOST=$(echo "$SECRET" | jq -r '.host' | cut -d: -f1)
  DB_USER=$(echo "$SECRET" | jq -r '.username')
  DB_PASS=$(echo "$SECRET" | jq -r '.password')
  DB_NAME=$(echo "$SECRET" | jq -r '.dbname')
  export PGPASSWORD="$DB_PASS"

  for i in $(seq 1 151); do
    P=$(curl -sf "https://pokeapi.co/api/v2/pokemon/${i}")
    NAME=$(echo "$P" | jq -r '.name')
    T1=$(echo "$P"  | jq -r '.types[0].type.name')
    T2=$(echo "$P"  | jq -r '.types[1].type.name // ""')   # empty string if no secondary type
    HP=$(echo "$P"  | jq -r '.stats[]|select(.stat.name=="hp").base_stat')
    ATK=$(echo "$P" | jq -r '.stats[]|select(.stat.name=="attack").base_stat')
    DEF=$(echo "$P" | jq -r '.stats[]|select(.stat.name=="defense").base_stat')
    SPD=$(echo "$P" | jq -r '.stats[]|select(.stat.name=="speed").base_stat')
    SPA=$(echo "$P" | jq -r '.stats[]|select(.stat.name=="special-attack").base_stat')
    SPE=$(echo "$P" | jq -r '.stats[]|select(.stat.name=="special-defense").base_stat')
    SPR=$(echo "$P" | jq -r '.sprites.front_default // ""')
    HT=$(echo "$P"  | jq -r '.height')
    WT=$(echo "$P"  | jq -r '.weight')
    EXP=$(echo "$P" | jq -r '.base_experience // 0')

    # NULLIF('$T2','') converts empty string to NULL for secondary_type
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
      INSERT INTO pokemon
        (pokedex_id,name,primary_type,secondary_type,hp,attack,defense,speed,
         special_attack,special_defense,sprite_url,height,weight,base_experience)
      VALUES ($i,'$NAME','$T1',NULLIF('$T2',''),$HP,$ATK,$DEF,$SPD,$SPA,$SPE,'$SPR',$HT,$WT,$EXP)
      ON CONFLICT (pokedex_id) DO NOTHING;
    " > /dev/null   # suppress row-count noise
    log "  #$i $NAME"
    sleep 0.1       # stay well under PokeAPI rate limits
  done
  log "Pokémon seeding complete ✓"
}

run_migration "auth"
run_migration "pokemon"
run_migration "favorites"
seed_pokemon
log "All databases ready for env: ${ENV}"
