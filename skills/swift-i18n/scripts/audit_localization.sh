#!/usr/bin/env bash
set -u

ROOT="${1:-.}"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg is required" >&2
  exit 1
fi

print_section() {
  printf '\n[%s]\n' "$1"
}

run_check() {
  local title="$1"
  local pattern="$2"

  print_section "$title"
  rg -n -P --glob '*.swift' \
    --glob '!**/Tests/**' \
    --glob '!**/*.generated.swift' \
    --glob '!**/Examples/**' \
    --glob '!**/Templates/**' \
    --glob '!**/.build/**' \
    --glob '!**/build/**' \
    --glob '!**/.derivedData/**' \
    --glob '!**/DerivedData/**' \
    --glob '!**/Pods/**' \
    --glob '!**/Carthage/**' \
    --glob '!**/vendor/**' \
    --glob '!**/node_modules/**' \
    --glob '!skills/**' \
    "$pattern" "$ROOT" || true
}

echo "Swift localization audit"
echo "Root: $ROOT"
echo "Heuristic only. Review findings manually."
echo "Tip: point this script at the app source directory for tighter results."

run_check \
  "SwiftUI literal calls" \
  '\b(Text|Label|Button|TextField|SecureField|navigationTitle|navigationSubtitle|Section|Picker)\(\s*"[^"]*[\p{L}\p{Han}][^"]*"'

run_check \
  "Accessibility literals" \
  '\.(accessibilityLabel|accessibilityHint|accessibilityValue)\(\s*"[^"]*[\p{L}\p{Han}][^"]*"'

run_check \
  "Raw NSLocalizedString usage" \
  '\bNSLocalizedString\(\s*"[^"]+"'

run_check \
  "String literals assigned to likely user-facing vars" \
  '\b(title|message|subtitle|label|hint|placeholder|errorMessage)\s*[:=]\s*"[^"]*[\p{L}\p{Han}][^"]*"'

exit 0
