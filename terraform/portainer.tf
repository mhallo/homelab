# Portainer stacks deployed from this repo. Each follows main: merge, then
# Portainer redeploys (on its own where update_interval is set).
#
# Secrets go in env_wo: Terraform sends them on deploy but never stores them in
# state. They come from TF_VAR_* fields on the Bitwarden item (see ./tf). After
# changing one, bump that stack's env_wo_version and apply.
#
# prevent_destroy: some settings (name, endpoint, method) force Portainer to
# delete and recreate a stack. That changes its id, which breaks traefik's
# routes.yml mount, so a plan that would do it fails instead.

locals {
  endpoint_id = 3 # "local", the NAS's Docker
  repo        = "https://github.com/mhallo/homelab"
}

# pull_image forces the container to be recreated on every deploy. Without
# it a redeploy re-clones the repo and Traefik keeps a stale, empty
# routes.yml mount. README.md, "Force the recreate".
resource "portainer_stack" "traefik" {
  name                          = "traefik"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/traefik/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"
  pull_image                    = true

  env_wo {
    name  = "CF_DNS_API_TOKEN"
    value = var.cf_dns_api_token
  }
  env_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}

# Immich's migrations are one-way, so its Renovate PRs carry a
# read-release-notes label: merging one is the upgrade.
resource "portainer_stack" "immich" {
  name                          = "immich"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/immich/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"

  env {
    name  = "UPLOAD_LOCATION"
    value = "/volume1/Software/Docker-Appdata/immich/upload_location"
  }

  env {
    name  = "DB_DATA_LOCATION"
    value = "/volume1/Software/Docker-Appdata/immich/postgres"
  }

  env_wo {
    name  = "DB_PASSWORD"
    value = var.db_password
  }

  env_wo {
    name  = "DB_USERNAME"
    value = var.db_username
  }

  env_wo {
    name  = "DB_DATABASE_NAME"
    value = var.db_database_name
  }
  env_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "portainer_stack" "tailscale" {
  name                          = "tailscale"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/tailscale/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"

  env_wo {
    name  = "TS_AUTHKEY"
    value = var.ts_authkey
  }
  env_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "portainer_stack" "sure" {
  name                          = "sure"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/sure/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"

  env_wo {
    name  = "SECRET_KEY_BASE"
    value = var.secret_key_base
  }

  env_wo {
    name  = "POSTGRES_PASSWORD"
    value = var.postgres_password
  }

  env_wo {
    name  = "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
    value = var.active_record_encryption_primary_key
  }

  env_wo {
    name  = "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"
    value = var.active_record_encryption_deterministic_key
  }

  env_wo {
    name  = "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
    value = var.active_record_encryption_key_derivation_salt
  }
  env_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "portainer_stack" "dozzle" {
  name                          = "dozzle"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/dozzle/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"

  lifecycle {
    prevent_destroy = true
  }
}

resource "portainer_stack" "backrest" {
  name                          = "backrest"
  deployment_type               = "standalone"
  method                        = "repository"
  endpoint_id                   = local.endpoint_id
  repository_url                = local.repo
  repository_reference_name     = "refs/heads/main"
  file_path_in_repository       = "stacks/backrest/docker-compose.yml"
  git_repository_authentication = false # public repo
  update_interval               = "5m"

  env_wo {
    name  = "B2_KEY_ID"
    value = var.b2_key_id
  }

  env_wo {
    name  = "B2_APPLICATION_KEY"
    value = var.b2_application_key
  }

  env_wo {
    name  = "RESTIC_PASSWORD"
    value = var.restic_password
  }
  env_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}
