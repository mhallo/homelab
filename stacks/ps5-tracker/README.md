# ps5-tracker

Stock alerts, built from the private repo
[mhallo/ps5-tracker](https://github.com/mhallo/ps5-tracker). It listens to
Telegram stock channels, checks store pages, and pushes alerts with
add-to-cart links to the iPhone through the `bark` stack. That repo's README
covers how it works and every config option. Its status server is at `https://ps5-tracker.gt3.dev`.

| Service   | What it is                                      | Network          |
|-----------|-------------------------------------------------|------------------|
| `tracker` | the tracker, plus its status server on port 8080 | default, `proxy` |

The `ps5-tracker_data` volume holds the Telegram login (`tg-session.json`)
and, optionally, `config.yml`. Without `config.yml` it runs the image's
built-in config, which watches the PS5 Pro. The image is private, so Portainer pulls it with the
`ghcr` registry credential in `terraform/portainer.tf`.

## First deploy

1. Create a classic GitHub token with only `read:packages`: GitHub →
   Settings → Developer settings → Personal access tokens → Tokens (classic).
2. Add these fields to the `homelab-terraform` Bitwarden note:
   - `TF_VAR_ghcr_token`: the token from step 1
   - `TF_VAR_bark_key`: the Bark device key, from registering the phone with
     the bark stack (`stacks/bark/README.md`)
   - `TF_VAR_tg_app_id`, `TF_VAR_tg_app_hash`: from https://my.telegram.org,
     under API development tools
3. Seed the Telegram login into the volume, so the tracker can start
   without a terminal. From the Mac that already has a session, stop its
   copy first (two copies sharing a session can get it revoked), then:

   ```
   launchctl bootout gui/$(id -u)/com.ps5-tracker
   scp ~/git/ps5-tracker/tg-session.json <user>@10.10.2.10:/tmp/
   ```

   On the NAS:

   ```
   docker run --rm -v ps5-tracker_data:/data -v /tmp/tg-session.json:/seed:ro busybox \
     sh -c 'cp /seed /data/tg-session.json && chown -R 65532:65532 /data && chmod 600 /data/tg-session.json'
   rm /tmp/tg-session.json
   ```

   With no existing session, skip this step and log in after step 4:
   `docker exec -it ps5-tracker /ps5-tracker -tg-login`. Until then the log
   shows `not logged in` every minute.
4. `./tf apply`. This creates the `ghcr` registry and the stack.
5. Check the log in Dozzle, or with `docker logs ps5-tracker`. It should
   show `config: …`, `status server on :8080` and
   `telegram: listening to "NowInStock.net PlayStation 5 Alerts"`.
6. Open `https://ps5-tracker.gt3.dev/ping`. Your phone should get a
   **Pong!** push with the same summary the page shows.

## Status

From any device on the LAN or tailnet, in a browser or with `curl`:

| URL | |
|---|---|
| `https://ps5-tracker.gt3.dev/ping` | Push **Pong!** to the phone with the config and each source's last activity, and show it. Once per 10s. |
| `https://ps5-tracker.gt3.dev/status` | The same summary, no push. |
| `https://ps5-tracker.gt3.dev/healthz` | `ok`. The container healthcheck uses it too. |

There's no login on these. They're only reachable on the LAN and tailnet,
and the summary leaves out the Bark key and other secrets.

## Changing what it watches

Write a `config.yml` (start from `config.example.yml` in the ps5-tracker
repo) and check it on the Mac:

```
cd ~/git/ps5-tracker && go run . -config config.yml -check-config
```

Then copy it into the volume, from the Mac:

```
ssh -t <user>@10.10.2.10 "echo $(base64 < config.yml) | base64 -d | sudo docker run --rm -i -v ps5-tracker_data:/data busybox sh -c 'cat > /data/config.yml && chown 65532:65532 /data/config.yml'"
```

No restart needed: the tracker applies the new file within 3 seconds, and
only the parts that changed start or stop. A file that doesn't parse is
rejected and the running config stays; `/status` shows why. New Telegram
channels need joining in the Telegram app first; the existing login covers
them.

### Versions and revert

Every applied config is kept as a numbered version in
`/data/config-versions/` (the last 50). On the NAS:

```
sudo docker exec ps5-tracker /ps5-tracker -versions
sudo docker exec ps5-tracker /ps5-tracker -revert previous   # or a number: -revert 12
```

A revert applies within 3 seconds as a new version, so it can be undone the
same way. To go back to the image's built-in config, delete
`/data/config.yml`; that's applied as a new version too.

## Updating

Tag a release in the ps5-tracker repo (`git tag v0.1.3 && git push origin
v0.1.3`). GitHub Actions publishes the image to GHCR. Then change the tag and
digest in `docker-compose.yml`; the build log prints the digest as
`containerimage.digest`. Portainer redeploys within 5 minutes of the merge.

Renovate can't see the private image, so this is done by hand.

## Pausing

`scale: 0` on the `tracker` service stops it: after the merge, Portainer's
next redeploy removes the container, and `/ping` stops answering. Delete the
line to resume. The Telegram login and config stay in the `data` volume, so
it picks up where it left off. Leave the bark stack running either way.

## Rotating secrets

Change the field on the Bitwarden note, bump `env_wo_version` on the stack
(or `password_wo_version` on the registry, for the token), and `./tf apply`.

## Backups

Keep `config.yml` in your own copy; otherwise there's nothing worth backing
up. If the volume is lost, log in again with `-tg-login`. Don't add the volume to backrest: `tg-session.json` gives full
access to the Telegram account.

## Troubleshooting

- **`pull access denied` or `denied` on deploy**: the `ghcr` registry token
  is missing `read:packages`, or has expired.
- **`not logged in` in the log**: no session in the volume. Run step 3, or
  `docker exec -it ps5-tracker /ps5-tracker -tg-login`.
- **`AUTH_KEY_DUPLICATED`, or the session stops working**: another copy used
  the same session at the same time. Stop the other copy, then log in again.
- **404 from Traefik on ps5-tracker.gt3.dev**: the container isn't on
  `proxy`, or it's restart-looping (check its log). A bad `config.yml` only
  stops it at start; while it's running, a bad edit is rejected instead.
- **No pushes**: try `/ping`, then check the `bark` container's log for the
  `POST /push`. A `400 failed to get device token` means `TF_VAR_bark_key`
  isn't the key from the `bark.gt3.dev` entry in the app; see
  `stacks/bark/README.md`. Pushes showing on the Mac instead of the iPhone
  mean iPhone notification mirroring is on.
