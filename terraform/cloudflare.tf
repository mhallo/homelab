# gt3.dev DNS. The email records (MX, DKIM, SPF, DMARC) belong to Cloudflare
# Email Routing, which creates and locks them, so they're left out.

locals {
  zone_id = "9529b23345405be2298fa42c95942b36"
}

# Every service hostname. Public DNS, private address: it only resolves to
# something reachable from the LAN or the tailnet. Not proxied, so Cloudflare
# never sees the traffic. README.md, "Networking model".
resource "cloudflare_dns_record" "wildcard" {
  zone_id = local.zone_id
  name    = "*.gt3.dev"
  type    = "A"
  content = "10.10.2.10"
  proxied = false
  ttl     = 1
}

# The apex and www serve the GitHub Pages site (mhallo.github.io).
resource "cloudflare_dns_record" "pages_apex" {
  for_each = toset(["185.199.108.153", "185.199.109.153", "185.199.110.153", "185.199.111.153"])

  zone_id = local.zone_id
  name    = "gt3.dev"
  type    = "A"
  content = each.value
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "pages_www" {
  zone_id = local.zone_id
  name    = "www.gt3.dev"
  type    = "CNAME"
  content = "mhallo.github.io"
  proxied = true
  ttl     = 1
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "pages_challenge" {
  zone_id = local.zone_id
  name    = "_github-pages-challenge-mhallo.gt3.dev"
  type    = "TXT"
  content = "\"bd907adfb828ce49e73f3b8b2f9a0b\""
  ttl     = 1
}
