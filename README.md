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

## Notes

* **Data Overwrite Warning:** The destination database will be overwritten.
* The script works across **any PostgreSQL hosting provider**.
* No local PostgreSQL installation is required — everything runs via Docker.

---

```

If you want, I can now also **add the matching `clone-db.sh` script** so this README is fully functional. Would you like me to do that next?
```
