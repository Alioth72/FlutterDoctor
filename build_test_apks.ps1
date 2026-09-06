[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:TURN_CREDENTIALS_URL)) {
    throw @'
TURN_CREDENTIALS_URL is not set in this PowerShell window.

Set it without printing it:
  $env:TURN_CREDENTIALS_URL = 'https://YOUR_APP.metered.live/api/v1/turn/credentials?apiKey=YOUR_API_KEY'

Then run this script again:
  .\build_test_apks.ps1
'@
}

$turnUri = $null
if (-not [Uri]::TryCreate($env:TURN_CREDENTIALS_URL, [UriKind]::Absolute, [ref]$turnUri) -or
    $turnUri.Scheme -ne 'https' -or
    -not $turnUri.Host.EndsWith('.metered.live') -or
    -not $turnUri.AbsolutePath.EndsWith('/api/v1/turn/credentials') -or
    -not $turnUri.Query.Contains('apiKey=')) {
    throw 'TURN_CREDENTIALS_URL does not match the expected Metered HTTPS credential endpoint.'
}

$workspaceRoot = $PSScriptRoot
$outputDirectory = Join-Path $workspaceRoot 'test_apks'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Build-TestApk {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputName
    )

    $appPath = Join-Path $workspaceRoot $AppDirectory
    $builtApk = Join-Path $appPath 'build\app\outputs\flutter-apk\app-debug.apk'
    $destination = Join-Path $outputDirectory $OutputName

    Write-Host "Building $AppDirectory..." -ForegroundColor Cyan
    Push-Location $appPath
    try {
        & flutter build apk --debug "--dart-define=TURN_CREDENTIALS_URL=$env:TURN_CREDENTIALS_URL"
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter failed to build $AppDirectory (exit code $LASTEXITCODE)."
        }
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $builtApk -PathType Leaf)) {
        throw "Flutter reported success but the APK was not found at $builtApk."
    }

    Copy-Item -LiteralPath $builtApk -Destination $destination -Force
    Write-Host "Created $destination" -ForegroundColor Green
}

# Build sequentially. Parallel Gradle builds consume much more disk and memory.
Build-TestApk -AppDirectory 'patient_app' -OutputName 'Swasthya-Patient-debug.apk'
Build-TestApk -AppDirectory 'doctor_app' -OutputName 'Swasthya-Doctor-debug.apk'

Write-Host ''
Write-Host 'Both test APKs are ready:' -ForegroundColor Green
Get-ChildItem -LiteralPath $outputDirectory -Filter '*.apk' |
    Select-Object Name, @{Name = 'SizeMB'; Expression = { [math]::Round($_.Length / 1MB, 1) } }, FullName

Write-Host ''
Write-Host 'Share the Patient APK to the patient phone and the Doctor APK to the doctor phone.'
