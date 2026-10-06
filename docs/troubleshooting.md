# Troubleshooting

**English** | [Türkçe](sorun-giderme.md)

## 1. `pull access denied for atendai/evolution-api`

The project moved its images. Use:

```yaml
image: evoapicloud/evolution-api:v2.3.7
```

Pin an explicit version. Avoid `latest`, because upgrades need a migration check (see below).

## 2. `The column wavoipToken does not exist` / instance creation fails

**Cause:** Evolution API keeps separate Prisma migration sets for PostgreSQL and MySQL, and the
MySQL set sometimes lags behind. In v2.2.3, for example, the `Setting.wavoipToken` column and a unique index on `Chat`
were missing, which blocked instance creation completely.

**Detect** what the live DB is missing compared to the schema:

```bash
./scripts/check-migrations.sh
```

**Fix:** apply the printed `ALTER TABLE` / `CREATE UNIQUE INDEX` statements manually (take a DB backup first).

**Upgrade trap (P3009):** when a later image ships the official migration for a column you already
added by hand, Prisma fails with `P3009` (duplicate column / migration failed). Mark that migration
as applied:

```bash
docker compose exec -T evolution-api npx prisma migrate resolve --applied <migration_name> \
  --schema prisma/mysql-schema.prisma
docker compose up -d --force-recreate evolution-api
```

The migration name appears in the container logs.

## 3. QR code never appears

**Symptom:** `GET /instance/connect/<name>` keeps returning `{"count":0}`, and the instance's session
folder stays empty.

**Cause:** WhatsApp rejects the Baileys version bundled in older images (seen with v2.2.3).

**Fix:** upgrade the image (v2.3.7 works). Newer versions also return `whatsappWebVersion` from `GET /`.
Check that field first when QR problems start.

## 4. Container cannot connect to MariaDB

- `bind-address` must include `172.17.0.1` (the host address on `docker0`), and the DB user must be
  `'user'@'%'`, or at least match the Docker subnet.
- If a host firewall is active, allow 3306 from the Docker subnets only:

  ```bash
  iptables -I INPUT -i docker0 -p tcp --dport 3306 -j ACCEPT
  iptables -I INPUT -i br-+ -p tcp --dport 3306 -j ACCEPT
  ```

- Test from inside the container network:

  ```bash
  docker run --rm --network evolution-api_evolution-net alpine \
    sh -c "apk add -q mariadb-client && mariadb -h 172.17.0.1 -u evolution_user -p -e 'SELECT 1'"
  ```

## 5. `.env` changes have no effect

`docker compose restart` keeps the old environment. Recreate the container:

```bash
docker compose up -d --force-recreate evolution-api
```

## 6. Manager UI: WebSocket errors, or the page loads but stays blank

- Make sure the `Upgrade` / `Connection "upgrade"` headers are in the nginx config.
- In Plesk, **Proxy mode** must be off. Otherwise requests go through Apache and the WebSocket upgrade is lost.
- Cloudflare: WebSockets must be enabled (Network tab, on by default).

## 7. Changes to nginx/branding are not visible

If the host is proxied by Cloudflare (orange cloud), static files such as PNGs and JS bundles are cached at the edge.

- Purge the cache after every nginx change. Bundle names change with each version, so this repeats after upgrades.
- Permanent fix: add a Cache Rule ("Bypass cache") for this hostname.
- Test the origin directly, bypassing Cloudflare:

  ```bash
  curl -k --resolve whatsapp.example.com:443:<SERVER_IP> https://whatsapp.example.com/
  ```

## 8. Branding: logo replaced but the browser shows a broken image

nginx picks the MIME type from the **file extension in the URI**. If you `alias` a `.png` path to an SVG, it
is served as `image/png` and the browser won't render it. `default_type` alone does not help. You need an
empty `types { }` block:

```nginx
location = /assets/images/evolution-logo.png {
    alias /path/to/branding/my-logo-white.svg;
    types { }
    default_type image/svg+xml;
}
```

Also note that `sub_filter` requires uncompressed upstream responses (`proxy_set_header Accept-Encoding "";`)
and may miss matches in very large JS bundles. For critical assets, prefer `location` + `alias`.
