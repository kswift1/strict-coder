#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD Red Phase
# 테스트를 실행하고 실패를 확인한 뒤 .tdd-state에 기록한다.
# 사용법: ./tdd-red.sh [테스트 인수...]

source "$(dirname "$0")/../_lib.sh"

TARGET_DIR="$SC_PROJECT_ROOT/$SC_PROJECT_DIR"

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: $TARGET_DIR 디렉토리가 없습니다." >&2
    exit 1
fi

# 현재 상태 확인 -- green 상태면 reset 먼저 필요
if [ -f "$SC_STATE_FILE" ]; then
    CURRENT_PHASE=$(jq -r '.phase // "none"' "$SC_STATE_FILE")
    if [ "$CURRENT_PHASE" = "green" ]; then
        echo "ERROR: 현재 green 상태입니다. 새 사이클을 시작하려면 먼저 tdd-reset.sh 를 실행하세요." >&2
        exit 1
    fi
fi

echo "🔴 Red Phase: 테스트 실행 중..."
echo "  디렉토리: $TARGET_DIR"
echo "  명령: $SC_TEST_COMMAND $*"
echo ""

# 테스트 실행 -- exit code로 성패 판단 (언어 무관)
set +e
# shellcheck disable=SC2086
TEST_OUTPUT=$(cd "$TARGET_DIR" && $SC_TEST_COMMAND "$@" 2>&1)
TEST_EXIT_CODE=$?
set -e

echo "$TEST_OUTPUT"
echo ""

if [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "ERROR: 모든 테스트가 통과했습니다. 먼저 실패하는 테스트를 작성하세요." >&2
    exit 1
fi

# 실패 횟수 추정 (정보용, 정확하지 않을 수 있음)
FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -ci "fail" || echo "1")
[ "$FAILED_COUNT" -eq 0 ] && FAILED_COUNT=1

# .tdd-state 기록
jq -n \
    --arg phase "red" \
    --arg red_complete "true" \
    --arg green_complete "false" \
    --arg last_red_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg test_command "$SC_TEST_COMMAND" \
    --arg project_dir "$SC_PROJECT_DIR" \
    --arg test_args "$*" \
    --argjson failed_count "$FAILED_COUNT" \
    '{
        phase: $phase,
        red_complete: ($red_complete == "true"),
        green_complete: ($green_complete == "true"),
        last_red_at: $last_red_at,
        last_green_at: null,
        test_command: $test_command,
        project_dir: $project_dir,
        test_args: $test_args,
        failed_count: $failed_count
    }' > "$SC_STATE_FILE"

echo "✅ Red 확인 완료: 테스트 실패 감지 (추정 ${FAILED_COUNT}건)"
echo "  상태 기록: $SC_STATE_FILE"
echo "  다음 단계: 구현 후 tdd-green.sh 실행"
