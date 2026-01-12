#!/usr/bin/env bash
set -euo pipefail

echo "Setting up AI Dev Atelier development environment..."

cleanup() {
  if [ -n "${SHASUMS_FILE:-}" ]; then
    rm -f "$SHASUMS_FILE"
  fi
  rm -f /tmp/shfmt
}
trap cleanup EXIT ERR

if ! command -v shfmt &> /dev/null; then
  echo "Installing shfmt..."
  SHFMT_VERSION="v3.8.0"
  
  # Detect OS for correct binary
  OS="$(uname -s)"
  case "$OS" in
    Darwin)
      SHFMT_ARCH="darwin_amd64"
      ;;
    Linux)
      SHFMT_ARCH="linux_amd64"
      ;;
    *)
      echo "⚠️  Unsupported OS: $OS" >&2
      exit 1
      ;;
  esac
  
  SHFMT_URL="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_ARCH}"
  
  # Download and verify checksum
  echo "Downloading checksums..."
  SHASUMS_FILE=$(mktemp)
  curl -fsSL "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/sha256sums.txt" -o "$SHASUMS_FILE"
  
  echo "Downloading $SHFMT_URL..."
  curl -fsSL "$SHFMT_URL" -o /tmp/shfmt
  
  # Verify checksum
  EXPECTED_CHECKSUM=$(grep "shfmt_${SHFMT_ARCH}$" "$SHASUMS_FILE" | awk '{print $1}')
  
  # Use OS-specific checksum command
  case "$OS" in
    Darwin)
      ACTUAL_CHECKSUM=$(shasum -a 256 /tmp/shfmt | awk '{print $1}')
      ;;
    Linux)
      ACTUAL_CHECKSUM=$(sha256sum /tmp/shfmt | awk '{print $1}')
      ;;
  esac
  
  echo "Expected checksum: $EXPECTED_CHECKSUM"
  echo "Actual checksum:   $ACTUAL_CHECKSUM"
  
  if [ "$ACTUAL_CHECKSUM" = "$EXPECTED_CHECKSUM" ]; then
    echo "✅ Checksum verified"
    chmod +x /tmp/shfmt
    sudo mv /tmp/shfmt /usr/local/bin/shfmt
    rm -f "$SHASUMS_FILE"
  else
    echo "❌ Checksum mismatch! Aborting installation."
    rm -f "$SHASUMS_FILE"
    rm -f /tmp/shfmt
    exit 1
  fi
fi

if command -v pip3 &> /dev/null; then
  echo "Installing pre-commit..."
  pip3 install --user pre-commit
fi

if command -v pre-commit &> /dev/null; then
  echo "Installing pre-commit hooks..."
  pre-commit install
fi

echo ""
echo "Environment ready!"
echo "Run 'make test' to validate all skills and lint shell scripts."
