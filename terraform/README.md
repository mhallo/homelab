# terraform

The lab's settings that live outside the compose files, as code:

| File            | What it manages                                                        |
|-----------------|------------------------------------------------------------------------|
| `cloudflare.tf` | `gt3.dev` DNS: the `*.gt3.dev` wildcard and the GitHub Pages records    |
| `tailscale.tf`  | tailnet policy (`tailscale/policy.hujson`), the NAS's subnet route and key expiry |
| `portainer.tf`  | the Portainer stacks deployed from this repo, with their secrets        |
| `imports.tf`    | adopts the existing resources on the first run; no-ops after that      |

Left out on purpose: Cloudflare Email Routing's records (Cloudflare owns and
locks them) and the stacks of the private repo (their Terraform lives there).

Run it from the Mac, on the LAN or tailnet. State is local and gitignored. It
holds no stack secrets (those are write-only), but it does hold ids and
settings, so it stays off GitHub.

## Secrets

Everything comes from one Bitwarden Secure Note, `homelab-terraform`. Each
custom field (type Hidden) is an environment variable: the field's label is
the name, its value the secret. `./tf` loads them for one command, so nothing
is written to disk.

| Field                                                | Used for                          |
|------------------------------------------------------|-----------------------------------|
| `CLOUDFLARE_API_TOKEN`                               | Terraform's own token: Zone Read + DNS Edit on `gt3.dev` |
| `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET` | OAuth client: Policy File, Devices Core, Devices Routes (write) |
| `PORTAINER_API_KEY`                                  | Portainer access token            |
| `TF_VAR_<name>`                                      | a stack secret, e.g. `TF_VAR_db_password` for immich's `DB_PASSWORD` (see `variables.tf`) |

## Running it

```
brew install bitwarden-cli hashicorp/tap/terraform
bw login                                  # once
export BW_SESSION=$(bw unlock --raw)      # once per shell, or ./tf prompts
cd terraform
terraform init
./tf plan
./tf apply
```

`./tf <args>` is `terraform <args>` with the secrets loaded; `./tf run <cmd>`
runs any other command with them (e.g. `./tf run ./snapshot.sh`).

**Before the first apply, read the plan.** It imports what exists, so the only
changes should be the ones you expect (moving stack secrets to write-only,
for one). The first plan after an import prints the stacks' old env values,
because the Portainer provider doesn't mark them sensitive; run it somewhere
private.

**After any apply that touches traefik**, check the routes file is still
mounted:

```
docker exec traefik ls /etc/traefik/dynamic    # should list routes.yml
```

## Common changes

- **New stack**: add `stacks/<name>/`, merge it, then add a `portainer_stack`
  block (copy `dozzle`'s) plus an `import` only if it already exists in
  Portainer. Secrets: a `variable` (ephemeral, sensitive), an `env_wo` block,
  `env_wo_version = 1`, and a `TF_VAR_<name>` field in Bitwarden. `./tf apply`.
- **Change a secret**: update the Bitwarden field, bump the stack's
  `env_wo_version`, `./tf apply`. Write-only values can't be compared, so
  without the bump nothing is sent.
- **Tailnet policy**: edit `tailscale/policy.hujson` here, not in the admin
  console; a console edit is reverted by the next apply.
- **DNS**: add a `cloudflare_dns_record`. Service hostnames need nothing: the
  wildcard covers them.

## Snapshot

`./tf run ./snapshot.sh` dumps the live Cloudflare, Tailscale and Portainer
config to `.snapshot/` (gitignored) with secrets blanked. It's how this code
was written; rerun it to compare after changing something by hand.

## Troubleshooting

- **`prevent_destroy` error**: the change would delete and recreate a stack
  (a new name, endpoint or method). Do that by hand in Portainer instead, then
  `terraform state rm` and re-import.
- **401 / 403**: a credential is missing or expired. `./tf run env | grep -c
  TF_VAR_` shows the note loaded; Cloudflare's token page shows its status.
- **Stack update fails with 409**: Portainer is still deploying it. Wait and
  re-run the apply.
