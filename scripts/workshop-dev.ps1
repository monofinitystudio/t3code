# House T3 workshop server. Isolated from Nightly (:3773 / ~/.t3/userdata).
# Usage: workshop-dev.ps1 start|stop|restart|status
param(
  [Parameter(Position = 0)]
  [ValidateSet('start', 'stop', 'restart', 'status')]
  [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$Repo = 'C:\p\t3code'
$HomeDir = Join-Path $env:USERPROFILE '.t3\syqo-fork-dev'
$LogDir = Join-Path $Repo '.logs'
$Log = Join-Path $LogDir 'syqo-fork-dev.log'
$Port = 3873
$NightlyPort = 3773
$Runtime = Join-Path $HomeDir 'userdata\server-runtime.json'

function Get-ListenerPid([int]$ListenPort) {
  $conn = Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($conn) { return [int]$conn.OwningProcess }
  return $null
}

function Test-Health([int]$ListenPort) {
  try {
    $r = Invoke-RestMethod "http://127.0.0.1:$ListenPort/.well-known/t3/environment" -TimeoutSec 3
    return $r
  } catch {
    return $null
  }
}

function Get-WorkshopPid {
  if (Test-Path $Runtime) {
    try {
      $j = Get-Content $Runtime -Raw | ConvertFrom-Json
      if ($j.pid -and (Get-Process -Id $j.pid -ErrorAction SilentlyContinue)) {
        return [int]$j.pid
      }
    } catch {}
  }
  return Get-ListenerPid $Port
}

function Show-Status {
  $nightly = Test-Health $NightlyPort
  $fork = Test-Health $Port
  $pidValue = Get-WorkshopPid
  Write-Output "Nightly :$NightlyPort  $(if ($nightly) { 'UP ' + $nightly.serverVersion } else { 'DOWN' })"
  Write-Output "Workshop :$Port  $(if ($fork) { 'UP ' + $fork.serverVersion } else { 'DOWN' }) pid=$pidValue"
  if (Test-Path $Runtime) {
    Write-Output "runtime $((Get-Content $Runtime -Raw).Trim())"
  }
}

function Stop-Workshop {
  $pidValue = Get-WorkshopPid
  if (-not $pidValue) {
    Write-Output 'Workshop not running'
    return
  }
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pidValue" -ErrorAction SilentlyContinue
  $cmd = if ($proc) { [string]$proc.CommandLine } else { '' }
  $ok = ($cmd -match 'syqo-fork-dev') -or ($cmd -match [regex]::Escape($Repo)) -or ($cmd -match 'dev-runner')
  if (-not $ok) {
    throw "Refusing to stop pid $pidValue — command line does not look like the workshop: $cmd"
  }
  Write-Output "Stopping workshop pid $pidValue"
  Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
  $deadline = (Get-Date).AddSeconds(15)
  while ((Get-Date) -lt $deadline) {
    if (-not (Get-ListenerPid $Port)) { break }
    Start-Sleep -Milliseconds 300
  }
}

function Start-Workshop {
  if (Test-Health $Port) {
    Write-Output 'Workshop already up'
    Show-Status
    return
  }
  New-Item -ItemType Directory -Force -Path $HomeDir, $LogDir | Out-Null
  $envFile = Join-Path $Repo '.env'
  if (-not (Test-Path $envFile)) {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    Set-Content -Path $envFile -Value "T3CODE_DEV_AUTH_TOKEN=$token" -Encoding ascii
  }
  $vpEnv = Join-Path $env:USERPROFILE 'AppData\Roaming\vite-plus\env.ps1'
  $starterPath = Join-Path $HomeDir 'start.ps1'
  $starter = @"
`$ErrorActionPreference = 'Stop'
. '$vpEnv'
Set-Location '$Repo'
New-Item -ItemType Directory -Force -Path '$LogDir' | Out-Null
vp run dev --home-dir '$HomeDir' --port $Port *> '$Log'
"@
  Set-Content -Path $starterPath -Value $starter -Encoding utf8
  Write-Output "Starting workshop on :$Port (log $Log)"
  $p = Start-Process -FilePath 'pwsh.exe' -ArgumentList @('-NoProfile', '-File', $starterPath) -WorkingDirectory $Repo -WindowStyle Hidden -PassThru
  $deadline = (Get-Date).AddSeconds(180)
  while ((Get-Date) -lt $deadline) {
    if (Test-Health $Port) {
      Show-Status
      return
    }
    if ($p.HasExited) {
      throw "Workshop process exited before becoming healthy. See $Log"
    }
    Start-Sleep -Seconds 2
  }
  throw "Workshop did not become healthy on :$Port. See $Log"
}

switch ($Action) {
  'status' { Show-Status }
  'stop' { Stop-Workshop; Show-Status }
  'start' { Start-Workshop }
  'restart' { Stop-Workshop; Start-Workshop }
}
