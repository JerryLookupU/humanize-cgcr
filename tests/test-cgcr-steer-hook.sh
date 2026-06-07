#!/usr/bin/env bash
#
# Tests for the CGCR steer prompt hook.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

HOOK="$PROJECT_ROOT/hooks/cgcr-steer-prompt-hook.sh"

run_hook() {
    "$HOOK" \
        --goal-id cgcr-goal-1 \
        --reason "scope drift detected" \
        --deviation-class scope_drift \
        --original-goal "Implement the CSV export requested by the user" \
        --latest-user-constraints "no fake data; no stubs" \
        --current-codex-direction "Refactoring unrelated authentication code" \
        --observed-deviation "Codex edited auth files unrelated to CSV export" \
        --evidence "transcript shows unrelated auth refactor" \
        "$@"
}

assert_contains_text() {
    local text="$1"
    local needle="$2"
    local desc="$3"
    if printf '%s' "$text" | grep -qF -- "$needle"; then
        pass "$desc"
    else
        fail "$desc" "$needle" "$text"
    fi
}

assert_not_contains_regex() {
    local text="$1"
    local pattern="$2"
    local desc="$3"
    if printf '%s' "$text" | grep -qiE "$pattern"; then
        fail "$desc" "absent pattern: $pattern" "$text"
    else
        pass "$desc"
    fi
}

echo "=========================================="
echo "CGCR Steer Hook Tests"
echo "=========================================="
echo ""

if [[ -x "$HOOK" ]]; then
    pass "cgcr steer hook is executable"
else
    fail "cgcr steer hook is executable" "executable" "missing or not executable"
fi

output="$(run_hook --correction-count 0)"
assert_contains_text "$output" "[MONITOR:approved]" "default mode is approved"
assert_contains_text "$output" "Return attention to the original goal" "count 0 selects simple guidance"
assert_not_contains_regex "$output" "steer_level|previous_steer_count|why_this_level|reset_condition" "prompt does not expose selector metadata"

output="$(run_hook --correction-count 1)"
assert_contains_text "$output" "Identify the exact mismatch" "count 1 selects explicit realignment"
assert_not_contains_regex "$output" "steer_level|previous_steer_count|why_this_level|reset_condition" "realignment prompt hides selector metadata"

output="$(run_hook --correction-count 2)"
assert_contains_text "$output" "Classify the current work into:" "count 2 selects stop-and-classify"
assert_contains_text "$output" "Work that directly supports the original goal" "stop-and-classify prompt includes in-scope category"

output="$(run_hook --correction-count 3)"
assert_contains_text "$output" "perform an Occam review" "count 3 selects Occam review"
assert_contains_text "$output" "simplest sufficient path" "Occam prompt asks for simplest path"

output="$(run_hook --correction-count 4)"
assert_contains_text "$output" "Return attention to the original goal" "count 4 wraps back to simple guidance"

output="$(run_hook --mode auto --correction-count 0)"
assert_contains_text "$output" "[MONITOR:auto]" "auto mode emits auto monitor tag"

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

TRANSCRIPT="$TEST_DIR/transcript.txt"
cat > "$TRANSCRIPT" <<'EOF'
[MONITOR:approved]
goal_id: cgcr-goal-1
reason: prior finding
[/MONITOR]

[MONITOR:auto]
goal_id: other-goal
reason: other goal
[/MONITOR]

[MONITOR:auto]
goal_id: cgcr-goal-1
reason: second prior finding
[/MONITOR]
EOF

output="$(run_hook --transcript "$TRANSCRIPT")"
assert_contains_text "$output" "Classify the current work into:" "transcript-derived count selects count 2 prompt"

if "$HOOK" --goal-id cgcr-goal-1 --correction-count not-a-number >/tmp/cgcr-steer-invalid.out 2>/tmp/cgcr-steer-invalid.err; then
    fail "invalid correction count fails" "non-zero exit" "exit 0"
else
    pass "invalid correction count fails"
fi

print_test_summary "CGCR Steer Hook Tests"
