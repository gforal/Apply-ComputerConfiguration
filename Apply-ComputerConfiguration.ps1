<#

    .DESCRIPTION    
    
    A script to import a JSON database of registry settings. Script works best for environments where no user is logged in or when the DEFAULT user is the target (AKA, OSD Task Sequences). Support for logged-on users is on-going and is experimental.

    .PARAMETER SettingsLibrary 
    
    Required parameter that tells the script which JSON to import.

    .PARAMETER LOGFILE

    Optional parameter what the logfile should be. By default, transciption is saved to the current directory from which the script runs.

    .NOTES
    
    Author:     Graham Foral
    Date:       9/27/2022
#>


param(
    
$SettingsLibrary,
$LogFile = "ApplyComputerSettings_" + (Get-ChildItem $SettingsLibrary).Name + "_" + (Get-Date -Format yyyy-MM-dd_HHmmss) + ".log"

)

Start-Transcript -Path $LogFile

$ExecDir = $MyInvocation.MyCommand.Path
$ConfigItems = Get-Content -Raw -Path $SettingsLibrary | ConvertFrom-Json
$CurrentItem = 1

$MachineConfigItems = $ConfigItems | Where-Object { $ConfigItems.Hive -ne "HKCU" }
$UserConfigItems = $ConfigItems | Where-Object { $ConfigItems.Hive -eq "HKCU" }

$UserProfiles = Get-ChildItem -Path "C:\Users" -Directory -Force -Exclude "All Users", "Default User", "Public"

Write-Host "Information: " -ForegroundColor Green -NoNewline
Write-Host "Executing from $ExecDir"

Write-Host "Information: " -ForegroundColor Green -NoNewline
Write-Host "There are $($MachineConfigItems.count) computer registry entries queued for writing."

Write-Host "Information: " -ForegroundColor Green -NoNewline
Write-Host "There are $($UserConfigItems.count) user registry entries queued for writing."



ForEach ($MachineConfigItem in $MachineConfigItems) {
    $RegPath = $MachineConfigItem.Hive + ":`\" + $MachineConfigItem.Path 

    If ($MachineConfigItem.Comment) {

        If (Get-Item -Path $RegPath -ErrorAction SilentlyContinue) {
            Write-Host "Information: " -ForegroundColor Green -NoNewline
            Write-Host "Item $($CurrentItem):`t `'$RegPath`' exists. Setting $($MachineConfigItem.Name) to $($MachineConfigItem.Value)"

            New-ItemProperty -Path $RegPath -Name $MachineConfigItem.Name -Value $MachineConfigItem.Value -PropertyType $MachineConfigItem.Type -Force | Out-Null
            $CurrentItem = $CurrentItem + 1
        }
        Else {
            Write-Host "Information: " -ForegroundColor Green -NoNewline
            Write-Host "Item $($CurrentItem):`t `'$RegPath`' does not exist. Creating path and setting $($MachineConfigItem.Name) to $($MachineConfigItem.Value)..."

            New-Item -Path $RegPath -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name $MachineConfigItem.Name -Value $MachineConfigItem.Value -PropertyType $MachineConfigItem.Type -Force | Out-Null
            $CurrentItem = $CurrentItem + 1            
        }
    }
    Else {
        Write-Host "Error: " -ForegroundColor Red -NoNewline
        Write-Host "Item $CurrentItem has no comment... This entry will be skipped."
        $CurrentItem = $CurrentItem + 1
    }

}
If ($UserConfigItems) {
    Write-Host "Information: " -ForegroundColor Green -NoNewline
    Write-Host "Found $($UserProfiles.count) user profiles."

    ForEach ($UserProfile in $UserProfiles) {
        Write-Host "Information: " -ForegroundColor Green -NoNewline
        Write-Host "Attempting to load NTUSER.DAT for user $($UserProfile.Name)."
    
        & reg.exe load "HKLM\ConfigTemp" "$UserProfile\NTUSER.DAT"
    
        ForEach ($UserConfigItem in $UserConfigItems) {
            $RegPath = $UserConfigItem.Hive + ":`\" + $UserConfigItem.Path 
            $RegPath = $RegPath.Replace("HKCU:", "HKLM:\ConfigTemp")

            If ($UserConfigItem.Comment) {

                If (Get-Item -Path $RegPath -ErrorAction SilentlyContinue) {
                    Write-Host "Information: " -ForegroundColor Green -NoNewline
                    Write-Host "Item $($CurrentItem):`t `'$RegPath`' Exists. Setting values in configuration file."

                    New-ItemProperty -Path $RegPath -Name $UserConfigItem.Name -Value $UserConfigItem.Value -PropertyType $UserConfigItem.Type -Force | Out-Null
                    $CurrentItem = $CurrentItem + 1
                }
                Else {
                    Write-Host "Information: " -ForegroundColor Green -NoNewline
                    Write-Host "Item $($CurrentItem):`t `'$RegPath`' Does not exist. Creating..."
            
                    New-Item -Path $RegPath -Force | Out-Null
                    New-ItemProperty -Path $RegPath -Name $UserConfigItem.Name -Value $UserConfigItem.Value -PropertyType $UserConfigItem.Type -Force | Out-Null
                    $CurrentItem = $CurrentItem + 1 
                      
                }
            }
            Else {
                Write-Host "Error: " -ForegroundColor Red -NoNewline
                Write-Host "Item $CurrentItem has no comment... This entry will be skipped."
                $CurrentItem = $CurrentItem + 1
            }    
    
        }
        Write-Host "Information: " -ForegroundColor Green -NoNewline
        Write-Host "Unloading $UserProfile\NTUSER.DAT"
        [gc]::Collect()
        Start-Sleep -Seconds 2
        & reg.exe unload "HKLM\ConfigTemp"
        $CurrentItem = 1   
    }
}
Stop-Transcript
