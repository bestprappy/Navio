<#
.SYNOPSIS
  Runs the Navio backend locally: Docker infrastructure plus every Spring service.

.DESCRIPTION
  Services are launched detached (through WMI), so they keep running after this
  terminal closes. Each one logs to logs/local/<service>.log at the repo root.

  Local-only values (Keycloak secrets, MinIO credentials) are the same ones the
  root docker-compose files already use. The Google Maps server key comes from
  $env:GOOGLE_MAPS_SERVER_API_KEY, or falls back to the browser key in
  client/.env.local.

.EXAMPLE
  .\navio start               # infra + every service, skipping ones already healthy
  .\navio start trip          # (re)start one service after a code change
  .\navio start user trip     # several at once
  .\navio restart             # stop and start every service
  .\navio stop                # stop every service (containers keep running)
  .\navio stop trip           # stop one service
  .\navio stop infra          # stop the Docker containers (wipes local Keycloak accounts)
  .\navio infra               # start only the Docker containers
  .\navio status
  .\navio logs gateway -Follow
  .\navio start trip -Online  # resolve Maven dependencies online after a pom.xml change
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('start', 'restart', 'stop', 'status', 'logs', 'infra', 'help')]
  [string]$Command = 'help',

  [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
  [string[]]$Targets = @(),

  # Resolve Maven dependencies online instead of offline (-o).
  [switch]$Online,

  # With 'logs': keep streaming new lines.
  [switch]$Follow
)

$ErrorActionPreference = 'Continue'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ServerDir = Join-Path $Root 'server'
$LogDir = Join-Path $Root 'logs\local'
$StorageCompose = Join-Path $Root 'docker-compose.storage.yml'
$KeycloakIssuer = 'http://localhost:8180/realms/navio'
$MediaBucket = 'navio-community'

# Stage order matters: everything loads config from the config server, then
# registers in Eureka; the gateway goes last so the services it routes to exist.
$Services = @(
  [pscustomobject]@{ Name = 'configuration-server';    Port = 8888; Stage = 1; Aliases = @('config') }
  [pscustomobject]@{ Name = 'discovery-server';        Port = 8761; Stage = 2; Aliases = @('discovery', 'eureka') }
  [pscustomobject]@{ Name = 'user-management-service'; Port = 8081; Stage = 3; Aliases = @('user', 'users', 'iam') }
  [pscustomobject]@{ Name = 'trip-planning-service';   Port = 8082; Stage = 3; Aliases = @('trip', 'trips') }
  [pscustomobject]@{ Name = 'mobility-and-ev-service'; Port = 8083; Stage = 3; Aliases = @('mobility', 'ev') }
  [pscustomobject]@{ Name = 'community-service';       Port = 8084; Stage = 3; Aliases = @('community', 'social') }
  [pscustomobject]@{ Name = 'api-gateway';             Port = 8080; Stage = 4; Aliases = @('gateway') }
)

# --- helpers -----------------------------------------------------------------

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "  [ok] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "  [!] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "  [x] $Message" -ForegroundColor Red }

function Get-HttpCode([string]$Url) {
  $code = & curl.exe -s -o NUL -m 3 -w '%{http_code}' $Url 2>$null
  if ($code) { return $code } else { return '000' }
}

function Wait-Until([string]$Label, [scriptblock]$Condition, [int]$TimeoutSec) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (& $Condition) { Write-Ok $Label; return $true }
    Start-Sleep -Seconds 2
  }
  Write-Fail "$Label (timed out after ${TimeoutSec}s)"
  return $false
}

function Resolve-NavioService([string]$Target) {
  $key = $Target.ToLowerInvariant()
  $match = $Services | Where-Object { $_.Name -eq $key -or $_.Aliases -contains $key }
  if (-not $match) {
    $known = ($Services | ForEach-Object { "$($_.Name) ($($_.Aliases -join ', '))" }) -join "`n  "
    throw "Unknown service '$Target'. Known services:`n  $known"
  }
  return $match
}

function Get-LogPath($Svc) { Join-Path $LogDir "$($Svc.Name).log" }
function Get-PidPath($Svc) { Join-Path $LogDir "$($Svc.Name).pid" }

function Get-PortPids([int]$Port) {
  Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -gt 0 }
}

function Test-ProcessAlive([int]$ProcessId) {
  return [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Get-MapsServerKey {
  if ($env:GOOGLE_MAPS_SERVER_API_KEY) { return $env:GOOGLE_MAPS_SERVER_API_KEY }
  $clientEnv = Join-Path $Root 'client\.env.local'
  if (Test-Path $clientEnv) {
    $line = Select-String -Path $clientEnv -Pattern '^NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=(.+)$' | Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value.Trim() }
  }
  return $null
}

function Get-LocalTransitSetting([string]$Setting) {
  if ($Setting -notin @('NAVIO_OTP_ENABLED', 'NAVIO_OTP_ENDPOINT', 'NAVIO_OTP_NETWORK_ID')) {
    throw 'Unsupported local transit setting'
  }
  $value = [Environment]::GetEnvironmentVariable($Setting)
  if ($value) { return $value }
  $localEnv = Join-Path $ServerDir 'mobility-and-ev-service\.env.local'
  if (Test-Path -LiteralPath $localEnv) {
    $pattern = '^' + [regex]::Escape($Setting) + '=(.+)$'
    $line = Select-String -LiteralPath $localEnv -Pattern $pattern | Select-Object -Last 1
    if ($line) { return $line.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'") }
  }
  return $null
}

function Get-ServiceEnv($Svc) {
  # Defaults in the config server assume Docker hostnames (kafka:9092, the
  # container hostname for Eureka); these make every service work on localhost.
  $vars = [ordered]@{
    KAFKA_BOOTSTRAP_SERVERS           = 'localhost:29092'
    EUREKA_INSTANCE_PREFER_IP_ADDRESS = 'true'
  }
  switch ($Svc.Name) {
    'api-gateway' {
      $vars.KEYCLOAK_ISSUER_URI = $KeycloakIssuer
    }
    'user-management-service' {
      $vars.KEYCLOAK_ISSUER_URI = $KeycloakIssuer
      $vars.KEYCLOAK_BASE_URL = 'http://localhost:8180'
      $vars.KEYCLOAK_ADMIN_CLIENT_SECRET = 'local-dev-admin-secret'
      $vars.USER_DB_URL = 'jdbc:postgresql://localhost:5432/tripplanner'
      $vars.USER_DB_PASSWORD = 'tripplanner'
    }
    'mobility-and-ev-service' {
      $key = Get-MapsServerKey
      if ($key) { $vars.GOOGLE_MAPS_SERVER_API_KEY = $key }
      else { Write-Warn 'No Google Maps key found; mobility-and-ev-service will refuse to start.' }
      foreach ($setting in @('NAVIO_OTP_ENABLED', 'NAVIO_OTP_ENDPOINT', 'NAVIO_OTP_NETWORK_ID')) {
        $value = Get-LocalTransitSetting $setting
        if ($value) {
          # These values enter the existing cmd launcher. Reject shell syntax and quoted values.
          if ($value -match '[&|<>^%"\r\n]') { throw "Invalid characters in $setting" }
          $vars[$setting] = $value
          $propertySuffix = @{ NAVIO_OTP_ENABLED='ENABLED'; NAVIO_OTP_ENDPOINT='ENDPOINT'; NAVIO_OTP_NETWORK_ID='NETWORKID' }[$setting]
          # Also bind directly, so local changes do not require restarting the shared config server.
          $vars["NAVIO_MOBILITY_PROVIDERS_OTP_$propertySuffix"] = $value
        }
      }
    }
    'community-service' {
      $vars.AWS_ACCESS_KEY_ID = 'navio-local'
      $vars.AWS_SECRET_ACCESS_KEY = 'navio-local-storage'
      $vars.AWS_REGION = 'us-east-1'
    }
  }
  return $vars
}

# --- infrastructure ----------------------------------------------------------

function Test-InfraRunning {
  foreach ($container in @('navio-postgres', 'navio-kafka')) {
    $state = & docker inspect $container --format '{{if .State.Running}}{{.State.Health.Status}}{{end}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or $state -ne 'healthy') { return $false }
  }
  # Container health alone does not prove that Windows can reach published ports.
  return ((Get-HttpCode "$KeycloakIssuer/.well-known/openid-configuration") -eq '200' -and
          (Get-HttpCode 'http://localhost:9000/minio/health/live') -eq '200')
}

function Start-Infra {
  Write-Step 'Starting Docker infrastructure'
  & docker info *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Docker is not running. Start Docker Desktop first.' }

  $keycloakState = & docker inspect navio-keycloak --format '{{if .State.Running}}{{.State.Health.Status}}{{end}}' 2>$null
  $discoveryUrl = "$KeycloakIssuer/.well-known/openid-configuration"
  if ($LASTEXITCODE -eq 0 -and $keycloakState -eq 'healthy' -and (Get-HttpCode $discoveryUrl) -eq '000') {
    throw "Keycloak is healthy inside Docker, but Windows cannot reach $discoveryUrl. Check Docker Desktop port forwarding; see docs/local-development.md. Restarting Keycloak resets local accounts."
  }

  Push-Location $Root
  try {
    # Not a bare 'up': that also starts Grafana on :3000, which Next.js needs.
    & docker compose up -d postgres keycloak kafka zipkin
    & docker compose -f $StorageCompose up -d minio
  } finally { Pop-Location }

  $ok = (Wait-Until 'Postgres healthy' { (& docker inspect navio-postgres --format '{{.State.Health.Status}}' 2>$null) -eq 'healthy' } 120) -and
        (Wait-Until 'Kafka healthy' { (& docker inspect navio-kafka --format '{{.State.Health.Status}}' 2>$null) -eq 'healthy' } 120) -and
        # Probe the host endpoints as well as the containers' internal health.
        (Wait-Until 'Keycloak realm ready' { (Get-HttpCode "$KeycloakIssuer/.well-known/openid-configuration") -eq '200' } 180) -and
        (Wait-Until 'MinIO ready' { (Get-HttpCode 'http://localhost:9000/minio/health/live') -eq '200' } 60)
  if (-not $ok) { throw 'Infrastructure did not become ready. Check: docker compose ps' }

  Initialize-MediaBucket
}

function Initialize-MediaBucket {
  # minio-init uses the mc client bundled in the storage image and is idempotent.
  Push-Location $Root
  try { & docker compose -f $StorageCompose run --rm minio-init *> $null } finally { Pop-Location }
  if ($LASTEXITCODE -eq 0) { Write-Ok "Bucket $MediaBucket ready" }
  else { Write-Warn "Could not create bucket $MediaBucket; community media uploads will fail." }
}

function Stop-Infra {
  Write-Step 'Stopping Docker infrastructure (local Keycloak accounts are in-memory and will be lost)'
  Push-Location $Root
  try {
    & docker compose stop postgres keycloak kafka zipkin
    & docker compose -f $StorageCompose stop minio
  } finally { Pop-Location }
}

# --- services ----------------------------------------------------------------

function Stop-NavioService($Svc) {
  if ($Svc.Name -eq 'mobility-and-ev-service') {
    # A targeted routing restart must never stop an unrelated process using this port.
    foreach ($listenerId in (Get-PortPids $Svc.Port)) {
      $listener = Get-CimInstance Win32_Process -Filter "ProcessId=$listenerId"
      if (-not $listener) { continue } # The listener exited after the port snapshot.
      if ($listener.Name -ne 'java.exe' -or
          $listener.CommandLine -notmatch 'com\.navio\.mobilityandevservice\.MobilityAndEvServiceApplication') {
        throw "Port $($Svc.Port) belongs to an unverified process; no process was stopped."
      }
    }
  }
  $pidPath = Get-PidPath $Svc
  if (Test-Path $pidPath) {
    $launcher = [int](Get-Content $pidPath -Raw)
    $launcherAlive = Test-ProcessAlive $launcher
    if ($Svc.Name -eq 'mobility-and-ev-service' -and $launcherAlive) {
      $launchProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$launcher"
      $servicePath = Join-Path $ServerDir $Svc.Name
      if (-not $launchProcess) { $launcherAlive = $false }
      elseif ($launchProcess.CommandLine -notmatch [regex]::Escape($servicePath) -or
          $launchProcess.CommandLine -notmatch 'mvnw\.cmd') {
        throw 'Mobility launcher identity does not match this workspace; no process was stopped.'
      }
    }
    # /T takes down the whole tree: cmd -> Maven JVM -> forked application JVM.
    if ($launcherAlive) { & taskkill.exe /PID $launcher /T /F *> $null }
    Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
  }
  # Fallback for instances started some other way (IntelliJ, a manual mvnw run).
  foreach ($p in (Get-PortPids $Svc.Port)) {
    if ($Svc.Name -eq 'mobility-and-ev-service') {
      $remaining = Get-CimInstance Win32_Process -Filter "ProcessId=$p"
      if (-not $remaining) { continue } # taskkill may finish between these two queries.
      if ($remaining.Name -ne 'java.exe' -or
          $remaining.CommandLine -notmatch 'com\.navio\.mobilityandevservice\.MobilityAndEvServiceApplication') {
        throw 'Mobility port changed owner during restart; refusing to stop it.'
      }
    }
    Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
  }
  $stopped = Wait-Until "$($Svc.Name) stopped" { -not (Get-PortPids $Svc.Port) } 20
  if (-not $stopped -and $Svc.Name -eq 'mobility-and-ev-service') {
    throw 'Mobility port is still occupied after shutdown; no replacement was started.'
  }
}

function Start-NavioService($Svc) {
  if ((Get-PortPids $Svc.Port) -or (Test-Path (Get-PidPath $Svc))) { Stop-NavioService $Svc }

  $serviceDir = Join-Path $ServerDir $Svc.Name
  $log = Get-LogPath $Svc
  $errLog = Join-Path $LogDir "$($Svc.Name).err.log"
  $mavenArgs = if ($Online) { '-q spring-boot:run' } else { '-o -q spring-boot:run' }

  $sets = (Get-ServiceEnv $Svc).GetEnumerator() | ForEach-Object { "set `"$($_.Key)=$($_.Value)`"&&" }
  $inner = "$($sets -join ' ') `"$serviceDir\mvnw.cmd`" $mavenArgs 1>`"$log`" 2>`"$errLog`""
  $commandLine = "cmd.exe /d /s /c `"$inner`""

  # WMI launches the process outside this console, so it survives the terminal closing.
  $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
  $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine               = $commandLine
    CurrentDirectory          = $serviceDir
    ProcessStartupInformation = $startup
  }
  if ($result.ReturnValue -ne 0) { throw "Could not launch $($Svc.Name) (WMI error $($result.ReturnValue))." }

  Set-Content -Path (Get-PidPath $Svc) -Value $result.ProcessId -NoNewline
  Write-Host "  launched $($Svc.Name) (port $($Svc.Port), log logs\local\$($Svc.Name).log)"
  return [int]$result.ProcessId
}

function Wait-NavioService($Svc, [int]$LauncherPid, [int]$TimeoutSec = 300) {
  $log = Get-LogPath $Svc
  $failure = 'APPLICATION FAILED TO START|Application run failed|BUILD FAILURE|COMPILATION ERROR'
  $started = Get-Date
  while (((Get-Date) - $started).TotalSeconds -lt $TimeoutSec) {
    if ((Get-HttpCode "http://localhost:$($Svc.Port)/actuator/health") -eq '200') {
      Write-Ok ("{0} up in {1:N0}s" -f $Svc.Name, ((Get-Date) - $started).TotalSeconds)
      return $true
    }
    $crashed = -not (Test-ProcessAlive $LauncherPid)
    $failed = (Test-Path $log) -and (Select-String -Path $log -Pattern $failure -Quiet)
    if ($crashed -or $failed) { break }
    Start-Sleep -Seconds 2
  }

  Write-Fail "$($Svc.Name) did not become healthy. Last log lines:"
  if (Test-Path $log) {
    Get-Content $log -Tail 25 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    if (Select-String -Path $log -Pattern 'offline mode|Cannot access .* in offline' -Quiet) {
      Write-Warn 'A dependency is missing from the local Maven cache. Re-run with -Online.'
    }
  }
  Write-Host "      Full log: $log"
  return $false
}

function Start-NavioServices($Svcs, [switch]$SkipHealthy) {
  foreach ($stage in ($Svcs | Select-Object -ExpandProperty Stage -Unique | Sort-Object)) {
    $launched = @()
    foreach ($svc in ($Svcs | Where-Object Stage -eq $stage)) {
      if ($SkipHealthy -and (Get-HttpCode "http://localhost:$($svc.Port)/actuator/health") -eq '200') {
        Write-Ok "$($svc.Name) already running"
        continue
      }
      $launched += [pscustomobject]@{ Svc = $svc; Pid = (Start-NavioService $svc) }
    }
    foreach ($item in $launched) {
      if (-not (Wait-NavioService $item.Svc $item.Pid)) { return $false }
    }
  }
  return $true
}

function Show-Status {
  Write-Step 'Services'
  $Services | ForEach-Object {
    $code = Get-HttpCode "http://localhost:$($_.Port)/actuator/health"
    $state = switch ($code) { '200' { 'UP' } '000' { 'stopped' } default { "unhealthy ($code)" } }
    [pscustomobject]@{ Service = $_.Name; Port = $_.Port; Status = $state }
  } | Format-Table -AutoSize | Out-String | Write-Host

  Write-Step 'Containers'
  & docker ps --filter 'name=navio' --format 'table {{.Names}}\t{{.Status}}' 2>$null | Write-Host
}

function Show-Help {
  Write-Host @'
Usage: navio <command> [service ...] [-Online] [-Follow]

  start                 infra + every service, skipping ones already healthy
  start <svc> [<svc>]   (re)start services after a code change
  restart               stop and start every service
  stop [<svc>]          stop services (all when none given); containers keep running
  stop infra            stop every service and the Docker containers
  infra                 start only the Docker containers
  status                health of every service and container
  logs <svc> [-Follow]  last 80 log lines, optionally streaming

  -Online               resolve Maven dependencies online (after a pom.xml change)

Services: config, discovery, user, trip, mobility (ev), community, gateway
          (full names such as trip-planning-service also work)
'@
}

# --- main --------------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

try {
  switch ($Command) {
    'help' { Show-Help }

    'infra' { Start-Infra }

    'status' { Show-Status }

    'logs' {
      if ($Targets.Count -ne 1) { throw 'Usage: navio logs <service> [-Follow]' }
      $log = Get-LogPath (Resolve-NavioService $Targets[0])
      if (-not (Test-Path $log)) { throw "No log yet at $log" }
      if ($Follow) { Get-Content $log -Tail 80 -Wait } else { Get-Content $log -Tail 80 }
    }

    'stop' {
      if ($Targets -contains 'infra') {
        Write-Step 'Stopping all services'
        foreach ($svc in $Services) { Stop-NavioService $svc }
        Stop-Infra
        break
      }
      $svcs = if ($Targets.Count) { $Targets | ForEach-Object { Resolve-NavioService $_ } } else { $Services }
      Write-Step 'Stopping services'
      # Reverse stage order: gateway first, config server last.
      foreach ($svc in ($svcs | Sort-Object Stage -Descending)) { Stop-NavioService $svc }
    }

    'restart' {
      Write-Step 'Stopping all services'
      foreach ($svc in ($Services | Sort-Object Stage -Descending)) { Stop-NavioService $svc }
      if (-not (Test-InfraRunning)) { Start-Infra }
      Write-Step 'Starting all services'
      if (-not (Start-NavioServices $Services)) { exit 1 }
      Show-Status
    }

    'start' {
      if ($Targets.Count) {
        # Targeted start always restarts, so it picks up code changes.
        $svcs = $Targets | ForEach-Object { Resolve-NavioService $_ } | Sort-Object Stage -Unique
        if (-not (Test-InfraRunning)) { Start-Infra }
        Write-Step "Restarting $(($svcs | ForEach-Object Name) -join ', ')"
        if (-not (Start-NavioServices $svcs)) { exit 1 }
        if ($svcs.Name -notcontains 'api-gateway') {
          Write-Host '  The gateway picks up the new instance from Eureka within about 30s.'
        }
      } else {
        Start-Infra
        Write-Step 'Starting services'
        if (-not (Start-NavioServices $Services -SkipHealthy)) { exit 1 }
        Show-Status
      }
    }
  }
} catch {
  Write-Fail $_.Exception.Message
  exit 1
}
