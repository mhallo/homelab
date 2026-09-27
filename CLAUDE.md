# CLAUDE.md

GitOps for a homelab. Portainer on the NAS deploys each `stacks/<name>/`
directory as a git-backed stack. README.md explains the reasoning behind the
rules below; read it before changing networking or traefik.

## Adding or changing a stack

- One stack per `stacks/<name>/docker-compose.yml`. The directory name is the
  Portainer stack name. Never rename an existing stack: compose derives volume
  names from it, so a rename orphans the data.
- **Images pinned as `tag@sha256:digest`** (e.g. `postgres:16@sha256:...`).
  No `latest`, `stable` or other floating tags without a digest. Renovate
  bumps them; add a `packageRules` entry in `renovate.json` when an app has
  one-way migrations or needs its own PR.
- **State in named volumes**, declared under top-level `volumes:`. Use an
  absolute `/volume1/...` path only when data must live somewhere specific.
  **Never a relative bind mount** (`./config`, `./bin/script.sh`): it resolves
  against Portainer's checkout and silently comes up empty. When porting an
  upstream compose file, drop or rework anything that needs one.
- **Secrets are `${VAR}`** with no default value, and never committed.
  Document every new variable under a `# ---- stacks/<name> ----` heading in
  `.env.example`. Non-secret config is hardcoded in the compose file.
- **Routing via Traefik labels**, not published ports. The routed service joins
  the external `proxy` network (plus `default` if it talks to siblings):

  ```yaml
      networks: [default, proxy]
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.<name>.rule=Host(`<name>.gt3.dev`)"
        - "traefik.http.routers.<name>.entrypoints=websecure"
        - "traefik.http.services.<name>.loadbalancer.server.port=<container port>"
  ...
  networks:
    proxy:
      external: true
  ```

  Only the web-facing container goes on `proxy`; databases and caches stay on
  `default`. No `ports:` unless it genuinely needs to be reachable by IP.
- Apps behind Traefik receive plain HTTP: tell them TLS is terminated upstream
  (e.g. `RAILS_ASSUME_SSL`, trusted proxy settings), and set any public URL
  to `https://<name>.gt3.dev`.
- `container_name` set on every service (`<stack>_<role>` for multi-container
  stacks), `restart: unless-stopped`, `TZ=America/Los_Angeles` where the
  image honours it.
- Keep a short header comment when a compose file deviates from the upstream
  example it came from, saying what changed and why.
- Non-container routes go in `stacks/traefik/dynamic/routes.yml`. Never route
  the same hostname from both labels and that file.
- Traefik static config stays as `command:` flags. Don't add a `traefik.yml`.

## Docs

When adding a stack, update README.md: the `Layout` tree and the mermaid
network diagram.

Stack-specific setup goes in `stacks/<name>/README.md`: first deploy in
Portainer (stack name, compose path, env vars), post-install steps, updating,
backups, troubleshooting. `stacks/sure/README.md` is the model. The top-level
README stays about how the whole lab fits together.

## Checking your work

- `docker compose -f stacks/<name>/docker-compose.yml config -q`
  (warnings about unset secret variables are expected)
- `npx --package renovate -- renovate-config-validator renovate.json`
  after touching `renovate.json`

## Git

Work on a branch and open a PR against `main`; don't commit to `main`.
