#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
default_repo_root="$(cd -- "$script_dir/.." && pwd)"

repo_root="${1:-$default_repo_root}"
out_dir="${2:-$default_repo_root/test/pbb-blocks}"
manifest="$out_dir/manifest.tsv"

if ! command -v pb >/dev/null 2>&1; then
  echo "error: 'pb' is not in PATH" >&2
  exit 127
fi

mkdir -p "$out_dir"
rm -f "$out_dir"/*.pbb "$manifest"

block_count=0
warn_count=0

while IFS= read -r -d '' md_file; do
  in_block=0
  start_line=0
  line_no=0
  block_content=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_no += 1))

    if [[ "$in_block" -eq 0 && "$line" =~ ^\`\`\`[[:space:]]*pbb([[:space:]].*)?$ ]]; then
      in_block=1
      start_line=$line_no
      block_content=""
      continue
    fi

    if [[ "$in_block" -eq 1 && "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      ((block_count += 1))
      out_file="$out_dir/block_$(printf '%04d' "$block_count").pbb"
      printf '%s' "$block_content" > "$out_file"
      printf '%s\t%s\t%s\n' "$out_file" "$md_file" "$start_line" >> "$manifest"
      in_block=0
      block_content=""
      continue
    fi

    if [[ "$in_block" -eq 1 ]]; then
      block_content+="$line"$'\n'
    fi
  done < "$md_file"

  if [[ "$in_block" -eq 1 ]]; then
    ((warn_count += 1))
    echo "warning: unclosed pbb block in $md_file starting at line $start_line" >&2
  fi
done < <(find "$repo_root" -type f -name '*.md' -print0)

if [[ "$block_count" -eq 0 ]]; then
  echo "No pbb code blocks found in markdown files under $repo_root"
  exit 0
fi

pass_count=0
fail_count=0

while IFS=$'\t' read -r out_file md_file start_line; do
  if pb -E -i "$out_file" >/tmp/pb-e.out 2>/tmp/pb-e.err; then
    ((pass_count += 1))
  else
    ((fail_count += 1))
    echo "parse failed: $out_file"
    echo "  source: $md_file:$start_line"
    if [[ -s /tmp/pb-e.out ]]; then
      cat /tmp/pb-e.out
    fi
    if [[ -s /tmp/pb-e.err ]]; then
      cat /tmp/pb-e.err >&2
    fi
  fi
done < "$manifest"

rm -f /tmp/pb-e.out /tmp/pb-e.err

echo "Extracted $block_count pbb block(s) into $out_dir"
echo "Validated with pb -E: $pass_count passed, $fail_count failed"

if [[ "$warn_count" -gt 0 ]]; then
  echo "Warnings: $warn_count markdown file(s) had unclosed pbb fences" >&2
fi

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
