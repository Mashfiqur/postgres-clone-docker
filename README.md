# PostgreSQL Database Clone Script

This script allows you to clone any PostgreSQL database to another PostgreSQL database — regardless of location.  
You can use it for:

- **Local → Local** copies
- **DigitalOcean → Local** copies
- **Local → DigitalOcean** copies
- **DigitalOcean → DigitalOcean** copies
- **Any PostgreSQL server to any PostgreSQL server**

It automatically uses the **same major version** of `pg_dump` and `psql` as the source and destination databases to avoid version mismatch issues.

---

## Prerequisites

- Docker installed
- Access to both source and destination PostgreSQL databases
- Correct credentials for both databases
- Network access between your machine and the target databases

---

## Environment Variables

Copy `.env.example` to `.env` and fill in your database credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```ini
SOURCE_DB_HOST=
SOURCE_DB_PORT=
SOURCE_DB_NAME=
SOURCE_DB_USER=
SOURCE_DB_PASSWORD=
SOURCE_POSTGRES_SSL= # true or false

DESTINATION_DB_HOST=
DESTINATION_DB_PORT=
DESTINATION_DB_NAME=
DESTINATION_DB_USER=
DESTINATION_DB_PASSWORD=
DESTINATION_POSTGRES_SSL= # true or false

# Performance Tuning Parameters (Optional - defaults shown)
# Number of parallel jobs for dump/restore (recommended: 2-8)
PARALLEL_JOBS=4

# Compression level for dump (1-9, higher = more compression but slower)
COMPRESS_LEVEL=6

# Buffer size for pg_dump operations
BUFFER_SIZE=64MB

# Number of rows per transaction during restore
CHUNK_SIZE=1000
```

---

## Usage

Run the clone script:

```bash
bash clone-db.sh
```

The script will:

1. Connect to the **source** PostgreSQL instance.
2. Detect the **PostgreSQL major version** of the source.
3. Run `pg_dump` using a Docker container with the matching PostgreSQL version.
4. Connect to the **destination** PostgreSQL instance.
5. Restore the dump using the matching `psql` version for the destination.
6. Drop temporary files after completion.

---

---
## Run through Docker
```
docker run --rm   --network=host   -v $(pwd):/app   -w /app   postgres:17-alpine   sh -c "apk add --no-cache bash && bash clone-db.sh"
```

---

## SSL Connections

* Set `SOURCE_POSTGRES_SSL=true` if your source DB requires SSL.
* Set `DESTINATION_POSTGRES_SSL=true` if your destination DB requires SSL.

The script automatically adds `sslmode=require` to the connection string when enabled.

---

## Example Scenarios

### Clone from DigitalOcean → Localhost

```env
SOURCE_DB_HOST=db-do-user-1234-0.b.db.ondigitalocean.com
SOURCE_DB_PORT=25060
SOURCE_DB_NAME=app_db
SOURCE_DB_USER=doadmin
SOURCE_DB_PASSWORD=source_password
SOURCE_POSTGRES_SSL=true

DESTINATION_DB_HOST=127.0.0.1
DESTINATION_DB_PORT=5432
DESTINATION_DB_NAME=app_db_clone
DESTINATION_DB_USER=postgres
DESTINATION_DB_PASSWORD=local_password
DESTINATION_POSTGRES_SSL=false
```

### Clone from Localhost → DigitalOcean

```env
SOURCE_DB_HOST=127.0.0.1
SOURCE_DB_PORT=5432
SOURCE_DB_NAME=app_db
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=local_password
SOURCE_POSTGRES_SSL=false

DESTINATION_DB_HOST=db-do-user-1234-0.b.db.ondigitalocean.com
DESTINATION_DB_PORT=25060
DESTINATION_DB_NAME=app_db_clone
DESTINATION_DB_USER=doadmin
DESTINATION_DB_PASSWORD=destination_password
DESTINATION_POSTGRES_SSL=true
```

---

## Performance Tuning for Large Databases

The script is optimized for large datasets with several performance enhancements:

### Key Optimizations

1. **Parallel Processing**: Uses `--jobs` parameter for concurrent dump/restore operations
2. **Compression**: Compresses data during transfer to reduce network bandwidth
3. **Directory Format**: Uses `--format=directory` for better performance than custom format
4. **Progress Monitoring**: Shows real-time progress and size information
5. **Optimized Flags**: Disables unnecessary operations like comments and security labels

### Performance Parameters

You can tune these parameters in your `.env` file:

- **`PARALLEL_JOBS`**: Number of parallel processes (2-8 recommended)
  - For small databases (< 1GB): Use 2-4
  - For medium databases (1-10GB): Use 4-6  
  - For large databases (> 10GB): Use 6-8
  - **Warning**: Don't exceed available CPU cores or memory

- **`COMPRESS_LEVEL`**: Compression level (1-9)
  - Lower values (1-3): Faster compression, larger files
  - Higher values (7-9): Slower compression, smaller files
  - **Recommended**: 6 (good balance of speed vs size)

### Network Optimization Tips

1. **High Bandwidth**: If you have fast network (1Gbps+), use lower compression (3-5)
2. **Low Bandwidth**: If network is slow, use higher compression (7-9)
3. **Local Network**: For local transfers, compression may not be needed (set to 1)

### Memory Considerations

- **Large Tables**: If you have tables > 1GB, ensure sufficient RAM
- **Parallel Jobs**: Each job uses memory, so don't exceed available RAM
- **Buffer Size**: Increase `BUFFER_SIZE` if you have plenty of RAM

### Example Performance Configurations

**Fast Local Network (High Performance):**
```env
PARALLEL_JOBS=8
COMPRESS_LEVEL=3
BUFFER_SIZE=128MB
```

**Slow Network (High Compression):**
```env
PARALLEL_JOBS=4
COMPRESS_LEVEL=9
BUFFER_SIZE=32MB
```

**Balanced (Recommended):**
```env
PARALLEL_JOBS=6
COMPRESS_LEVEL=6
BUFFER_SIZE=64MB
```

### Monitoring Progress

The script provides real-time feedback:
- Database sizes before and after
- Dump file sizes
- Progress indicators during operations
- Final verification of clone success

---

## Notes

* **Data Overwrite Warning:** The destination database will be overwritten.
* The script works across **any PostgreSQL hosting provider**.
* No local PostgreSQL installation is required — everything runs via Docker.
* **Performance Tip**: For very large databases (> 100GB), consider running during off-peak hours.

---