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

1. Deploy traefik first. This stack joins its `proxy` network.
2. In Portainer: **Stacks → Add stack → Repository**.
   - Name: `dozzle`. Don't rename it later: the volume name derives from it,
     and step 3 writes to `dozzle_data` by name.
   - Compose path: `stacks/dozzle/docker-compose.yml`
   - Environment variables: none.

   Deploy. `dozzle_web` restart-loops with `No users.yaml or users.yml file
   found` until step 3 is done; that's expected.
3. Seed `users.yml` into the volume. On the NAS, with your own username,
   email and password:

   ```
    docker run -i --rm amir20/dozzle:v11.2.0 generate you@example.com --email you@example.com --name "Matt" --password 'YOUR-PASSWORD' 2>/dev/null | docker run -i --rm -v dozzle_data:/data alpine sh -c 'cat > /data/users.yml'
   history -c
   ```

   - The username is the first argument after `generate` and is matched
     exactly, case included. Use what your password manager stores as the
     username so autofill works.
   - `--password` keeps the input exact. The prompt and piped alternatives
     corrupted the password or the file in practice (`-t` adds `\r` and the
     prompt to the output; pasting into a hidden prompt over SSH can mangle it).
   - The leading space keeps the command out of history where `HISTCONTROL`
     has `ignorespace`; `history -c` covers it otherwise.
   - A password containing `'` breaks the quoting; generate one without it.
4. Log in at `https://dozzle.gt3.dev`. No restart needed: Dozzle re-reads
   `users.yml` on each login attempt. If it fails, check what was written:

   ```
   docker run --rm -v dozzle_data:/data alpine cat -v /data/users.yml
   ```

   It should be plain lines starting with `users:`, with no `^M` or `^[`, and
   a 60-character `$2a$` hash.
5. Check it's routed:

   ```
   curl -sI https://dozzle.gt3.dev | head -1
   ```

## Users

To change the password, re-run step 3; it overwrites `users.yml`. To add a
user, generate an entry the same way but send it to the terminal, and paste it
under `users:` in `/data/users.yml`. No restart needed either way. The file
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
`amir20/dozzle` tag in the step 3 command to match.

## Backups

Nothing worth backing up beyond `users.yml`, which is easy to regenerate.

## Troubleshooting

- **404 from Traefik**: `dozzle` isn't on `proxy`, or the labels are missing.
- **`dozzle_web` restarting with `No users.yaml or users.yml file found`**:
  the volume wasn't seeded, or was seeded under a different name. Compare
  `docker volume ls | grep dozzle` with the name used in step 3, then check
  with `docker run --rm -v dozzle_data:/data alpine ls -la /data`.
- **`invalid credentials` in the log**: the username doesn't match exactly
  (autofill putting in an email, a phone capitalising the first letter), or
  the password differs from what was hashed. Re-run step 3 with `--password`.
- **`yaml: control characters are not allowed`**: `users.yml` has `\r` or
  terminal escape codes in it, usually from `docker run -t`. Re-run step 3.
- **Dozzle shows no containers, or `403` in the `dozzle_socket-proxy`
  log**: Dozzle hit an endpoint the proxy blocks. Note which API path in the
  proxy log and enable only that section.
- **Socket proxy logs `permission denied` on `docker.sock`**: AppArmor or
  SELinux is blocking the socket. Upstream's fix is `privileged: true` on
  `socket-proxy`.
