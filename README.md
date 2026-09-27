# Homelab

GitOps for my homelab. GitHub is the source of truth; Portainer on the NAS
deploys from this repo.

## Layout

```
stacks/             One directory per Portainer stack
  traefik/          Reverse proxy for *.gt3.dev
    docker-compose.yml      static config, as command flags
    dynamic/routes.yml      >>> EDIT THIS to add a service <<<
  immich/
  media-stack/
  tailscale/        see the warning at the top of its compose file
  sd-import-watcher/
```

## Networking model

The NAS sits on its own VLAN, `10.10.2.0/24`, at `10.10.2.10`. That subnet is
why everything below is scoped the way it is.

`*.gt3.dev` is a wildcard A record on Cloudflare pointing at `10.10.2.10`,
grey-clouded so Cloudflare doesn't proxy it. Public DNS, private address: the
names resolve from anywhere, but only go somewhere useful from inside the
network. Nothing is port forwarded.

TLS is a Let's Encrypt wildcard for `*.gt3.dev` via the Cloudflare DNS-01
challenge. It validates with a TXT record, so nothing needs to be reachable
from outside for certificates to issue or renew.

### Network flow

Both address ranges below are private and unroutable from the internet:
`10.10.2.0/24` is RFC1918, `100.64.0.0/10` is the CGNAT space Tailscale uses.

```mermaid
flowchart TB
    CF["Cloudflare DNS<br>*.gt3.dev → 10.10.2.10<br>DNS only, not proxied"]
    LE["Let's Encrypt<br>DNS-01 TXT challenge"]

    AWAY["Client away from home<br>tailnet 100.64.0.0/10"]
    HOME["Client on the main LAN"]

    UCG["Ubiquiti Cloud Gateway Fiber<br>WAN edge · VLANs · inter-VLAN routing<br>no ports forwarded"]

    HOME -. "resolves" .-> CF
    AWAY -. "resolves" .-> CF
    HOME -- "https :443" --> UCG
    UCG -- "routes into the VLAN" --> TRAEFIK

    subgraph VLAN["VLAN 10.10.2.0/24 — private, RFC1918"]
        subgraph NAS["NAS · 10.10.2.10"]
            TSC["tailscale<br>host network<br>advertises 10.10.2.0/24"]
            TRAEFIK["traefik<br>:80 redirect → :443"]
            PORT["portainer :9000"]
            UGOS["UGOS web UI :9999"]

            subgraph STACKS["Portainer stacks"]
                IMM["immich :2283<br>immich_server · postgres<br>redis · machine-learning"]
                MED["media-stack<br>jellyfin :8096 · sonarr :8989<br>radarr :7878 · lidarr :8686<br>prowlarr :9696 · jellyseerr :5055<br>decypharr :8282"]
                SD["sd-import-watcher<br>no published port"]
            end
        end

        HP["HP EliteDesk mini<br>planned — joins as a swarm node"]
    end

    AWAY -- "subnet route" --> TSC
    TSC --> TRAEFIK

    TRAEFIK --> IMM
    TRAEFIK --> MED
    TRAEFIK --> PORT
    TRAEFIK --> UGOS
    TRAEFIK -. "planned" .-> HP
    TRAEFIK -. "Cloudflare API writes TXT" .-> LE
```

### Getting to it from outside

Tailscale. The NAS advertises `10.10.2.0/24` as a subnet route (`TS_ROUTES` in
the tailscale stack), which puts the VLAN on the tailnet and makes the same
hostnames work away from home.

Two parts of that don't live in the compose file:

- `ip_forward` has to be enabled on the NAS, in `/etc/sysctl.d/99-tailscale.conf`
- the route has to be approved in the Tailscale admin console, under the
  machine's subnets

iOS and macOS pick up subnet routes on their own. Linux clients need
`--accept-routes`.

### Why the file provider instead of Docker labels

Traefik routes to services by host IP and published port, not by Docker
discovery. This means:

- no existing stack needs editing, joining a shared network, or redeploying
- Traefik does not mount `docker.sock`, so it holds no Docker privileges
- the whole routing table is one reviewable file in git

Trade-off: new services are added manually in `routes.yml` rather than being
auto-discovered. For a stable service list this is the better trade.

## Adding a service

1. Deploy the container, publishing a port on the host.

2. Add a router and a service to `stacks/traefik/dynamic/routes.yml`:

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

3. Push and merge to `main`.

4. In Portainer, open the `traefik` stack, hit Pull and redeploy, and tick
   "Re-pull image and redeploy".

5. Check it: `curl -sI https://newthing.gt3.dev | head -1`

   2xx or 3xx means it routed. 404 means no router matched the hostname, so
   check the rule for a typo.

No DNS or cert work. The `*.gt3.dev` wildcard covers every hostname already.

### Force the recreate

Step 4 matters. Updating a git stack makes Portainer delete and re-clone the
repo directory on the host. Containers that aren't recreated stay pointed at
the old directory, so the mount goes empty and Traefik serves nothing -- still
running, no errors anywhere. Forcing the recreate remounts it.

https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/empty-relative-bind-mounts

### Where routes.yml comes from

Traefik mounts its dynamic config out of Portainer's git checkout, using the
host path:

```
/volume1/docker/portainer/compose/11/stacks/traefik/dynamic
```

Portainer clones to `/data/compose/<stackId>/` inside its own container. The
Docker daemon resolves bind mounts on the host, where that path doesn't exist,
so it creates an empty directory instead of failing. Portainer's `/data` comes
from `/volume1/docker/portainer`, so the path above is the same directory the
daemon can actually see.

The `11` is the stack id. Delete and recreate the traefik stack and it changes,
which breaks the mount the same silent way. If routing dies after a redeploy,
start here:

```
docker exec traefik ls /etc/traefik/dynamic    # should list routes.yml
```

Docker labels would drop this dependency, at the cost of putting every stack on
a shared network and giving Traefik the docker socket.

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
