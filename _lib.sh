#!/usr/bin/env bash
# strict-coder/_lib.sh — 공통 설정 로더
# Source this from any strict-coder script:
#   source "$(dirname "$0")/../_lib.sh"
# shellcheck disable=SC2034  # 변수들은 source하는 스크립트에서 사용됨

# 프로젝트 루트 탐지
SC_PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
if [ -z "$SC_PROJECT_ROOT" ]; then
    echo "ERROR: git 저장소를 찾을 수 없습니다." >&2
    exit 1
fi

# strict-coder 디렉토리
SC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 설정 파일
SC_CONFIG="$SC_PROJECT_ROOT/strict-coder.config.json"

# 상태 파일
SC_STATE_FILE="$SC_PROJECT_ROOT/.tdd-state"

# 설정 로드
if [ ! -f "$SC_CONFIG" ]; then
    echo "ERROR: $SC_CONFIG 파일이 없습니다." >&2
    echo "  해결: bash $SC_DIR/install.sh 를 먼저 실행하세요." >&2
    exit 1
fi

# 설정값 로드
SC_TEST_COMMAND=$(jq -r '.tdd.test_command // "make test"' "$SC_CONFIG")
SC_PROJECT_DIR=$(jq -r '.tdd.project_dir // "."' "$SC_CONFIG")
SC_WATCH_PATHS=$(jq -r '.tdd.watch_paths // ["src/"] | .[]' "$SC_CONFIG")
SC_TEST_FILE_PATTERNS=$(jq -r '.tdd.test_file_patterns // [] | .[]' "$SC_CONFIG")

# Helper: 경로가 watch_paths에 매치되는지
sc_matches_watch_path() {
    local file_path="$1"
    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        if [[ "$file_path" == *"$pattern"* ]]; then
            return 0
        fi
    done <<< "$SC_WATCH_PATHS"
    return 1
}

# Helper: 테스트 파일인지
sc_is_test_file() {
    local file_path="$1"
    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        if echo "$file_path" | grep -qE "$pattern"; then
            return 0
        fi
    done <<< "$SC_TEST_FILE_PATTERNS"
    return 1
}
