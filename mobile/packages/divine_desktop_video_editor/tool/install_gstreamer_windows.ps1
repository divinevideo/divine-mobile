# Install the pinned development SDK only into an ephemeral CI directory.
param([Parameter(Mandatory = $true)][string]$Destination)
$ErrorActionPreference = 'Stop'
if (-not $env:RUNNER_TEMP) { throw 'This SDK installer is for an isolated CI runner.' }
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
$destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
if (-not $destinationRoot.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The SDK destination must be inside RUNNER_TEMP.'
}
$installer = Join-Path $env:RUNNER_TEMP 'gstreamer-1.0-msvc-x86_64-1.28.9.exe'
$url = 'https://gstreamer.freedesktop.org/data/pkg/windows/1.28.9/msvc/gstreamer-1.0-msvc-x86_64-1.28.9.exe'
$expected = 'ce4008705e8c6fe92803535b82fb3d6551e183f438e6ef26682ac4d0aca61076'
& curl.exe --fail --location --retry 3 --silent --show-error --output $installer $url
if ($LASTEXITCODE -ne 0) { throw 'GStreamer SDK download failed.' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $installer).Hash.ToLowerInvariant() -ne $expected) {
  throw 'GStreamer SDK checksum mismatch.'
}
# Cerbero 1.28.9 uses Inno Setup. Portable/current-user mode suppresses system
# registration, environment changes, VS templates and redistributable installs.
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
  '/CURRENTUSER', '/portable=1', '/TYPE=devel', '/TASKS=""', ('/DIR="' + $Destination + '"'))
$installed = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru -Wait
if ($installed.ExitCode -ne 0) { throw 'GStreamer SDK installation failed.' }
if (-not (Test-Path (Join-Path $Destination 'include/gstreamer-1.0/ges/ges.h'))) {
  throw 'The SDK does not include GStreamer Editing Services development files.'
}
if (-not (Test-Path (Join-Path $Destination 'include/json-glib-1.0/json-glib/json-glib.h'))) {
  throw 'The SDK does not include JSON-GLib development files.'
}
