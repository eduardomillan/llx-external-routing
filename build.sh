#!/usr/bin/env bash
# =============================================================================
# build.sh
# Builds the .deb package. Output goes to build/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load version
source "$SCRIPT_DIR/conf/version.conf"

BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$BUILD_DIR/output"

echo "=== Building $PACKAGE v${VERSION}-${RELEASE} ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# Generate debian/changelog from version.conf
cat > "$SCRIPT_DIR/debian/changelog" << EOF
${PACKAGE} (${VERSION}-${RELEASE}) unstable; urgency=medium

  * See CHANGELOG.md for details.

 -- Eduardo Millan <eduardo.millan@gmail.com>  $(date -R)
EOF

# Build
cd "$SCRIPT_DIR"
dpkg-buildpackage -us -uc -b 2>&1

# Move .deb to build/output
mv "$SCRIPT_DIR"/../${PACKAGE}_${VERSION}-${RELEASE}_*.deb "$OUTPUT_DIR/" 2>/dev/null || true
mv "$SCRIPT_DIR"/../${PACKAGE}_${VERSION}-${RELEASE}_*.buildinfo "$OUTPUT_DIR/" 2>/dev/null || true
mv "$SCRIPT_DIR"/../${PACKAGE}_${VERSION}-${RELEASE}_*.changes "$OUTPUT_DIR/" 2>/dev/null || true

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"
