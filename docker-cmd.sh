#!/usr/bin/env bash
set -Eeuo pipefail

echo "RUN"
exec su - postgres -c "/app/bin/postgres -D $PGDATA"
