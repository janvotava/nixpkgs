#!/usr/bin/env nix-shell
#!nix-shell -I nixpkgs=./. -i bash -p curl gnused nix

set -euo pipefail

ATTR="timoni"
FILE="$(dirname "${BASH_SOURCE[@]}")/default.nix"

PREV_VERSION=$(nix eval --raw -f default.nix $ATTR.version)
LATEST_TAG=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} --silent https://api.github.com/repos/stefanprodan/timoni/releases/latest | jq -r '.tag_name')
NEXT_VERSION=$(echo ${LATEST_TAG} | sed 's/^v//')

if [ "$PREV_VERSION" = "$NEXT_VERSION" ]; then
  echo "$ATTR is already up-to-date"
  exit 0
fi

# update version
sed -i "s|$PREV_VERSION|$NEXT_VERSION|" "$FILE"

# update hash
PREV_HASH=$(nix eval --raw -f default.nix $ATTR.src.outputHash)
NEXT_HASH=$(nix hash to-sri --type sha256 $(nix-prefetch-url --unpack --type sha256 $(nix eval --raw -f default.nix $ATTR.src.url)))
sed -i "s|$PREV_HASH|$NEXT_HASH|" "$FILE"

# update vendor hash
PREV_VENDOR_HASH=$(nix eval --raw -f default.nix $ATTR.vendorHash)
EMPTY_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i "s|$PREV_VENDOR_HASH|$EMPTY_HASH|" "$FILE"

set +e
NEXT_VENDOR_HASH=$(nix-build --no-out-link -A $ATTR 2>&1 | grep "got:" | cut -d':' -f2 | sed 's| ||g')
set -e

if [ -z "${NEXT_VENDOR_HASH:-}" ]; then
    echo "Update failed. NEXT_VENDOR_HASH is empty." >&2
    exit 1
fi

sed -i "s|$EMPTY_HASH|$NEXT_VENDOR_HASH|" "$FILE"

cat <<EOF
[{
    "attrPath": "$ATTR",
    "oldVersion": "$PREV_VERSION",
    "newVersion": "$NEXT_VERSION",
    "files": ["$PWD/default.nix.nix"]
}]
EOF
