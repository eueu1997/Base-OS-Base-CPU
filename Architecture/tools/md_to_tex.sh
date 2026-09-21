#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s [file.md ...]\n' "$(basename "$0")"
    printf '       %s                  # convert all .md files in the current directory\n' "$(basename "$0")"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v pandoc >/dev/null 2>&1; then
    printf 'Error: pandoc is not installed or not in PATH.\n' >&2
    exit 1
fi

if (( $# > 0 )); then
    markdown_files=("$@")
else
    shopt -s nullglob
    markdown_files=( *.md )
    shopt -u nullglob
fi

if (( ${#markdown_files[@]} == 0 )); then
    printf 'Error: no Markdown files found.\n' >&2
    exit 1
fi

for markdown_file in "${markdown_files[@]}"; do
    if [[ ! -f "$markdown_file" ]]; then
        printf 'Error: file not found: %s\n' "$markdown_file" >&2
        exit 1
    fi

    case "$markdown_file" in
        *.md) tex_file="${markdown_file%.md}.tex" ;;
        *)
            printf 'Error: input is not a .md file: %s\n' "$markdown_file" >&2
            exit 1
            ;;
    esac

    pandoc "$markdown_file" \
        --from=gfm \
        --to=latex \
        --standalone \
        --metadata="title:$(basename "${markdown_file%.md}")" \
        -V geometry:margin=25mm \
        -V documentclass=article \
        -o "$tex_file"

    printf 'Created: %s\n' "$tex_file"
done
