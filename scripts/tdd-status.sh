#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD 상태 확인

source "$(dirname "$0")/../_lib.sh"

if [ ! -f "$SC_STATE_FILE" ]; then
    echo "📋 TDD 상태: 없음 (사이클 시작 전)"
    exit 0
fi

PHASE=$(jq -r '.phase' "$SC_STATE_FILE")
RED_COMPLETE=$(jq -r '.red_complete' "$SC_STATE_FILE")
GREEN_COMPLETE=$(jq -r '.green_complete' "$SC_STATE_FILE")
LAST_RED=$(jq -r '.last_red_at // "없음"' "$SC_STATE_FILE")
LAST_GREEN=$(jq -r '.last_green_at // "없음"' "$SC_STATE_FILE")
TEST_CMD=$(jq -r '.test_command // "없음"' "$SC_STATE_FILE")
TEST_ARGS=$(jq -r '.test_args // "없음"' "$SC_STATE_FILE")
FAILED=$(jq -r '.failed_count // 0' "$SC_STATE_FILE")

echo "📋 TDD 상태"
echo "  phase:          $PHASE"
echo "  red_complete:   $RED_COMPLETE"
echo "  green_complete: $GREEN_COMPLETE"
echo "  last_red_at:    $LAST_RED"
echo "  last_green_at:  $LAST_GREEN"
echo "  test_command:   $TEST_CMD"
echo "  test_args:      $TEST_ARGS"
echo "  failed_count:   $FAILED"
