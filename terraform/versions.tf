terraform {
  # env_wo (write-only stack secrets) needs 1.11+.
  required_version = ">= 1.11"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.29.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.3"
    }
    portainer = {
      source  = "portainer/portainer"
      version = "2.2.0"
    }
  }
}

# Credentials come from the environment (see ./tf):
#   CLOUDFLARE_API_TOKEN, TAILSCALE_OAUTH_CLIENT_ID/SECRET, PORTAINER_API_KEY
provider "cloudflare" {}

provider "tailscale" {}

# Direct, not through Traefik: a traefik redeploy would cut Terraform's own
# connection mid-request.
provider "portainer" {
  endpoint = "http://10.10.2.10:9000"
}
