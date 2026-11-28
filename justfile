RECIPE := "recipes/recipe.yml"
BLUEBUILD := "podman run --rm --volume=.:/bluebuild:Z --workdir=/bluebuild ghcr.io/blue-build/cli:latest bluebuild"
COSIGN := "podman run --rm --user=0 --volume=.:/work:Z --workdir=/work --env=COSIGN_PASSWORD cgr.dev/chainguard/cosign"

# Check the recipe against the BlueBuild schema
validate:
    {{BLUEBUILD}} validate {{RECIPE}}

# Write the Containerfile the recipe expands to, for inspection; without the signing module, which needs keys
generate: validate
    grep -v 'type: signing' {{RECIPE}} > recipes/.local.yml
    {{BLUEBUILD}} generate --output=Containerfile recipes/.local.yml
    rm recipes/.local.yml

# Build the image locally from the generated Containerfile
build: generate
    podman build --tag=localhost/earthcore:latest --file=Containerfile .

# Lint everything pre-commit covers
lint:
    pre-commit run --all-files

# Rotating the key locks out hosts that already trust the old one.
# One-time: create the signing key pair, store the private key as the repo secret, keep only the public key
cosign:
    test ! -e cosign.pub || { echo "cosign.pub exists" >&2; exit 1; }
    COSIGN_PASSWORD= {{COSIGN}} generate-key-pair
    gh secret set SIGNING_SECRET < cosign.key
    rm cosign.key

IMAGE := "ghcr.io/ykgmfq/earthcore:latest"

# Needs root. Turn the published image into a qcow2 in output/, with the local ssh key on user core
disk:
    mkdir -p output
    printf '[[customizations.user]]\nname = "core"\nkey = "%s"\ngroups = ["wheel"]\n' "$(cat ~/.ssh/id_ed25519.pub)" > output/config.toml
    sudo sh -euc 'podman pull {{IMAGE}}; \
        podman run --rm --privileged --security-opt label=type:unconfined_t \
            --volume=./output:/output --volume=/var/lib/containers/storage:/var/lib/containers/storage \
            --volume=./output/config.toml:/config.toml:ro \
            quay.io/centos-bootc/bootc-image-builder:latest --type qcow2 --rootfs xfs --local {{IMAGE}}; \
        chown -R "$SUDO_USER": output'
    # bootc-image-builder leaves the user's home unlabelled, so sshd cannot read authorized_keys
    H=system_u:object_r:user_home_dir_t:s0; S=system_u:object_r:ssh_home_t:s0; R=/ostree/deploy/fedora-coreos/var/home/core; \
    printf 'setxattr security.selinux %s %s %s\n' "$H" $((${#H}+1)) "$R" "$S" $((${#S}+1)) "$R/.ssh" "$S" $((${#S}+1)) "$R/.ssh/authorized_keys" \
        | LIBGUESTFS_BACKEND=direct guestfish -a output/qcow2/disk.qcow2 -m /dev/sda4

# Boot a copy of the disk image as a user-session libvirt VM; the copy lives outside the repo, whose container labels qemu cannot read
vm:
    mkdir -p ~/.local/share/libvirt/images
    cp --reflink=auto output/qcow2/disk.qcow2 ~/.local/share/libvirt/images/earthcore-test.qcow2
    restorecon ~/.local/share/libvirt/images/earthcore-test.qcow2
    virt-install --connect qemu:///session --name earthcore-test --memory 4096 --vcpus 2 \
        --import --disk ~/.local/share/libvirt/images/earthcore-test.qcow2 --os-variant fedora-coreos-stable \
        --network passt,portForward=2222:22 --graphics none --noautoconsole

# Remove the test VM and its disk copy
vm-clean:
    -virsh --connect qemu:///session destroy earthcore-test
    virsh --connect qemu:///session undefine earthcore-test --nvram
    rm -f ~/.local/share/libvirt/images/earthcore-test.qcow2
