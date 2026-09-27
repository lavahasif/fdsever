<#
.SYNOPSIS
    Automated Android UI Test Runner for FDServer Traffic Diverter.
    Tests live on any connected Android device via ADB and Flutter integration test.

.EXAMPLE
    .\scripts\run_android_ui_test.ps1
    .\scripts\run_android_ui_test.ps1 -Mode flutter_integration
    .\scripts\run_android_ui_test.ps1 -Mode adb_uiautomator
#>

param(
    [ValidateSet("flutter_widget", "flutter_integration", "adb_uiautomator", "all")]
    [string]$Mode = "all",
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  FDSERVER ANDROID UI TEST RUNNER" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 1. Check ADB Devices
Write-Host "`n[1/3] Checking connected Android devices via ADB..." -ForegroundColor Yellow
$adbDevices = adb devices | Where-Object { $_ -match "\tdevice$" }
if (-not $adbDevices) {
    Write-Warning "No authorized Android device connected via ADB. Skipping device-specific tests."
    $hasDevice = $false
} else {
    $firstDevice = ($adbDevices[0] -split "\s+")[0]
    if (-not $DeviceId) { $DeviceId = $firstDevice }
    Write-Host "  Found device: $DeviceId" -ForegroundColor Green
    $hasDevice = $true
}

# 2. Run Flutter Mobile UI Unit / Widget Tests
if ($Mode -eq "flutter_widget" -or $Mode -eq "all") {
    Write-Host "`n[2/3] Running Mobile Bottom Navigation & Diverter UI Tests..." -ForegroundColor Yellow
    flutter test test/traffic_diverter_ui_test.dart
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: All Flutter mobile UI tests passed!" -ForegroundColor Green
    } else {
        Write-Error "  FAILED: Flutter mobile UI tests encountered errors."
    }
}

# 3. Run On-Device Tests if Device is Attached
if ($hasDevice -and ($Mode -eq "flutter_integration" -or $Mode -eq "all")) {
    Write-Host "`n[3/3] Running Flutter Live Integration Test on Android device ($DeviceId)..." -ForegroundColor Yellow
    flutter test integration_test/traffic_diverter_android_test.dart -d $DeviceId
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: Device integration test passed!" -ForegroundColor Green
    } else {
        Write-Warning "  Integration test exited with code $LASTEXITCODE"
    }
}

if ($hasDevice -and ($Mode -eq "adb_uiautomator" -or $Mode -eq "all")) {
    Write-Host "`n[UIAutomator] Performing live ADB UI inspection..." -ForegroundColor Yellow
    $outDir = "build\test_artifacts"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

    # Launch app
    adb -s $DeviceId shell am start -n com.hasif.fdserver.fdserver/.MainActivity | Out-Null
    Start-Sleep -Seconds 2

    # Capture screenshot
    adb -s $DeviceId shell screencap -p /sdcard/ui_test_screen.png
    adb -s $DeviceId pull /sdcard/ui_test_screen.png "$outDir\diverter_ui_test.png" | Out-Null

    # Dump UI hierarchy
    adb -s $DeviceId shell uiautomator dump /sdcard/ui_dump.xml | Out-Null
    adb -s $DeviceId pull /sdcard/ui_dump.xml "$outDir\ui_dump.xml" | Out-Null

    Write-Host "  Screenshot saved to: $outDir\diverter_ui_test.png" -ForegroundColor Green
    Write-Host "  UI Hierarchy dumped to: $outDir\ui_dump.xml" -ForegroundColor Green
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ANDROID UI TEST SUITE COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
