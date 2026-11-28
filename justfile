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
