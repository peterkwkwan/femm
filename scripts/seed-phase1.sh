#!/usr/bin/env bash
# Reset Phase 1 fictional clinics / slots / upsell partners against a linked
# Supabase Postgres. Requires DATABASE_URL (or SUPABASE_DB_URL) in the env.
# Never pass the service_role key on argv or commit connection strings.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_SQL="${ROOT}/supabase/seed/phase1_demo_supply.sql"
SCHEMA_SQL="${ROOT}/supabase/migrations/20261101120000_phase1_clinical_and_upsell_supply.sql"

DB_URL="${DATABASE_URL:-${SUPABASE_DB_URL:-}}"
if [[ -z "${DB_URL}" ]]; then
  echo "Set DATABASE_URL (or SUPABASE_DB_URL) to your Supabase Postgres URI." >&2
  echo "Dashboard path (no CLI): paste ${SEED_SQL} into SQL Editor." >&2
  echo "Docs: docs/phase1-demo-seed.md" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Install PostgreSQL client tools, or use the Dashboard SQL Editor." >&2
  exit 1
fi

if [[ ! -f "${SEED_SQL}" ]]; then
  echo "Missing seed file: ${SEED_SQL}" >&2
  exit 1
fi

echo "Applying Phase 1 schema (idempotent)…"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -f "${SCHEMA_SQL}"

echo "Resetting demo supply…"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -f "${SEED_SQL}"

echo "Counts:"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c \
  "select
     (select count(*) from public.clinics) as clinics,
     (select count(*) from public.appointment_slots) as slots,
     (select count(*) from public.upsell_partners) as upsell_partners;"

echo "Phase 1 demo supply reset OK."
