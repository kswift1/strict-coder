<p align="center">
  <h1 align="center">Strict Coder</h1>
  <p align="center">
    <strong>AI Agent Governance Harness</strong>
    <br />
    Control AI autonomy. Enforce TDD. Prevent completion bias.
  </p>
  <p align="center">
    <a href="#quick-start">Quick Start</a> &middot;
    <a href="#three-layer-tdd-enforcement">How It Works</a> &middot;
    <a href="#configuration">Configuration</a> &middot;
    <a href="./README.md">한국어</a>
  </p>
</p>

---

## The Problem

LLMs skip steps. When told to follow TDD, they write the test *and* the implementation in one shot. When told to ask before deciding, they decide anyway "for efficiency." This is **completion bias** -- the tendency to reach the finish line by the shortest path, bypassing the process that makes the output trustworthy.

A single rule in a prompt is not enough. AI models find workarounds.

## The Solution

Strict Coder is a **three-layer harness** that physically enforces Red-Green TDD and controls AI autonomy through configuration, not prompting.

- **L1 Claude Code Hook** -- blocks source file edits without Red evidence
- **L2 Shell State Machine** -- enforces Red-Green order via `.tdd-state`
- **L3 Git Pre-commit** -- blocks commit without Red-Green cycle
- **Autonomy Modes** -- suggest (confirmation required) / drive (autonomous) / custom
- **Learning Profiles** -- learner (always explain) / practitioner (on request)

**No Red evidence? Can't edit source files.**
**No Green evidence? Can't commit.**
**No exceptions.**

---

## Quick Start

```bash
# 1. Clone into your project
git clone --depth 1 https://github.com/kswift1/strict-coder .ai/strict-coder

# 2. Run interactive installer
bash .ai/strict-coder/install.sh

# 3. Write a failing test, then:
.ai/strict-coder/scripts/tdd-red.sh --test my_test   # Confirm failure
# ... implement ...
.ai/strict-coder/scripts/tdd-green.sh                 # Confirm pass
# ... commit ...
.ai/strict-coder/scripts/tdd-reset.sh                 # Next cycle
```

The installer auto-detects source directories and asks for your test command and file patterns. Just confirm the detected paths and you're done.

**For AI agent installation:** follow [`setup-guide.md`](setup-guide.md) to collect settings from the user conversationally, then run the installer.

---

## Three-Layer TDD Enforcement

### Why three layers?

| Layer | Blocks at | Scope | Bypassed by |
|-------|-----------|-------|-------------|
| **L1: Claude Code Hook** | File edit | Claude Code sessions | Other AI tools, humans |
| **L2: Shell State Machine** | Script execution | All AI tools | Direct git commit |
| **L3: Git Pre-commit** | Commit | Everyone | `--no-verify` (intentional) |

Each layer covers the gap of the one above. Together, they form an airtight gate.

### Layer dependencies

```
L2 (Scripts) ── WRITES ──> .tdd-state
L1 (Hook)    ── READS  ──> .tdd-state ──> blocks Edit/Write
L3 (Git)     ── READS  ──> .tdd-state ──> blocks commit
```

- **L2 is the core**: the only layer that writes state. Without it, L1 and L3 have nothing to read.
- **L1 is real-time defense**: blocks at the earliest point, but Claude Code only.
- **L3 is the universal safety net**: works with any tool, catches everything at commit time.

### How it works

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

### State file

All three layers communicate through a single `.tdd-state` file:

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

## Configuration

`install.sh` creates `strict-coder.config.json` at your project root. During installation, it auto-detects source directories (`src/`, `lib/`, `pkg/`, `internal/`, etc.) and proposes them as watch paths.

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

### Changing configuration

To modify settings after installation:

```bash
bash .ai/strict-coder/scripts/tdd-config.sh
```

Interactive menu for adding/removing watch paths, rescanning, editing test patterns, and changing the test command.

### Limitations

`test_file_patterns` matches against **file paths**. Inline tests like Rust's `#[cfg(test)] mod tests { ... }` live inside implementation files and cannot be distinguished by file patterns. Such files are treated as implementation files and require the Red-Green cycle.

### Language examples

| Language | `test_command` | `watch_paths` | `test_file_patterns` |
|----------|---------------|---------------|---------------------|
| Rust | `cargo test` | `["src/"]` | `["_test\\.rs$", "/tests/"]` |
| Go | `go test ./...` | `["pkg/", "internal/"]` | `["_test\\.go$"]` |
| Python | `pytest` | `["src/"]` | `["test_.*\\.py$", "/tests/"]` |
| TypeScript | `npm test` | `["src/"]` | `["\\.test\\.ts$", "\\.spec\\.ts$"]` |
| Swift | `swift test` | `["Sources/"]` | `["/Tests/"]` |
| Java | `./gradlew test` | `["src/main/"]` | `["src/test/"]` |

---

## Autonomy Modes

Control how much the AI decides on its own. 22 capabilities across 6 categories.

| Mode | Behavior |
|------|----------|
| **suggest** (default) | Asks before every judgment call. All 13 configurable capabilities require confirmation. |
| **drive** | Autonomous for minor decisions. Only asks for direction changes, scope shifts, or exceptions. |

### Switching

Tell the AI in natural language:

```
Switch to drive mode
이번 작업은 suggest로 진행해
Create a custom mode
```

### Capability matrix

**Always autonomous (8):** file reading, code search, docs, web search, naming, instructed changes, build/test, formatting.

**Always requires confirmation (5):** substitute tool selection, scope changes, exception protocol, unrequested refactoring, unrelated bug fixes.

**Configurable (13):**

| # | Capability | suggest | drive |
|---|-----------|---------|-------|
| 1 | Ambiguous instruction interpretation | X | O |
| 2 | Scope judgment | X | O |
| 3 | Implicit requirement inference | X | O |
| 4 | Priority decision | X | O |
| 5 | Tool/library selection | X | O |
| 6 | Architecture/pattern selection | X | O |
| 7 | File structure/location | X | O |
| 8 | Uninstructed file creation | X | O |
| 9 | Workflow phase transition | X | O |
| 10 | Obstacle workaround | X | O |
| 11 | Work completion judgment | X | O |
| 12 | Memory saving | X | O |
| 13 | Related doc updates | X | O |

**O** = autonomous / **X** = requires confirmation

See [`modes/suggest.md`](modes/suggest.md) and [`modes/drive.md`](modes/drive.md) for details. Custom modes let you mix and match.

---

## Learning Profiles

Control how the AI explains new-language code using your familiar language as reference.

| Profile | Target | Explains | Format |
|---------|--------|----------|--------|
| **learner** | Beginners | Every code block | Side-by-side code + commentary |
| **practitioner** | Intermediate+ | On request only | Code diff only |

```
// Rust
let name: String = String::from("hello");

// Swift comparison
// let name: String = "hello"
// Rust string literals ("") are &str (reference), requiring
// explicit conversion to String. Swift literals are String directly.
```

Create custom profiles with any language pair. See [`profiles/README.md`](profiles/README.md).

---

## Project structure

```
strict-coder/
├── install.sh                 Interactive setup (auto-detect)
├── setup-guide.md             AI agent installation guide
├── _lib.sh                    Shared config loader
├── _detect.sh                 Source directory auto-detection
├── strict-coder.config.example
├── hooks/
│   ├── tdd-gate.sh            L1: Claude Code PreToolUse hook
│   └── pre-commit             L3: Git pre-commit hook
├── scripts/
│   ├── tdd-red.sh             L2: Record test failure
│   ├── tdd-green.sh           L2: Record test pass
│   ├── tdd-status.sh          Show current TDD state
│   ├── tdd-reset.sh           Reset for new cycle
│   └── tdd-config.sh          Configuration management
├── modes/
│   ├── suggest.md             Default: confirmation required
│   └── drive.md               Autonomous mode
└── profiles/
    ├── learner.md             Beginner learning profile
    └── practitioner.md        Intermediate learning profile
```

---

## Requirements

- **bash** 4.0+
- **jq** (pre-installed on macOS, `apt install jq` on Linux)
- **git**
- **Claude Code** (for Layer 1 only; L2 + L3 work with any AI tool)

## Origin

Built during a Firebase-to-Rust backend migration on the [Promiso](https://github.com/kswift1/Promiso) iOS project. After discovering that AI coding agents consistently bypassed TDD steps despite explicit instructions, this three-layer enforcement architecture was designed to make skipping physically impossible.

## License

[MIT](LICENSE)
