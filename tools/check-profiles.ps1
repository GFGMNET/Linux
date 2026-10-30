<#
.SYNOPSIS
  Check every profile's package names before installing (Windows, no Python needed).

.DESCRIPTION
  Easiest: double-click check-profiles.cmd.
    .\check-profiles.ps1            check all profiles
    .\check-profiles.ps1 ai games   check only these

  Checks pacman names against archlinux.org, AUR names against the AUR,
  Flatpak IDs against Flathub, and warns when a multilib package is used
  without NEEDS_MULTILIB=yes. Also runs with PowerShell 7 on Linux/macOS.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Profiles)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'profiles'
$Headers = @{ 'User-Agent' = 'archprofiles-check/1.0' }

function Read-List([string]$Path) {
  if (-not (Test-Path $Path)) { return @() }
  $out = @()
  foreach ($line in (Get-Content $Path)) {
    $line = ($line -split '#', 2)[0]
    $out += ($line -split '\s+' | Where-Object { $_ -ne '' })
  }
  return $out
}

function Get-Conf([string]$Path, [string]$Key, [string]$Default = '') {
  $value = $Default
  if (Test-Path $Path) {
    foreach ($line in (Get-Content $Path)) {
      if ($line -match "^\s*$Key\s*=(.*)$") {
        $v = $Matches[1]
        if ($v -match '^\s*"(.*)"') { $value = $Matches[1] }
        elseif ($v -match "^\s*'(.*)'") { $value = $Matches[1] }
        else { $value = (($v -split '#', 2)[0]).Trim() }
      }
    }
  }
  return $value
}

function Get-Status([string]$Url) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $Url -Headers $Headers -TimeoutSec 20
    return [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    throw
  }
}

function Test-Pacman([string]$Name) {
  $q = [uri]::EscapeDataString($Name)
  $data = Invoke-RestMethod -Uri "https://archlinux.org/packages/search/json/?name=$q" -Headers $Headers -TimeoutSec 20
  foreach ($r in $data.results) {
    if ($r.pkgname -eq $Name) { return @{ Ok = $true; Info = $r.repo } }
  }
  if ((Get-Status "https://archlinux.org/groups/x86_64/$q/") -eq 200) { return @{ Ok = $true; Info = 'group' } }
  return @{ Ok = $false; Info = 'not in the Arch repositories (AUR package? typo?)' }
}

function Get-AurFound([string[]]$Names) {
  if (-not $Names -or $Names.Count -eq 0) { return @() }
  $query = ($Names | ForEach-Object { 'arg[]=' + [uri]::EscapeDataString($_) }) -join '&'
  $data = Invoke-RestMethod -Uri "https://aur.archlinux.org/rpc/v5/info?$query" -Headers $Headers -TimeoutSec 20
  return @($data.results | ForEach-Object { $_.Name })
}

function Test-Flatpak([string]$Id) {
  return (Get-Status ('https://flathub.org/api/v2/appstream/' + [uri]::EscapeDataString($Id))) -eq 200
}

$dirs = Get-ChildItem $Root -Directory | Where-Object { $_.Name -ne '_template' } | Sort-Object Name
if ($Profiles) { $dirs = $dirs | Where-Object { $Profiles -contains $_.Name } }

$problems = 0
foreach ($d in $dirs) {
  $conf = Join-Path $d.FullName 'profile.conf'
  Write-Host ''
  Write-Host "== $($d.Name): $(Get-Conf $conf 'DESCRIPTION')" -ForegroundColor Cyan
  $multilib = (Get-Conf $conf 'NEEDS_MULTILIB' 'no') -match '^(yes|y|true|1|on)$'

  foreach ($f in (Get-ChildItem $d.FullName -Filter 'packages*.txt' | Sort-Object Name)) {
    foreach ($pkg in (Read-List $f.FullName)) {
      $r = Test-Pacman $pkg
      if (-not $r.Ok) {
        $problems++; Write-Host "  X $($f.Name): $pkg - $($r.Info)" -ForegroundColor Red
      } elseif ($r.Info -eq 'multilib' -and -not $multilib -and $d.Name -ne '_base') {
        $problems++; Write-Host "  ! $($f.Name): $pkg is in [multilib] - set NEEDS_MULTILIB=yes in profile.conf" -ForegroundColor Yellow
      } else {
        Write-Host "  OK $pkg ($($r.Info))"
      }
    }
  }

  $aur = @(Read-List (Join-Path $d.FullName 'aur.txt'))
  $found = Get-AurFound $aur
  foreach ($pkg in $aur) {
    if ($found -contains $pkg) { Write-Host "  OK $pkg (AUR)" }
    else { $problems++; Write-Host "  X aur.txt: $pkg - not found in the AUR" -ForegroundColor Red }
  }

  foreach ($app in (Read-List (Join-Path $d.FullName 'flatpak.txt'))) {
    if (Test-Flatpak $app) { Write-Host "  OK $app (Flathub)" }
    else { $problems++; Write-Host "  X flatpak.txt: $app - not found on Flathub" -ForegroundColor Red }
  }
}

Write-Host ''
if ($problems -eq 0) { Write-Host 'No problems found.' -ForegroundColor Green; exit 0 }
Write-Host "$problems problem(s) found." -ForegroundColor Red
exit 1
