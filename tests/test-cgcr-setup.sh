#!/usr/bin/env bash
#
# Tests for the Codex-side humanize-cgcr setup flow and resources.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup-cgcr.sh"
CGCR_SKILL="$PROJECT_ROOT/skills/humanize-cgcr/SKILL.md"

assert_contains() {
    local file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$file"; then
        pass "$desc"
    else
        fail "$desc" "$needle" "not found in $file"
    fi
}

echo "=========================================="
echo "CGCR Setup Tests"
echo "=========================================="
echo ""

if [[ -x "$SETUP_SCRIPT" ]]; then
    pass "setup-cgcr.sh is executable"
else
    fail "setup-cgcr.sh is executable" "executable" "missing or not executable"
fi

if [[ -f "$CGCR_SKILL" ]]; then
    pass "Codex cgcr launcher skill exists"
else
    fail "Codex cgcr launcher skill exists" "$CGCR_SKILL exists" "missing"
fi

assert_contains "$CGCR_SKILL" "/flow:humanize-cgcr" "cgcr skill documents Codex flow command"
assert_contains "$CGCR_SKILL" 'Do not implement `/humanize:cgcr` as a Claude Code command.' "cgcr skill rejects Claude command wrapper"
assert_contains "$CGCR_SKILL" "setup-cgcr.sh" "cgcr skill calls setup script"
assert_contains "$CGCR_SKILL" "Codex is the only implementation agent" "cgcr skill preserves executor boundary"

setup_test_dir
REPO="$TEST_DIR/repo"
mkdir -p "$REPO"
(
    cd "$REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test User"
    git config commit.gpgsign false
    printf 'initial\n' > README.md
    git add README.md
    git commit -q -m "Initial commit"
)

TASK="Implement a long-running feature without fake data or placeholder stubs"
OUTPUT="$(
    cd "$REPO"
    "$SETUP_SCRIPT" \
        --prepare-only \
        --goal-id cgcr-test-goal \
        --session humanize-cgcr-test \
        --cadence 30m \
        --principles "no fake data; no stubs; do not broaden scope" \
        --task "$TASK"
)"

RUN_DIR="$(printf '%s\n' "$OUTPUT" | sed -n 's/^  run_dir:[[:space:]]*//p' | tail -1)"

if [[ -d "$RUN_DIR" ]]; then
    pass "prepare-only creates CGCR run directory"
else
    fail "prepare-only creates CGCR run directory" "directory exists" "${RUN_DIR:-missing}"
fi

TASK_FILE="$RUN_DIR/task.md"
PROMPT_FILE="$RUN_DIR/codex-goal-prompt.md"
MONITOR_FILE="$RUN_DIR/claude-monitor-command.txt"
RESOURCE_FILE="$RUN_DIR/resources.json"
README_FILE="$RUN_DIR/README.md"

for file in "$TASK_FILE" "$PROMPT_FILE" "$MONITOR_FILE" "$RESOURCE_FILE" "$README_FILE"; do
    if [[ -f "$file" ]]; then
        pass "created $(basename "$file")"
    else
        fail "created $(basename "$file")" "$file exists" "missing"
    fi
done

assert_contains "$TASK_FILE" "$TASK" "task file records original task"
assert_contains "$PROMPT_FILE" "/goal $TASK" "Codex prompt starts /goal"
assert_contains "$PROMPT_FILE" "MONITOR_TARGET_ID: cgcr-test-goal" "Codex prompt includes goal id"
assert_contains "$PROMPT_FILE" "If a message starts with [MONITOR], reply with [MONITOR-ACK] before acting." "Codex prompt includes monitor ack contract"
assert_contains "$PROMPT_FILE" "Never claim tests passed unless the exact commands were run." "Codex prompt forbids fake verification"
assert_contains "$MONITOR_FILE" "/humanize:monitor-codex-goal --discover --expect-goal cgcr-test-goal" "Monitor command discovers expected goal"
assert_contains "$MONITOR_FILE" "--cadence 30m" "Monitor command includes cadence"
assert_contains "$MONITOR_FILE" "--principles" "Monitor command includes principles"
assert_contains "$RESOURCE_FILE" '"workflow": "CGCR"' "resources record workflow"
assert_contains "$RESOURCE_FILE" '"tmux_session": "humanize-cgcr-test"' "resources record tmux session"
assert_contains "$RESOURCE_FILE" '"codex_target": "humanize-cgcr-test:codex-goal.0"' "resources record Codex target"
assert_contains "$RESOURCE_FILE" '"claude_monitor_target": "humanize-cgcr-test:claude-monitor.0"' "resources record Claude monitor target"
assert_contains "$README_FILE" "Do not implement from Claude Code." "run README preserves monitor boundary"

print_test_summary "CGCR Setup Tests"
