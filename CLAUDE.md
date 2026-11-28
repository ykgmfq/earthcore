# Conventions

- **The image is public.** Hostnames, domains, addresses, keys and other host-specific values or secrets never go into it; they stay in the ansible repo's personal inventory.
- **What every host shares goes here; what differs per host or changes at runtime stays in Ansible.** Moving something into the image means removing it from the role in the same change.
- **Prefer vendor locations (`/usr`) over `/etc`** for shipped config where the tool reads both, so local edits on a host stay distinguishable from image defaults.
- **Always use `just` commands** instead of invoking tools directly.
- **Before reporting done**, run the `docs-curator` agent (if the task touched config or prose), then `just lint`.
