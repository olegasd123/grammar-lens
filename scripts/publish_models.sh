#!/usr/bin/env bash
#
# publish_models.sh — Publish GGUF model files to GitHub Releases.
#
# Computes SHA-256 hashes, uploads models as release assets, and updates
# both models/manifest.json and the bundled Dart constant.
#
# Usage:
#   ./scripts/publish_models.sh <models_dir> <tag> [--dry-run]
#
# Examples:
#   ./scripts/publish_models.sh ./trained_models models-v1 --dry-run
#   ./scripts/publish_models.sh ./trained_models models-v1
#
# Requirements:
#   - gh CLI (authenticated)
#   - jq
#   - shasum or sha256sum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_PATH="$REPO_ROOT/models/manifest.json"
DART_MANIFEST_PATH="$REPO_ROOT/packages/model_repository/lib/src/model_manifest.dart"

# --- Helpers ----------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $(basename "$0") <models_dir> <release_tag> [--dry-run]

Arguments:
  models_dir    Directory containing .gguf model files
  release_tag   Git tag for the GitHub Release (e.g., models-v1)

Options:
  --dry-run     Compute hashes and print manifest without uploading
  --help        Show this help message

The script expects model filenames to match IDs in models/manifest.json,
e.g. phi3-mini-grammar-en-q4km.gguf
EOF
  exit 1
}

die() {
  echo "Error: $1" >&2
  exit 1
}

check_deps() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
  if [ "$DRY_RUN" = false ]; then
    command -v gh >/dev/null 2>&1 || die "gh CLI is required but not installed"
  fi
}

compute_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die "Neither sha256sum nor shasum found"
  fi
}

get_repo_slug() {
  gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null \
    || die "Could not determine repository. Run 'gh auth login' first."
}

# --- Parse args -------------------------------------------------------------

DRY_RUN=false
MODELS_DIR=""
TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage ;;
    *)
      if [ -z "$MODELS_DIR" ]; then
        MODELS_DIR="$1"
      elif [ -z "$TAG" ]; then
        TAG="$1"
      else
        die "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[ -z "$MODELS_DIR" ] && usage
[ -z "$TAG" ] && usage
[ -d "$MODELS_DIR" ] || die "Models directory not found: $MODELS_DIR"

check_deps

# --- Collect model files ----------------------------------------------------

GGUF_FILES=()
while IFS= read -r -d '' f; do
  GGUF_FILES+=("$f")
done < <(find "$MODELS_DIR" -maxdepth 1 -name '*.gguf' -print0 | sort -z)

[ ${#GGUF_FILES[@]} -eq 0 ] && die "No .gguf files found in $MODELS_DIR"

echo "Found ${#GGUF_FILES[@]} model file(s):"
printf '  %s\n' "${GGUF_FILES[@]}"
echo

# --- Determine repo slug ---------------------------------------------------

if [ "$DRY_RUN" = false ]; then
  REPO_SLUG="$(get_repo_slug)"
else
  REPO_SLUG="$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo 'grammarlens/grammarlens')"
fi

echo "Repository: $REPO_SLUG"
echo "Release tag: $TAG"
echo

# --- Compute hashes and sizes -----------------------------------------------

declare -A FILE_HASHES
declare -A FILE_SIZES

for gguf in "${GGUF_FILES[@]}"; do
  filename="$(basename "$gguf")"
  model_id="${filename%.gguf}"

  echo "Computing SHA-256 for $filename..."
  hash="$(compute_sha256 "$gguf")"
  size="$(stat -f%z "$gguf" 2>/dev/null || stat -c%s "$gguf" 2>/dev/null)"

  FILE_HASHES["$model_id"]="$hash"
  FILE_SIZES["$model_id"]="$size"

  echo "  $model_id: sha256=$hash size=$size"
done

echo

# --- Update models/manifest.json -------------------------------------------

echo "Updating $MANIFEST_PATH..."

# Read the existing manifest and update entries that match our model files
UPDATED_MANIFEST="$(jq --arg tag "$TAG" --arg repo "$REPO_SLUG" '
  .models |= [.[] | . as $m |
    $m
  ]
' "$MANIFEST_PATH")"

# Apply hashes, sizes, and URLs per model
for model_id in "${!FILE_HASHES[@]}"; do
  hash="${FILE_HASHES[$model_id]}"
  size="${FILE_SIZES[$model_id]}"
  url="https://github.com/$REPO_SLUG/releases/download/$TAG/$model_id.gguf"

  UPDATED_MANIFEST="$(echo "$UPDATED_MANIFEST" | jq \
    --arg id "$model_id" \
    --arg hash "$hash" \
    --argjson size "$size" \
    --arg url "$url" \
    '.models |= [.[] | if .id == $id then .sha256 = $hash | .fileSizeBytes = $size | .downloadUrl = $url else . end]'
  )"
done

if [ "$DRY_RUN" = true ]; then
  echo
  echo "=== Updated manifest (dry run) ==="
  echo "$UPDATED_MANIFEST" | jq .
  echo
else
  echo "$UPDATED_MANIFEST" | jq . > "$MANIFEST_PATH"
  echo "  Written to $MANIFEST_PATH"
fi

# --- Update bundled Dart manifest -------------------------------------------

echo "Updating $DART_MANIFEST_PATH..."

# Build the Dart map literal entries
DART_ENTRIES=""
MODEL_IDS="$(echo "$UPDATED_MANIFEST" | jq -r '.models[].id')"

while IFS= read -r mid; do
  MODEL_JSON="$(echo "$UPDATED_MANIFEST" | jq -c ".models[] | select(.id == \"$mid\")")"

  display_name="$(echo "$MODEL_JSON" | jq -r '.displayName')"
  language="$(echo "$MODEL_JSON" | jq -r '.language')"
  quantization="$(echo "$MODEL_JSON" | jq -r '.quantization')"
  file_size="$(echo "$MODEL_JSON" | jq -r '.fileSizeBytes')"
  sha256="$(echo "$MODEL_JSON" | jq -r '.sha256')"
  download_url="$(echo "$MODEL_JSON" | jq -r '.downloadUrl')"
  min_version="$(echo "$MODEL_JSON" | jq -r '.minAppVersion')"
  ctx_length="$(echo "$MODEL_JSON" | jq -r '.contextLength')"

  DART_ENTRIES+="      {
        'id': '$mid',
        'displayName': '$display_name',
        'language': '$language',
        'quantization': '$quantization',
        'fileSizeBytes': $file_size,
        'sha256': '$sha256',
        'downloadUrl':
            '$download_url',
        'minAppVersion': '$min_version',
        'contextLength': $ctx_length,
      },
"
done <<< "$MODEL_IDS"

# Build the full replacement block
DART_BLOCK="  static const bundledManifestJson = {
    'version': 1,
    'models': [
$DART_ENTRIES    ],
  };"

if [ "$DRY_RUN" = true ]; then
  echo
  echo "=== Updated Dart constant (dry run) ==="
  echo "$DART_BLOCK"
  echo
else
  # Replace the bundledManifestJson block in the Dart file using sed.
  # Match from "static const bundledManifestJson" to the closing "};"
  # We write the new block to a temp file and use awk for multi-line replacement.
  TEMP_DART="$(mktemp)"
  awk -v replacement="$DART_BLOCK" '
    /static const bundledManifestJson/ { found=1; print replacement; next }
    found && /^  };/ { found=0; next }
    found { next }
    { print }
  ' "$DART_MANIFEST_PATH" > "$TEMP_DART"
  mv "$TEMP_DART" "$DART_MANIFEST_PATH"
  echo "  Written to $DART_MANIFEST_PATH"
fi

# --- Create GitHub Release --------------------------------------------------

if [ "$DRY_RUN" = true ]; then
  echo "=== Dry run complete. No files uploaded. ==="
  exit 0
fi

echo
echo "Creating GitHub Release: $TAG..."

# Build asset args
ASSET_ARGS=()
for gguf in "${GGUF_FILES[@]}"; do
  ASSET_ARGS+=("$gguf")
done

gh release create "$TAG" \
  --title "Models $TAG" \
  --notes "GrammarLens GGUF model files.

Models included:
$(for gguf in "${GGUF_FILES[@]}"; do
    mid="$(basename "${gguf%.gguf}")"
    echo "- $mid (sha256: ${FILE_HASHES[$mid]:-unknown})"
  done)" \
  "${ASSET_ARGS[@]}"

echo
echo "Release created: https://github.com/$REPO_SLUG/releases/tag/$TAG"
echo "Manifest files updated. Don't forget to commit the changes."
