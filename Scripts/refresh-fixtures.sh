#!/usr/bin/env bash
#
# Re-downloads the three pages the app scrapes into CMCTests/Fixtures/.
#
# When the tests then fail, the site changed — that diff *is* the alert, and the
# failing test names the selector that died. Fix Services/Selectors.swift, then
# note the change in PLAN.md §2.
#
# Usage:  Scripts/refresh-fixtures.sh
#         git diff --stat CMCTests/Fixtures    # see what moved
set -euo pipefail

BASE="https://marista-carcavelos.globaleduca.com"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/CMCTests/Fixtures"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

mkdir -p "$DIR"

fetch() {
  local url="$1" out="$2"
  echo "→ $url"
  curl -fsS -A "$UA" --compressed "$url" -o "$DIR/$out"
  # robots.txt sets no Crawl-delay, but be polite anyway.
  sleep 1
}

fetch "$BASE/"                                 homepage.html
fetch "$BASE/calendario-geral/"                calendario.html
fetch "$BASE/oferecemos/refeitorio-ementas/"   ementas.html
fetch "$BASE/wp-json/wp/v2/ultima_hora?orderby=date&order=desc&per_page=20&_fields=id,date,title" ultima_hora.json

echo
echo "Done. Now run the tests:"
echo "  xcodebuild test -project CMC.xcodeproj -scheme CMC -destination 'platform=iOS Simulator,name=iPhone 15'"
