# backrest

[Backrest](https://github.com/garethgeorge/backrest), a web UI and scheduler
for [restic](https://restic.net), at `https://backrest.gt3.dev`. It backs the
NAS's app data up nightly to Backblaze B2. The header of `docker-compose.yml`
lists where this stack differs from upstream's example.

The repo is plain restic, so the `restic` CLI can restore from it without
Backrest (see [Restoring without Backrest](#restoring-without-backrest)).

## What's backed up

Everything is mounted read-only under `/userdata`:

| Path in Backrest       | Host path                         | What's in it |
|------------------------|-----------------------------------|--------------|
| `/userdata/appdata`    | `/volume1/Software/Docker-Appdata`| the media apps' configs, Immich's uploads, Traefik's certificates |
| `/userdata/volumes`    | `/volume1/@docker/volumes`        | every named volume: Sure, Tidarr, Tailscale, Dozzle |
| `/userdata/portainer`  | `/volume1/docker/portainer`       | Portainer's database |
| `/userdata/photos`     | `/volume1/Photos`                 | Immich's external library: the original photos |

Media (`/volume1/Media`) isn't backed up. It can be downloaded again.

Excluded from the plan:

| Exclude | Why |
|---------|-----|
| `/userdata/appdata/immich/postgres` | live database files; Immich's nightly dumps in `upload_location/backups` are backed up instead |
| `/userdata/volumes/sure_postgres-data` | the same; `sure_db-backups` holds Sure's nightly dumps |
| `/userdata/appdata/immich/upload_location/thumbs`, `.../encoded-video` | Immich regenerates them |
| `/userdata/volumes/sure_redis-data`, `/userdata/volumes/immich_model-cache` | caches |
| `/userdata/appdata/decypharr-cache`, `/userdata/appdata/jellyfin/cache`, `**/transcodes` | caches |

The arr apps' SQLite databases are copied live, which can catch them
mid-write. Each app also writes its own weekly zip to `config/Backups`, which
is consistent and gets backed up with the rest.

## First deploy

1. In B2: a private bucket (`gt3-homelab-backup`), lifecycle set to **Keep
   only the last version**, and an application key limited to that bucket with
   read and write. Without the lifecycle setting, B2 keeps every file restic
   prunes and bills for it.
2. Bitwarden fields on `homelab-terraform`:
   - `TF_VAR_b2_key_id`, `TF_VAR_b2_application_key`: the application key
   - `TF_VAR_restic_password`: a long random password, e.g.
     `openssl rand -base64 48`. **Keep a second copy outside Bitwarden.**
     Without it the backups can't be decrypted.
3. Merge, then `./tf apply` in `terraform/` (it adds `portainer_stack.backrest`).
4. Open `https://backrest.gt3.dev`. Set the instance id to `nas` and create a
   login. Put that in Bitwarden too.
5. **Add repo**:
   - Name: `b2`
   - URI: `s3:https://s3.us-west-004.backblazeb2.com/gt3-homelab-backup`
   - Password: leave empty
   - Env vars, typed exactly like this so Backrest fills them in at run time
     and `config.json` holds no secrets:
     ```
     AWS_ACCESS_KEY_ID=${BACKREST_B2_KEY_ID}
     AWS_SECRET_ACCESS_KEY=${BACKREST_B2_APPLICATION_KEY}
     RESTIC_PASSWORD=${BACKREST_REPO_PASSWORD}
     ```
   - Auto Unlock on (Backrest is the only client). Prune and check: leave
     the defaults, monthly.
6. **Add plan**:
   - Name: `nas`, repo `b2`
   - Paths: the four `/userdata/...` paths above
   - Excludes: the table above
   - Schedule: cron `0 3 * * *`. That's after Sure's dump (01:00) and Immich's
     (02:00).
   - Retention: 7 daily, 4 weekly, 6 monthly
7. Run it once with **Backup now**. The first upload is the whole photo
   library and can take a day or more.
8. Test a restore (see below) before relying on it.

## Restoring

In Backrest: **Repos → b2 → Snapshots**, pick a snapshot and a path, then
**Restore to path** under `/restore`. That's `/volume1/Software/backrest-restore`
on the NAS, the only path Backrest can write. Stop the app, copy the files
into place, and start it again.

Databases come back as dumps:

- **Sure**: the newest `sure_production-*.sql` in
  `/userdata/volumes/sure_db-backups/_data/last/` (the `-latest` file is a
  symlink, so restore the directory). Stop `sure_web` and `sure_worker`, then
  `docker exec -i sure_postgres psql -U sure_user -d sure_production < dump.sql`
  into an empty database. The encryption keys in Bitwarden have to match
  the ones the dump was taken with.
- **Immich**: follow upstream's
  [restore guide](https://docs.immich.app/administration/backup-and-restore)
  with the dump from `upload_location/backups`.

### Restoring without Backrest

From any machine with restic, after loading the Bitwarden fields:

```
export AWS_ACCESS_KEY_ID=<TF_VAR_b2_key_id>
export AWS_SECRET_ACCESS_KEY=<TF_VAR_b2_application_key>
export RESTIC_PASSWORD=<TF_VAR_restic_password>
restic -r s3:https://s3.us-west-004.backblazeb2.com/gt3-homelab-backup snapshots
restic -r ... restore latest --target ./restore --include /userdata/volumes/sure_db-backups
```

## Updating

Renovate opens a PR; merging it redeploys the stack within 5 minutes.

## Troubleshooting

- **Repo errors with 403 or "access denied"**: the application key isn't
  allowed on the bucket, or a Bitwarden field changed without bumping
  `env_wo_version`.
- **An env var shows as empty in the repo**: the `${...}` names in Backrest
  must match the container's `BACKREST_*` variables, not the Bitwarden names.
- **Backrest won't start, citing issue 1139**: a plain `RESTIC_PASSWORD`
  reached the container's environment. Only `BACKREST_REPO_PASSWORD` should.
