#!/usr/bin/env bash
set -euo pipefail

# strict-coder 설정 관리
# 사용법: bash .ai/strict-coder/scripts/tdd-config.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SC_DIR/_detect.sh"

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
if [ -z "$PROJECT_ROOT" ]; then
    echo "ERROR: git 저장소 내에서 실행해주세요." >&2
    exit 1
fi

CONFIG_FILE="$PROJECT_ROOT/strict-coder.config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE 파일이 없습니다." >&2
    echo "  해결: bash $SC_DIR/install.sh 를 먼저 실행하세요." >&2
    exit 1
fi

# 현재 설정 로드
load_current() {
    CURRENT_WATCH_PATHS=$(jq -r '.tdd.watch_paths // ["src/"] | .[]' "$CONFIG_FILE")
    CURRENT_TEST_PATTERNS=$(jq -r '.tdd.test_file_patterns // [] | .[]' "$CONFIG_FILE")
    CURRENT_TEST_CMD=$(jq -r '.tdd.test_command // "make test"' "$CONFIG_FILE")
    CURRENT_PROJ_DIR=$(jq -r '.tdd.project_dir // "."' "$CONFIG_FILE")
}

# 현재 설정 출력
show_config() {
    load_current
    echo ""
    echo "=== strict-coder 현재 설정 ==="
    echo ""
    echo "감시 경로 (watch_paths):"
    local i=1
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        echo "  $i) $p"
        i=$((i + 1))
    done <<< "$CURRENT_WATCH_PATHS"

    echo ""
    echo "테스트 파일 패턴 (test_file_patterns):"
    i=1
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        echo "  $i) $p"
        i=$((i + 1))
    done <<< "$CURRENT_TEST_PATTERNS"

    echo ""
    echo "테스트 명령: $CURRENT_TEST_CMD"
    echo "프로젝트 디렉토리: $CURRENT_PROJ_DIR"
    echo ""
}

# watch_paths 편집
edit_watch_paths() {
    load_current

    # 현재 값을 SC_SELECTED_PATHS 배열로 변환
    SC_SELECTED_PATHS=()
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        SC_SELECTED_PATHS+=("$p")
    done <<< "$CURRENT_WATCH_PATHS"

    echo ""
    echo "── 감시 경로 편집 ──"
    _sc_edit_paths

    sc_paths_to_json
    local updated
    updated=$(jq --argjson wp "$SC_PATHS_JSON" '.tdd.watch_paths = $wp' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
    echo "  ✅ watch_paths 저장 완료"
}

# watch_paths 자동 재스캔
rescan_watch_paths() {
    echo ""
    echo "── 감시 경로 재스캔 ──"
    sc_interactive_watch_paths "$PROJECT_ROOT"
    sc_paths_to_json

    local updated
    updated=$(jq --argjson wp "$SC_PATHS_JSON" '.tdd.watch_paths = $wp' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
    echo "  ✅ watch_paths 저장 완료"
}

# test_file_patterns 편집
edit_test_patterns() {
    load_current

    local patterns=()
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        patterns+=("$p")
    done <<< "$CURRENT_TEST_PATTERNS"

    echo ""
    echo "── 테스트 파일 패턴 편집 ──"

    while true; do
        echo ""
        echo "  현재 패턴:"
        local i=1
        for p in "${patterns[@]}"; do
            echo "    $i) $p"
            i=$((i + 1))
        done
        echo ""
        echo "  [a] 추가  [d 번호] 제거  [q] 완료"
        read -rp "  > " cmd arg
        case "$cmd" in
            a)
                read -rp "  추가할 패턴 (정규식): " new_pattern
                if [ -n "$new_pattern" ]; then
                    patterns+=("$new_pattern")
                fi
                ;;
            d)
                if [ -n "$arg" ] && [ "$arg" -ge 1 ] 2>/dev/null && [ "$arg" -le ${#patterns[@]} ]; then
                    local idx=$((arg - 1))
                    patterns=("${patterns[@]:0:$idx}" "${patterns[@]:$((idx+1))}")
                else
                    echo "  잘못된 번호입니다."
                fi
                ;;
            q) break ;;
            *) echo "  a(추가), d 번호(제거), q(완료) 중 선택하세요." ;;
        esac
    done

    # JSON 배열로 변환
    local json="["
    local first=true
    for p in "${patterns[@]}"; do
        if [ "$first" = true ]; then first=false; else json+=","; fi
        json+="\"$p\""
    done
    json+="]"

    local updated
    updated=$(jq --argjson tp "$json" '.tdd.test_file_patterns = $tp' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
    echo "  ✅ test_file_patterns 저장 완료"
}

# 테스트 명령 변경
edit_test_command() {
    load_current
    echo ""
    read -rp "  테스트 실행 명령 (현재: $CURRENT_TEST_CMD): " new_cmd
    if [ -n "$new_cmd" ]; then
        local updated
        updated=$(jq --arg tc "$new_cmd" '.tdd.test_command = $tc' "$CONFIG_FILE")
        echo "$updated" > "$CONFIG_FILE"
        echo "  ✅ test_command 저장 완료"
    else
        echo "  변경 없음"
    fi
}

# 메인 메뉴
main_menu() {
    while true; do
        show_config
        echo "  [w] 감시 경로 편집"
        echo "  [s] 감시 경로 재스캔 (자동감지)"
        echo "  [t] 테스트 파일 패턴 편집"
        echo "  [c] 테스트 명령 변경"
        echo "  [q] 종료"
        echo ""
        read -rp "  선택: " choice
        case "$choice" in
            w) edit_watch_paths ;;
            s) rescan_watch_paths ;;
            t) edit_test_patterns ;;
            c) edit_test_command ;;
            q) echo "종료."; break ;;
            *) echo "  w/s/t/c/q 중 선택하세요." ;;
        esac
    done
}

main_menu
