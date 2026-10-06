#!/usr/bin/env bash
# Creates a self-signed "All Set Development" code-signing certificate in the
# login keychain, once. Signing every build with the same certificate lets
# macOS remember privacy permissions (like Accessibility) across rebuilds;
# ad-hoc signatures change every build, so macOS would forget them.
#
# This certificate is only for this Mac. Distributing the app needs an Apple
# Developer ID certificate instead.
set -euo pipefail

NAME="All Set Development"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "\"$NAME\" is already set up."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.conf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# macOS's LibreSSL writes PKCS#12 files that `security import` accepts.
/usr/bin/openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$WORK/cert.conf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" -passout pass:allset -out "$WORK/identity.p12" 2>/dev/null

# -T lets codesign use the key without asking each time.
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P allset -T /usr/bin/codesign >/dev/null
echo "Created \"$NAME\" in the login keychain."
