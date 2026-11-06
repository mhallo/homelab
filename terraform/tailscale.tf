# Tailnet policy and the NAS's subnet router.

resource "tailscale_acl" "this" {
  acl = file("${path.module}/tailscale/policy.hujson")
}

data "tailscale_device" "nas" {
  hostname = "tailscale-nginx"
}

# Approves the route the tailscale stack advertises (TS_ROUTES), which puts the
# NAS's VLAN on the tailnet. This replaces the manual approval step.
resource "tailscale_device_subnet_routes" "nas" {
  device_id = data.tailscale_device.nas.node_id
  routes    = ["10.10.2.0/24"]
}

# A server shouldn't drop off the tailnet when its node key expires.
resource "tailscale_device_key" "nas" {
  device_id           = data.tailscale_device.nas.node_id
  key_expiry_disabled = true
}
