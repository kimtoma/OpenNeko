#!/usr/bin/env bash
# Show public release download counts plus authenticated GitHub traffic stats.
#
# Requirements:
#   gh auth login
set -euo pipefail

REPO="${OPENNEKO_REPO:-kimtoma/openNeko}"

echo "openNeko metrics"
echo "repo: https://github.com/$REPO"
echo

echo "Release downloads"
gh release view --repo "$REPO" --json tagName,name,assets \
  --jq '
    "release: \(.name) (\(.tagName))",
    (.assets[] | "  \(.name): \(.downloadCount) downloads")
  '

echo
echo "Repository traffic (last 14 days, GitHub authenticated API)"
echo "Views:"
gh api "repos/$REPO/traffic/views" --jq '
  "  total: \(.count), uniques: \(.uniques)",
  (.views[] | "  \(.timestamp): \(.count) views / \(.uniques) uniques")
' || echo "  unavailable: requires repo admin/push access"

echo
echo "Clones:"
gh api "repos/$REPO/traffic/clones" --jq '
  "  total: \(.count), uniques: \(.uniques)",
  (.clones[] | "  \(.timestamp): \(.count) clones / \(.uniques) uniques")
' || echo "  unavailable: requires repo admin/push access"

echo
echo "Referrers:"
gh api "repos/$REPO/traffic/popular/referrers" --jq '
  if length == 0 then "  none yet" else .[] | "  \(.referrer): \(.count) / \(.uniques) uniques" end
' || echo "  unavailable: requires repo admin/push access"
