[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$DataDirectory,
  [Parameter(Mandatory = $true)][string]$JarPath,
  [ValidateRange(1,65535)][int]$Port = 8801,
  [ValidateRange(256,65536)][int]$HeapMegabytes = 1024,
  [switch]$Build
)
$ErrorActionPreference = 'Stop'
$dataPath = (Resolve-Path -LiteralPath $DataDirectory).ProviderPath
$jarFile = (Resolve-Path -LiteralPath $JarPath).ProviderPath
$ErrorActionPreference = 'Continue' # Java writes this successful diagnostic to stderr.
$javaSettings = java -XshowSettings:properties -version 2>&1
$ErrorActionPreference = 'Stop'
$javaHomeLine = $javaSettings | Select-String '^\s*java.home = (.+)$' | Select-Object -First 1
if (-not $javaHomeLine) { throw 'Cannot resolve the installed Java runtime' }
$javaExecutable = Join-Path $javaHomeLine.Matches[0].Groups[1].Value.Trim() 'bin/java.exe'
if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
  throw "Port $Port is occupied. Choose another port; no existing process was stopped."
}
if (-not $Build -and -not (Test-Path -LiteralPath (Join-Path $dataPath 'graph.obj'))) {
  throw 'graph.obj is missing; first run this command with -Build.'
}
$arguments = @("-Xmx${HeapMegabytes}m", '-XX:ActiveProcessorCount=2', '-XX:+UseSerialGC', '-jar', ('"' + $jarFile + '"'))
if ($Build) {
  # Build/save and load/serve are separate: OTP 2.10 can leave its RAPTOR index empty when combined.
  $buildArguments = $arguments + @('--build','--save',('"' + $dataPath + '"'))
  $builder = Start-Process -FilePath $javaExecutable -ArgumentList $buildArguments -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $dataPath 'otp-build.stdout.log') `
    -RedirectStandardError (Join-Path $dataPath 'otp-build.stderr.log') -Wait -PassThru
  if ($builder.ExitCode -ne 0) { throw 'OTP graph build failed; check otp-build.stderr.log' }
}
$arguments += @('--load','--serve')
$arguments += @('--bindAddress','127.0.0.1','--port',"$Port",('"' + $dataPath + '"'))
$otpProcess = Start-Process -FilePath $javaExecutable -ArgumentList $arguments -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $dataPath 'otp.stdout.log') `
  -RedirectStandardError (Join-Path $dataPath 'otp.stderr.log') -PassThru
@{ pid=$otpProcess.Id; port=$Port; jar=$jarFile; data=$dataPath } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dataPath 'otp-process.json')
Write-Output "OpenTripPlanner PID $($otpProcess.Id), endpoint http://localhost:$Port/otp/gtfs/v1. Check otp.stdout.log for readiness."
