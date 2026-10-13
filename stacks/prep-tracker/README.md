# prep-tracker

[prep-tracker](https://github.com/mhallo/prep-tracker) (private), the
interview prep tracker, at `https://prep.gt3.dev`. One FastAPI container. Its
image is built by that repo's CI and pushed to `ghcr.io/mhallo/prep-tracker`.
The header of `docker-compose.yml` lists where this stack differs from the
repo's `deploy/docker-compose.yml`.

| Service        | What it is            | Network |
|----------------|-----------------------|---------|
| `prep-tracker` | FastAPI app, port 8000 | `proxy` |

All state is `state.json` in the `data` named volume (`prep-tracker_data` on
the host).

The app has no auth. It's only reachable from the LAN and tailnet, like
everything else here, and should stay that way.

## First deploy

1. Deploy traefik first. This stack joins its `proxy` network.
2. The GHCR package is private, so Portainer needs credentials to pull it.
   Create a GitHub PAT (classic) with only `read:packages`, then in Portainer:
   **Registries → Add registry → Custom registry**, URL `ghcr.io`, username
   `mhallo`, the PAT as password.
3. **Stacks → Add stack → Repository**.
   - Name: `prep-tracker`. Don't rename it later: the volume name derives from it.
   - Compose path: `stacks/prep-tracker/docker-compose.yml`
   - No environment variables.
4. Deploy, then check it:

   ```
   curl -s https://prep.gt3.dev/healthz    # {"ok":true}
   ```

## Moving from the standalone deploy

If it already ran from `~/docker/prep-tracker` with a `./data` bind mount,
copy the state into the volume after the first Portainer deploy:

```
docker cp ~/docker/prep-tracker/data/state.json prep-tracker:/data/state.json
docker restart prep-tracker
```

Then `docker compose down` the old one, and remove its NPM proxy host.

## Updating

Every push to prep-tracker's `main` publishes a new `latest`. Renovate sees the
digest change and opens a PR here. Merge it, then redeploy the stack in
Portainer with **Re-pull image and redeploy**.

## Backups

```
docker cp prep-tracker:/data/state.json prep-$(date +%F).json
```

## Troubleshooting

- **`unauthorized` / `denied` pulling the image**: the GHCR registry isn't set
  up in Portainer, or the PAT expired or lacks `read:packages`.
- **404 from Traefik**: the container isn't on `proxy`, or the labels are
  missing.
- **`PermissionError` writing `/data`**: the volume was created by something
  other than this image, so it isn't owned by uid 1000. Fix with
  `docker run --rm -v prep-tracker_data:/data alpine chown -R 1000:1000 /data`.
- Timestamps in `state.json` are UTC. The image has no tzdata, so `TZ` isn't
  set.
