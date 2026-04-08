#!/usr/bin/env bash
# strict-coder/_detect.sh — 프로젝트 소스 디렉토리 자동 감지
# install.sh와 tdd-config.sh에서 공통으로 source
# shellcheck disable=SC2034  # 변수들은 source하는 스크립트에서 사용됨

# 알려진 소스 디렉토리 패턴
_SC_KNOWN_SRC_DIRS=(
    "src/"
    "lib/"
    "pkg/"
    "internal/"
    "cmd/"
    "app/"
    "packages/"
    "Sources/"
    "src/main/"
)

# 프로젝트 루트에서 소스 디렉토리 후보를 감지한다.
# 결과를 SC_DETECTED_PATHS 배열에 저장.
# 인수: $1 = 프로젝트 루트 경로
sc_detect_watch_paths() {
    local project_root="$1"
    SC_DETECTED_PATHS=()

    for pattern in "${_SC_KNOWN_SRC_DIRS[@]}"; do
        if [ -d "$project_root/$pattern" ]; then
            SC_DETECTED_PATHS+=("$pattern")
        fi
    done
}

# 대화형 감시 경로 선택 플로우.
# 결과를 SC_SELECTED_PATHS 배열에 저장.
# 인수: $1 = 프로젝트 루트 경로
sc_interactive_watch_paths() {
    local project_root="$1"
    SC_SELECTED_PATHS=()

    sc_detect_watch_paths "$project_root"

    if [ ${#SC_DETECTED_PATHS[@]} -gt 0 ]; then
        echo "  감시 대상 경로 자동 감지:"
        local i=1
        for p in "${SC_DETECTED_PATHS[@]}"; do
            echo "    $i) $p"
            i=$((i + 1))
        done
        echo ""
        echo "  [Y] 이대로 사용  [e] 편집 (추가/제거)  [m] 직접 입력"
        read -rp "  선택 (Y/e/m): " choice
        choice="${choice:-Y}"

        case "$choice" in
            [Yy]*)
                SC_SELECTED_PATHS=("${SC_DETECTED_PATHS[@]}")
                ;;
            [Ee]*)
                SC_SELECTED_PATHS=("${SC_DETECTED_PATHS[@]}")
                _sc_edit_paths
                ;;
            [Mm]*)
                _sc_manual_input
                ;;
            *)
                SC_SELECTED_PATHS=("${SC_DETECTED_PATHS[@]}")
                ;;
        esac
    else
        echo "  소스 디렉토리를 자동 감지하지 못했습니다."
        _sc_manual_input
    fi
}

# 편집 모드: 현재 목록에서 추가/제거
_sc_edit_paths() {
    while true; do
        echo ""
        echo "  현재 감시 경로:"
        local i=1
        for p in "${SC_SELECTED_PATHS[@]}"; do
            echo "    $i) $p"
            i=$((i + 1))
        done
        echo ""
        echo "  [a] 추가  [d 번호] 제거  [q] 완료"
        read -rp "  > " cmd arg
        case "$cmd" in
            a)
                read -rp "  추가할 경로: " new_path
                if [ -n "$new_path" ]; then
                    SC_SELECTED_PATHS+=("$new_path")
                fi
                ;;
            d)
                if [ -n "$arg" ] && [ "$arg" -ge 1 ] 2>/dev/null && [ "$arg" -le ${#SC_SELECTED_PATHS[@]} ]; then
                    local idx=$((arg - 1))
                    SC_SELECTED_PATHS=("${SC_SELECTED_PATHS[@]:0:$idx}" "${SC_SELECTED_PATHS[@]:$((idx+1))}")
                else
                    echo "  잘못된 번호입니다."
                fi
                ;;
            q)
                break
                ;;
            *)
                echo "  a(추가), d 번호(제거), q(완료) 중 선택하세요."
                ;;
        esac
    done

    if [ ${#SC_SELECTED_PATHS[@]} -eq 0 ]; then
        echo "  ⚠️  감시 경로가 비어있습니다. 최소 1개 필요합니다."
        _sc_manual_input
    fi
}

# 직접 입력 모드
_sc_manual_input() {
    read -rp "  감시 대상 경로 (쉼표 구분, 기본: src/): " input
    input="${input:-src/}"

    IFS=',' read -ra raw_paths <<< "$input"
    SC_SELECTED_PATHS=()
    for p in "${raw_paths[@]}"; do
        # 앞뒤 공백 제거
        p="$(echo "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -n "$p" ] && SC_SELECTED_PATHS+=("$p")
    done
}

# SC_SELECTED_PATHS 배열을 jq용 JSON 배열 문자열로 변환
# 결과: SC_PATHS_JSON (예: '["src/","lib/"]')
sc_paths_to_json() {
    local json="["
    local first=true
    for p in "${SC_SELECTED_PATHS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            json+=","
        fi
        json+="\"$p\""
    done
    json+="]"
    SC_PATHS_JSON="$json"
}
