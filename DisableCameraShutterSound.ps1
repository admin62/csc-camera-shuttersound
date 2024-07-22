# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path -Path $scriptDir -ChildPath "DisableCameraShutterSound.ps1"

function Ensure-Admin {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "Administrator privileges are required. Attempting to restart the script with administrator privileges..."
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            Exit
        }
    } catch {
        Write-Host "An error occurred trying to run the script with administrator privileges. Error: $_"
        # Wait for user input
		Pause
        Exit
    }
}

function Set-ExecutionPolicyIfNeeded {
    $currentPolicy = Get-ExecutionPolicy
    if ($currentPolicy -ne "RemoteSigned") {
        Write-Host "Current policy: $currentPolicy"
        Write-Host "Change current policy to RemoteSigned."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    } else {
        Write-Host "Current policy is already changed to RemoteSigned."
    }
}

# Check Administrator authority
Ensure-Admin

# Check Execution policy
Set-ExecutionPolicyIfNeeded

$adbPath = Join-Path -Path $scriptDir -ChildPath "adb.exe"

# executing 'adb devices' and logging the result
Write-Host "Executing adb devices at $(Get-Date)"
$adbDevicesOutput = & $adbPath devices
Write-Host $adbDevicesOutput

# analyzing the 'adb devices' result
if ($adbDevicesOutput -like "*unauthorized*") {
    Write-Host "Device is unauthorized. Please check the device for an RSA key fingerprint prompt."
} elseif ($adbDevicesOutput -like "*device*") {
    Write-Host "Device is authorized. Proceeding with adb command."
    # executing adb command and checking the result
    try {
        $adbCommandOutput = & $adbPath shell settings get system csc_pref_camera_forced_shuttersound_key
        if ($adbCommandOutput -eq "1") {
            & $adbPath shell settings put system csc_pref_camera_forced_shuttersound_key 0
            $adbCommandOutput = & $adbPath shell settings get system csc_pref_camera_forced_shuttersound_key

            if ($adbCommandOutput -eq "0") {
                Write-Host "Camera shutter sound disabled successfully."
            } else {
                Write-Host "Failed to disable camera shutter sound. The current value is: $adbCommandOutput"
            }
        } else {
            Write-Host "Camera shutter sound is already disabled."
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