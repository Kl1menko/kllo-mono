#!/usr/bin/env bash
# Заливає СТАТИЧНІ медіа (img, video, audio, fonts) на CDN через PHP-ендпоінт
# (upload-static.php) за допомогою curl.
#
# Структура на сервері: cdn/assets/<шлях>  (напр. cdn/assets/img/logo-kllo.svg)
# Публічний URL:        $PUBLIC_CDN_BASE/assets/<шлях>
#
# Використання:
#   ./scripts/deploy-media.sh              # залити все медіа
#   ./scripts/deploy-media.sh --dry-run    # показати список без заливки
#   ./scripts/deploy-media.sh img/logo-kllo.svg   # залити один файл (шлях від assets/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/cdn.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Нема $ENV_FILE — скопіюй scripts/cdn.env.example у scripts/cdn.env." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${UPLOAD_ENDPOINT:?нема UPLOAD_ENDPOINT в cdn.env}"
: "${UPLOAD_API_KEY:?нема UPLOAD_API_KEY в cdn.env}"
: "${PUBLIC_CDN_BASE:=}"

DRY=0
SINGLE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    -*) echo "Невідомий аргумент: $arg" >&2; exit 1 ;;
    *) SINGLE="$arg" ;;
  esac
done

ASSETS_DIR="$ROOT_DIR/assets"

# Збираємо список файлів (відносні шляхи від assets/)
if [[ -n "$SINGLE" ]]; then
  FILES=("$SINGLE")
else
  FILES=()
  while IFS= read -r f; do
    FILES+=("${f#"$ASSETS_DIR"/}")
  done < <(find "$ASSETS_DIR" \( -path "*/img/*" -o -path "*/video/*" -o -path "*/audio/*" \) -type f | sort)
  # Шрифти НЕ заливаємо на CDN — лишаються локальними (CORS на крос-домені).
fi

total=${#FILES[@]}
echo "→ Ендпоінт: $UPLOAD_ENDPOINT"
echo "→ Файлів до заливки: $total"
[[ $DRY == 1 ]] && echo "🔎 DRY-RUN — нічого не заливаю"
echo

ok=0; failed=0; i=0
for rel in "${FILES[@]}"; do
  i=$((i+1))
  local_path="$ASSETS_DIR/$rel"
  if [[ ! -f "$local_path" ]]; then
    echo "  [$i/$total] ❌ нема локально: $rel" >&2
    failed=$((failed+1)); continue
  fi

  if [[ $DRY == 1 ]]; then
    printf "  [%d/%d] %s\n" "$i" "$total" "$rel"
    continue
  fi

  resp="$(curl -sS -w $'\n%{http_code}' \
    -H "X-API-Key: $UPLOAD_API_KEY" \
    -F "path=$rel" \
    -F "file=@$local_path" \
    "$UPLOAD_ENDPOINT" || true)"

  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  if [[ "$code" == "200" ]] && grep -q '"success":true' <<<"$body"; then
    printf "  [%d/%d] ✅ %s\n" "$i" "$total" "$rel"
    ok=$((ok+1))
  else
    printf "  [%d/%d] ❌ %s (HTTP %s) %s\n" "$i" "$total" "$rel" "$code" "$body" >&2
    failed=$((failed+1))
  fi
done

echo
echo "✅ Залито: $ok   ❌ Помилок: $failed   Усього: $total"
if [[ $DRY == 0 && -n "$PUBLIC_CDN_BASE" && $ok -gt 0 ]]; then
  echo "Перевір: ${PUBLIC_CDN_BASE%/}/assets/img/logo-kllo.svg"
fi
[[ $failed == 0 ]]
