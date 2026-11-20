# ps5-tracker

PS5 Pro stock alerts, built from the private repo
[mhallo/ps5-tracker](https://github.com/mhallo/ps5-tracker). It checks PS
Direct, Walmart and Sam's Club, listens to the NowInStock PS5 Telegram
channel, and pushes in-stock and preorder alerts to ntfy with add-to-cart
links. That repo's README covers how it works.

| Service   | What it is                         | Network |
|-----------|------------------------------------|---------|
| `tracker` | the tracker; outbound requests only | default |

The Telegram login lives in the `ps5-tracker_data` volume as
`tg-session.json`. The image is private, so Portainer pulls it with the
`ghcr` registry credential in `terraform/portainer.tf`.

## First deploy

1. Create a classic GitHub token with only `read:packages`: GitHub →
   Settings → Developer settings → Personal access tokens → Tokens (classic).
2. Add these fields to the `homelab-terraform` Bitwarden note:
   - `TF_VAR_ghcr_token`: the token from step 1
   - `TF_VAR_ntfy_topic`: the ntfy topic your phone subscribes to
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
   show `watching 4 listings` and
   `telegram: listening to "NowInStock.net PlayStation 5 Alerts"`.
6. Send a test push to your phone:

   ```
   docker exec ps5-tracker /ps5-tracker -test-notify
   ```

## Updating

Tag a release in the ps5-tracker repo (`git tag v0.1.3 && git push origin
v0.1.3`). GitHub Actions publishes the image to GHCR. Then change the tag and
digest in `docker-compose.yml`; the build log prints the digest as
`containerimage.digest`. Portainer redeploys within 5 minutes of the merge.

Renovate can't see the private image, so this is done by hand.

## Rotating secrets

Change the field on the Bitwarden note, bump `env_wo_version` on the stack
(or `password_wo_version` on the registry, for the token), and `./tf apply`.

## Backups

There's nothing worth backing up. If the volume is lost, log in again with
`-tg-login`. Don't add the volume to backrest: `tg-session.json` gives full
access to the Telegram account.

## Troubleshooting

- **`pull access denied` or `denied` on deploy**: the `ghcr` registry token
  is missing `read:packages`, or has expired.
- **`not logged in` in the log**: no session in the volume. Run step 3, or
  `docker exec -it ps5-tracker /ps5-tracker -tg-login`.
- **`AUTH_KEY_DUPLICATED`, or the session stops working**: another copy used
  the same session at the same time. Stop the other copy, then log in again.
- **No pushes**: check the topic with `-test-notify`. On iOS, turn on Time
  Sensitive Notifications for ntfy so alerts get through Focus.
