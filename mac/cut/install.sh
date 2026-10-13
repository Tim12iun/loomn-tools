#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  CUTN by loomn — installieren oder neu installieren (kostenlos, ohne Developer-Account)
#
#     curl -fsSL https://raw.githubusercontent.com/Tim12iun/loomn-tools/main/mac/cut/install.sh | bash
#
#  Lädt die neueste fertige CUTN.app aus den Releases von Tim12iun/loomn-tools und legt sie
#  in den Ordner Programme. Weil curl lädt (nicht der Browser), blockiert macOS die App nicht.
#  Deine Daten (Dokumente/CUTN-Daten) werden nicht angefasst.
# ─────────────────────────────────────────────────────────────
set -euo pipefail
FEED="https://raw.githubusercontent.com/Tim12iun/loomn-tools/main/mac/cut/feed.json"
ALLOWED="https://github.com/Tim12iun/loomn-tools/releases/download/"

say() { printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
die() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
[ "$(uname -s)" = "Darwin" ] || die "Nur für den Mac."

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
say "Suche neueste CUTN-Version…"
curl -fsSL "$FEED?t=$(date +%s)" -o "$T/feed.json" || die "Keine Verbindung zu GitHub."
get() { /usr/bin/plutil -extract "app_download.$1" raw -o - "$T/feed.json" 2>/dev/null || true; }
URL="$(get url)"; SHA="$(get sha256)"; VER="$(get version)"; BUILD="$(get build)"
[ -n "$URL" ] || die "Es ist noch keine fertige CUTN.app veröffentlicht."
case "$URL" in "$ALLOWED"*) ;; *) die "Unerwartete Download-Adresse: $URL" ;; esac

say "Lade CUTN $VER (Build $BUILD)…"
curl -fL --progress-bar "$URL" -o "$T/cutn.zip" || die "Download fehlgeschlagen."
if [ -n "$SHA" ]; then
  echo "$SHA  $T/cutn.zip" | /usr/bin/shasum -a 256 -c - >/dev/null || die "Download beschädigt (Prüfsumme)."
fi
/usr/bin/ditto -x -k "$T/cutn.zip" "$T/x" || die "Entpacken fehlgeschlagen."
SRC="$(find "$T/x" -maxdepth 3 -type d -name CUTN.app | head -1)"
[ -n "$SRC" ] || die "Im Paket ist keine CUTN.app."

DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

# Laufendes CUTN beenden (ein laufender Render wird nicht abgebrochen)
if curl -s -m 2 http://127.0.0.1:5555/ping | grep -q '"app":"cutn"'; then
  R="$(curl -s -m 3 -X POST -H 'Content-Type: application/json' -d '{"force":false}' http://127.0.0.1:5555/shutdown || true)"
  echo "$R" | grep -q '"busy":true' && die "CUTN rendert gerade. Bitte warten und dann nochmal ausführen."
  pkill -f "CUTN.app/Contents/Resources/app/fenster.py" 2>/dev/null || true
  sleep 1
fi

say "Installiere nach $DEST/CUTN.app…"
if [ -d "$DEST/CUTN.app" ]; then mv "$DEST/CUTN.app" "$T/CUTN-alt.app"; fi
if ! mv "$SRC" "$DEST/CUTN.app"; then
  [ -d "$T/CUTN-alt.app" ] && mv "$T/CUTN-alt.app" "$DEST/CUTN.app"
  die "Konnte CUTN.app nicht nach $DEST legen."
fi
/usr/bin/xattr -dr com.apple.quarantine "$DEST/CUTN.app" 2>/dev/null || true

D="$HOME/Documents/CUTN-Daten"
[ -d "$D" ] || { [ -d "$HOME/Desktop/CUTN/CUTN-Daten/projects" ] && D="$HOME/Desktop/CUTN/CUTN-Daten"; }
printf "\n\033[32m✓ CUTN %s installiert.\033[0m  Daten: %s\n" "$VER" "$D"
/usr/bin/open "$DEST/CUTN.app"
