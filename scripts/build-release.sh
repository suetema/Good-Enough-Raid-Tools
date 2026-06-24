#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
addon_name="GoodEnoughRaidTools"
toc_path="$repo_root/${addon_name}.toc"
dist_dir="$repo_root/dist"
stage_dir="$dist_dir/$addon_name"
zip_path="$dist_dir/${addon_name}.zip"

if [[ ! -f "$toc_path" ]]; then
  echo "Missing TOC: $toc_path" >&2
  exit 1
fi

rm -rf "$stage_dir"
mkdir -p "$stage_dir"

while IFS= read -r line; do
  trimmed="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$trimmed" ]] && continue
  [[ "$trimmed" == \#* ]] && continue

  source_path="$repo_root/$trimmed"
  target_path="$stage_dir/$trimmed"

  if [[ ! -f "$source_path" ]]; then
    echo "TOC references missing file: $trimmed" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
done < "$toc_path"

cp "$toc_path" "$stage_dir/${addon_name}.toc"

rm -f "$zip_path"
(
  cd "$dist_dir"
  zip -qr "$(basename "$zip_path")" "$addon_name"
)

echo "$zip_path"
