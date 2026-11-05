# tidarr

[Tidarr](https://github.com/cstaelen/tidarr) at `https://tidarr.gt3.dev`. It
plugs into Lidarr as both a Newznab indexer and a SABnzbd download client, so
Lidarr treats it like any other source. Aurral (in
`media-stack`) uses it the same way, through Prowlarr; Aurral needs Tidarr
1.2.9 or later. Based on upstream's
[README](https://github.com/cstaelen/tidarr#getting-started) and
[Lidarr integration guide](https://github.com/cstaelen/tidarr/wiki/Lidarr-Integration-Guide);
the header of `docker-compose.yml` lists where this stack differs.

It needs a Tidal account.

| Service  | What it is                         | Network               |
|----------|------------------------------------|-----------------------|
| `tidarr` | Web UI and API on port 8484        | `media-net`, `proxy`  |

State (your Tidal login, settings and the API key) is in the `tidarr-config`
named volume. Finished downloads land in `/volume1/Media/tidarr-downloads`,
which Lidarr sees as `/mnt/storage/tidarr-downloads` and Aurral sees as
`/downloads`.

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

## Connect Lidarr and Aurral

Tidarr answers as a Newznab indexer and a SABnzbd download client. Lidarr
gets both directly. Prowlarr carries the indexer only for Aurral: it can't
sync it to Lidarr (see below). Based on upstream's
[Lidarr guide](https://github.com/cstaelen/tidarr/wiki/Lidarr-Integration-Guide)
and Aurral's [Tidarr docs](https://docs.aurral.org/integrations/usenet/#tidarr).

Use `http://tidarr:8484` everywhere, never `https` or `tidarr.gt3.dev`:
Prowlarr, Lidarr and Aurral reach Tidarr directly on `media-net`, and Tidarr
only speaks plain HTTP. An `https` URL fails with "The SSL connection could
not be established".

Get the API key:

```
docker exec tidarr cat /shared/.tidarr-api-key
```

### Lidarr

Turn on **Show advanced** (the cog) on these screens: URL Base, API Path and
the indexer's Download Client are hidden without it.

1. **Lidarr → Settings → Download Clients → + → SABnzbd**
   - Name: `Tidarr`
   - Host: `tidarr`, Port: `8484`
   - URL Base: `/api/sabnzbd`
   - API Key: the key above
   - Category: `music`
   - **Test**, then **Save**.
2. **Lidarr → Settings → Download Clients → Remote Path Mappings → +**
   - Host: `tidarr`
   - Remote Path: `/downloads/`
   - Local Path: `/mnt/storage/tidarr-downloads/`
   
   Tidarr reports finished albums as `/downloads/<id>`, a path that only
   exists inside Aurral. Without this mapping Lidarr's health page says
   "Tidarr places downloads in /downloads but this directory does not appear
   to exist inside the container" and nothing imports.
3. **Lidarr → Settings → Indexers → + → Newznab**
   - Name: `Tidarr`
   - URL: `http://tidarr:8484` (nothing after the port)
   - API Path: `/api/lidarr`
   - API Key: the key above
   - Categories: `3000`, `3010`, `3040` (Music, MP3, Lossless)
   - Download Client: `Tidarr`
   - Enable RSS off; Automatic Search and Interactive Search on.
   - **Test**, then **Save**.
   
   Putting `/api/lidarr` in the URL field instead fails with "Unable to
   connect to indexer": Lidarr appends its own API Path to it.

### Prowlarr (for Aurral)

4. **Prowlarr → Settings → Apps → Sync Profiles → +**: name `Not synced`,
   with RSS, Automatic Search and Interactive Search all off.
5. **Prowlarr → Indexers → Add Indexer → Generic Newznab**
   - Name: `Tidarr`
   - URL: `http://tidarr:8484`, API Path: `/api/lidarr`
   - API Key: the key above
   - Sync Profile: `Not synced`
   - **Test**, then **Save**.

It must not sync to Lidarr. When Prowlarr adds an indexer, Lidarr runs an
empty test search; Tidarr 1.2.9 answers with a dummy `test` release that has
no category, Prowlarr drops it ("No categories provided"), and Lidarr rejects
the indexer with "no results in the configured categories". Real searches
carry categories, so Aurral's searches through Prowlarr work.

### Aurral

6. **Aurral → Settings → Downloads → Prowlarr**: enable it, URL
   `http://prowlarr:9696`, Prowlarr's API key, **Test connection**, then
   **Refresh indexers** and turn on `Tidarr`.
7. **Aurral → Settings → Downloads → Tidarr**: URL `http://tidarr:8484`, the
   Tidarr key, **Test connection**.

Aurral mounts the download folder at `/downloads`, the path Tidarr reports,
so it needs no path mapping. Tidarr
deletes an album's files once Aurral has imported and removed the download.

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

- **Lidarr or Aurral can't reach Tidarr**: `media-net` doesn't exist, or
  `tidarr` isn't on it. Deploy `media-stack` first. To test from Prowlarr:
  `docker exec prowlarr curl -s "http://tidarr:8484/api/lidarr?t=caps&apikey=<key>"`
  should print XML.
- **"SSL connection could not be established"**: the URL is `https`. Use
  `http://tidarr:8484`.
- **Prowlarr logs a 400 from Lidarr for Tidarr on every sync**: the Prowlarr
  indexer is syncing. Set its Sync Profile to `Not synced`.
- **Grab stays "Pending - Download client is unavailable"**: the SABnzbd
  client is missing, disabled, or failing its Test (URL Base `/api/sabnzbd`,
  SSL off).
- **Aurral says the Tidarr download finished but can't find it**: check that
  `docker exec aurral ls /downloads` lists the album folders.
- **Downloads complete but nothing imports**: the Remote Path Mapping above is
  missing or has the wrong host or paths (`/downloads/`, trailing slashes).
- **Auth errors from Tidal**: the Tidal token expired or was revoked. Open the
  Tidarr settings and run the device login again.
- **No search results**: the indexer's API key is wrong, or the album isn't on
  Tidal in your region.
