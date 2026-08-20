[CmdletBinding()]
param(
    [ValidateSet("debug", "release")]
    [string]$Configuration = "debug",

    [string]$GodotPath = "",

	[switch]$SkipPluginBuild,

	[switch]$DeviceTest
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$gameRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $gameRoot
$outputDirectory = Join-Path $projectRoot "builds"
$overridePath = Join-Path $projectRoot "override.cfg"
$androidPluginPath = Join-Path $projectRoot "addons\godot_taptap\tools\taptap\android_plugin"
$androidBuildPath = Join-Path $projectRoot "android\build\build.gradle"

function Resolve-ExistingFile {
    param(
        [string]$RequestedPath,
        [string[]]$Candidates,
        [string]$ToolName
    )

    if ($RequestedPath) {
        $resolvedRequestedPath = Resolve-Path -LiteralPath $RequestedPath -ErrorAction SilentlyContinue
        if ($resolvedRequestedPath) {
            return $resolvedRequestedPath.Path
        }
        throw "$ToolName does not exist: $RequestedPath"
    }

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "$ToolName was not found. Install it or pass its path explicitly."
}

function Find-Godot {
    $pathCommand = Get-Command "godot" -ErrorAction SilentlyContinue
    $pathCandidate = if ($pathCommand) { $pathCommand.Source } else { "" }
    return Resolve-ExistingFile -RequestedPath $GodotPath -ToolName "Godot" -Candidates @(
        $pathCandidate,
        "C:\Tools\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe",
        "C:\Tools\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
    )
}

function Find-Gradle {
    $pathCommand = Get-Command "gradle.bat" -ErrorAction SilentlyContinue
    if (-not $pathCommand) {
        $pathCommand = Get-Command "gradle" -ErrorAction SilentlyContinue
    }
    if ($pathCommand) {
        return $pathCommand.Source
    }

    $gradleCache = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".gradle\wrapper\dists\gradle-8.14.3-bin"
    if (Test-Path -LiteralPath $gradleCache) {
        $cachedGradle = Get-ChildItem -LiteralPath $gradleCache -Filter "gradle.bat" -File -Recurse |
            Where-Object { $_.FullName -match "gradle-8\.14\.3\\bin\\gradle\.bat$" } |
            Select-Object -First 1
        if ($cachedGradle) {
            return $cachedGradle.FullName
        }
    }

    throw "Gradle 8.14.3 was not found. Keep or restore the user Gradle cache."
}

function Resolve-AndroidSdk {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Android SDK was not found. The default location is %LOCALAPPDATA%\Android\Sdk."
}

function Resolve-JavaHome {
    $candidates = @(
        $env:JAVA_HOME,
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".local\tools\jdk-17.0.19+10")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "bin\java.exe") -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "JDK 17 was not found. Set JAVA_HOME and retry."
}

if (-not (Test-Path -LiteralPath $overridePath -PathType Leaf)) {
    throw "override.cfg is missing. Copy addons/godot_taptap/tools/taptap/config/override.cfg.example to the repository root and fill in the TapTap credentials."
}

$overrideText = Get-Content -LiteralPath $overridePath -Raw
$clientIdMatch = [regex]::Match($overrideText, '(?m)^client_id="([^\"]+)"\s*$')
$clientTokenMatch = [regex]::Match($overrideText, '(?m)^client_token="([^\"]+)"\s*$')
if (-not $clientIdMatch.Success -or -not $clientTokenMatch.Success) {
    throw "TapTap Client ID or Client Token is missing from override.cfg."
}

$debugLogMatch = [regex]::Match($overrideText, '(?m)^enable_debug_log=(true|false)\s*$')
if ($Configuration -eq "release" -and $debugLogMatch.Success -and $debugLogMatch.Groups[1].Value -eq "true") {
    throw "Release builds require tap_sdk/enable_debug_log=false in override.cfg."
}

$godot = Find-Godot
$env:ANDROID_HOME = Resolve-AndroidSdk
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_HOME = Resolve-JavaHome

if (-not $SkipPluginBuild) {
    $gradle = Find-Gradle
    Write-Host "Building the TapTap Android plugin..."
    & $gradle -p $androidPluginPath clean assemble
    if ($LASTEXITCODE -ne 0) {
        throw "TapTap Android plugin build failed with exit code $LASTEXITCODE."
    }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactName = if ($DeviceTest) { "godot-taptap-device-test" } else { "godot-taptap-test" }
$presetName = if ($DeviceTest) { "Android Device Test" } else { "Android" }
$outputPath = Join-Path $outputDirectory "$artifactName-$Configuration-$timestamp.apk"
$exportFlag = if ($Configuration -eq "release") { "--export-release" } else { "--export-debug" }
$godotArguments = @("--headless", "--path", $projectRoot)
if (-not (Test-Path -LiteralPath $androidBuildPath -PathType Leaf)) {
    $godotArguments += "--install-android-build-template"
}
$godotArguments += @($exportFlag, $presetName, $outputPath)

Write-Host "Exporting the Android $Configuration package..."
& $godot @godotArguments
if ($LASTEXITCODE -ne 0) {
    throw "Godot Android export failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Godot did not create the expected APK: $outputPath"
}

$apk = Get-Item -LiteralPath $outputPath
$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
Write-Host "Build complete: $($apk.FullName)"
Write-Host "Size: $($apk.Length) bytes"
Write-Host "SHA256: $($hash.Hash)"
