# claud-code_day2

## 이 프로젝트의 규칙

- 사용자는 git/GitHub를 직접 다루지 않기를 원합니다. 커밋·푸시를 사용자에게 시키지 마세요.
- 변경 사항은 `.claude/autosync.ps1`이 자동으로 커밋하고 푸시합니다 (Stop 훅 + 30분 예약 작업).
- 따라서 작업 후 "커밋할까요?"라고 묻지 말고, 그냥 작업을 끝내면 됩니다. 훅이 처리합니다.
- 되돌리기가 필요하면 `git revert`를 우선 쓰세요. `git reset --hard`와 강제 푸시는 이력을 지우므로 쓰지 마세요.
- 비밀키·토큰·`.env`는 `.gitignore`로 막혀 있습니다. 새로운 비밀정보 파일이 생기면 먼저 `.gitignore`에 추가하세요.

## 저장소

- GitHub: 비공개(private) 저장소, 소유자 `kimjinsol049-pixel`
- 기본 브랜치: `main`
