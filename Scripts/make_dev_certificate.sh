#!/usr/bin/env bash
# Creates a self-signed code signing identity in the login keychain so that
# rebuilt bundles keep the same designated requirement. With ad-hoc signing
# every build has a new cdhash and macOS forgets Accessibility and Input
# Monitoring grants. macOS asks for your password once when trusting the
# certificate. This is a local development identity, not a Developer ID.
set -euo pipefail

NAME="${1:-NagaController Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$NAME\""; then
  printf 'Identity "%s" already exists.\n' "$NAME"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/openssl.cnf" >/dev/null 2>&1
openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout pass:nagacontroller >/dev/null 2>&1 \
  || openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout pass:nagacontroller

KEYCHAIN="$(security default-keychain -d user | tr -d ' "')"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P nagacontroller -T /usr/bin/codesign >/dev/null
printf 'Trusting "%s" for code signing (macOS may ask for your password)...\n' "$NAME"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"
security find-identity -v -p codesigning | grep -F "\"$NAME\""
printf 'Done. Scripts/build_app.sh will use this identity automatically.\n'
