#!/usr/bin/env bash
# publish.sh <pr-number> <artifacts-dir> <commit-sha>
#
# Run by e2e.yml after e2e.sh. Puts the run's proof where people look:
#   - the draft release pr-<number>: video.mp4, report.xml, screenshots.zip,
#     and a summary as its notes (release.yml publishes it on merge);
#   - a comment on the PR with the same summary and a link.
# Needs gh, authenticated with contents and pull-requests write.
set -euo pipefail

pr="${1:?pr number}"
out="${2:?artifacts dir}"
sha="${3:?commit sha}"
repo="${GITHUB_REPOSITORY:?}"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/${GITHUB_RUN_ID:-}"

status="$(cat "$out/exit-code" 2> /dev/null || echo 1)"
verdict=$([ "$status" = 0 ] && echo "passed" || echo "failed")

rows=""
passed=0
failed=0
if [ -f "$out/report.xml" ]; then
  while IFS='|' read -r name result; do
    [ -z "$name" ] && continue
    if [ "$result" = ok ]; then passed=$((passed + 1)); icon="✅"; else failed=$((failed + 1)); icon="❌"; fi
    rows+="| $icon | $name |"$'\n'
  done < <(python3 - "$out/report.xml" << 'PY'
import sys, xml.etree.ElementTree as ET
for case in ET.parse(sys.argv[1]).iter("testcase"):
    bad = case.find("failure") is not None or case.find("error") is not None
    print(f"{case.get('name')}|{'fail' if bad else 'ok'}")
PY
  )
fi

summary="$out/summary.md"
{
  echo "### E2E: $verdict"
  echo
  echo "Maestro on Flutter web, against this PR's own backend and agent, at \`${sha:0:7}\`: $passed passed, $failed failed."
  echo
  if [ -n "$rows" ]; then
    echo "| | Flow |"
    echo "|---|---|"
    printf '%s' "$rows"
    echo
  fi
  echo "Run: $run_url"
} > "$summary"

assets=()
[ -f "$out/report.xml" ] && assets+=("$out/report.xml")
if find "$out" -name '*.png' | grep -q .; then
  (cd "$out" && find . -name '*.png' -print | zip -q screenshots.zip -@)
  assets+=("$out/screenshots.zip")
fi
[ -s "$out/video.mp4" ] && assets+=("$out/video.mp4")

tag="pr-$pr"
title="PR #$pr: $(gh pr view "$pr" --repo "$repo" --json title -q .title)"
if gh release view "$tag" --repo "$repo" > /dev/null 2>&1; then
  gh release edit "$tag" --repo "$repo" --draft --title "$title" --notes-file "$summary" > /dev/null
  [ ${#assets[@]} -gt 0 ] && gh release upload "$tag" --repo "$repo" --clobber "${assets[@]}"
else
  gh release create "$tag" --repo "$repo" --draft --target "$sha" \
    --title "$title" --notes-file "$summary" ${assets[@]+"${assets[@]}"} > /dev/null
fi
release_url="$(gh release view "$tag" --repo "$repo" --json url -q .url)"

gh pr comment "$pr" --repo "$repo" --body "$(cat "$summary")
Video and screenshots: $release_url" > /dev/null
echo "Published to $release_url"
