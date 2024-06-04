# Get administrator authority
function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # 관리자 권한이 없는 경우, 관리자 권한으로 스크립트 재실행 요청
        Write-Host "관리자 권한이 필요합니다. 관리자 권한으로 스크립트를 다시 실행합니다."
        Start-Process powershell -Verb runAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`"")
        Exit
    }
}

# Check Administrator authority
Ensure-Admin

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$adbPath = Join-Path -Path $scriptDir -ChildPath "adb.exe"

# executing 'adb devices' and logging the result
Write-Host "Executing adb devices at $(Get-Date)"
$adbDevicesOutput = adb devices
Write-Host $adbDevicesOutput

# analyzing the 'adb devices' result
if ($adbDevicesOutput -like "*unauthorized*") {
    Write-Host "Device is unauthorized. Please check the device for an RSA key fingerprint prompt."
} elseif ($adbDevicesOutput -like "*device*") {
    Write-Host "Device is authorized. Proceeding with adb command."
    # executing adb command and checking the result
    try {
        adb shell settings put system csc_pref_camera_forced_shuttersound_key 0
        $adbCommandOutput = adb shell settings get system csc_pref_camera_forced_shuttersound_key

        if ($adbCommandOutput -eq "0") {
            Write-Host "Camera shutter sound disabled successfully."
        } else {
            Write-Host "Failed to disable camera shutter sound. The current value is: $adbCommandOutput"
        }
    } catch {
        Write-Host "An error occurred while executing the adb command: $_"
    }
} elseif ($adbDevicesOutput -like "*no devices/emulators found*") {
    Write-Host "No devices found. Please ensure that the device is connected and USB debugging is enabled."
} elseif ($adbDevicesOutput -eq "") {
    Write-Host "adb devices command did not return any output. Is adb properly installed and accessible?"
} else {
    Write-Host "An unexpected error occurred. Please check the adb devices output for more details."
}

Write-Host "Script execution completed at $(Get-Date)"
Write-Host "========================================="

# do not close this window before user press any key
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")