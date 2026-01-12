#!/bin/bash
set -euo pipefail

# Usage: REPO_NAME=owner/repo VERSION=1.0.0 bash generate-release-notes.sh
# Or: bash generate-release-notes.sh [version]

VERSION="${VERSION:-${1:-1.0.0}}"
REPO_NAME="${REPO_NAME:-${GITHUB_REPOSITORY:-LukasStrickler/ai-dev-atelier}}"

cat > release-body.md <<EOF
## Installation

\`\`\`bash
# Clone and install
git clone https://github.com/${REPO_NAME}.git ~/ai-dev-atelier
cd ~/ai-dev-atelier && git checkout v${VERSION}
bash install.sh
\`\`\`

Or update an existing installation:

\`\`\`bash
cd ~/ai-dev-atelier
git fetch --tags && git checkout v${VERSION}
bash install.sh
\`\`\`
EOF

echo "Generated release-body.md for ${REPO_NAME} v${VERSION}"
