#!/bin/bash
set -e

# Load environment variables from .env
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

echo "🔄 Starting database clone..."
echo "Source: $SOURCE_DB_HOST:$SOURCE_DB_PORT/$SOURCE_DB_NAME"
echo "Destination: $DESTINATION_DB_HOST:$DESTINATION_DB_PORT/$DESTINATION_DB_NAME"

# Determine SSL modes
SOURCE_SSL_MODE=$([ "$SOURCE_POSTGRES_SSL" = "true" ] && echo "require" || echo "disable")
DEST_SSL_MODE=$([ "$DESTINATION_POSTGRES_SSL" = "true" ] && echo "require" || echo "disable")

# Connection URIs
SOURCE_URI="postgresql://${SOURCE_DB_USER}:${SOURCE_DB_PASSWORD}@${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}?sslmode=${SOURCE_SSL_MODE}"
DEST_ADMIN_URI="postgresql://${DESTINATION_DB_USER}:${DESTINATION_DB_PASSWORD}@${DESTINATION_DB_HOST}:${DESTINATION_DB_PORT}/postgres?sslmode=${DEST_SSL_MODE}"
DEST_URI="postgresql://${DESTINATION_DB_USER}:${DESTINATION_DB_PASSWORD}@${DESTINATION_DB_HOST}:${DESTINATION_DB_PORT}/${DESTINATION_DB_NAME}?sslmode=${DEST_SSL_MODE}"

echo "🚫 Terminating connections to destination database..."
PGPASSWORD=$DESTINATION_DB_PASSWORD psql "$DEST_ADMIN_URI" <<EOF
-- Terminate all other sessions to the destination DB
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${DESTINATION_DB_NAME}'
  AND pid <> pg_backend_pid();

-- Drop and recreate the database
DROP DATABASE IF EXISTS ${DESTINATION_DB_NAME};
CREATE DATABASE ${DESTINATION_DB_NAME};
EOF

echo "📥 Dumping data from source and restoring to destination..."
pg_dump --clean --if-exists --no-owner --no-privileges "$SOURCE_URI" \
| psql "$DEST_URI"

echo "✅ Clone completed successfully!"
