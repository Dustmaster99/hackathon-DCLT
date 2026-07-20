#!/bin/sh
set -eu

psql \
  --set ON_ERROR_STOP=1 \
  --set ngo_db_name="$NGO_DB_NAME" \
  --set donation_db_name="$DONATION_DB_NAME" \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" <<'EOSQL'
SELECT format('CREATE DATABASE %I', :'ngo_db_name')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'ngo_db_name')\gexec

SELECT format('CREATE DATABASE %I', :'donation_db_name')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'donation_db_name')\gexec
EOSQL

psql \
  --set ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$NGO_DB_NAME" \
  --file /schemas/ngo-init.sql

psql \
  --set ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$DONATION_DB_NAME" \
  --file /schemas/donation-init.sql
