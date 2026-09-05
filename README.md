# claud-code_day2

## 이 저장소에 대해

작업 내용이 **자동으로 GitHub에 백업되는** 프로젝트입니다.
커밋이나 푸시를 직접 신경 쓸 필요가 없습니다.

## 자동 동기화가 언제 동작하나

| 상황 | 동작 |
|---|---|
| Claude Code에서 작업이 끝날 때 | 변경분을 커밋하고 GitHub에 푸시 |
| 직접 `git commit` 했을 때 | 푸시를 깜빡해도 자동으로 올라감 |
| 다른 편집기로 작업했을 때 | 30분마다 훑어서 변경분이 있으면 자동 반영 |

동기화 기록은 `.claude/autosync.log`에 남습니다. (이 파일 자체는 GitHub에 올라가지 않습니다.)

## 문제가 생겼을 때 되돌리는 법

```bash
git log --oneline
```

원하는 시점의 코드를 꺼내 보려면:

```bash
git checkout <커밋해시> -- .
```

전체를 그 시점으로 완전히 되돌리려면:

```bash
git revert --no-edit <커밋해시>
```

`revert`는 되돌린 사실 자체도 이력으로 남기기 때문에 안전합니다.

## 자동 동기화를 끄고 싶을 때

Windows 예약 작업만 제거:

```powershell
Unregister-ScheduledTask -TaskName "ClaudeCode-AutoSync-claud-code_day2" -Confirm:$false
```

Claude Code 세션 종료 시 동기화도 끄려면 `.claude/settings.json`의 `hooks` 항목을 지우면 됩니다.
