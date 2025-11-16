cls

#Requires -RunAsAdministrator

$isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║           ADMINISTRATOR PRIVILEGES REQUIRED       ║" -ForegroundColor Red
    Write-Host "║     Please run this script as Administrator!      ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Red
    exit
}

function Show-Section {
    param([string]$Title)
    Write-Host "`n╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "║  $Title" -ForegroundColor Cyan -NoNewline
    $padding = 67 - $Title.Length
    Write-Host (" " * $padding + "║") -ForegroundColor DarkCyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
}

Write-Host "`n                      SYSTEM ANALYSIS TOOL" -ForegroundColor Cyan
Write-Host "                   made by denischifer | funtime" -ForegroundColor DarkCyan

Show-Section "SYSTEM INFORMATION"
try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $bootTime = $osInfo.LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    Write-Host ("  OS Version: {0}" -f $osInfo.Caption) -ForegroundColor White
    Write-Host ("  Last Boot: {0}" -f $bootTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
    Write-Host ("  Uptime: {0} days, {1:D2}:{2:D2}:{3:D2}" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds) -ForegroundColor White
} catch { Write-Host "  Unable to retrieve boot time information" -ForegroundColor Red }

Show-Section "CONNECTED DRIVES & USB HISTORY"
$drives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
if ($drives) {
    foreach ($drive in $drives) {
        $driveLabel = if ([string]::IsNullOrWhiteSpace($drive.VolumeName)) { "No Label" } else { $drive.VolumeName }
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSizeGB = [math]::Round($drive.Size / 1GB, 2)
        Write-Host ("  {0} ({1}) - {2} | {3} GB free of {4} GB" -f $drive.DeviceID, $driveLabel, $drive.FileSystem, $freeSpaceGB, $totalSizeGB) -ForegroundColor Green
    }
}

Write-Host "`n  USB DEVICE HISTORY:" -ForegroundColor White
try {
    $usbDevices = @()
    $usbStorPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    
    if (Test-Path $usbStorPath) {
        $deviceKeys = Get-ChildItem -Path $usbStorPath -ErrorAction SilentlyContinue
        foreach ($deviceKey in $deviceKeys) {
            $instances = Get-ChildItem -Path $deviceKey.PSPath -ErrorAction SilentlyContinue
            foreach ($instance in $instances) {
                $friendlyName = (Get-ItemProperty -Path $instance.PSPath -Name "FriendlyName" -ErrorAction SilentlyContinue).FriendlyName
                $lastWrite = $instance.LastWriteTime
                
                if ($friendlyName) {
                    $usbDevices += [PSCustomObject]@{
                        Name = $friendlyName
                        LastConnected = $lastWrite
                    }
                }
            }
        }
    }
    
    if ($usbDevices.Count -gt 0) {
        $usbDevices | Sort-Object LastConnected -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host ("    Device: {0}" -f $_.Name) -ForegroundColor Gray
            Write-Host ("      Last Connected: {0}" -f $_.LastConnected.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Yellow
        }
    } else {
        Write-Host "    No USB device history found." -ForegroundColor Green
    }
} catch {
    Write-Host "    Unable to retrieve USB device history." -ForegroundColor Red
}

Show-Section "NETWORK INFORMATION"
Write-Host "  Network Adapters Configuration:" -ForegroundColor White

$adapters = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address -ne $null }

if ($adapters) {
    foreach ($adapter in $adapters) {
        Write-Host "`n    ═══ $($adapter.InterfaceAlias) ═══" -ForegroundColor Cyan
        
        $dnsConnectionSuffix = $adapter.DNSSuffix
        if ($dnsConnectionSuffix) {
            Write-Host ("      DNS Connection Suffix: {0}" -f $dnsConnectionSuffix) -ForegroundColor Gray
        }
        
        if ($adapter.IPv4Address) {
            foreach ($ipv4 in $adapter.IPv4Address) {
                Write-Host ("      IPv4 Address: {0}" -f $ipv4.IPAddress) -ForegroundColor White
                
                $prefixLength = $ipv4.PrefixLength
                $subnetMask = switch ($prefixLength) {
                    24 { "255.255.255.0" }
                    16 { "255.255.0.0" }
                    8 { "255.0.0.0" }
                    default { 
                        $maskBits = ('1' * $prefixLength).PadRight(32, '0')
                        $octets = @()
                        for ($i = 0; $i -lt 32; $i += 8) {
                            $octets += [Convert]::ToByte($maskBits.Substring($i, 8), 2)
                        }
                        $octets -join '.'
                    }
                }
                Write-Host ("      Subnet Mask: {0}" -f $subnetMask) -ForegroundColor Gray
            }
        }
        
        if ($adapter.IPv4DefaultGateway) {
            Write-Host ("      Default Gateway: {0}" -f ($adapter.IPv4DefaultGateway.NextHop -join ", ")) -ForegroundColor Gray
        }
        
        $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dnsServers -and $dnsServers.ServerAddresses) {
            Write-Host ("      DNS Servers: {0}" -f ($dnsServers.ServerAddresses -join ", ")) -ForegroundColor Gray
        }
    }
} else {
    Write-Host "    No network adapters with IPv4 configuration found." -ForegroundColor Yellow
}

Write-Host "`n  Port 25565 TCP Connections:" -ForegroundColor White
$netstatResult = netstat -an | Select-String "25565" | Select-String "TCP"
if ($netstatResult) {
    $netstatResult | ForEach-Object {
        Write-Host ("    {0}" -f $_.Line.Trim()) -ForegroundColor Yellow
    }
} else {
    Write-Host "    No active connections on port 25565" -ForegroundColor Green
}

Show-Section "SERVICE STATUS"
$services = @(
    @{Name = "SysMain"; DisplayName = "SysMain"}, @{Name = "PcaSvc"; DisplayName = "Program Compatibility Assistant Service"},
    @{Name = "DPS"; DisplayName = "Diagnostic Policy Service"}, @{Name = "EventLog"; DisplayName = "Windows Event Log"},
    @{Name = "Schedule"; DisplayName = "Task Scheduler"}, @{Name = "Bam"; DisplayName = "Background Activity Moderator"},
    @{Name = "Dusmsvc"; DisplayName = "Data Usage"}, @{Name = "Appinfo"; DisplayName = "Application Information"},
    @{Name = "CDPSvc"; DisplayName = "Connected Devices Platform Service"}, @{Name = "DcomLaunch"; DisplayName = "DCOM Server Process Launcher"},
    @{Name = "PlugPlay"; DisplayName = "Plug and Play"}, @{Name = "wsearch"; DisplayName = "Windows Search"}
)
foreach ($svc in $services) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        $displayName = if ($service.DisplayName.Length -gt 40) { "$($service.DisplayName.Substring(0, 37))..." } else { $service.DisplayName }
        if ($service.Status -eq "Running") {
            Write-Host ("  {0,-12} {1,-40}" -f $svc.Name, $displayName) -ForegroundColor Green -NoNewline
            try {
                $process = Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" | Select-Object ProcessId
                if ($process.ProcessId -gt 0) {
                    $proc = Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
                    if ($proc) { Write-Host (" | PID: {0,-5} | Started: {1}" -f $proc.Id, $proc.StartTime.ToString("HH:mm:ss")) -ForegroundColor Yellow } else { Write-Host " | N/A" -ForegroundColor Yellow }
                } else { Write-Host " | N/A" -ForegroundColor Yellow }
            } catch { Write-Host " | N/A" -ForegroundColor Yellow }
        } else { Write-Host ("  {0,-12} {1,-40} {2}" -f $svc.Name, $displayName, $service.Status) -ForegroundColor Red }
    } else { Write-Host ("  {0,-12} {1,-40} {2}" -f $svc.Name, "Not Found", "N/A") -ForegroundColor Yellow }
}

Show-Section "SECURITY STATUS"
try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defenderStatus) {
        Write-Host "  Windows Defender:" -ForegroundColor White
        $avEnabled = $defenderStatus.AntivirusEnabled
        $rtEnabled = $defenderStatus.RealTimeProtectionEnabled
        $avStatus = if ($avEnabled -and $rtEnabled) { "Enabled" } else { "Disabled" }
        $avColor = if ($avEnabled -and $rtEnabled) { "Green" } else { "Red" }
        
        Write-Host ("    Status: {0}" -f $avStatus) -ForegroundColor $avColor
        
        $sigAge = (Get-Date) - $defenderStatus.AntivirusSignatureLastUpdated
        $sigStatus = if ($sigAge.Days -eq 0) { "Up to date" } elseif ($sigAge.Days -eq 1) { "1 day old" } else { "$($sigAge.Days) days old" }
        $sigColor = if ($sigAge.Days -le 1) { "Green" } else { "Yellow" }
        Write-Host ("    Definitions: {0} (Updated: {1})" -f $sigStatus, $defenderStatus.AntivirusSignatureLastUpdated.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor $sigColor
    } else {
        $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction SilentlyContinue
        if ($avProducts) {
            foreach ($product in $avProducts) {
                $state = "{0:X6}" -f $product.productState
                $enabledStatus = if ($state.Substring(2, 2) -in @('10', '11')) { "Enabled" } else { "Disabled" }
                $updateStatus = if ($state.Substring(4, 2) -eq '00') { "Up to date" } else { "Needs update" }
                Write-Host ("  Antivirus: {0}" -f $product.displayName) -ForegroundColor White
                Write-Host ("    Status: {0}" -f $enabledStatus) -ForegroundColor (if ($enabledStatus -eq 'Enabled') { 'Green' } else { 'Red' })
                Write-Host ("    Definitions: {0}" -f $updateStatus) -ForegroundColor (if ($updateStatus -eq 'Up to date') { 'Green' } else { 'Yellow' })
            }
        } else {
            Write-Host "  No antivirus information available." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  Unable to retrieve antivirus status." -ForegroundColor Red
}

Show-Section "REGISTRY INFORMATION"
$registrySettings = @(
    @{ Name = "CMD Access"; Path = "HKCU:\Software\Policies\Microsoft\Windows\System"; Key = "DisableCMD"; BadValue = 1; Good = "Available"; Bad = "Disabled" },
    @{ Name = "PowerShell Logging"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; Key = "EnableScriptBlockLogging"; GoodValue = 1; Good = "Enabled"; Bad = "Disabled" },
    @{ Name = "Activities Cache"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Key = "EnableActivityFeed"; GoodValue = 1; Good = "Enabled"; Bad = "Disabled" },
    @{ Name = "Prefetch"; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"; Key = "EnablePrefetcher"; GoodValue = 3; Good = "Enabled (Optimal)"; Bad = "Disabled or Altered" },
    @{ Name = "LSA Protection"; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"; Key = "RunAsPPL"; GoodValue = 1; Good = "Enabled"; Bad = "Disabled" }
)
foreach ($setting in $registrySettings) {
    $value = (Get-ItemProperty -Path $setting.Path -Name $setting.Key -ErrorAction SilentlyContinue).($setting.Key)
    $isBad = if ($null -ne $setting.BadValue) { $value -eq $setting.BadValue } else { $null -eq $value -or $value -ne $setting.GoodValue }
    Write-Host "  $($setting.Name): " -NoNewline -ForegroundColor White
    if ($isBad) { Write-Host $setting.Bad -ForegroundColor Red } else { Write-Host $setting.Good -ForegroundColor Green }
}

function Check-USNJournalState {
    param($driveLetter)
    try {
        $fsutilOutput = fsutil usn queryjournal $driveLetter 2>&1
        if ($fsutilOutput -match "is not active") {
            Write-Host "  USN Journal State ($driveLetter): " -NoNewline -ForegroundColor White; Write-Host "Not Active" -ForegroundColor Red
        } elseif ($fsutilOutput -match "The system cannot find the file specified") {
            Write-Host "  USN Journal State ($driveLetter): " -NoNewline -ForegroundColor White; Write-Host "Journal Deleted" -ForegroundColor Red
        } else { Write-Host "  USN Journal State ($driveLetter): " -NoNewline -ForegroundColor White; Write-Host "Active" -ForegroundColor Green }
    } catch { Write-Host "  USN Journal State ($driveLetter): Unable to query" -ForegroundColor Yellow }
}

Show-Section "EVENT LOGS & ARTIFACTS"
foreach ($drive in $drives) { Check-USNJournalState $drive.DeviceID }
$usn_deletes = try { Get-WinEvent -FilterXml "<QueryList><Query Id='0' Path='Microsoft-Windows-Ntfs/Operational'><Select Path='Microsoft-Windows-Ntfs/Operational'>*[System[EventID=501]] and *[EventData[Data[@Name='ProcessName'] and (Data='fsutil.exe')]]</Select></Query></QueryList>" -MaxEvents 1 -ErrorAction Stop } catch { $null }
if ($usn_deletes) {
    Write-Host "  USN Journal Deletion Event at: " -NoNewline -ForegroundColor White; Write-Host $usn_deletes.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Red
} else { Write-Host "  USN Journal Deletion Events: Not found" -ForegroundColor Green }
$clearEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ID=@(104, 1102)} -MaxEvents 1 -ErrorAction SilentlyContinue
if ($clearEvent) { Write-Host "  Event Logs Cleared Event at: " -NoNewline -ForegroundColor White; Write-Host $($clearEvent.TimeCreated.ToString("MM/dd HH:mm")) -ForegroundColor Red } 
else { Write-Host "  Event Logs Cleared Events: Not found" -ForegroundColor Green }
$lastShutdown = Get-WinEvent -FilterHashtable @{LogName='System'; ID=1074} -MaxEvents 1 -ErrorAction SilentlyContinue
if ($lastShutdown) { Write-Host "  Last Clean Shutdown Event at: " -NoNewline -ForegroundColor White; Write-Host $($lastShutdown.TimeCreated.ToString("MM/dd HH:mm")) -ForegroundColor Yellow } 
else { Write-Host "  Last Clean Shutdown Event: Not found" -ForegroundColor Green }

Show-Section "COMMAND & SCRIPTING HISTORY"
Write-Host "  CONSOLE COMMAND HISTORY (PSReadline):" -ForegroundColor White
try {
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $historyPath) {
        Write-Host "    History File: $historyPath" -ForegroundColor Gray
        Get-Content $historyPath -Tail 10 | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
    } else { Write-Host "    PSReadline history file not found." -ForegroundColor Green }
} catch { Write-Host "    Could not retrieve PSReadline history." -ForegroundColor Red }

Write-Host "`n  POWERSHELL SCRIPTBLOCK LOGS (Last Event):" -ForegroundColor White
$lastScriptBlock = Get-WinEvent -LogName "Microsoft-Windows-PowerShell/Operational" -FilterXPath "*[System[EventID=4104]]" -MaxEvents 1 -ErrorAction SilentlyContinue
if ($lastScriptBlock) {
    Write-Host "    Last ScriptBlock log entry found at: " -NoNewline -ForegroundColor White; Write-Host $lastScriptBlock.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
} else { Write-Host "    No ScriptBlock log entries found." -ForegroundColor Green }

Show-Section "PERSISTENCE MECHANISMS"
Write-Host "  LOCAL USER ACCOUNTS:" -ForegroundColor White
try {
    Get-LocalUser | ForEach-Object {
        $status = if ($_.Enabled) { "Enabled" } else { "Disabled" }; $color = if ($_.Enabled) { "Green" } else { "Red" }
        $lastLogon = if ($_.LastLogon) { $_.LastLogon.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
        Write-Host ("    {0,-20} Status: " -f $_.Name) -NoNewline -ForegroundColor Gray
        Write-Host ("{0,-10}" -f $status) -NoNewline -ForegroundColor $color; Write-Host (" Last Logon: {0}" -f $lastLogon) -ForegroundColor Gray
    }
} catch { Write-Host "    Could not retrieve local user accounts." -ForegroundColor Red }

Write-Host "`n  STARTUP FOLDER SHORTCUTS:" -ForegroundColor White
$startupPaths = @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))
$foundLinks = $false
try {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($path in $startupPaths | Where-Object { Test-Path $_ }) {
        $links = Get-ChildItem -Path $path -Filter *.lnk -File -ErrorAction SilentlyContinue
        if ($links) {
            $foundLinks = $true; Write-Host "    From Folder: $path" -ForegroundColor Gray
            foreach ($link in $links) {
                $target = try { $shell.CreateShortcut($link.FullName).TargetPath } catch { "Error reading target" }
                Write-Host ("      {0} -> {1}" -f $link.Name, $target) -ForegroundColor Yellow
            }
        }
    }
    if (-not $foundLinks) { Write-Host "    No shortcuts found in startup folders." -ForegroundColor Green }
} catch { Write-Host "    Error processing startup shortcuts." -ForegroundColor Red } finally { if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } }

Write-Host "`n  STARTUP PROGRAMS (Registry Run Keys):" -ForegroundColor White
$runKeys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$foundStartup = $false
foreach ($key in $runKeys | Where-Object { Test-Path $_ }) {
    $properties = Get-ItemProperty -Path $key
    $psobject = $properties.psobject.Properties | Where-Object { $_.Name -notmatch "^PS" }
    if ($psobject) {
        $foundStartup = $true; Write-Host "    From Key: $key" -ForegroundColor Gray
        $psobject | ForEach-Object { Write-Host ("      '{0}' -> '{1}'" -f $_.Name, $_.Value) -ForegroundColor Yellow }
    }
}
if (-not $foundStartup) { Write-Host "    No startup entries found in common Run keys." -ForegroundColor Green }

Show-Section "RECENTLY ACCESSED FILES"
try {
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    $recentItems = Get-ChildItem -Path $recentPath -Filter *.lnk -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10
    if ($recentItems) {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($item in $recentItems) {
            $target = try { $shell.CreateShortcut($item.FullName).TargetPath } catch { "Unresolvable" }
            if ($target) { Write-Host ("  {0,-40} -> {1}" -f $item.BaseName, $target) -ForegroundColor White }
        }
    } else { Write-Host "  No recent items found." -ForegroundColor Green }
} catch { Write-Host "  Could not retrieve recent items." -ForegroundColor Red } finally { if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } }

Show-Section "RECYCLE BIN"
try {
    $anyFound = $false
    foreach ($drive in $drives) {
        $recycleBinPath = Join-Path $drive.DeviceID '$Recycle.Bin'
        if (Test-Path -LiteralPath $recycleBinPath) {
            $anyFound = $true
            $userFolders = Get-ChildItem -LiteralPath $recycleBinPath -Directory -Force -ErrorAction SilentlyContinue
            if ($userFolders) {
                $totalItems = 0
                $userFolders | ForEach-Object { $totalItems += (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue).Count }
                $latestModTime = ($userFolders | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
                Write-Host "  $($drive.DeviceID) Recycle Bin: " -NoNewline -ForegroundColor White
                Write-Host "$totalItems items, last modified " -NoNewline -ForegroundColor Yellow
                Write-Host $latestModTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
            } else { Write-Host "  $($drive.DeviceID) Recycle Bin: Empty" -ForegroundColor Green }
        }
    }
    if (-not $anyFound) { Write-Host "  Recycle Bin folders not found on any drives." -ForegroundColor Green }
} catch { Write-Host "  Recycle Bin: Unable to access. $_.Exception.Message" -ForegroundColor Red }

Write-Host "`n╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "║                       ANALYSIS COMPLETE                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""
