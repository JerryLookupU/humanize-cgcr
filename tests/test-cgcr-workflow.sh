#!/usr/bin/env bash
#
# Tests for the optional CGCR (Codex Goal with Claude Review) workflow wiring.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

README="$PROJECT_ROOT/README.md"
USAGE_DOC="$PROJECT_ROOT/docs/usage.md"
CGCR_DOC="$PROJECT_ROOT/docs/codex-goal-claude-review.md"
CLAUDE_INSTALL_DOC="$PROJECT_ROOT/docs/install-for-claude.md"
CODEX_INSTALL_DOC="$PROJECT_ROOT/docs/install-for-codex.md"
INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-skill.sh"
CODEX_GOAL_SKILL="$PROJECT_ROOT/skills/humanize-codex-goal/SKILL.md"
CGCR_LAUNCHER_SKILL="$PROJECT_ROOT/skills/humanize-cgcr/SKILL.md"
MONITOR_SKILL="$PROJECT_ROOT/skills/monitor-codex-goal/SKILL.md"
MONITOR_COMMAND="$PROJECT_ROOT/commands/monitor-codex-goal.md"
RLCR_COMMAND="$PROJECT_ROOT/commands/start-rlcr-loop.md"
RLCR_SKILL="$PROJECT_ROOT/skills/humanize-rlcr/SKILL.md"

assert_file_exists() {
    local file="$1" desc="$2"
    if [[ -f "$file" ]]; then
        pass "$desc"
    else
        fail "$desc" "$file exists" "missing"
    fi
}

assert_contains() {
    local file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$file"; then
        pass "$desc"
    else
        fail "$desc" "$needle" "not found in $file"
    fi
}

assert_not_contains() {
    local file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$file"; then
        fail "$desc" "absent: $needle" "found in $file"
    else
        pass "$desc"
    fi
}

echo "=========================================="
echo "CGCR Workflow Tests"
echo "=========================================="
echo ""

assert_file_exists "$CODEX_GOAL_SKILL" "Codex-side goal skill exists"
assert_file_exists "$CGCR_LAUNCHER_SKILL" "Codex-side CGCR launcher skill exists"
assert_file_exists "$MONITOR_SKILL" "Claude-side monitor skill exists"
assert_file_exists "$MONITOR_COMMAND" "Claude command wrapper exists"
assert_file_exists "$RLCR_COMMAND" "Existing RLCR command still exists"
assert_file_exists "$RLCR_SKILL" "Existing RLCR skill still exists"

assert_contains "$CODEX_GOAL_SKILL" "[GOAL-BINDING]" "Codex goal skill defines binding block"
assert_contains "$CODEX_GOAL_SKILL" "MONITOR_TARGET_ID:" "Codex goal skill defines monitor target id"
assert_contains "$CODEX_GOAL_SKILL" "[CHECKPOINT:<phase-name>]" "Codex goal skill defines checkpoints"
assert_contains "$CODEX_GOAL_SKILL" "[MONITOR-ACK]" "Codex goal skill defines monitor acknowledgement"
assert_contains "$CODEX_GOAL_SKILL" "[GOAL-CLOSEOUT]" "Codex goal skill defines closeout"
assert_contains "$CODEX_GOAL_SKILL" "Never claim tests passed unless the exact command was actually run" "Codex goal skill forbids fabricated test claims"
assert_contains "$CODEX_GOAL_SKILL" 'Codex optional flow skill: `/flow:humanize-codex-goal`' "Codex goal skill names Codex-side flow"
assert_contains "$CODEX_GOAL_SKILL" 'Claude Code monitor command: `/humanize:monitor-codex-goal`' "Codex goal skill distinguishes Claude monitor command"

assert_contains "$CGCR_LAUNCHER_SKILL" "name: humanize-cgcr" "CGCR launcher skill has correct name"
assert_contains "$CGCR_LAUNCHER_SKILL" "type: flow" "CGCR launcher skill is a Codex flow"
assert_contains "$CGCR_LAUNCHER_SKILL" "/flow:humanize-cgcr" "CGCR launcher documents Codex flow command"
assert_contains "$CGCR_LAUNCHER_SKILL" 'Do not implement `/humanize:cgcr` as a Claude Code command.' "CGCR launcher rejects Claude command wrapper"
assert_contains "$CGCR_LAUNCHER_SKILL" "setup-cgcr.sh" "CGCR launcher delegates to setup script"
assert_contains "$CGCR_LAUNCHER_SKILL" "Codex is the only implementation agent" "CGCR launcher preserves executor boundary"

assert_contains "$MONITOR_SKILL" "Forbidden Operations" "Monitor skill contains forbidden operation list"
assert_contains "$MONITOR_SKILL" "CGCR is not a dual-executor system" "Monitor skill rejects dual-executor CGCR"
assert_contains "$MONITOR_SKILL" "Codex is the only implementation agent" "Monitor skill names Codex as only implementation agent"
assert_contains "$MONITOR_SKILL" "reject that design and document why" "Monitor skill rejects Claude-mutating designs"
assert_contains "$MONITOR_SKILL" "apply_patch" "Monitor skill forbids apply_patch"
assert_contains "$MONITOR_SKILL" "git add" "Monitor skill forbids git add"
assert_contains "$MONITOR_SKILL" "git commit" "Monitor skill forbids git commit"
assert_contains "$MONITOR_SKILL" "build commands" "Monitor skill forbids build commands"
assert_contains "$MONITOR_SKILL" "package install" "Monitor skill forbids package install"
assert_contains "$MONITOR_SKILL" "Binding Rules" "Monitor skill contains binding rules"
assert_contains "$MONITOR_SKILL" "This is a Claude Code monitor skill. It is not a Codex command." "Monitor skill distinguishes Claude side"
assert_contains "$MONITOR_SKILL" 'Codex-side executor command: `/goal`' "Monitor skill names Codex /goal separately"
assert_contains "$MONITOR_SKILL" "CGCR requires a verified tmux target for injection" "Monitor skill requires tmux target for injection"
assert_contains "$MONITOR_SKILL" "codex_session_id" "Monitor skill binds by Codex session id"
assert_contains "$MONITOR_SKILL" "tmux_target" "Monitor skill binds by tmux target"
assert_contains "$MONITOR_SKILL" "MONITOR_TARGET_ID" "Monitor skill binds by monitor target id"
assert_contains "$MONITOR_SKILL" "Automatic injection is allowed only when all conditions are true" "Monitor skill documents auto-injection gate"
assert_contains "$MONITOR_SKILL" "tmux send-keys -l" "Monitor skill documents literal tmux injection"
assert_contains "$MONITOR_SKILL" "--once" "Monitor skill supports --once alias"
assert_contains "$MONITOR_SKILL" "--no-cron" "Monitor skill supports --no-cron alias"
assert_contains "$MONITOR_SKILL" "State And Checkpoints" "Monitor skill documents checkpoint state"
assert_contains "$MONITOR_SKILL" "Transcript progress" "Monitor skill documents transcript inspection"
assert_contains "$MONITOR_SKILL" "Repository delta" "Monitor skill documents repository delta inspection"
assert_contains "$MONITOR_SKILL" "Artifact reasonableness" "Monitor skill documents artifact inspection"
assert_contains "$MONITOR_SKILL" '"CronCreate"' "Monitor skill allows CronCreate"
assert_contains "$MONITOR_SKILL" '"CronDelete"' "Monitor skill allows CronDelete"
assert_contains "$MONITOR_SKILL" '"PushNotification"' "Monitor skill allows PushNotification"
assert_contains "$MONITOR_SKILL" "prompt must re-enter the monitor for one tick only" "Monitor skill prevents recursive cron scheduling"

assert_contains "$MONITOR_COMMAND" "/humanize:monitor-codex-goal" "Monitor command documents Humanize command name"
assert_contains "$MONITOR_COMMAND" "This is a Claude Code command. It is not a Codex command." "Monitor command distinguishes Claude command"
assert_contains "$MONITOR_COMMAND" '| Codex | `/goal` |' "Monitor command lists Codex command separately"
assert_contains "$MONITOR_COMMAND" "This is **not RLCR**" "Monitor command distinguishes CGCR from RLCR"
assert_contains "$MONITOR_COMMAND" "not a dual-executor system" "Monitor command rejects dual-executor framing"
assert_contains "$MONITOR_COMMAND" "--once" "Monitor command supports --once alias"
assert_contains "$MONITOR_COMMAND" "--no-cron" "Monitor command supports --no-cron alias"
assert_contains "$MONITOR_COMMAND" '"CronCreate"' "Monitor command allows CronCreate"
assert_contains "$MONITOR_COMMAND" "prompt must include" "Monitor command prevents recursive cron scheduling"
assert_contains "$MONITOR_COMMAND" "one tmux pane/window runs Codex" "Monitor command requires tmux topology"
assert_contains "$MONITOR_COMMAND" "AskUserQuestion" "Monitor command allows user approval path"

assert_contains "$CGCR_DOC" "RLCR" "CGCR doc mentions RLCR"
assert_contains "$CGCR_DOC" "CGCR" "CGCR doc mentions CGCR"
assert_contains "$CGCR_DOC" "Claude Code implements" "CGCR doc documents RLCR executor"
assert_contains "$CGCR_DOC" 'Codex `/goal` implements' "CGCR doc documents CGCR executor"
assert_contains "$CGCR_DOC" "/humanize:start-rlcr-loop" "CGCR doc preserves RLCR command reference"
assert_contains "$CGCR_DOC" "/humanize:monitor-codex-goal" "CGCR doc documents monitor command"
assert_contains "$CGCR_DOC" "## Command Surfaces" "CGCR doc separates command surfaces"
assert_contains "$CGCR_DOC" '| Codex | `/flow:humanize-codex-goal`' "CGCR doc lists Codex flow separately"
assert_contains "$CGCR_DOC" '| Codex | `/flow:humanize-cgcr`' "CGCR doc lists Codex launcher separately"
assert_contains "$CGCR_DOC" "CGCR is designed around two tmux panes or windows" "CGCR doc requires two-tmux layout"
assert_contains "$CGCR_DOC" "Claude feedback may enter Codex only as a normal" "CGCR doc restricts feedback path to monitor prompt"
assert_contains "$CGCR_DOC" '--notify-only` controls intervention authority only' "CGCR doc separates scheduling from notify-only"
assert_contains "$CGCR_DOC" 'built-in `CronCreate`' "CGCR doc documents built-in CronCreate scheduling"

assert_contains "$README" "Optional: Codex Goal with Claude Review" "README documents optional CGCR workflow"
assert_contains "$README" "Claude Code implements, Codex reviews" "README distinguishes RLCR roles"
assert_contains "$README" '/humanize:monitor-codex-goal` in Claude Code' "README labels Claude monitor command"
assert_contains "$README" '/flow:humanize-codex-goal` in Codex' "README labels Codex executor flow"
assert_contains "$README" '/flow:humanize-cgcr` in Codex' "README labels Codex launcher flow"
assert_contains "$USAGE_DOC" "/humanize:monitor-codex-goal <session-id> <tmux-target>" "Usage guide includes Claude monitor command"
assert_contains "$USAGE_DOC" "/flow:humanize-cgcr <task>" "Usage guide includes Codex launcher command"
assert_contains "$CLAUDE_INSTALL_DOC" "/humanize:monitor-codex-goal" "Claude install doc lists monitor command"
assert_contains "$CODEX_INSTALL_DOC" "humanize-codex-goal" "Codex install doc lists Codex goal skill"
assert_contains "$CODEX_INSTALL_DOC" "humanize-cgcr" "Codex install doc lists Codex launcher skill"

assert_contains "$INSTALL_SCRIPT" "CODEX_SKILL_NAMES" "Installer has Codex-specific skill group"
assert_contains "$INSTALL_SCRIPT" "humanize-codex-goal" "Installer recognizes humanize-codex-goal"
assert_contains "$INSTALL_SCRIPT" "humanize-cgcr" "Installer recognizes humanize-cgcr"
assert_contains "$INSTALL_SCRIPT" "humanize-rlcr" "Installer still includes humanize-rlcr"
assert_not_contains "$INSTALL_SCRIPT" "monitor-codex-goal" "Installer does not install Claude monitor as a Codex skill"

assert_contains "$RLCR_COMMAND" "/humanize:start-rlcr-loop" "RLCR command name remains documented"
assert_contains "$RLCR_SKILL" "name: humanize-rlcr" "RLCR skill name remains unchanged"

print_test_summary "CGCR Workflow Tests"
