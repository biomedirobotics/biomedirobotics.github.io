#!/bin/sh
# Refresh the fallback "Last updated" date on every page at once.
#
# The date a reader sees now comes from js/last-updated.js, which reads
# the newest commit from the GitHub API now that the site is published from a
# public repository. Each page also carries a literal date for the visits where
# that fetch cannot run — no JavaScript, no network, or the 60 requests an hour
# the unauthenticated API allows an address — and this script is what moves
# those literals forward. Running it is optional housekeeping rather than part
# of publishing.
#
# Only the contents of <span data-last-updated> are touched, so hand edits
# elsewhere in these files are safe.
#
# Usage: scripts/stamp-last-updated.sh [YYYY-MM-DD]      (default: today)

set -e
cd "$(dirname "$0")/.."

date="${1:-$(date +%Y-%m-%d)}"
case "$date" in
[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
*)
    echo "expected YYYY-MM-DD, got: $date" >&2
    exit 1
    ;;
esac

for file in ./*.html; do
    perl -pi -e "s|<span data-last-updated>[^<]*</span>|<span data-last-updated>$date</span>|g" "$file"
done

echo "stamped $date:"
grep -h -o '<span data-last-updated>[^<]*</span>' ./*.html | sort | uniq -c
