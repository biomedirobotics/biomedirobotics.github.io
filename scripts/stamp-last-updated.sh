#!/bin/sh
# Refresh the footer's "Last updated" date on every page at once.
#
# The pages share one literal date rather than fetching it, because a browser
# cannot read the commit date of a private repository: the unauthenticated
# GitHub API answers 404 for one. If this site is ever published from a public
# repo, drop this script and read the date at load instead, from
#   https://api.github.com/repos/<owner>/<repo>/commits?per_page=1
# writing commit.committer.date into the very same <span> this script targets.
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
