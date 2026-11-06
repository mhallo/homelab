# Adopts what already exists instead of creating duplicates. After the first
# successful apply these are no-ops; delete this file then if you like.

import {
  to = cloudflare_dns_record.wildcard
  id = "${local.zone_id}/82d20e506011d852c57c13a2caadd57c"
}

import {
  to = cloudflare_dns_record.pages_apex["185.199.108.153"]
  id = "${local.zone_id}/611bafebf360104c67b17e75aebae129"
}

import {
  to = cloudflare_dns_record.pages_apex["185.199.109.153"]
  id = "${local.zone_id}/05edfb742904328ae5e6e0d4a0e66597"
}

import {
  to = cloudflare_dns_record.pages_apex["185.199.110.153"]
  id = "${local.zone_id}/4108affd7627b552971d5bd688827e9f"
}

import {
  to = cloudflare_dns_record.pages_apex["185.199.111.153"]
  id = "${local.zone_id}/74d2f0e408ece835f54712c45317a143"
}

import {
  to = cloudflare_dns_record.pages_www
  id = "${local.zone_id}/116f687c10ff5ac91e6467cf1748e2f4"
}

import {
  to = cloudflare_dns_record.pages_challenge
  id = "${local.zone_id}/c61b72925bad2f38148414407fb95bc9"
}

import {
  to = tailscale_acl.this
  id = "acl"
}

import {
  to = tailscale_device_subnet_routes.nas
  id = "nK5DHbNjz821CNTRL"
}

import {
  to = tailscale_device_key.nas
  id = "nK5DHbNjz821CNTRL"
}

import {
  to = portainer_stack.traefik
  id = "${local.endpoint_id}-11-standalone-repository"
}

import {
  to = portainer_stack.immich
  id = "${local.endpoint_id}-17-standalone-repository"
}

import {
  to = portainer_stack.tailscale
  id = "${local.endpoint_id}-18-standalone-repository"
}

import {
  to = portainer_stack.sure
  id = "${local.endpoint_id}-21-standalone-repository"
}

import {
  to = portainer_stack.dozzle
  id = "${local.endpoint_id}-22-standalone-repository"
}
