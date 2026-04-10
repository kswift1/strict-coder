# AI 에이전트 설치 가이드

> AI 에이전트가 strict-coder를 설치할 때 따르는 플로우.
> 유저에게 선택지를 제시하고, 답변을 수집해 config를 생성한 뒤 install.sh를 실행한다.

---

## 전제 조건

- strict-coder가 프로젝트에 클론되어 있어야 한다: `.ai/strict-coder/`
- `jq`, `bash 4.0+`, `git` 필요

---

## 플로우 개요

```
Step 1: 도구 소개
Step 2: 감시 경로 선택 (자동감지 → 확인)
Step 3: 테스트 설정
Step 4: 자율성 모드 선택
Step 5: 학습 프로필 선택
Step 6: config 생성 + install.sh 실행
```

---

## Step 1: 도구 소개

유저에게 아래 내용을 전달한다:

```
strict-coder를 설치합니다.
이 도구는 AI가 TDD(Test-Driven Development) 단계를 건너뛰지 못하게
물리적으로 차단하는 3레이어 하네스입니다.

- Red 증거 없이 소스 파일 수정 불가
- Green 증거 없이 커밋 불가
- 예외 없음
```

---

## Step 2: 감시 경로 선택

### 2-1. 자동감지 실행

프로젝트 루트에서 `_detect.sh`의 `sc_detect_watch_paths()` 로직을 참고해
소스 디렉토리를 스캔한다. 루트 + 1단계 서브디렉토리에서 아래 패턴을 찾는다:

```
src/, lib/, pkg/, internal/, cmd/, app/, packages/, Sources/, src/main/
```

### 2-2. 유저에게 제시

**감지된 경우:**

```
프로젝트를 스캔해서 소스 디렉토리를 찾았습니다:

  1) backend/src/
  2) frontend/src/

이 경로 안의 파일을 수정하려면 TDD 사이클이 필요합니다.

  [Y] 이대로 사용
  [번호] 해당 경로 제거 (예: "2" → frontend/src/ 제거)
  [+경로] 경로 추가 (예: "+lib/")

선택:
```

**감지 안 된 경우:**

```
소스 디렉토리를 자동으로 찾지 못했습니다.
감시할 경로를 입력해주세요 (쉼표 구분):
```

### 2-3. 반복

유저가 제거/추가할 때마다 업데이트된 목록을 보여주고 다시 확인받는다.
`Y` 또는 빈 입력이면 확정.

---

## Step 3: 테스트 설정

### 3-1. 테스트 명령

```
테스트 실행 명령을 선택하세요:

  1) cargo test
  2) go test ./...
  3) pytest
  4) npm test
  5) swift test
  6) ./gradlew test
  7) make test
  8) 직접 입력

선택:
```

프로젝트에 `Cargo.toml`, `go.mod`, `pytest.ini`/`pyproject.toml`, `package.json`,
`Package.swift`, `build.gradle` 등이 있으면 해당 항목을 추천 표시한다.

### 3-2. 테스트 파일 패턴

선택된 언어에 따라 기본값을 제안한다:

```
테스트 파일 패턴 (이 패턴에 매치되는 파일은 TDD 사이클 없이 수정 가능):

  Rust 추천: _test\.rs$, /tests/
  Go 추천: _test\.go$
  Python 추천: test_.*\.py$, /tests/
  TypeScript 추천: \.test\.ts$, \.spec\.ts$

  [Y] 추천값 사용
  [직접 입력] 쉼표 구분 정규식

선택:
```

### 3-3. 프로젝트 디렉토리

테스트 실행 위치. 대부분 `.`(루트)이지만, 모노레포면 다를 수 있다.

```
테스트를 어디서 실행하나요?

  1) . (프로젝트 루트) ← 기본
  2) 직접 입력

선택:
```

---

## Step 4: 자율성 모드 선택

```
AI 자율성 모드를 선택하세요:

  1) suggest (추천) — 판단마다 확인. 안전하지만 느림.
  2) drive — 사소한 판단은 자율. 방향 전환만 물어봄.

선택:
```

---

## Step 5: 학습 프로필 선택

```
새 언어를 배우는 중이면, 익숙한 언어 기준으로 비교 설명을 드릴 수 있습니다.

  1) 사용 안 함 ← 기본
  2) learner — 코드 작성마다 비교 설명
  3) practitioner — 요청 시에만 비교
  4) 커스텀 생성

선택:
```

### 2~3 선택 시 추가 질문:

```
익숙한 언어: (예: Swift, Python, TypeScript)
타겟 언어: (예: Rust, Go, Kotlin)
```

### 4 선택 시:

profiles/README.md 의 5개 설정을 순서대로 물어본다:
1. 익숙한 언어 숙련도 (주니어/시니어)
2. 새 언어 경험 수준 (입문/기초/중급)
3. 비교 설명 범위 (문법만/+패턴/+생태계)
4. 설명 시점 (항상/요청 시)
5. 설명 형식 (코드 비교/텍스트/코드+텍스트)

---

## Step 6: config 생성 + 설치

### 6-1. 확인

수집한 설정을 요약해서 보여준다:

```
설정 요약:
  감시 경로: backend/src/
  테스트 명령: cargo test
  테스트 패턴: _test\.rs$, /tests/
  실행 디렉토리: .
  모드: suggest
  프로필: learner (Swift → Rust)

  [Y] 설치 진행
  [n] 처음부터 다시

선택:
```

### 6-2. config 파일 생성

`strict-coder.config.json`을 프로젝트 루트에 생성한다:

```json
{
  "tdd": {
    "watch_paths": ["backend/src/"],
    "test_file_patterns": ["_test\\.rs$", "/tests/"],
    "test_command": "cargo test",
    "project_dir": "."
  },
  "mode": "suggest",
  "profile": "learner"
}
```

### 6-3. install.sh 실행

```bash
bash .ai/strict-coder/install.sh
```

config가 이미 존재하므로 step 0이 자동 스킵된다.
나머지 step 1~5 (hooks, Claude Code 훅, .gitignore, 권한, 검증)이 자동 실행된다.

### 6-4. hooksPath 충돌 대비

install.sh 실행 전에 아래를 확인한다:

```bash
git config --get core.hooksPath
```

기존 값이 있으면 유저에게 알린다:

```
기존 git hooks 경로가 설정되어 있습니다: .husky
strict-coder 훅으로 교체하면 기존 훅이 무시됩니다.

  [Y] 교체
  [n] 취소

선택:
```

`Y`면 install.sh 실행 (자동으로 덮어씀).
`n`이면 설치를 중단하고, 수동 통합 방법을 안내한다.

### 6-5. 완료 메시지

```
strict-coder 설치 완료!

TDD 사이클:
  1. 실패하는 테스트 작성
  2. tdd-red.sh 실행 (실패 확인)
  3. 구현
  4. tdd-green.sh 실행 (통과 확인)
  5. 커밋
  6. tdd-reset.sh (다음 사이클)

설정 변경: bash .ai/strict-coder/scripts/tdd-config.sh
```

---

## 핵심 원칙

1. **묻고 진행한다.** 추측하지 않는다.
2. **선택지를 준다.** 자유 입력보다 번호 선택을 우선한다.
3. **기본값을 제안한다.** 유저가 엔터만 쳐도 합리적인 설정이 되어야 한다.
4. **요약 후 확인한다.** 설치 전에 반드시 전체 설정을 보여주고 확인받는다.
