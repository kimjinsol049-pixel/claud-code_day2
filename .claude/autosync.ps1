# 프로젝트의 변경분을 자동으로 커밋하고 GitHub에 푸시합니다.
# 호출되는 곳: Claude Code Stop 훅, Windows 예약 작업(30분마다), 수동 실행
# 설계 원칙: 어떤 경우에도 exit 0 — 동기화 실패가 사용자의 작업을 막지 않도록.

$repo = Split-Path -Parent $PSScriptRoot
$log = Join-Path $PSScriptRoot 'autosync.log'

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $log -Encoding utf8
}

try {
    Set-Location $repo

    # git 저장소가 아니면 조용히 종료
    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) { exit 0 }

    # 병합/리베이스/체리픽 진행 중이면 절대 건드리지 않는다 (사용자 작업을 망가뜨림)
    $gitDir = git rev-parse --git-dir
    foreach ($marker in 'MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'rebase-merge', 'rebase-apply') {
        if (Test-Path (Join-Path $gitDir $marker)) {
            Write-Log "건너뜀 - $marker 진행 중"
            exit 0
        }
    }

    $changes = @(git status --porcelain | Where-Object { $_.Trim() })

    if ($changes.Count -eq 0) {
        # 변경은 없지만 아직 안 올라간 커밋이 남아 있을 수 있다
        $ahead = git rev-list --count '@{u}..HEAD' 2>$null
        if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
            git push *> $null
            if ($LASTEXITCODE -eq 0) { Write-Log "밀린 커밋 $ahead 개 푸시 완료" }
            else { Write-Log "푸시 실패 (네트워크?) - 다음 기회에 재시도" }
        }
        exit 0
    }

    git add -A
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    git commit -m "auto: $stamp ($($changes.Count)개 파일)" --no-verify *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Log "커밋할 것이 없음 (무시된 파일만 변경)"
        exit 0
    }

    git push *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "커밋+푸시 완료 ($($changes.Count)개 파일)"
    }
    else {
        Write-Log "커밋은 됐으나 푸시 실패 - 다음 동기화 때 자동 재시도"
    }
}
catch {
    Write-Log "오류: $($_.Exception.Message)"
}

exit 0
