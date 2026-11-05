# media-stack

Jellyfin, the *arr apps, Decypharr and Aurral. Every service mounts
`/volume1/Media` at `/mnt/storage`, so a file has the same path in all of
them, and keeps its config in `/volume1/Software/Docker-Appdata/<service>`.
The stack creates the `media-net` network that `tidarr` joins.

Only Aurral is documented here so far.

## Aurral

[Aurral](https://github.com/lklynet/aurral) at `https://aurral.gt3.dev`:
music discovery, scheduled "flow" playlists, playlist imports from Spotify and
others, and a Subsonic server. It fetches music through its built-in yt-dlp
and Tidarr, and can hand albums to Lidarr.
Upstream docs: <https://docs.aurral.org/>.

| Path in container | Host path                                 | What it is                    |
|-------------------|-------------------------------------------|-------------------------------|
| `/config`         | `Docker-Appdata/aurral`                   | database, settings, yt-dlp staging |
| `/mnt/storage`    | `/volume1/Media`                          | shared media root             |
| `/downloads`      | `/volume1/Media/tidarr-downloads`         | Tidarr's finished albums      |

Its Library folder is `/mnt/storage/aurral` (`/volume1/Media/aurral`).

### First deploy

No new env vars. Redeploy `media-stack` in Portainer, then:

1. Open `https://aurral.gt3.dev` and create the admin account.
2. First-run setup asks for the Library folder: keep `/mnt/storage/aurral`.
3. Connect Lidarr (last step of setup, or **Settings → Library → Lidarr**):
   URL `http://lidarr:8686`, Lidarr's API key, **Test connection**, then pick
   the root folder and profiles for new artists. Leave **Apply to Lidarr**
   (community guide) alone unless you want Aurral to rewrite Lidarr's quality
   profile and naming.
4. In **Lidarr → Settings → Metadata**, set **Tag Audio Files with Metadata**
   to all files, so Aurral matches artists by MusicBrainz ID, not name.
5. Connect Tidarr: see `stacks/tidarr/README.md`, "Connect Lidarr and
   Aurral".
6. **Settings → Status → Storage → Run checks** should pass for the Library
   folder and the Lidarr library.
7. In Jellyfin, add a Music library for `/mnt/storage/aurral` (Lidarr's
   folder too, if it isn't already a library) to play what Aurral downloads.
   Subsonic apps can instead point at `https://aurral.gt3.dev` directly.

yt-dlp is on by default with priority 50, so Aurral tries Tidarr (via
Prowlarr) first and falls back to YouTube.

### Updating

Renovate's `media-stack` group bumps the pinned tag. Aurral migrates its
database on start, so read the release notes, and copy
`Docker-Appdata/aurral` first if they mention a migration. Don't switch to the
`nightly` tag: it's amd64-only and unstable.

Aurral checks aurral.org hourly for a newer release, sending only its version.

### Backups

`Docker-Appdata/aurral` has the database (users, flows, library index, API
keys). Downloaded music is in `/volume1/Media/aurral`.

### Troubleshooting

- **API test to Lidarr passes but tracks don't show up**: a path problem.
  Run the storage checks; the path Lidarr reports must exist under
  `/mnt/storage` in Aurral.
- **Logins break or redirect to http**: `TRUST_PROXY` and `AURRAL_PUBLIC_URL`
  must stay set; Traefik terminates TLS.
- **More logging**: add `AURRAL_VERBOSE_LOGS=true` and redeploy.
