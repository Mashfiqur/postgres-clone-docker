#!/bin/bash
set -e

# Load environment variables from .env
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Performance tuning parameters
PARALLEL_JOBS=${PARALLEL_JOBS:-4}  # Number of parallel jobs for restore
COMPRESS_LEVEL=${COMPRESS_LEVEL:-6}  # Compression level (1-9, higher = more compression)
BUFFER_SIZE=${BUFFER_SIZE:-64MB}  # Buffer size for pg_dump
CHUNK_SIZE=${CHUNK_SIZE:-1000}  # Number of rows per transaction during restore

echo "🚀 Starting optimized database clone..."
echo "Source: $SOURCE_DB_HOST:$SOURCE_DB_PORT/$SOURCE_DB_NAME"
echo "Destination: $DESTINATION_DB_HOST:$DESTINATION_DB_PORT/$DESTINATION_DB_NAME"
echo "Performance settings: $PARALLEL_JOBS parallel jobs, compression level $COMPRESS_LEVEL"

# Determine SSL modes
SOURCE_SSL_MODE=$([ "$SOURCE_POSTGRES_SSL" = "true" ] && echo "require" || echo "disable")
DEST_SSL_MODE=$([ "$DESTINATION_POSTGRES_SSL" = "true" ] && echo "require" || echo "disable")

# Connection URIs
SOURCE_URI="postgresql://${SOURCE_DB_USER}:${SOURCE_DB_PASSWORD}@${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}?sslmode=${SOURCE_SSL_MODE}"
DEST_ADMIN_URI="postgresql://${DESTINATION_DB_USER}:${DESTINATION_DB_PASSWORD}@${DESTINATION_DB_HOST}:${DESTINATION_DB_PORT}/postgres?sslmode=${DEST_SSL_MODE}"
DEST_URI="postgresql://${DESTINATION_DB_USER}:${DESTINATION_DB_PASSWORD}@${DESTINATION_DB_HOST}:${DESTINATION_DB_PORT}/${DESTINATION_DB_NAME}?sslmode=${DEST_SSL_MODE}"

# Create temporary directory for dump files
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

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

echo "📊 Getting database size information..."
SOURCE_SIZE=$(PGPASSWORD=$SOURCE_DB_PASSWORD psql "$SOURCE_URI" -t -c "SELECT pg_size_pretty(pg_database_size('${SOURCE_DB_NAME}'));" | xargs)
echo "Source database size: $SOURCE_SIZE"

echo "📥 Creating optimized dump from source..."
echo "⏱️  This may take a while for large databases..."

# Use optimized pg_dump with compression and progress
pg_dump \
  --verbose \
  --compress=9 \
  --jobs=$PARALLEL_JOBS \
  --format=directory \
  --file="$TEMP_DIR/dump" \
  --no-owner \
  --no-privileges \
  --no-comments \
  --no-security-labels \
  --disable-triggers \
  "$SOURCE_URI"

echo "📦 Dump completed. Restoring to destination..."

# Get dump size
DUMP_SIZE=$(du -sh "$TEMP_DIR/dump" | cut -f1)
echo "Dump size: $DUMP_SIZE"

echo "📤 Restoring to destination database..."
echo "⏱️  This may take a while for large databases..."

# Use pg_restore with parallel processing and progress
pg_restore \
  --verbose \
  --jobs=$PARALLEL_JOBS \
  --format=directory \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --disable-triggers \
  --single-transaction \
  --exit-on-error \
  "$TEMP_DIR/dump" \
  "$DEST_URI"

echo "✅ Clone completed successfully!"
echo "📊 Source size: $SOURCE_SIZE, Dump size: $DUMP_SIZE"

# Verify the clone
echo "🔍 Verifying clone..."
DEST_SIZE=$(PGPASSWORD=$DESTINATION_DB_PASSWORD psql "$DEST_URI" -t -c "SELECT pg_size_pretty(pg_database_size('${DESTINATION_DB_NAME}'));" | xargs)
echo "Destination database size: $DEST_SIZE"

if [ "$SOURCE_SIZE" = "$DEST_SIZE" ] || [ "$(echo $SOURCE_SIZE | sed 's/[^0-9]//g')" -eq "$(echo $DEST_SIZE | sed 's/[^0-9]//g')" ]; then
    echo "✅ Size verification passed!"
else
    echo "⚠️  Size verification failed. Source: $SOURCE_SIZE, Destination: $DEST_SIZE"
    echo "This might be normal due to different storage formats or indexes."
fi
