# Homelab

Provisioning and GitOps for my homelab. GitHub is the source of truth; Portainer
on the NAS deploys from this repo.

## Layout

```
homelab/            Ansible provisioning for a fresh compute node
stacks/             One directory per Portainer stack
  traefik/          Reverse proxy for *.gt3.dev
    docker-compose.yml      static config, as command flags
    dynamic/routes.yml      >>> EDIT THIS to add a service <<<
  immich/
  media-stack/
  tailscale/        see the warning at the top of its compose file
  sd-import-watcher/
```

## Provisioning

`curl -fsSL https://raw.githubusercontent.com/mhallo/homelab/refs/heads/main/homelab/bootstrap.sh | bash`

## Networking model

`*.gt3.dev` resolves to the NAS's LAN IP (`10.10.2.10`) via a public wildcard
A record on Cloudflare, grey-clouded (DNS only, not proxied).

This makes every service LAN-reachable and nothing internet-reachable: outside
the network the name resolves to a private IP that does not exist on the public
internet. No ports are forwarded. Remote access stays with Tailscale; enabling
subnet routing for `10.10.2.0/24` makes the same hostnames work remotely.

TLS is a real Let's Encrypt wildcard for `*.gt3.dev`, obtained via the
Cloudflare DNS-01 challenge. Validation is a TXT record, so no inbound
connection to the NAS is required.

### Why the file provider instead of Docker labels

Traefik routes to services by host IP and published port, not by Docker
discovery. This means:

- no existing stack needs editing, joining a shared network, or redeploying
- Traefik does not mount `docker.sock`, so it holds no Docker privileges
- the whole routing table is one reviewable file in git

Trade-off: new services are added manually in `routes.yml` rather than being
auto-discovered. For a stable service list this is the better trade.

## Adding a service

1. Add a router + service entry in `stacks/traefik/dynamic/routes.yml`
2. Copy the file to the NAS at
   `/volume1/Software/Docker-Appdata/traefik/dynamic/`
3. Traefik watches that directory and hot-reloads -- no redeploy, no downtime

No DNS change is ever needed -- the wildcard already covers every hostname.

### Why the dynamic config is copied rather than mounted from the repo

Portainer deploys the compose file from git correctly, but relative bind
mounts in that compose do not resolve to the repo checkout -- Docker silently
creates an empty directory instead, and Traefik starts with no configuration
while appearing to run normally. Absolute paths avoid that entirely. Automating
the copy (a clone on the NAS plus a scheduled `git pull`) is a later task.

## Secrets

Secrets are **never** committed. Compose files reference `${VAR}`; the values
are set per-stack in Portainer's *Environment variables* section and stored on
the NAS.

See `.env.example` for which variables each stack requires. That file is
documentation only -- git-backed stacks in Portainer do not read it.

## Port 80/443 on the NAS

UGOS ships an nginx bound to `0.0.0.0:80` and `0.0.0.0:443` that exists only
to provide portless redirects to its web UI, which actually runs on 9999
(HTTP) and 9443 (HTTPS). Traefik cannot bind those ports until the redirects
are disabled:

> Control Panel → Device Connection → Portal settings → Web service
> uncheck **Redirect port 80 to HTTP port** and **Redirect port 443 to HTTPS
> port**, then Apply.

After that the NAS UI is reached at `:9999` / `:9443`, or through
`nas.gt3.dev` once Traefik is up.

## Static vs dynamic config

Static config (entrypoints, providers, ACME, the wildcard certificate) is set
as `command:` flags. Do not add a `traefik.yml` back -- Traefik's static config
sources are mutually exclusive, so the file would silently disable every flag.

Dynamic config is `dynamic/routes.yml` only. Traefik watches it and reloads on
change.

## Conventions

- **Bind mounts for state must be absolute paths.** A relative path resolves
  inside the stack's project directory (`/data/compose/<stack-id>/`), which
  changes if the stack is ever recreated -- silently losing the data. The
  `tailscale` stack currently violates this; see its compose file.
- Config that should come from git may use relative paths, since it is
  reproducible from the repo.
