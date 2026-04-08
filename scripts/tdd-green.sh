#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD Green Phase
# Red 상태를 확인한 뒤 테스트를 실행하고 통과를 확인한다.
# .tdd-state의 test_command와 test_args를 사용해 테스트를 실행한다.

source "$(dirname "$0")/../_lib.sh"

# .tdd-state 존재 확인
if [ ! -f "$SC_STATE_FILE" ]; then
    echo "ERROR: .tdd-state 파일이 없습니다. 먼저 tdd-red.sh 를 실행하세요." >&2
    exit 1
fi

PHASE=$(jq -r '.phase' "$SC_STATE_FILE")
RED_COMPLETE=$(jq -r '.red_complete' "$SC_STATE_FILE")
TEST_COMMAND=$(jq -r '.test_command' "$SC_STATE_FILE")
PROJECT_DIR=$(jq -r '.project_dir' "$SC_STATE_FILE")
TEST_ARGS=$(jq -r '.test_args' "$SC_STATE_FILE")

# Red 상태 확인
if [ "$PHASE" != "red" ]; then
    echo "ERROR: 현재 phase=$PHASE. Red 상태에서만 Green으로 진행할 수 있습니다." >&2
    exit 1
fi

if [ "$RED_COMPLETE" != "true" ]; then
    echo "ERROR: Red가 완료되지 않았습니다. tdd-red.sh 를 먼저 실행하세요." >&2
    exit 1
fi

TARGET_DIR="$SC_PROJECT_ROOT/$PROJECT_DIR"
echo "🟢 Green Phase: 테스트 실행 중..."
echo "  디렉토리: $TARGET_DIR"
echo "  명령: $TEST_COMMAND $TEST_ARGS"
echo ""

# 테스트 실행 -- exit code로 성패 판단
set +e
# shellcheck disable=SC2086
TEST_OUTPUT=$(cd "$TARGET_DIR" && $TEST_COMMAND $TEST_ARGS 2>&1)
TEST_EXIT_CODE=$?
set -e

echo "$TEST_OUTPUT"
echo ""

if [ "$TEST_EXIT_CODE" -ne 0 ]; then
    echo "ERROR: 테스트가 여전히 실패합니다. 구현을 완성하세요." >&2
    exit 1
fi

# .tdd-state 갱신
UPDATED=$(jq \
    --arg phase "green" \
    --arg green_complete "true" \
    --arg last_green_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '. + {
        phase: $phase,
        green_complete: ($green_complete == "true"),
        last_green_at: $last_green_at
    }' "$SC_STATE_FILE")

echo "$UPDATED" > "$SC_STATE_FILE"

echo "✅ Green 확인 완료: 모든 테스트 통과"
echo "  상태 기록: $SC_STATE_FILE"
echo "  다음 단계: 커밋 가능"
