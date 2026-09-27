# sure

[Sure](https://github.com/we-promise/sure), self-hosted personal finance, at
`https://sure.gt3.dev`. Based on upstream's
[Docker guide](https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md);
the header of `docker-compose.yml` lists where this stack differs from it.

| Service  | What it is                        | Network          |
|----------|-----------------------------------|------------------|
| `web`    | Rails app, port 3000              | default, `proxy` |
| `worker` | Sidekiq: syncs, imports, cron     | default          |
| `db`     | Postgres 16                       | default          |
| `redis`  | Sidekiq queue                     | default          |

State lives in the `app-storage`, `postgres-data` and `redis-data` named
volumes.

## First deploy

1. Deploy traefik first. This stack joins its `proxy` network.
2. Generate a secret key:

   ```
   openssl rand -hex 64
   ```

3. In Portainer: **Stacks → Add stack → Repository**.
   - Name: `sure`. Don't rename it later: the volume names derive from it.
   - Compose path: `stacks/sure/docker-compose.yml`
   - Environment variables:
     - `SECRET_KEY_BASE`: the key from step 2
     - `POSTGRES_PASSWORD`: anything strong

4. Deploy, then check it's routed:

   ```
   curl -sI https://sure.gt3.dev | head -1
   ```

5. Open `https://sure.gt3.dev` and register. The first account is the super
   admin.
6. **Settings → Self-Hosting → Onboarding**: set to **Closed** so nobody else
   can register.

`POSTGRES_PASSWORD` is only read when `postgres-data` is first created.
Changing it in Portainer afterwards doesn't change the database's password;
the app would just fail to connect.

## Passkeys

`WEBAUTHN_RP_ID` is `gt3.dev` and `WEBAUTHN_ALLOWED_ORIGINS` is
`https://sure.gt3.dev`, both hardcoded in the compose file. Changing either,
or the hostname, after registering a passkey invalidates it. See upstream's
[WebAuthn notes](https://github.com/we-promise/sure/blob/main/docs/hosting/webauthn.md).

## Updating

Renovate opens a PR for new Sure releases, a week after they ship. Migrations
run on boot and are one-way, so read the release notes before merging. After
merging, redeploy the stack in Portainer with **Re-pull image and redeploy**.

Postgres major upgrades are disabled in `renovate.json`. A new major can't read
the old data directory, so it needs a `pg_dump` / restore rather than a tag
bump.

## Connecting Claude (MCP)

Sure serves an MCP endpoint at `https://sure.gt3.dev/mcp` with OAuth, so no
extra configuration is needed here. See upstream's
[MCP docs](https://github.com/we-promise/sure/blob/main/docs/hosting/mcp.md).

It only works from clients that connect from a machine on the LAN or tailnet.
claude.ai, the mobile app and Desktop's Settings → Connectors connect from
Anthropic's servers, which can't reach `10.10.2.10`.

From Claude Code:

```
claude mcp add --transport http sure https://sure.gt3.dev/mcp
```

then `/mcp` in Claude Code to sign in to Sure and approve access.

The tools can write as well as read: edit transactions, budgets, categories and
tags, and import statements. Consider confirming each tool call rather than
auto-approving them.

The static-token alternative (`MCP_API_TOKEN` + `MCP_USER_EMAIL`) is only
for clients without OAuth. It would be two more Portainer variables, documented
in `.env.example`.

## Backups

Upstream's `backup` service isn't included: it bind mounts `./bin/db-backup.sh`,
which comes up empty under Portainer. A manual dump:

```
docker exec sure_postgres pg_dump -U sure_user -d sure_production | gzip > sure-$(date +%F).sql.gz
```

## Troubleshooting

- **404 from Traefik**: `web` isn't on `proxy`, or the labels are missing.
- **`ActiveRecord::DatabaseConnectionError` on first start**: `postgres-data`
  was initialised with different credentials, e.g. by an earlier attempt.
  With no data worth keeping yet, delete the stack, remove the
  `sure_postgres-data` volume, and deploy again.
- **Market data syncs hang**: the IPv6-first DNS problem upstream works around.
  `web` and `worker` already use `8.8.8.8` / `1.1.1.1` for this.
- **Stuck syncs or imports**: **Settings → Background jobs**. The Sidekiq
  dashboard at `/sidekiq` (super admin only) is the fallback.
