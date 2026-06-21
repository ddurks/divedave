#!/usr/bin/env bash
#
# Manual fallback deploy for the divedave web app.
# Mirrors .github/workflows/deploy.yml.
#
# Prereqs: AWS CLI v2 installed and configured with credentials that have
#   s3:PutObject / s3:DeleteObject / s3:ListBucket on the bucket below and
#   cloudfront:CreateInvalidation on the distribution below.
#
# Usage: ./deploy.sh   (run from anywhere; paths are resolved relative to this script)
set -euo pipefail

BUCKET="divedave.drawvid.com"
DISTRIBUTION_ID="E19FEOYHE02U7G"
REGION="us-east-1"

# Source = the divedave-web directory next to this script; its CONTENTS land at
# the bucket root (so index.html, src/, assets/ are served from the site root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/divedave-web"

echo "Syncing assets (long cache) from $SRC ..."
aws s3 sync "$SRC" "s3://$BUCKET" \
  --region "$REGION" \
  --delete \
  --exclude "*.html" \
  --exclude "node_modules/*" \
  --exclude ".git/*" \
  --exclude ".DS_Store" \
  --cache-control "public, max-age=31536000, immutable"

echo "Syncing HTML (short cache) from $SRC ..."
aws s3 sync "$SRC" "s3://$BUCKET" \
  --region "$REGION" \
  --exclude "*" \
  --include "*.html" \
  --cache-control "public, max-age=3600"

echo "Invalidating CloudFront distribution $DISTRIBUTION_ID ..."
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*"

echo "Done."
