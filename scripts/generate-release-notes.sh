#!/bin/bash
# Generate clean release notes markdown file

set -euo pipefail

REPO_NAME="${GITHUB_REPOSITORY:-LukasStrickler/ai-dev-atelier}"
VERSION="${1:-1.0.0}"

cat > release-body.md <<EOFMARKER
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
EOFMARKER

echo "✅ Generated release-body.md"
cat release-body.md
EOFMARKER
