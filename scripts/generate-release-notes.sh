#!/bin/bash
set -euo pipefail

# Usage: VERSION=1.0.0 bash generate-release-notes.sh
# Or: bash generate-release-notes.sh <version>

VERSION="${VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  echo "Error: VERSION is required. Set VERSION env var or pass as argument." >&2
  exit 1
fi
REPO_NAME="${REPO_NAME:-${GITHUB_REPOSITORY:-LukasStrickler/ai-dev-atelier}}"
REPO_BASENAME="${REPO_NAME##*/}"

cat > release-body.md <<EOF
## Installation

\`\`\`bash
# Clone and install
git clone https://github.com/${REPO_NAME}.git ~/${REPO_BASENAME}
cd ~/${REPO_BASENAME} && git checkout v${VERSION}
bash install.sh
\`\`\`

Or update an existing installation:

\`\`\`bash
cd ~/${REPO_BASENAME}
git fetch --tags && git checkout v${VERSION}
bash install.sh
\`\`\`
EOF

echo "Generated release-body.md for ${REPO_NAME} v${VERSION}"
