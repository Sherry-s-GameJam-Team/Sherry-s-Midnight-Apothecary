<#
Builds the temperature-blendable furnace assets from a single front-facing video.
Requires FFmpeg 6+ with libwebp. Example:
  .\tools\process_fire_video.ps1 -InputVideo C:\Users\jisub\Downloads\preduct.mp4 -Ffmpeg C:\ffmpeg\bin\ffmpeg.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputVideo,
    [string]$Ffmpeg = "ffmpeg",
    [string]$OutputRoot = "",
    [int]$StateCount = 9,
    [int]$FramesPerState = 12,
    [double]$AnimationFps = 15.0
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $InputVideo)) { throw "Video not found: $InputVideo" }
if (-not (Get-Command $Ffmpeg -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $Ffmpeg)) {
    throw "FFmpeg was not found. Pass -Ffmpeg with the full path to ffmpeg.exe."
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot "..\game\apothecary\fire_visual\assets"
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force $OutputRoot, (Join-Path $OutputRoot "upper"), (Join-Path $OutputRoot "lower"), (Join-Path $OutputRoot "glow") | Out-Null

# These bounds are measured from preduct.mp4 (834x1112). Keep them fixed for every state.
$upperCrop = "525:420:155:55"
$lowerCrop = "515:270:160:430"
$sourceFps = 24.1196
$sourceFrames = 121

function Invoke-Ffmpeg([string[]]$Arguments) {
    & $Ffmpeg @Arguments
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed with exit code $LASTEXITCODE." }
}

function Write-MaskedSequence([double]$StartTime, [string]$Crop, [string]$DestinationPattern, [bool]$Glow) {
    # Retain warm fire pixels only. The fixed crops prevent furnace geometry from entering the layers.
    $alpha = "if(gt(r(X,Y),80)*gt(r(X,Y),g(X,Y)*1.10)*gt(g(X,Y),b(X,Y)*1.03),255,0)"
    $filter = "crop=$Crop,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='$alpha'"
    if ($Glow) { $filter += ",gblur=sigma=10" }
    Invoke-Ffmpeg @("-y", "-hide_banner", "-loglevel", "error", "-ss", ("{0:F5}" -f $StartTime), "-i", $InputVideo, "-frames:v", $FramesPerState, "-vf", "fps=$AnimationFps,$filter", "-start_number", "0", "-c:v", "libwebp", "-lossless", "1", $DestinationPattern)
}

# The first frame is the least-lit source frame and becomes the static furnace base.
Invoke-Ffmpeg @("-y", "-hide_banner", "-loglevel", "error", "-ss", "0", "-i", $InputVideo, "-frames:v", "1", "-c:v", "libwebp", "-lossless", "1", (Join-Path $OutputRoot "furnace_base.webp"))

for ($state = 0; $state -lt $StateCount; $state++) {
    $stateName = "s{0:D2}" -f $state
    foreach ($layer in @("upper", "lower", "glow")) { New-Item -ItemType Directory -Force (Join-Path $OutputRoot "$layer\$stateName") | Out-Null }
    $center = ($state / [double]($StateCount - 1)) * ($sourceFrames - 1)
    # A single decode per layer keeps regeneration fast. State windows overlap slightly to make adjacent blends natural.
    $startFrame = [Math]::Max(0, [Math]::Min($sourceFrames - $FramesPerState, [int][Math]::Round($center - ($FramesPerState * 0.5))))
    $time = $startFrame / $sourceFps
    Write-MaskedSequence $time $upperCrop (Join-Path $OutputRoot "upper\$stateName\upper_${stateName}_%03d.webp") $false
    Write-MaskedSequence $time $lowerCrop (Join-Path $OutputRoot "lower\$stateName\lower_${stateName}_%03d.webp") $false
    # Glow uses the lower flame crop and is composited additively by the scene.
    Write-MaskedSequence $time $lowerCrop (Join-Path $OutputRoot "glow\$stateName\glow_${stateName}_%03d.webp") $true
}

Write-Host "Generated $StateCount states x $FramesPerState frames in $OutputRoot"
