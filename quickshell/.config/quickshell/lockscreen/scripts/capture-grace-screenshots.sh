#!/usr/bin/env bash
set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/qs-lock"
stamp="$(date +%s%N)"

mkdir -p "$runtime_dir" || exit 1
find "$runtime_dir" -maxdepth 1 -type f -name 'grace-*.png' -mmin +10 -delete 2>/dev/null || true

fallback_printed=0
index=0

for output_name in "$@"; do
    output_path="${runtime_dir}/grace-${index}-${stamp}.png"

    if grim -o "$output_name" "$output_path" >/dev/null 2>&1; then
        output_uri="file://${output_path}?${stamp}"
        printf 'output\t%s\t%s\n' "$output_name" "$output_uri"

        if [[ "$fallback_printed" -eq 0 ]]; then
            printf 'fallback\t%s\n' "$output_uri"
            fallback_printed=1
        fi
    fi

    index=$((index + 1))
done

if [[ "$fallback_printed" -eq 0 ]]; then
    fallback_path="${runtime_dir}/grace-fallback-${stamp}.png"
    if grim "$fallback_path" >/dev/null 2>&1; then
        printf 'fallback\tfile://%s?%s\n' "$fallback_path" "$stamp"
    fi
fi
