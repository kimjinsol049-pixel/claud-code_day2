# 작업 기록

## 2026-09-05 — 스킬 5개 추가와 자동 동기화 복구

### 한 일

1. 작업 절차서 스킬 5개를 만들어 `.claude/skills/`에 넣고 공개 저장소에 올렸다.
2. 그 과정에서 `.claude/autosync.ps1`이 실제로는 동작하지 않는다는 걸 발견하고 고쳤다.

---

## 1. 스킬 5개

| 스킬 | 언제 | 핵심 |
|---|---|---|
| `interview` | 요청이 흐릿할 때 | 최대 3라운드 질문으로 요구사항 문서화. **"이번에 하지 않는 것"을 반드시 받아냄** |
| `define-goal` | 방향은 있는데 기준이 없을 때 | 기준선·목표값·기한·측정법·guardrail이 붙은 목표로 변환 |
| `grillme` | 계획을 검증하고 싶을 때 | 근거를 붙여 혹독하게 반박. 근거 없는 비판 금지, 없는 문제 지어내기 금지 |
| `sdd` | 여러 파일에 걸친 기능·리팩터링 | SPEC → REVIEW → PLAN → BUILD → VERIFY → SYNC |
| `tdd` | 로직 구현·버그 수정 | Red-Green-Refactor |

설계에서 의도적으로 넣은 제약:

- `interview` — 인터뷰가 취조가 되지 않도록 **최대 3라운드**. 남은 불확실성은 "가정"으로 문서에 남기고 진행한다.
- `grillme` — 지적마다 "이 입력 → 이 결과" 형태의 구체적 실패 시나리오를 요구한다. 지적할 게 없으면 억지로 만들지 않는다.
- `define-goal` — **기준선(현재값)을 모르면 그것부터 재는 게 첫 목표.** 기준선 없는 목표는 나중에 성공을 자칭하게 만든다.
- `sdd` — 구현 중 명세와 어긋나면 코드를 몰래 바꾸지 않고 멈춘다.
- `tdd` — **실패를 눈으로 본 적 없는 테스트는 믿지 않는다.** import 오류로 실패한 건 RED가 아니라 그냥 고장이다.

---

## 2. 부딪힌 문제 3가지

### 2-1. `goal`은 예약된 이름이라 스킬이 조용히 무시된다

처음엔 `goal`이라는 이름으로 만들었다. 그런데 **이 스킬만 스킬 목록에 나타나지 않았다.** 오류 메시지도 없었다.

원인: `/goal`은 Claude Code **내장 명령어**다. 내장 명령어와 이름이 겹치는 스킬은 로드되지 않고 건너뛰어진다.

판별 근거 — 공식 문서에 이렇게 적혀 있다:

> The listing always contains every skill name

즉 **이름 자체가 목록에 없으면 로드 실패**다. 설명만 짧아졌다면 그건 listing budget 절삭으로 다른 문제다. 이 한 줄이 "YAML이 깨졌나"와 "이름이 겹쳤나"를 가른다.

`define-goal`로 개명하니 즉시 로드됐다.

> 참고로 처음엔 YAML 인용부호를 의심해서 description을 작은따옴표로 감싸는 헛발질을 했다. 원인이 아니었다.

확인 방법:
- 내장 명령어·번들 스킬 목록: <https://code.claude.com/docs/en/commands>
- 프런트매터 파싱 검증: `claude plugin validate .claude/skills` (v2.1.233+, CLI가 PATH에 있을 때)

### 2-2. git이 무한 대기 — 원인 두 개가 겹쳐 있었다

`.claude/autosync.ps1`을 규칙대로 실행했더니 **20분 넘게 끝나지 않았다.** CPU 0%인 git 프로세스가 30개 넘게 쌓였고 `taskkill /F`로도 죽지 않았다.

**원인 A — 인덱스 락 경합**

이 저장소는 OneDrive로 리디렉션된 `Documents` 아래에 있어 파일 I/O가 느리다. 그 상태에서 편집기가 백그라운드로 돌리는 `git status`가 인덱스를 갱신하며 락을 잡는다. 호출 하나가 길어지고, 수십 개가 겹쳐 서로 물린다.

`--no-optional-locks`를 붙이자 **같은 명령이 3초에 끝났다.**

**원인 B — Windows Credential Manager**

`git push`가 `Pushing to ...`만 찍고 아무 출력 없이 끝나는데 원격에는 반영되지 않았다. 자격증명 창을 띄우려다 멈추는 것인데, 예약 작업에는 띄울 화면이 없다.

gh CLI를 자격증명 헬퍼로 지정해서 해결했다. `gh auth setup-git`만으로는 `credential.helper=manager`가 그대로 남아 해결되지 않았다.

```bash
git --no-optional-locks \
  -c credential.helper= \
  -c 'credential.helper=!"C:/Program Files/GitHub CLI/gh.exe" auth git-credential' \
  push -v origin main
```

### 2-3. PowerShell 5.1이 큰따옴표를 벗겨먹는다

수정한 스크립트를 처음 돌렸을 때 커밋은 됐는데 **푸시만 조용히 실패**했다(`ahead 1`).

원인: Windows PowerShell 5.1은 네이티브 명령에 인자를 넘길 때 **인자 안에 박힌 큰따옴표를 벗겨버린다.** 그래서 헬퍼 값이 이렇게 도착했다.

```
보낸 것:   credential.helper=!"C:/Program Files/GitHub CLI/gh.exe" auth git-credential
도착한 것: credential.helper=!C:/Program Files/GitHub CLI/gh.exe auth git-credential
```

git은 `!` 뒤를 sh로 실행하므로 `C:/Program`을 명령어로 해석한다. 헬퍼가 조용히 실패하고 인증 없이 push가 끝난다.

**작은따옴표로 감싸면 해결된다.** PowerShell은 건드리지 않고, git이 넘기는 sh는 그대로 이해한다.

```powershell
return @('-c', 'credential.helper=', '-c', "credential.helper=!'$p' auth git-credential")
```

---

## 3. autosync.ps1에 적용한 수정

| 문제 | 수정 |
|---|---|
| 인덱스 락 경합으로 무한 대기 | 모든 git 호출에 `--no-optional-locks` + `GIT_OPTIONAL_LOCKS=0` |
| Credential Manager가 push에서 멈춤 | gh CLI를 자격증명 헬퍼로 지정, `GIT_TERMINAL_PROMPT=0` · `GCM_INTERACTIVE=never` |
| 실행이 겹쳐 쌓임 | `.claude/autosync.lock` 단일 인스턴스 잠금. 30분 지난 잠금은 죽은 것으로 보고 정리 |
| 로그 파일이 잠기면 에러 | `Write-Log` 3회 재시도 후 조용히 포기 — 동기화 자체는 계속 |

부수적으로 git 호출을 `Invoke-Git` 래퍼로 모았다. 인자는 **배열로** 넘긴다 — `-m` 같은 값이 PowerShell 함수의 이름 있는 매개변수로 오해받지 않게.

기존 설계 원칙은 유지했다.

- 어떤 경우에도 `exit 0` — 동기화 실패가 사용자 작업을 막지 않는다
- 병합·리베이스·체리픽 진행 중이면 건드리지 않는다
- `git reset --hard`와 강제 푸시는 쓰지 않는다
- UTF-8 **BOM 포함**으로 저장 (BOM이 없으면 PowerShell 5.1이 한글을 깨뜨린다)

### 검증 결과

실제로 실행해서 확인했다.

```
완료: 72초
2026-09-05 13:10:19  커밋+푸시 완료 (1개 파일)
잠금 남았나: False
## main...origin/main
```

20분 넘게 멈추던 것이 **72초에 커밋 → 푸시 → 로그 → 잠금 해제까지 완주**한다.

---

## 4. 로컬 저장소가 통째로 초기화된 사고

작업 도중 로컬 작업 트리가 **`.git`과 `history.md`만 남기고 전부 사라졌다.** 게다가 남아 있던 `.git`도 원래 것이 아니었다.

발견 당시 상태:

```
.git 생성 시각   2026-09-05 13:14:43   (새로 git init 된 것)
objects 개수     0
origin           없음
user.email       t@t.t
브랜치 main      "does not have any commits yet"
```

**원격은 무사했다.** GitHub의 `main`은 그대로였고, 잃은 커밋은 하나도 없다.

### 복구

로컬에 살릴 것이 없었으므로 원격에서 그대로 받아왔다. 이력을 다시 쓰는 작업이 아니라서 `reset --hard` 없이 끝난다.

```powershell
git remote add origin https://github.com/kimjinsol049-pixel/claud-code_day2.git
git --no-optional-locks -c credential.helper= -c "credential.helper=!'C:/Program Files/GitHub CLI/gh.exe' auth git-credential" fetch origin
git --no-optional-locks checkout -B main origin/main
```

`history.md`는 원격에 없는 유일한 파일이라 먼저 따로 복사해두고 진행했다. 추적되지 않는 파일이므로 checkout이 건드리지 않았다.

`user.email`도 `t@t.t`로 바뀌어 있어 GitHub noreply 주소로 되돌렸다.

### 원인

**확실하게 밝히지 못했다.** 확인한 사실만 적는다.

- 사용자 터미널에는 실행 기록이 없었다.
- 원격에 **내가 만들지 않은 커밋** `ecf75be`(13:31:21)가 있었다. 즉 같은 시간대에 **다른 세션이 같은 저장소를 함께 건드리고 있었다.**
- 재초기화 시각(13:14:43)과 그 커밋 시각이 가깝다.

가장 그럴듯한 설명은 동시에 돌던 다른 작업이 이 폴더를 새로 잡았다는 것이지만, 단정할 근거는 없다.

다행히 서로의 수정이 충돌 없이 합쳐졌다. 지금 `autosync.ps1`에는 이 세션의 수정(락·자격증명·단일 인스턴스)과 다른 세션의 `-LiteralPath` 수정이 함께 들어 있다.

### 남는 교훈

**자동 푸시가 걸려 있는 저장소를 여러 세션이 동시에 만지지 않는 게 좋다.** 이 저장소는 30분마다 예약 작업이 돌고 Stop 훅도 걸려 있어서, 두 곳에서 동시에 작업하면 어느 쪽이 무엇을 덮었는지 추적하기 어렵다.

그리고 이번에 아무것도 잃지 않은 이유는 하나다 — **이미 푸시해뒀기 때문이다.**

---

## 5. 커밋

| 커밋 | 내용 |
|---|---|
| `a5b2f1c` | 스킬 5개 추가 |
| `5b01f2e` | `goal` → `define-goal` 개명 (예약 이름 충돌) |
| `f835338` | autosync 수정 1차 + `.gitignore`에 잠금 파일 추가 |
| `76b5dce` | autosync 푸시 실패 수정 (작은따옴표) |
| `ecf75be` | 경로에 대괄호가 있어도 동작하도록 `-LiteralPath` 적용 — **다른 세션의 작업** |

저장소는 이미 public이었다. CLAUDE.md에 "비공개(private)"로 적혀 있던 건 오래된 내용이었고 실제 파일은 갱신돼 있었다.

---

## 6. 아직 안 된 것

**스킬 라우팅 에이전트** — 작업을 요청하면 5개 스킬 중 무엇을, 어떤 순서로, 어떻게 조합해 쓸지 스스로 판단하는 에이전트.

조사를 시작했다가 위 사고 때문에 **중단했다.** 추가 삭제를 막으려고 돌던 작업을 세웠다. 조사하려던 것:

1. Claude Code 서브에이전트 파일 형식의 정확한 스펙과 예약 이름 (2-1에서 겪은 걸 또 겪지 않으려고 문서로 확인)
2. 5개 스킬의 트리거·연계 지점을 읽고 라우팅 정책 설계 — 특히 **"아무 스킬도 쓰지 않는 게 맞는 경우"**(오타 한 줄 수정, 단순 질문)를 명시적으로 포함

과잉 라우팅(사소한 일에 절차를 씌움)과 과소 라우팅(모호한 요청에 바로 코딩)을 둘 다 실패로 보고 각각의 방지 규칙을 넣을 예정이다.
