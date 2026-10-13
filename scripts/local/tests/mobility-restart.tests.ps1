# Isolated shutdown regressions: every process/file operation below is mocked.
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot '../navio.ps1'
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($runner, [ref]$null, [ref]$parseErrors)
if ($parseErrors) { throw $parseErrors }
$definition = $ast.Find({ param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-NavioService'
}, $true)
if (-not $definition) { throw 'Shutdown function is missing' }
Invoke-Expression $definition.Extent.Text

$ServerDir = 'C:\navio-tests\server'
$service = [pscustomobject]@{ Name = 'mobility-and-ev-service'; Port = 8083 }
$mobility = [pscustomobject]@{ Name = 'java.exe'; CommandLine = 'com.navio.mobilityandevservice.MobilityAndEvServiceApplication' }
$other = [pscustomobject]@{ Name = 'java.exe'; CommandLine = 'com.example.OtherApplication' }
$launcher = [pscustomobject]@{ Name = 'cmd.exe'; CommandLine = 'C:\navio-tests\server\mobility-and-ev-service\mvnw.cmd' }

function Get-PidPath { 'mock.pid' }
function Get-PortPids {
  $script:portReads++
  if ($script:case.HasListener -and $script:portReads -le 2) { 101 }
}
function Get-CimInstance {
  param($ClassName, $Filter)
  $value = $script:case.Lookups[$script:lookupIndex]
  $script:lookupIndex++
  return $value
}
function Test-Path { param($Path) $script:case.HasPidFile }
function Get-Content { param($Path, [switch]$Raw) '202' }
function Test-ProcessAlive { param($ProcessId) $script:case.LauncherAlive }
function taskkill.exe { $script:treeStops++ }
function Stop-Process {
  [CmdletBinding()] param($Id, [switch]$Force)
  if ($Id -ne 101) { throw 'Unexpected process ID' }
  $script:processStops++
}
function Remove-Item { [CmdletBinding()] param($Path, [switch]$Force) }
function Wait-Until { param($Description, $Check, $TimeoutSec) $script:case.Stopped }

$cases = @(
  @{ Name = 'missing listener is already stopped'; HasListener = $false; Lookups = @(); ExpectedStops = 0 },
  @{ Name = 'listener exits before initial identity lookup'; Lookups = @($null, $null); ExpectedStops = 0 },
  @{ Name = 'listener exits before fallback identity lookup'; Lookups = @($mobility, $null); ExpectedStops = 0 },
  @{ Name = 'remaining Mobility process is stopped'; Lookups = @($mobility, $mobility); ExpectedStops = 1 },
  @{ Name = 'unrelated initial listener is refused'; Lookups = @($other); Error = 'unverified process'; ExpectedStops = 0 },
  @{ Name = 'different fallback owner is refused'; Lookups = @($mobility, $other); Error = 'changed owner'; ExpectedStops = 0 },
  @{ Name = 'verified launcher tree finishes before fallback lookup'; HasPidFile = $true; LauncherAlive = $true;
     Lookups = @($mobility, $launcher, $null); ExpectedTreeStops = 1; ExpectedStops = 0 },
  @{ Name = 'launcher exits before identity lookup'; HasPidFile = $true; LauncherAlive = $true;
     Lookups = @($mobility, $null, $null); ExpectedStops = 0 },
  @{ Name = 'unrelated launcher is refused'; HasPidFile = $true; LauncherAlive = $true;
     Lookups = @($mobility, $other); Error = 'launcher identity'; ExpectedStops = 0 },
  @{ Name = 'occupied port after shutdown prevents replacement'; Lookups = @($mobility, $mobility);
     Stopped = $false; Error = 'still occupied'; ExpectedStops = 1 }
)

foreach ($scenario in $cases) {
  $script:case = @{ HasListener = $true; HasPidFile = $false; LauncherAlive = $false; Stopped = $true; ExpectedTreeStops = 0 }
  foreach ($entry in $scenario.GetEnumerator()) { $script:case[$entry.Key] = $entry.Value }
  $script:portReads = 0
  $script:lookupIndex = 0
  $script:treeStops = 0
  $script:processStops = 0
  $caught = $null
  try { Stop-NavioService $service } catch { $caught = $_.Exception.Message }
  if ($script:case.Error) {
    if (-not $caught -or $caught -notmatch $script:case.Error) { throw "$($scenario.Name): expected rejection, got '$caught'" }
  } elseif ($caught) { throw "$($scenario.Name): $caught" }
  if ($script:processStops -ne $script:case.ExpectedStops -or $script:treeStops -ne $script:case.ExpectedTreeStops) {
    throw "$($scenario.Name): unexpected process stop"
  }
  Write-Output "PASS: $($scenario.Name)"
}
Write-Output "$($cases.Count) isolated Mobility shutdown regressions passed."
