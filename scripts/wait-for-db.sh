#!/bin/sh
# wait-for-db.sh

set -e

host="$1"
shift

until mysql -h "$host" -u root; do
  >&2 echo "MySQL is unavailable - sleeping"
  sleep 1
done

>&2 echo "MySQL is up - executing command"
exec "$@"
