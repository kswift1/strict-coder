#!/usr/bin/env bash
set -euo pipefail

# Layer 1: Claude Code PreToolUse Hook
# Edit/Write 도구가 감시 대상 경로의 파일을 수정하려 할 때
# .tdd-state 를 확인하고 Red 완료 전이면 차단한다.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091  # 동적 경로 — 런타임에 정상 resolve
source "$HOOK_DIR/../_lib.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# MultiEdit 지원
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.edits[0].file_path // empty')
fi

# 경로가 없으면 통과
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# 감시 대상 경로가 아니면 통과
if ! sc_matches_watch_path "$FILE_PATH"; then
    exit 0
fi

# 테스트 파일은 통과 (Red phase에서 테스트 작성 허용)
if sc_is_test_file "$FILE_PATH"; then
    exit 0
fi

# .tdd-state 확인
if [ ! -f "$SC_STATE_FILE" ]; then
    echo "TDD 게이트: 차단" >&2
    echo "  대상: $FILE_PATH" >&2
    echo "  사유: .tdd-state 파일 없음" >&2
    echo "  해결: $SC_DIR/scripts/tdd-red.sh 를 먼저 실행하세요" >&2
    exit 2
fi

PHASE=$(jq -r '.phase // "none"' "$SC_STATE_FILE")
RED_COMPLETE=$(jq -r '.red_complete // false' "$SC_STATE_FILE")

# Red 완료 전이면 차단
if [ "$RED_COMPLETE" != "true" ]; then
    echo "TDD 게이트: 차단" >&2
    echo "  대상: $FILE_PATH" >&2
    echo "  현재: phase=$PHASE, red_complete=$RED_COMPLETE" >&2
    echo "  사유: Red 증거가 없는 상태에서 구현 코드 수정 불가" >&2
    echo "  해결: $SC_DIR/scripts/tdd-red.sh 를 먼저 실행하세요" >&2
    exit 2
fi

exit 0
