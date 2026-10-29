#!/bin/sh
set -eu

EXIFTOOL_SHA256="${EXIFTOOL_SHA256:-}"
EXIFTOOL_VERSION="${EXIFTOOL_VERSION:-13.60}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"

export PATH="$NATIVE_DIR/prefix/bin:$PATH"
PERL="$NATIVE_DIR/prefix/bin/perl"

if ! printf '%s\n' "$EXIFTOOL_VERSION" | grep -Eq '^[0-9]+\.[0-9]+$'; then
    echo "EXIFTOOL_VERSION must name an explicit numeric release" >&2
    exit 1
fi
if [ "${#EXIFTOOL_SHA256}" -ne 64 ]; then
    echo "EXIFTOOL_SHA256 must be the release's published SHA-256 digest" >&2
    exit 1
fi
case "$EXIFTOOL_SHA256" in
    *[!0-9a-f]*)
        echo "EXIFTOOL_SHA256 must contain lowercase hexadecimal digits" >&2
        exit 1
        ;;
esac

ARCHIVE="/build/Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz"
curl --fail --location --retry 3 --connect-timeout 30 --max-time 300 \
    "https://sourceforge.net/projects/exiftool/files/Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz" \
    --output "$ARCHIVE"
printf '%s  %s\n' "$EXIFTOOL_SHA256" "$ARCHIVE" | sha256sum --check --strict
tar -xzf "$ARCHIVE" -C /build
cd "/build/Image-ExifTool-${EXIFTOOL_VERSION}"
test "$("$PERL" exiftool -ver)" = "$EXIFTOOL_VERSION"
test "$("$PERL" -Ilib -MImage::ExifTool -e 'print $Image::ExifTool::VERSION')" = "$EXIFTOOL_VERSION"
"$PERL" Makefile.PL
make
make test
make install PREFIX="$NATIVE_DIR/prefix"

cd "$REPO_DIR"
sed -i "/\$SIG{INT}\\s*=\\s*'SigInt';/d" "$NATIVE_DIR/prefix/bin/exiftool"
sed -i "/\$SIG{CONT}\\s*=\\s*'SigCont';/d" "$NATIVE_DIR/prefix/bin/exiftool"
perltidy --delete-block-comments --delete-side-comments --delete-pod \
    "$NATIVE_DIR/prefix/bin/exiftool" -o "$REPO_DIR/exiftool.min.pl"
test -s "$REPO_DIR/exiftool.min.pl"
