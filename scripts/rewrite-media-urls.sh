#!/usr/bin/env bash
# Перемикає посилання на медіа між локальними шляхами та CDN-URL.
#
#   ./scripts/rewrite-media-urls.sh --to-cdn     # ./assets/...  → $PUBLIC_CDN_BASE/assets/...
#   ./scripts/rewrite-media-urls.sh --to-local   # назад до локальних шляхів
#   ./scripts/rewrite-media-urls.sh --to-cdn --dry-run   # показати без запису
#
# Чіпає ТІЛЬКИ медіа (img/video/audio/fonts) у index.html, assets/css/*.css,
# assets/js/odyn-bundle.js. JS/CSS-бібліотеки та код не зачіпаються.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/cdn.env"

[[ -f "$ENV_FILE" ]] || { echo "❌ Нема $ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${PUBLIC_CDN_BASE:?нема PUBLIC_CDN_BASE в cdn.env}"
BASE="${PUBLIC_CDN_BASE%/}"   # без кінцевого слешу

MODE=""
DRY=0
for arg in "$@"; do
  case "$arg" in
    --to-cdn)   MODE="cdn" ;;
    --to-local) MODE="local" ;;
    --dry-run)  DRY=1 ;;
    *) echo "Невідомий аргумент: $arg" >&2; exit 1 ;;
  esac
done
[[ -n "$MODE" ]] || { echo "Вкажи --to-cdn або --to-local" >&2; exit 1; }

cd "$ROOT_DIR"

# Файли, у яких переписуємо посилання
FILES=(index.html assets/css/custom.css assets/css/main.css assets/js/odyn-bundle.js)

run_python () {
python3 - "$MODE" "$BASE" "$DRY" "${FILES[@]}" <<'PY'
import sys, re, os
mode, base, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
files = sys.argv[4:]
# Шрифти (fonts) НЕ переписуємо — вони лишаються локальними через CORS.
media = r'(?:img|video|audio)'

# Пари замін для кожного контексту. Кожне правило ідемпотентне.
def rules_to_cdn():
    return [
        # HTML/JS: "./assets/img/..." та "assets/img/..."  → "<BASE>/assets/img/..."
        (re.compile(r'(["\'(])\.?/?assets/(' + media + r')/'), r'\1' + base + r'/assets/\2/'),
        # JS база звуку: L="./assets/audio" → L="<BASE>/assets/audio"
        # Якорь на відкривальну лапку, щоб не матчити хвіст вже-CDN-ного URL.
        (re.compile(r'(["\'])\.?/?assets/(audio)(["\'])'), r'\1' + base + r'/assets/\2\3'),
        # CSS url(../img/...) / url(../fonts/...) → url(<BASE>/assets/img/...)
        (re.compile(r'url\(\s*(["\']?)\.\./(' + media + r')/'), r'url(\1' + base + r'/assets/\2/'),
    ]

def rules_to_local():
    b = re.escape(base)
    return [
        # CSS: url(<BASE>/assets/img/...) → url(../img/...)
        (re.compile(r'url\(\s*(["\']?)' + b + r'/assets/(' + media + r')/'), r'url(\1../\2/'),
        # HTML/JS: "<BASE>/assets/img/..." → "./assets/img/..."
        (re.compile(r'(["\'(])' + b + r'/assets/(' + media + r')/'), r'\1./assets/\2/'),
        # JS аудіо база: "<BASE>/assets/audio" → "./assets/audio"
        (re.compile(r'(["\'])' + b + r'/assets/(audio)(["\'])'), r'\1./assets/\2\3'),
    ]

rules = rules_to_cdn() if mode == "cdn" else rules_to_local()

total = 0
for f in files:
    if not os.path.exists(f):
        continue
    src = open(f, encoding="utf-8").read()
    out = src
    n = 0
    for pat, repl in rules:
        out, c = pat.subn(repl, out)
        n += c
    if n and not dry:
        open(f, "w", encoding="utf-8").write(out)
    total += n
    tag = "(dry)" if dry else ""
    print(f"  {f}: {n} замін {tag}")
print(f"→ Разом: {total} замін, режим={mode}")
PY
}

echo "Режим: $([[ $MODE == cdn ]] && echo 'локальні → CDN' || echo 'CDN → локальні')"
echo "BASE:  $BASE"
[[ $DRY == 1 ]] && echo "🔎 DRY-RUN"
echo
run_python
