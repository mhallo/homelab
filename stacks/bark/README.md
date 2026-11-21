# bark

[bark-server](https://github.com/Finb/bark-server), the push server for the
[Bark](https://github.com/Finb/Bark) iOS app, at `https://bark.gt3.dev`.
ps5-tracker sends its alerts here. The server sends them to Apple's push
service directly, using the Bark app's key that ships in the image, so they
don't go through ntfy.sh or Firebase. Based on upstream's
[docker-compose.yaml](https://github.com/Finb/bark-server/blob/master/deploy/docker-compose.yaml);
the header of `docker-compose.yml` lists where this stack differs from it.

| Service | What it is                    | Network |
|---------|-------------------------------|---------|
| `bark`  | push server, port 8080        | `proxy` |

The `bark_data` volume holds the registered devices (each device key and its
Apple push token).

## First deploy

1. The `portainer_stack.bark` in `terraform/portainer.tf`. Bitwarden fields:
   none.
2. `./tf apply`.
3. Check it: `curl -s https://bark.gt3.dev/healthz` should print `ok`.

## Registering the iPhone

1. Install **Bark** from the App Store and allow notifications, including
   **Critical Alerts** when it asks (or later in Settings → Notifications →
   Bark). Critical alerts sound through Focus and silent mode.
2. On the LAN or tailnet, open Bark → **Servers** → add
   `https://bark.gt3.dev`. The app registers and shows a URL like
   `https://bark.gt3.dev/<device key>/`.
3. Test it:

   ```
   curl -s "https://bark.gt3.dev/<device key>/Test/Hello?level=critical"
   ```

The phone only needs to reach the server for this step. Afterwards pushes go
from the NAS to Apple, so they arrive anywhere.

The device key is what lets something push to the phone. Treat it as a
secret: for ps5-tracker it's `TF_VAR_bark_key` on the `homelab-terraform`
Bitwarden note.

## Updating

Renovate opens a PR for new `finab/bark-server` releases. Merge it and
Portainer redeploys within 5 minutes.

## Backups

Nothing worth backing up. If the volume is lost, register the phone again;
it gets a new device key, so update `TF_VAR_bark_key` and `./tf apply`.

## Troubleshooting

- **The app can't add the server**: the phone isn't on the LAN or tailnet,
  or the container is down (`docker logs bark`).
- **`400 failed to get device token`** on a push: the device key isn't
  registered on this server (for example, it came from Bark's public server).
  Copy the key from this server's entry in the app.
- **Pushes arrive but don't sound through Focus**: allow Critical Alerts for
  Bark, or add Bark to the Focus's allowed apps.
- **Pushes show on the Mac instead of the iPhone**: turn off iPhone
  notification mirroring on the Mac.
