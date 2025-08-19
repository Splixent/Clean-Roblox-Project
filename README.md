# Seraphs://END

> **totaly not a type soul clone :p.**

---

## Table of Contents
1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Core Libraries](#core-libraries)
4. [Branching Strategy](#branching-strategy)
5. [Commit & Pull‑Request Guidelines](#commit--pull-request-guidelines)
6. [Code Style & Commenting](#code-style--commenting)
7. [Local Setup](#local-setup)
8. [License](#license)

---

## Overview
Describe **what** the project is, **why** it exists, and the high‑level features it offers. Keep it short—readers should grasp the value in under 30 seconds.

---

## Tech Stack
| Layer | Technology |
|-------|------------|
| Engine | **Roblox** (Luau) |
| Data Sync | [**ReplicaService**](https://madstudioroblox.github.io/ReplicaService/api/) |
| Reactive UI | [**Fusion**](https://elttob.uk/Fusion/0.2/api-reference/) |
| Event Bus | [**Red**](https://red.redblox.dev/guide/events/declaring.html) |
| Data Persistence | [**ProfileService**](https://madstudioroblox.github.io/ProfileService/) |

---

## Core Libraries
### [Red](https://red.redblox.dev/guide/events/declaring.html)
Lightweight, type‑safe signal/event framework for Roblox that keeps server–client communication organized.

### [ReplicaService](https://madstudioroblox.github.io/ReplicaService/api/)
Structured, schema‑driven data replication with fine‑grained permissions. Perfect for real‑time, authoritative gameplay state.

### [Fusion](https://elttob.uk/Fusion/0.2/api-reference/)
A declarative, reactive UI engine—build components once; let Fusion handle updates when data changes.

### [ProfileService](https://madstudioroblox.github.io/ProfileService/)
Battle‑tested profile persistence with session locking, write cooldowns, and automatic versioning.

---

## Branching Strategy
We follow a **Git Flow–lite** model to balance stability and rapid iteration.

| Branch | Purpose | Rules |
|--------|---------|-------|
| **main** | Production‑ready releases | • Protected<br>• Only merged via PR from `dev`<br>• Tagged (e.g., `v1.2.0`) |
| **dev** | Ongoing integration | • Default branch for day‑to‑day work<br>• CI must pass before merge into `main` |
| **feature/×××** | New features | • Branch off `dev`<br>• Squash‑merge back into `dev` |
| **hotfix/×××** | Urgent production fixes | • Branch off `main`<br>• PR back into `main` **and** `dev` |

**TL;DR**
1. Create a `feature/your‑topic` branch.
2. Commit iteratively (see commit rules below).
3. Open a PR into `dev`; request review.
4. CI green? -> Merge.
5. Maintainers periodically merge `dev` → `main` when stable.

---

## Commit & Pull‑Request Guidelines
We use the **FFC commit format** — `feat`, `fix`, `chore` — a lightweight subset of Conventional Commits.

```text
<type>(optional-scope): <short, imperative summary>
```

| Type | Use When | Example |
|------|----------|---------|
| **feat** | Introducing **anything new** (features, modules, assets) | `feat: add idle‑summon queue` |
| **fix**  | Repairing **existing** logic or behaviour | `fix(network): resolve packet duplication` |
| **chore**| House‑keeping (CI, tooling, docs, refactor) | `chore: bump rojo to 7.4` |

**Quick Rules**
* Keep the summary ≤ 72 chars.
* Add a body/footer only if it clarifies the change or links issues.
* Scope `(network)` is optional but helpful.

### Pull Requests
* Reference the related issue/task.
* Explain **why** the change matters.
* Ensure tests & linters pass before requesting review.
* One logical change per PR — avoid mega‑PRs.

Screenshots/GIFs are welcome but **not required**.

---

## Code Style & Commenting
* Use **lowerCamelCase** for variables and functions; reserve **PascalCase** for modules and constants.
* Clarity over ceremony — omit type annotations when names & logic already convey intent.
* Comment the **why**, not the **what**.
* If code still feels confusing after good names and comments, **refactor** it.
* Enforced by `luau-lint` in CI.

```lua
-- ✅ Good
local cooldownSeconds = 30 -- 30‑second cooldown prevents spam

-- ❌ Bad
local cd = 30 -- unclear purpose
```

---

## Local Setup
```bash
# 1. Clone the repository
$ git clone https://github.com/your‑org/your‑repo.git
$ cd your‑repo

# 2. Build & run tests
$ rojo build default.project.json
```
All third‑party packages are vendored in the repo, so **no extra installs** are needed.

---

## License
Distributed under the **MIT License**. See `LICENSE` for full text.

---

*Happy coding! 🚀*