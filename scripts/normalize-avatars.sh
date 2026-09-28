#!/bin/sh
# Normalise the square member avatars: one resolution, one colour space.
#
# The people cards render every portrait into a 1:1 slot with object-fit: cover,
# yet the fifteen files behind them came in fifteen different sizes from 384x384
# to 4928x4928, tagged with a mix of profiles — sRGB, Display P3, Adobe RGB and
# Apple's "Color LCD". This crops each to a centred square, exactly the crop the
# browser was already applying, resamples it to 1024x1024, and converts it to
# sRGB so the row of faces renders the same on every display.
#
# Colour conversion is ICC-aware: an image carrying a profile is converted from
# it, while an untagged one is simply assigned sRGB, since that is what an
# untagged web image is already assumed to be.
#
# 1024 is well beyond what the layout needs: the card slot is about 168 CSS
# pixels, so 512 would already cover a 3x display. It is the project's chosen
# size, leaving headroom to reuse the avatars at larger sizes. Note that the
# eight sources smaller than 1024 are interpolated up, which adds bytes without
# adding detail.
#
# The set is read from people.html, so it follows the page. The PI page's own
# images under people/au/ are not cards and are left untouched.
#
# A file already at the target size is skipped rather than re-encoded, so
# re-running is safe and never degrades an avatar twice. That means changing the
# target size, or this script's colour handling, needs the originals restored
# from .backups/ first — otherwise the resized files are re-encoded a second
# time.
#
# Originals are copied into .backups/ (gitignored) before being replaced.
# Needs ImageMagick, perl and an sRGB ICC profile.
#
# The avatar list is split on whitespace, so an avatar path must not contain a
# space. None does, and the site's other paths avoid them as well.
#
# Usage: scripts/normalize-avatars.sh [--dry-run] [size]

set -e
cd "$(dirname "$0")/.."

dry_run=false
size=1024

for arg in "$@"; do
    case "$arg" in
    --dry-run) dry_run=true ;;
    [0-9]*) size=$arg ;;
    *)
        echo "usage: scripts/normalize-avatars.sh [--dry-run] [size]" >&2
        exit 1
        ;;
    esac
done

case "$size" in
*[!0-9]* | '')
    echo "size must be a number of pixels, got: $size" >&2
    exit 1
    ;;
esac

# An ICC-aware conversion needs an actual profile; ImageMagick ships none.
srgb_profile=""
for candidate in \
    "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
    "/Library/ColorSync/Profiles/sRGB Profile.icc" \
    "/usr/share/color/icc/sRGB.icc" \
    "/usr/share/color/icc/colord/sRGB.icc"; do
    if [ -f "$candidate" ]; then
        srgb_profile=$candidate
        break
    fi
done

if [ -z "$srgb_profile" ] && [ "$dry_run" = false ]; then
    echo "no sRGB ICC profile found; looked in the usual macOS and Linux paths" >&2
    exit 1
fi

backup_dir=".backups"
mkdir -p "$backup_dir"

avatars=$(perl -0777 -ne '
    while (/<div class="person">(.*?)(?=<div class="person">|<\/section>)/gs) {
        my $card = $1;
        while ($card =~ /<img src="([^"]+)"/g) { print "$1\n" }
    }' people.html | sort -u)

changed=0
skipped=0

for file in $avatars; do
    if [ ! -f "$file" ]; then
        echo "  $file — not found, skipped" >&2
        continue
    fi

    dims=$(magick identify -format '%wx%h' "$file" 2>/dev/null | head -1)
    if [ "$dims" = "${size}x${size}" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    echo "  $file — $dims -> ${size}x${size}"
    changed=$((changed + 1))
    [ "$dry_run" = true ] && continue

    cp "$file" "$backup_dir/$(printf '%s' "$file" | tr '/' '_').$(date +%Y%m%d-%H%M%S).avatar.bak"

    # -auto-orient bakes in any EXIF rotation first, then -profile converts
    # whatever profile the file carries into sRGB (or assigns it to an untagged
    # file) before the resample, so the pixels are already in the target space
    # when they are scaled. '^' fills the box and -extent takes the centred
    # square out of it: the crop object-fit: cover performs in the browser.
    magick "$file" -auto-orient -profile "$srgb_profile" \
        -resize "${size}x${size}^" -gravity center -extent "${size}x${size}" \
        -quality 85 "$file.avatar"
    mv "$file.avatar" "$file"
done

echo
if [ "$dry_run" = true ]; then
    echo "$changed avatar(s) would be resized to ${size}x${size} and converted to sRGB; $skipped already at target (dry run, nothing written)"
else
    echo "resized $changed avatar(s) to ${size}x${size} and converted to sRGB ($srgb_profile); $skipped already at target; originals in $backup_dir/"
fi
