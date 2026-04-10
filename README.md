<p align="center">
  <h1 align="center">Strict Coder</h1>
  <p align="center">
    <strong>AI 에이전트 거버넌스 하네스</strong>
    <br />
    AI 자율성을 제어하고, TDD를 강제하고, 완료 편향을 억제한다.
  </p>
  <p align="center">
    <a href="#빠른-시작">빠른 시작</a> &middot;
    <a href="#3레이어-tdd-강제">작동 원리</a> &middot;
    <a href="#설정">설정</a> &middot;
    <a href="./README.en.md">English</a>
  </p>
</p>

---

## 문제

LLM은 단계를 건너뛴다. TDD를 따르라고 해도 테스트와 구현을 한 번에 작성한다. 판단 전에 물어보라고 해도 "효율"을 위해 혼자 결정한다. 이것이 **완료 편향(completion bias)** -- 결과물의 신뢰성을 보장하는 프로세스를 우회해서 최단 경로로 완료하려는 경향이다.

프롬프트에 규칙 한 줄 적는 것으로는 부족하다. AI 모델은 우회 경로를 찾는다.

## 해결

Strict Coder는 프롬프트가 아닌 **물리적 제약**으로 Red-Green TDD를 강제하고, 설정 파일로 AI 자율성을 제어하는 **3레이어 하네스**다.

- **L1 Claude Code Hook** -- Red 증거 없이 소스 파일 수정 차단
- **L2 Shell 상태 머신** -- `.tdd-state` 파일로 Red-Green 순서 강제
- **L3 Git Pre-commit** -- Red-Green 사이클 없이 커밋 차단
- **자율성 모드** -- suggest(확인 필수) / drive(자율) / custom
- **학습 프로필** -- learner(항상 비교 설명) / practitioner(요청 시만)

**Red 증거 없으면 소스 파일 수정 불가.**
**Green 증거 없으면 커밋 불가.**
**예외 없음.**

---

## 빠른 시작

```bash
# 1. 프로젝트에 클론
git clone --depth 1 https://github.com/kswift1/strict-coder .ai/strict-coder

# 2. 대화형 설치
bash .ai/strict-coder/install.sh

# 3. 실패하는 테스트를 작성한 뒤:
.ai/strict-coder/scripts/tdd-red.sh --test my_test   # 실패 확인
# ... 구현 ...
.ai/strict-coder/scripts/tdd-green.sh                 # 통과 확인
# ... 커밋 ...
.ai/strict-coder/scripts/tdd-reset.sh                 # 다음 사이클
```

설치 중 소스 디렉토리를 자동으로 감지하고, 테스트 명령과 파일 패턴을 물어봅니다. 감지된 경로를 확인만 하면 끝.

**AI 에이전트가 설치하는 경우:** [`setup-guide.md`](setup-guide.md)를 따라 유저와 대화형으로 설정을 수집한 뒤 설치합니다.

---

## 3레이어 TDD 강제

### 왜 3개인가?

| 레이어 | 차단 시점 | 범위 | 우회 가능 |
|--------|----------|------|----------|
| **L1: Claude Code Hook** | 파일 수정 전 | Claude Code 세션 | 다른 AI 도구, 사람 |
| **L2: Shell 상태 머신** | 스크립트 실행 시 | 모든 AI 도구 | 직접 git commit |
| **L3: Git Pre-commit** | 커밋 시 | 모든 도구 + 사람 | `--no-verify` (의도적) |

각 레이어가 위 레이어의 빈틈을 메운다. 함께 동작하면 빈틈없는 게이트가 된다.

### 레이어 간 의존성

```
L2 (Scripts) ── WRITES ──> .tdd-state
L1 (Hook)    ── READS  ──> .tdd-state ──> blocks Edit/Write
L3 (Git)     ── READS  ──> .tdd-state ──> blocks commit
```

- **L2가 핵심**: 상태를 기록하는 유일한 레이어. 없으면 L1, L3가 읽을 게 없다.
- **L1은 실시간 방어**: 가장 이른 시점에서 차단하지만 Claude Code 전용.
- **L3는 최종 안전망**: 모든 도구에서 동작, 커밋 시점에서 모든 것을 잡는다.

### 작동 흐름

```
Write failing test
       |
       v
+--------------+         +-----------------+
| tdd-red.sh   |-------->|   .tdd-state    |
+------+-------+         | phase: red      |
       |                 | red: true       |
       |                 | green: false    |
       v                 +-----------------+
  L1 gate opens
  (Edit/Write allowed)
       |
       v
  Implement code
       |
       v
+--------------+         +-----------------+
| tdd-green.sh |-------->|   .tdd-state    |
+------+-------+         | phase: green    |
       |                 | red: true       |
       |                 | green: true     |
       v                 +-----------------+
  L3 gate opens
  (commit allowed)
       |
       v
  git commit --> tdd-reset.sh --> next cycle
```

### 상태 파일

3개 레이어 모두 하나의 `.tdd-state` 파일을 통해 소통한다:

```json
{
  "phase": "red",
  "red_complete": true,
  "green_complete": false,
  "last_red_at": "2026-04-07T10:30:00Z",
  "test_command": "cargo test",
  "project_dir": ".",
  "failed_count": 3
}
```

---

## 설정

`install.sh`가 프로젝트 루트에 `strict-coder.config.json`을 생성한다. 설치 시 소스 디렉토리(`src/`, `lib/`, `pkg/`, `internal/` 등)를 자동 감지하여 제안한다.

```json
{
  "tdd": {
    "watch_paths": ["src/"],
    "test_file_patterns": ["_test\\..+$", "/tests/"],
    "test_command": "cargo test",
    "project_dir": "."
  },
  "mode": "suggest",
  "profile": null
}
```

### 설정 변경

설치 후 설정을 변경하려면:

```bash
bash .ai/strict-coder/scripts/tdd-config.sh
```

대화형 메뉴로 감시 경로 추가/제거, 재스캔, 테스트 패턴 편집, 테스트 명령 변경이 가능하다.

### 제약사항

`test_file_patterns`는 **파일 경로** 기반 매칭이다. Rust의 `#[cfg(test)] mod tests { ... }` 같은 인라인 테스트는 구현 파일 안에 있어서 파일 패턴으로 구분할 수 없다. 이 경우 해당 파일은 구현 파일로 취급되며, Red-Green 사이클이 필요하다.

### 언어별 예시

| 언어 | `test_command` | `watch_paths` | `test_file_patterns` |
|------|---------------|---------------|---------------------|
| Rust | `cargo test` | `["src/"]` | `["_test\\.rs$", "/tests/"]` |
| Go | `go test ./...` | `["pkg/", "internal/"]` | `["_test\\.go$"]` |
| Python | `pytest` | `["src/"]` | `["test_.*\\.py$", "/tests/"]` |
| TypeScript | `npm test` | `["src/"]` | `["\\.test\\.ts$", "\\.spec\\.ts$"]` |
| Swift | `swift test` | `["Sources/"]` | `["/Tests/"]` |
| Java | `./gradlew test` | `["src/main/"]` | `["src/test/"]` |

---

## 자율성 모드

AI가 어디까지 혼자 판단하는지 제어한다. 6개 카테고리, 22개 능력.

| 모드 | 행동 |
|------|------|
| **suggest** (기본) | 판단마다 확인. 설정 가능한 13개 능력 전부 확인 필수. |
| **drive** | 사소한 판단은 자율. 방향 전환, 범위 변경, 예외 상황만 물어봄. |

### 전환 방법

자연어로 말하면 된다:

```
suggest로 진행해
Switch to drive mode
커스텀 모드 만들어줘
```

### 능력 매트릭스

**항상 자율 (8개):** 파일 읽기, 코드 검색, 문서 조회, 웹 검색, 네이밍, 지시된 코드 변경, 빌드/테스트 실행, 포매팅.

**항상 확인 필수 (5개):** 대체 도구 선택, 범위 확대/축소, 예외 프로토콜, 요청하지 않은 리팩터링, 관련 없는 버그 수정.

**설정 가능 (13개):**

| # | 능력 | suggest | drive |
|---|------|---------|-------|
| 1 | 모호한 지시 해석 | X | O |
| 2 | 범위 판단 | X | O |
| 3 | 암묵적 요구사항 추론 | X | O |
| 4 | 우선순위 결정 | X | O |
| 5 | 도구/라이브러리 선택 | X | O |
| 6 | 아키텍처/패턴 선택 | X | O |
| 7 | 파일 구조/위치 결정 | X | O |
| 8 | 지시되지 않은 파일 생성 | X | O |
| 9 | 워크플로우 단계 전환 | X | O |
| 10 | 장애물 우회 방법 결정 | X | O |
| 11 | 작업 완료 판단 | X | O |
| 12 | 메모리 저장 | X | O |
| 13 | 관련 문서 업데이트 | X | O |

**O** = 자율 / **X** = 확인 필수

상세: [`modes/suggest.md`](modes/suggest.md), [`modes/drive.md`](modes/drive.md). 커스텀 모드로 조합도 가능.

---

## 학습 프로필

새 언어로 코드를 작성할 때, 익숙한 언어 기반으로 설명하는 방식을 제어한다.

| 프로필 | 대상 | 설명 시점 | 형식 |
|--------|------|----------|------|
| **learner** | 입문자 | 코드 작성마다 | 코드 비교 + 해설 |
| **practitioner** | 기초 이상 | 요청 시만 | 코드 비교만 |

```
// Rust
let name: String = String::from("hello");

// Swift 비교
// let name: String = "hello"
// Rust는 String 리터럴("")이 &str(참조)이라 String으로 변환이 필요하다.
// Swift는 String 리터럴이 곧 String이라 이 구분이 없다.
```

어떤 언어 쌍이든 커스텀 프로필 생성 가능. 상세: [`profiles/README.md`](profiles/README.md).

---

## 프로젝트 구조

```
strict-coder/
├── install.sh                 대화형 설치 (자동감지)
├── setup-guide.md             AI 에이전트 설치 가이드
├── _lib.sh                    공통 설정 로더
├── _detect.sh                 소스 디렉토리 자동 감지
├── strict-coder.config.example
├── hooks/
│   ├── tdd-gate.sh            L1: Claude Code PreToolUse 훅
│   └── pre-commit             L3: Git pre-commit 훅
├── scripts/
│   ├── tdd-red.sh             L2: 테스트 실패 기록
│   ├── tdd-green.sh           L2: 테스트 통과 기록
│   ├── tdd-status.sh          현재 TDD 상태 출력
│   ├── tdd-reset.sh           사이클 초기화
│   └── tdd-config.sh          설정 변경 (감시 경로, 패턴 등)
├── modes/
│   ├── suggest.md             기본: 확인 필수
│   └── drive.md               자율 모드
└── profiles/
    ├── learner.md             입문자 학습 프로필
    └── practitioner.md        중급자 학습 프로필
```

---

## 요구사항

- **bash** 4.0+
- **jq** (macOS 기본 설치, Linux는 `apt install jq`)
- **git**
- **Claude Code** (L1 전용. L2 + L3는 어떤 AI 도구에서든 동작)

## 탄생 배경

[Promiso](https://github.com/kswift1/Promiso) iOS 프로젝트에서 Firebase를 Rust 백엔드로 마이그레이션하는 과정에서 만들어졌다. AI 코딩 에이전트가 명시적 지시에도 불구하고 일관되게 TDD 단계를 건너뛰는 것을 발견한 뒤, 건너뛰기 자체를 물리적으로 불가능하게 만드는 3레이어 강제 아키텍처를 설계했다.

## 라이선스

[MIT](LICENSE)
