# 프로젝트의 변경분을 자동으로 커밋하고 GitHub에 푸시합니다.
# 호출되는 곳: Claude Code Stop 훅, Windows 예약 작업(30분마다), 수동 실행
# 설계 원칙: 어떤 경우에도 exit 0 — 동기화 실패가 사용자의 작업을 막지 않도록.

$repo = Split-Path -Parent $PSScriptRoot
$log = Join-Path $PSScriptRoot 'autosync.log'
$lock = Join-Path $PSScriptRoot 'autosync.lock'

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $log -Encoding utf8
}

# --- git이 멈추지 않게 하는 설정 -----------------------------------------------
# 이 저장소는 OneDrive로 리디렉션된 Documents 아래에 있어 파일 I/O가 느리다.
# 그 상태에서 아래 두 가지가 겹치면 git이 응답 없이 무한 대기한다.
#
# 1) 인덱스 락 경합 — 편집기가 백그라운드로 돌리는 git status가 인덱스를 갱신하며
#    락을 잡는다. 느린 I/O 탓에 호출 하나가 길어지고, 수십 개가 겹쳐 서로 물린다.
#    (실제로 CPU 0%인 git 프로세스가 30개 넘게 쌓여 taskkill /F로도 안 죽었다.)
#    -> --no-optional-locks 로 인덱스 락을 아예 잡지 않게 한다. 같은 명령이 3초에 끝난다.
#
# 2) Windows Credential Manager — push에서 자격증명 창을 띄우려다 멈춘다.
#    예약 작업에는 띄울 화면이 없으므로 영원히 기다린다. "Pushing to ..."만 찍고
#    아무 출력 없이 끝나며 원격에는 반영되지 않는다.
#    -> gh CLI를 자격증명 헬퍼로 지정하고, 터미널 프롬프트도 막는다.
$env:GIT_OPTIONAL_LOCKS = '0'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'never'

$gitCommon = @('--no-optional-locks')

# git 호출은 전부 이걸 거친다. 인자는 배열로 넘긴다 — 이름 있는 매개변수로 오해받지 않게.
function Invoke-Git([string[]]$GitArgs) {
    & git @gitCommon @GitArgs
}

# gh CLI 경로. PATH에 없는 경우가 흔해서 설치 위치도 훑는다. 없으면 $null.
function Get-GhPath {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe') }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'GitHub CLI\gh.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe') }

    return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# push 앞에만 붙이는 자격증명 옵션.
# 첫 번째 -c 가 기존 헬퍼 목록을 비우고, 두 번째가 gh를 대신 세운다.
# gh가 없으면 빈 배열 — 원래 설정 그대로 시도한다(성공할 수도 있으므로 막지는 않는다).
function Get-PushArgs {
    $gh = Get-GhPath
    if (-not $gh) { return @() }
    $p = $gh.Replace('\', '/')
    return @('-c', 'credential.helper=', '-c', "credential.helper=!`"$p`" auth git-credential")
}

function Sync-Repo {
    Set-Location $repo

    # git 저장소가 아니면 조용히 종료
    Invoke-Git @('rev-parse', '--is-inside-work-tree') *> $null
    if ($LASTEXITCODE -ne 0) { return }

    # 병합/리베이스/체리픽 진행 중이면 절대 건드리지 않는다 (사용자 작업을 망가뜨림)
    $gitDir = Invoke-Git @('rev-parse', '--git-dir')
    foreach ($marker in 'MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'rebase-merge', 'rebase-apply') {
        if (Test-Path (Join-Path $gitDir $marker)) {
            Write-Log "건너뜀 - $marker 진행 중"
            return
        }
    }

    $changes = @(Invoke-Git @('status', '--porcelain') | Where-Object { $_.Trim() })

    if ($changes.Count -eq 0) {
        # 변경은 없지만 아직 안 올라간 커밋이 남아 있을 수 있다
        $ahead = Invoke-Git @('rev-list', '--count', '@{u}..HEAD') 2>$null
        if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
            $pushArgs = (Get-PushArgs) + @('push')
            Invoke-Git $pushArgs *> $null
            if ($LASTEXITCODE -eq 0) { Write-Log "밀린 커밋 $ahead 개 푸시 완료" }
            else { Write-Log "푸시 실패 (네트워크?) - 다음 기회에 재시도" }
        }
        return
    }

    Invoke-Git @('add', '-A') *> $null
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    Invoke-Git @('commit', '-m', "auto: $stamp ($($changes.Count)개 파일)", '--no-verify') *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Log "커밋할 것이 없음 (무시된 파일만 변경)"
        return
    }

    $pushArgs = (Get-PushArgs) + @('push')
    Invoke-Git $pushArgs *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "커밋+푸시 완료 ($($changes.Count)개 파일)"
    }
    else {
        Write-Log "커밋은 됐으나 푸시 실패 - 다음 동기화 때 자동 재시도"
    }
}

# --- 겹쳐 실행 방지 ------------------------------------------------------------
# 예약 작업(30분마다) · Stop 훅 · 수동 실행이 서로 겹칠 수 있다. 한 번에 하나만 돈다.
# 이게 없으면 한 번 느려졌을 때 실행이 쌓이면서 서로를 더 느리게 만든다.
if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalMinutes -lt 30) { exit 0 }
    Write-Log "오래된 잠금 파일 제거 ($([int]$age.TotalMinutes)분 경과)"
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}

try { New-Item -ItemType File -Path $lock -ErrorAction Stop | Out-Null }
catch { exit 0 }

try {
    Sync-Repo
}
catch {
    Write-Log "오류: $($_.Exception.Message)"
}
finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}

exit 0
