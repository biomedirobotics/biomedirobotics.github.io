#!/bin/sh
# Remove HDR from the site's images.
#
# An HDR photo — an iPhone "UltraHDR" capture, say — stores a second, brighter
# rendering as a gain map appended after the base JPEG, along with an
# HDRGainCurve describing how to combine them. Browsers that can display HDR use
# it and every other viewer ignores it, so a single such photo renders
# differently from the rest of a page. This drops the gain map and leaves plain
# SDR images.
#
# A JPEG gain map comes off losslessly. The base image occupies the first
# MPImageLength bytes of the file, so truncating there discards the gain map
# without touching a single base-image byte; only the metadata left dangling is
# then rewritten. The result is pixel-identical to the base image and smaller by
# roughly the size of the gain map. The ICC profile is kept as it was.
#
# Anything HDR by another route — a PQ or HLG transfer characteristic, an HDR
# PNG — falls back to an ImageMagick re-encode to sRGB, which is lossy. Nothing
# in this repo currently needs that path.
#
# Every original is copied into .backups/ (gitignored) before being replaced.
#
# Needs exiftool, plus ImageMagick for the re-encode path only.
#
# Usage: scripts/strip-hdr.sh [--dry-run]

set -e
cd "$(dirname "$0")/.."

dry_run=false
[ "$1" = "--dry-run" ] && dry_run=true

hdr_probe='$HDRGainCurveSize or $HDRGainMapVersion or ($TransferCharacteristics =~ /PQ|HLG/i) or ($ProfileDescription =~ /PQ|HLG|2084|2100/i)'
backup_dir=".backups"
mkdir -p "$backup_dir"

find_images() {
    find . -path ./.git -prune -o -path ./.backups -prune -o -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
        -o -iname '*.avif' -o -iname '*.heic' -o -iname '*.tif' -o -iname '*.tiff' \) -print
}

list=$(mktemp)
trap 'rm -f "$list"' EXIT

find_images | while IFS= read -r file; do
    exiftool -q -q -s3 -if "$hdr_probe" -p 'HDR' "$file" 2>/dev/null | grep -q HDR || continue
    printf '%s\n' "$file" >>"$list"
done

scanned=$(find_images | wc -l | tr -d ' ')
found=$(wc -l <"$list" | tr -d ' ')

if [ "$found" = 0 ]; then
    echo "scanned $scanned image(s): all SDR, nothing to strip"
    exit 0
fi

while IFS= read -r file; do
    how=""
    primary=$(exiftool -q -q -s3 -MPImage1:MPImageLength "$file" 2>/dev/null || true)
    case "$file" in
    *.jpg | *.jpeg) [ -n "$primary" ] && how="drop the gain map (lossless)" ;;
    esac
    [ -n "$how" ] || how="re-encode to sRGB (lossy)"
    echo "  $file — $how"
    [ "$dry_run" = true ] && continue

    cp "$file" "$backup_dir/$(printf '%s' "${file#./}" | tr '/' '_').$(date +%Y%m%d-%H%M%S).hdr.bak"

    if [ -n "$primary" ]; then
        head -c "$primary" "$file" >"$file.sdr"
        exiftool -q -q -MPF:all= -AROT:all= -XMP-hdrgm:all= -overwrite_original "$file.sdr"
    else
        magick "$file" -strip -colorspace sRGB -quality 95 "$file.sdr"
    fi
    mv "$file.sdr" "$file"
done <"$list"

echo
if [ "$dry_run" = true ]; then
    echo "scanned $scanned image(s); $found HDR (dry run, nothing written)"
else
    echo "scanned $scanned image(s); stripped $found HDR image(s), originals in $backup_dir/"
fi
