# claud-code_day2

## 이 프로젝트의 규칙

- 사용자는 git/GitHub를 직접 다루지 않기를 원합니다. **커밋·푸시를 사용자에게 시키지 마세요.**
- 변경 사항은 `.claude/autosync.ps1`이 커밋하고 푸시합니다. Windows 예약 작업이 30분마다 이걸 실행합니다.
- 작업을 끝낼 때는 "커밋할까요?"라고 묻지 말고, 직접 `.claude/autosync.ps1`을 한 번 실행해서 즉시 반영하세요:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude\autosync.ps1`
- 이 스크립트는 UTF-8 **BOM 포함**으로 저장해야 합니다. BOM이 없으면 Windows PowerShell 5.1이 한글을 깨뜨려 파싱에 실패합니다.
- 되돌리기가 필요하면 `git revert`를 우선 쓰세요. `git reset --hard`와 강제 푸시는 이력을 지우므로 쓰지 마세요.
## 보안 — 이 저장소는 공개(public)입니다

**여기에 올라가는 모든 것은 전 세계에 공개됩니다.** 자동 동기화가 켜져 있으므로 파일을 만드는 순간 곧 공개된다고 생각하세요.

- 비밀키·토큰·비밀번호·개인정보는 **절대** 이 폴더에 두지 마세요. `.gitignore`가 `.env`, `*.key`, `*.pem` 등을 막고 있지만, 새로운 형태의 비밀정보 파일이 생기면 **파일을 만들기 전에** `.gitignore`에 먼저 추가하세요.
- 커밋 작성자 이메일은 GitHub noreply 주소로 설정돼 있습니다. 개인 이메일이 노출되지 않도록 되돌리지 마세요.
- 한 번 푸시된 비밀정보는 이력에서 지워도 이미 수집됐을 수 있습니다. 사고가 나면 해당 키를 **폐기·재발급**하는 것이 유일한 대응입니다.

## 저장소

- GitHub: **공개(public)**, 소유자 `kimjinsol049-pixel`
- 기본 브랜치: `main`
