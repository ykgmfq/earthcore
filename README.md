# earthcore

Dig deep. A custom uCore image for whatever lives below your stack.

earthcore is a [BlueBuild](https://blue-build.org) image derived from [uCore](https://github.com/ublue-os/ucore).
It carries what every one of my servers has in common, so a fresh host already has it after its first reboot.
Configuration that differs per host, depends on secrets or changes at runtime stays with Ansible in the [ansible](https://github.com/ykgmfq/ansible) repo.

GitHub Actions builds the image every night on top of the latest uCore, signs it with cosign and publishes it to `ghcr.io/ykgmfq/earthcore`.

## Setup

The signing key is created once with `just cosign`, which needs a logged-in `gh`.
It commits nothing; commit the resulting `cosign.pub`.
Hosts that trust a key cannot verify images signed with a new one, so the key is never rotated casually.

## Rebasing a host

A host on uCore first moves to the unverified image, because it does not trust the signing key yet:

```sh
rpm-ostree rebase ostree-unverified-registry:ghcr.io/ykgmfq/earthcore:latest
systemctl reboot
```

The image ships the key and the matching policy, so after the reboot the host can switch to the verified image:

```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ykgmfq/earthcore:latest
systemctl reboot
```

## Local work

`just -l` lists the recipes.
They run the BlueBuild CLI and cosign from their container images, so only `podman` and `just` are needed.
