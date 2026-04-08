#!/usr/bin/env bash
set -euo pipefail

# strict-coder 설치 스크립트
# 사용법:
#   git clone https://github.com/{user}/strict-coder .ai/strict-coder
#   bash .ai/strict-coder/install.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_detect.sh"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: git 저장소 내에서 실행해주세요." >&2
    exit 1
fi

# strict-coder의 상대 경로 계산
INSTALL_PATH="${SCRIPT_DIR#"$PROJECT_ROOT"/}"

echo "📦 strict-coder 설치 중..."
echo "  프로젝트: $PROJECT_ROOT"
echo "  설치 경로: $INSTALL_PATH"
echo ""

# ── 0. 설정 파일 ──────────────────────────────────────────
CONFIG_FILE="$PROJECT_ROOT/strict-coder.config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "0/5 — 설정 파일"
    echo "  ⏭️  strict-coder.config.json 이미 존재 (스킵)"
else
    echo "0/5 — 설정 파일 생성"
    echo ""
    echo "  프로젝트에 맞게 TDD 설정을 구성합니다."
    echo ""

    # 감시 경로: 자동감지 → 확인/편집/직접입력
    sc_interactive_watch_paths "$PROJECT_ROOT"
    sc_paths_to_json

    # 테스트 파일 패턴 (복수 입력 지원)
    read -rp "  테스트 파일 패턴 (정규식, 쉼표 구분, 기본: _test\\..+$): " TEST_PATTERN_INPUT
    TEST_PATTERN_INPUT="${TEST_PATTERN_INPUT:-_test\\..+$}"
    IFS=',' read -ra TEST_PATTERNS <<< "$TEST_PATTERN_INPUT"
    TEST_PATTERNS_JSON="["
    first=true
    for tp in "${TEST_PATTERNS[@]}"; do
        tp="$(echo "$tp" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$tp" ] && continue
        if [ "$first" = true ]; then first=false; else TEST_PATTERNS_JSON+=","; fi
        TEST_PATTERNS_JSON+="\"$tp\""
    done
    TEST_PATTERNS_JSON+="]"

    read -rp "  테스트 실행 명령 (기본: make test): " TEST_CMD
    TEST_CMD="${TEST_CMD:-make test}"

    read -rp "  프로젝트 디렉토리 (테스트 실행 위치, 기본: .): " PROJ_DIR
    PROJ_DIR="${PROJ_DIR:-.}"

    jq -n \
        --argjson wp "$SC_PATHS_JSON" \
        --argjson tp "$TEST_PATTERNS_JSON" \
        --arg tc "$TEST_CMD" \
        --arg pd "$PROJ_DIR" \
        '{
            tdd: {
                watch_paths: $wp,
                test_file_patterns: $tp,
                test_command: $tc,
                project_dir: $pd
            },
            mode: "suggest",
            profile: null
        }' > "$CONFIG_FILE"

    echo ""
    echo "  ✅ strict-coder.config.json 생성 완료"
fi
echo ""

# ── 1. git hooks 경로 ─────────────────────────────────────
echo "1/5 — git hooks 경로 설정"
cd "$PROJECT_ROOT"
HOOKS_PATH="$INSTALL_PATH/hooks"
EXISTING_HOOKS_PATH=$(git config --get core.hooksPath 2>/dev/null || echo "")

if [ -n "$EXISTING_HOOKS_PATH" ] && [ "$EXISTING_HOOKS_PATH" != "$HOOKS_PATH" ] && [ "$EXISTING_HOOKS_PATH" != "$HOOKS_PATH/" ]; then
    echo "  ⚠️  기존 core.hooksPath 감지: $EXISTING_HOOKS_PATH"
    echo "  strict-coder 훅으로 덮어쓰면 기존 훅이 무시됩니다."
    echo "  계속하려면 Enter, 취소하려면 Ctrl+C"
    read -r
fi

git config core.hooksPath "$HOOKS_PATH"
echo "  ✅ core.hooksPath → $HOOKS_PATH"

# ── 2. Claude Code 훅 등록 ────────────────────────────────
echo "2/5 — Claude Code 훅 등록"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
GATE_CMD="bash \"\$CLAUDE_PROJECT_DIR/$INSTALL_PATH/hooks/tdd-gate.sh\""

if [ -f "$SETTINGS_FILE" ]; then
    HAS_TDD_GATE=$(jq '.hooks.PreToolUse // [] | any(.hooks[]?.command | test("tdd-gate"))' "$SETTINGS_FILE" 2>/dev/null || echo "false")
    if [ "$HAS_TDD_GATE" = "true" ]; then
        echo "  ⏭️  tdd-gate 훅 이미 등록됨 (스킵)"
    else
        UPDATED=$(jq --arg cmd "$GATE_CMD" '(.hooks.PreToolUse) |= (. // []) + [
            {
                "matcher": "Edit|Write|MultiEdit",
                "hooks": [
                    {
                        "type": "command",
                        "command": $cmd,
                        "timeout": 10
                    }
                ]
            }
        ]' "$SETTINGS_FILE")
        echo "$UPDATED" > "$SETTINGS_FILE"
        echo "  ✅ PreToolUse 훅 등록 완료 (기존 훅 보존)"
    fi
else
    mkdir -p "$PROJECT_ROOT/.claude"
    jq -n --arg cmd "$GATE_CMD" '{
        hooks: {
            PreToolUse: [
                {
                    matcher: "Edit|Write|MultiEdit",
                    hooks: [
                        {
                            type: "command",
                            command: $cmd,
                            timeout: 10
                        }
                    ]
                }
            ]
        }
    }' > "$SETTINGS_FILE"
    echo "  ✅ .claude/settings.json 생성 + 훅 등록 완료"
fi

# ── 3. .gitignore ─────────────────────────────────────────
echo "3/5 — .gitignore 설정"
GITIGNORE="$PROJECT_ROOT/.gitignore"

if [ -f "$GITIGNORE" ]; then
    if grep -q ".tdd-state" "$GITIGNORE"; then
        echo "  ⏭️  .tdd-state 이미 등록됨 (스킵)"
    else
        {
            echo ""
            echo "# TDD State (strict-coder)"
            echo ".tdd-state"
        } >> "$GITIGNORE"
        echo "  ✅ .tdd-state 추가"
    fi
else
    echo ".tdd-state" > "$GITIGNORE"
    echo "  ✅ .gitignore 생성 + .tdd-state 추가"
fi

# ── 4. 실행 권한 ──────────────────────────────────────────
echo "4/5 — 실행 권한 설정"
chmod +x "$SCRIPT_DIR/_lib.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR/hooks/"* 2>/dev/null || true
echo "  ✅ 실행 권한 부여 완료"

# ── 5. 검증 ───────────────────────────────────────────────
echo "5/5 — 설치 검증"
VERIFY_OK=true

if [ ! -f "$CONFIG_FILE" ]; then
    echo "  ❌ strict-coder.config.json 없음"
    VERIFY_OK=false
fi

CONFIGURED_HOOKS=$(git config --get core.hooksPath 2>/dev/null || echo "")
if [ "$CONFIGURED_HOOKS" != "$HOOKS_PATH" ]; then
    echo "  ❌ core.hooksPath 불일치: $CONFIGURED_HOOKS"
    VERIFY_OK=false
fi

if [ "$VERIFY_OK" = true ]; then
    echo "  ✅ 모든 검증 통과"
fi

echo ""
echo "✅ strict-coder 설치 완료"
echo ""
echo "사용법:"
echo "  TDD Red:    $INSTALL_PATH/scripts/tdd-red.sh [테스트 인수...]"
echo "  TDD Green:  $INSTALL_PATH/scripts/tdd-green.sh"
echo "  TDD Status: $INSTALL_PATH/scripts/tdd-status.sh"
echo "  TDD Reset:  $INSTALL_PATH/scripts/tdd-reset.sh"
echo ""
echo "설정 변경: $INSTALL_PATH/scripts/tdd-config.sh"
echo "모드 전환: 대화 중 'suggest로 진행해' 또는 'drive 모드로'"
