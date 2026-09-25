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

1. **Deploy the container** as usual, publishing a port on the host.

2. **Add two entries** to `stacks/traefik/dynamic/routes.yml` -- a router
   (hostname to service name) and a service (service name to upstream URL):

   ```yaml
   http:
     routers:
       newthing:
         rule: "Host(`newthing.gt3.dev`)"
         service: newthing
         entryPoints: [websecure]

     services:
       newthing:
         loadBalancer:
           servers:
             - url: "http://10.10.2.10:PORT"
   ```

3. **Commit and push**, then merge to `main`.

4. **In Portainer**, open the `traefik` stack and use **Pull and redeploy**
   with **Re-pull image and redeploy** enabled.

5. **Verify**: `curl -sI https://newthing.gt3.dev | head -1`
   Any 2xx or 3xx means it routed. A 404 from Traefik means no router matched
   the hostname -- check for a typo in the rule.

No DNS record and no certificate work is ever needed. The `*.gt3.dev` wildcard
already resolves every hostname to the NAS, and the wildcard certificate
already covers them.

### Always force the recreate

Step 4 is not optional. When a git stack updates to a new commit, Portainer
deletes and re-clones the repository directory on the host. Existing containers
keep pointing at the directory that was replaced, so the bind mount goes
silently empty and Traefik loses all routing -- running, healthy, serving
nothing. Forcing a recreate remounts against the new checkout.

See https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/empty-relative-bind-mounts

### Where the routing config actually lives

The Traefik stack mounts its dynamic config from Portainer's own git checkout,
by that checkout's **host** path:

```
/volume1/docker/portainer/compose/11/stacks/traefik/dynamic
```

Portainer clones to `/data/compose/<stackId>/` inside its own container, but
the Docker daemon resolves bind mounts against the host filesystem, where that
path does not exist -- it silently creates an empty directory instead. Since
Portainer's `/data` is bind-mounted from `/volume1/docker/portainer`, the host
path above is the same directory addressed the way the daemon sees it.

The `11` is this stack's id. **Deleting and recreating the traefik stack
changes it**, which breaks the mount in exactly the same invisible way. If
routing ever stops working after a redeploy, check this first:

```
docker exec traefik ls /etc/traefik/dynamic    # should list routes.yml
```

Moving the container services to Docker labels would remove this dependency
entirely; it would also require every stack to join a shared network and
Traefik to mount `docker.sock`.

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
