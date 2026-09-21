#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEX_FILE="${SCRIPT_DIR}/RISCV_Core_Datasheet.tex"

if ! command -v pdflatex >/dev/null 2>&1; then
    printf 'Error: pdflatex is not installed or not in PATH.\n' >&2
    exit 1
fi

if [[ ! -f "${TEX_FILE}" ]]; then
    printf 'Error: LaTeX source not found: %s\n' "${TEX_FILE}" >&2
    exit 1
fi

cd "${SCRIPT_DIR}"
pdflatex -interaction=nonstopmode -halt-on-error -file-line-error "${TEX_FILE}"
pdflatex -interaction=nonstopmode -halt-on-error -file-line-error "${TEX_FILE}"

printf 'PDF generated: %s\n' "${SCRIPT_DIR}/RISCV_Core_Datasheet.pdf"
