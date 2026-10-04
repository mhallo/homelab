# dozzle

[Dozzle](https://dozzle.dev), a live log viewer for every container on the
NAS, at `https://dozzle.gt3.dev`. It streams straight from the Docker API and
stores nothing, so it shows only what `docker logs` still has. Once a container
is removed or its logs rotate, those lines are gone. Based on upstream's
[Docker Compose example](https://dozzle.dev/guide/getting-started); the header
of `docker-compose.yml` lists where this stack differs from it.

| Service        | What it is                                   | Network          |
|----------------|----------------------------------------------|------------------|
| `dozzle`       | Web UI, port 8080                            | default, `proxy` |
| `socket-proxy` | Read-only Docker API on `socket-proxy:2375`  | default          |

State (`users.yml` and per-user UI settings) lives in the `data` named volume,
which compose names `dozzle_data`.

## First deploy

Dozzle runs with simple auth and won't start without `users.yml`, so seed
the volume first. On the NAS:

1. Generate the user file. Leaving out `--password` makes Dozzle prompt for
   it, so the password stays out of shell history:

   ```
   docker run -it --rm amir20/dozzle:v11.2.0 generate admin --name "Matt" --email you@example.com > users.yml
   ```

2. Copy it into the volume, then delete the local copy:

   ```
   docker run --rm -i -v dozzle_data:/data alpine sh -c 'cat > /data/users.yml' < users.yml
   rm users.yml
   ```

3. Deploy traefik first. This stack joins its `proxy` network.
4. In Portainer: **Stacks → Add stack → Repository**.
   - Name: `dozzle`. Don't rename it later: the volume name derives from it,
     and step 2 writes to `dozzle_data` by name.
   - Compose path: `stacks/dozzle/docker-compose.yml`
   - Environment variables: none.
5. Deploy, then check it's routed:

   ```
   curl -sI https://dozzle.gt3.dev | head -1
   ```

Compose warns that `dozzle_data` "already exists but was not created by Docker
Compose" because step 2 created it. That's harmless; it uses the volume as is.

## Users

To add a user or change a password, generate a new entry as in step 1 and
edit `/data/users.yml` in the volume, then restart `dozzle_web`. The file
format and per-user roles/filters are in upstream's
[simple auth docs](https://dozzle.dev/guide/authentication/simple).

## Security

Docker API access is close to root on the host, which is why Dozzle doesn't
mount the socket itself. `socket-proxy` allows only `GET`/`HEAD` on the
container, info, events, ping and version endpoints, so even a compromised
Dozzle can read logs and metadata but can't start, stop or exec into anything.

That also means Dozzle's [actions](https://dozzle.dev/guide/actions) and
[shell](https://dozzle.dev/guide/shell) features can't work here. Enabling
them would mean `POST=1` (and more) on the proxy, which removes most of the
point of having it.

## Updating

Renovate opens one PR for this stack covering both images. After merging,
redeploy in Portainer with **Re-pull image and redeploy**. Bump the
`amir20/dozzle` tag in the step 1 command to match.

## Backups

Nothing worth backing up beyond `users.yml`, which is easy to regenerate.

## Troubleshooting

- **404 from Traefik**: `dozzle` isn't on `proxy`, or the labels are missing.
- **`dozzle_web` restarting, log mentions `users.yml`**: the volume wasn't
  seeded, or was seeded under a different name. Check with
  `docker run --rm -v dozzle_data:/data alpine ls /data`.
- **Dozzle shows no containers, or `403` in the `dozzle_socket-proxy`
  log**: Dozzle hit an endpoint the proxy blocks. Note which API path in the
  proxy log and enable only that section.
- **Socket proxy logs `permission denied` on `docker.sock`**: AppArmor or
  SELinux is blocking the socket. Upstream's fix is `privileged: true` on
  `socket-proxy`.
