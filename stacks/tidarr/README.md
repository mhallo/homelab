# tidarr

[Tidarr](https://github.com/cstaelen/tidarr), a Tidal downloader (FLAC, up to
24-bit/192 kHz), at `https://tidarr.gt3.dev`. It plugs into Lidarr as both a
Newznab indexer and a SABnzbd download client, so Lidarr searches Tidal, grabs
albums from it and imports them like any other source. Based on upstream's
[README](https://github.com/cstaelen/tidarr#getting-started) and
[Lidarr integration guide](https://github.com/cstaelen/tidarr/wiki/Lidarr-Integration-Guide);
the header of `docker-compose.yml` lists where this stack differs.

It needs an **active Tidal subscription** (upstream says an official account).
Downloading from Tidal this way is against Tidal's terms of service, and
Tidarr is described as for personal use. Downloads come straight to the NAS
from Tidal, not through the debrid service.

| Service  | What it is                         | Network               |
|----------|------------------------------------|-----------------------|
| `tidarr` | Web UI and API on port 8484        | `media-net`, `proxy`  |

State (your Tidal login, settings and the API key) is in the `tidarr-config`
named volume. Finished downloads land in `/volume1/Media/tidarr-downloads`,
which Lidarr sees as `/mnt/storage/tidarr-downloads`.

## First deploy

1. Deploy `traefik` and `media-stack` first: this stack joins the `proxy` and
   `media-net` networks.
2. In Portainer: **Stacks → Add stack → Repository**.
   - Name: `tidarr`. Don't rename it later: the volume name derives from it.
   - Compose path: `stacks/tidarr/docker-compose.yml`
   - Environment variables:
     - `TIDARR_ADMIN_PASSWORD`: password for the web UI (and the login screen)
3. Deploy, then open `https://tidarr.gt3.dev`, log in with that password, and
   follow the Tidal device-login prompt (the token dialog). It gives you a
   code to approve in your own Tidal account.
4. In Tidarr's settings, check the quality you want (up to "max") and the
   path template. Upstream warns to set the template path correctly.

## Connect Lidarr

Do these in order; the indexer refers to the download client. Both screens
need **Show advanced** (the cog) turned on.

Get the API key:

```
docker exec tidarr cat /shared/.tidarr-api-key
```

1. **Lidarr → Settings → Download Clients → + → SABnzbd**
   - Name: `Tidarr`
   - Host: `tidarr`, Port: `8484`
   - URL Base: `/api/sabnzbd`
   - API Key: the key above
   - Category: `music`
   - **Test**, then **Save**.
2. **Lidarr → Settings → Download Clients → Remote Path Mappings → +**
   - Host: `tidarr`
   - Remote Path: `/shared/nzb_downloads/`
   - Local Path: `/mnt/storage/tidarr-downloads/`
   
   Without this, Lidarr reports "No files found are eligible for import"
   because it looks in a path that only exists inside Tidarr.
3. **Lidarr → Settings → Indexers → + → Newznab**
   - Name: `Tidarr`
   - URL: `http://tidarr:8484`, API Path: `/api/lidarr`
   - API Key: the key above
   - Categories: `3000`, `3010`, `3040`
   - Download Client: `Tidarr`
   - Enable RSS off; Automatic Search and Interactive Search on.
   - **Test**, then **Save**.

## Using it

Lidarr's searches (Interactive Search included) now show Tidal results. Only
albums you have monitored and searched for are fetched.

If Tidal rate-limits you, set `DOWNLOAD_BATCH_SIZE` and `DOWNLOAD_BATCH_DELAY`
(see upstream's
[rate-limited mode](https://github.com/cstaelen/tidarr#rate-limited-download-mode))
as environment variables in the compose file.

## Updating

Renovate opens a PR for new Tidarr releases. After merging, redeploy the stack
in Portainer with **Re-pull image and redeploy**.

## Backups

The `tidarr-config` volume holds your Tidal token and settings, but nothing
that can't be recreated by logging in again.

## Troubleshooting

- **Lidarr can't reach Tidarr**: `media-net` doesn't exist, or `tidarr` isn't
  on it. Deploy `media-stack` first.
- **Downloads complete but nothing imports**: the Remote Path Mapping above is
  missing or has the wrong host or paths (note the trailing slashes).
- **Auth errors from Tidal**: the Tidal token expired or was revoked. Open the
  Tidarr settings and run the device login again.
- **No search results**: the indexer's API key is wrong, or the album isn't on
  Tidal in your region.
