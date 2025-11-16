[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false
$Host.UI.RawUI.WindowTitle = "SS Tools | FunTime 2025"

$downloadPath = "C:\screenshare"

Clear-Host
Write-Host ""
Write-Host "  [*] Initializing session..." -ForegroundColor Yellow
New-Item -Path $downloadPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
Get-Service -Name "cbdhsvc_*" -ErrorAction SilentlyContinue | Restart-Service -Force -ErrorAction SilentlyContinue
Clear-EventLog -LogName "Windows PowerShell" -ErrorAction SilentlyContinue
Write-Host "  [+] Session initialized successfully. Loading..." -ForegroundColor Green
Start-Sleep -Seconds 2

$menuItems = @(
    [PSCustomObject]@{ Name = 'InjGen'; Type = 'Cmd'; Command = "curl -L -o `"$($downloadPath)\InjGen.exe`" `"https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe`" && `"$($downloadPath)\InjGen.exe`" && del `"$($downloadPath)\InjGen.exe`""; HasSide = $false }
    [PSCustomObject]@{ Name = 'Checker'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/Check.ps1)'; HasSide = $false }
    [PSCustomObject]@{ Name = 'Everything'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/ft/Everything15.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'JournalTrace'; Type = 'Download'; Command = 'https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe'; HasSide = $true; SideName = 'Echo Journal'; SideType = 'Download'; SideCommand = 'https://github.com/lordsql/SS/releases/download/funtime/echo-journal.exe' }
    [PSCustomObject]@{ Name = 'WinPrefetchView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/WinPrefetchView.exe'; HasSide = $true; SideName = 'PrefetchView++'; SideType = 'Download'; SideCommand = 'https://github.com/Orbdiff/PrefetchView/releases/download/v1.4/PrefetchView++.exe' }
    [PSCustomObject]@{ Name = 'System Informer'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/systeminformer-build-canary-setup.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'ShellBagsView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/ShellBagsView.exe'; HasSide = $true; SideName = 'ShellBagAnalyzer'; SideType = 'Download'; SideCommand = 'https://github.com/lordsql/SS/releases/download/funtime/shellbag_analyzer_cleaner.exe' }
    [PSCustomObject]@{ Name = 'LastActivityView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/LastActivityView.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'USBDriveLog'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/USBDriveLog.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'ModAnalyzer'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/ModAnalyzer.ps1)'; HasSide = $false }
    [PSCustomObject]@{ Name = 'BamParser'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/BamParser.ps1)'; HasSide = $true; SideName = 'BAMReveal'; SideType = 'Download'; SideCommand = 'https://github.com/Orbdiff/BAMReveal/releases/download/v1.0/BAMReveal.exe'}
    [PSCustomObject]@{ Name = 'Clean & Exit'; Type = 'Clean'; Command = ''; HasSide = $false }
)

$selectedIndex = 0
$sideSelectedState = @{}
for ($i = 0; $i -lt $menuItems.Count; $i++) {
    if ($menuItems[$i].HasSide) {
        $sideSelectedState[$i] = $false
    }
}

function Write-Menu {
    Clear-Host
    $width = 60
    
    Write-Host "`n" -NoNewline
    Write-Host ("  ╔" + "═" * ($width - 4) + "╗") -ForegroundColor DarkCyan
    Write-Host ("  ║" + " " * ($width - 4) + "║") -ForegroundColor DarkCyan
    
    $title = "SS Tools"
    $subtitle = "FunTime 2025 | denischifer"
    $titlePadding = [math]::Floor(($width - 4 - $title.Length) / 2)
    $subtitlePadding = [math]::Floor(($width - 4 - $subtitle.Length) / 2)
    
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host (" " * $titlePadding) -NoNewline
    Write-Host $title -NoNewline -ForegroundColor Cyan
    Write-Host (" " * ($width - 4 - $titlePadding - $title.Length)) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan
    
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host (" " * $subtitlePadding) -NoNewline
    Write-Host $subtitle -NoNewline -ForegroundColor DarkGray
    Write-Host (" " * ($width - 4 - $subtitlePadding - $subtitle.Length)) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan
    
    Write-Host ("  ║" + " " * ($width - 4) + "║") -ForegroundColor DarkCyan
    Write-Host ("  ╠" + "═" * ($width - 4) + "╣") -ForegroundColor DarkCyan
    
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        $item = $menuItems[$i]
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
        
        if ($i -eq $selectedIndex) {
            $itemColor = if ($item.Type -eq 'Clean') { [System.ConsoleColor]::Red } else { [System.ConsoleColor]::Cyan }
            Write-Host "  " -NoNewline
            Write-Host "►" -NoNewline -ForegroundColor Magenta
            Write-Host " " -NoNewline
            
            if ($item.HasSide) {
                if ($sideSelectedState[$i]) {
                    Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor DarkGray
                    Write-Host " • " -NoNewline -ForegroundColor DarkMagenta
                    Write-Host "[$($item.SideName)]" -NoNewline -ForegroundColor $itemColor
                } else {
                    Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor $itemColor
                    Write-Host " • " -NoNewline -ForegroundColor DarkMagenta
                    Write-Host "[$($item.SideName)]" -NoNewline -ForegroundColor DarkGray
                }
            } else {
                Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor $itemColor
            }
            
            $textLength = $item.Name.Length + 6
            if ($item.HasSide) { $textLength += $item.SideName.Length + 6 }
            Write-Host (" " * ($width - 8 - $textLength)) -NoNewline
        } else {
             $itemColor = if ($item.Type -eq 'Clean') { [System.ConsoleColor]::DarkRed } else { [System.ConsoleColor]::Gray }
            Write-Host "    " -NoNewline
            
            if ($item.HasSide) {
                Write-Host $item.Name -NoNewline -ForegroundColor $itemColor
                Write-Host " • " -NoNewline -ForegroundColor DarkGray
                Write-Host $item.SideName -NoNewline -ForegroundColor $itemColor
                $textLength = $item.Name.Length + $item.SideName.Length + 7
            } else {
                Write-Host $item.Name -NoNewline -ForegroundColor $itemColor
                $textLength = $item.Name.Length + 4
            }
            Write-Host (" " * ($width - 8 - $textLength)) -NoNewline
        }
        
        Write-Host " ║" -ForegroundColor DarkCyan
    }
    
    Write-Host ("  ╠" + "═" * ($width - 4) + "╣") -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "  ↑↓ Navigate " -NoNewline -ForegroundColor DarkYellow
    Write-Host "• " -NoNewline -ForegroundColor DarkGray
    Write-Host "←→ Switch " -NoNewline -ForegroundColor DarkYellow
    Write-Host "• " -NoNewline -ForegroundColor DarkGray
    Write-Host "Enter Execute" -NoNewline -ForegroundColor DarkYellow
    Write-Host (" " * 13) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host ("  ╚" + "═" * ($width - 4) + "╝") -ForegroundColor DarkCyan
}

function Show-DownloadProgress {
    param(
        [string]$fileName,
        [int]$percent,
        [string]$status = "Downloading"
    )
    
    $barWidth = 40
    $filled = [math]::Round($barWidth * $percent / 100)
    $empty = $barWidth - $filled
    
    $cursorTop = [Console]::WindowHeight - 5
    [Console]::SetCursorPosition(0, $cursorTop)
    
    Write-Host "  ╔" -NoNewline -ForegroundColor DarkCyan
    Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkCyan
    Write-Host "╗" -ForegroundColor DarkCyan
    
    [Console]::SetCursorPosition(0, $cursorTop + 1)
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
    
    $spinner = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $spinnerIndex = $percent % $spinner.Length
    Write-Host $spinner[$spinnerIndex] -NoNewline -ForegroundColor Yellow
    Write-Host " $status" -NoNewline -ForegroundColor White
    Write-Host ": " -NoNewline -ForegroundColor DarkGray
    
    $displayName = if ($fileName.Length -gt 30) { $fileName.Substring(0, 27) + "..." } else { $fileName }
    Write-Host $displayName -NoNewline -ForegroundColor Cyan
    Write-Host (" " * (56 - $displayName.Length - $status.Length - 5)) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan
    
    [Console]::SetCursorPosition(0, $cursorTop + 2)
    Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
    Write-Host "[" -NoNewline -ForegroundColor DarkGray
    
    for ($i = 0; $i -lt $filled; $i++) {
        Write-Host "█" -NoNewline -ForegroundColor Green
    }
    for ($i = 0; $i -lt $empty; $i++) {
        Write-Host "░" -NoNewline -ForegroundColor DarkGray
    }
    
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    $percentText = "$percent%"
    Write-Host $percentText -NoNewline -ForegroundColor Yellow
    Write-Host (" " * (11 - $percentText.Length)) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan
    
    [Console]::SetCursorPosition(0, $cursorTop + 3)
    Write-Host "  ╚" -NoNewline -ForegroundColor DarkCyan
    Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkCyan
    Write-Host "╝" -ForegroundColor DarkCyan
}

function Download-File {
    param([string]$url)
    
    try {
        $fileName = [System.IO.Path]::GetFileName($url)
        $destinationPath = Join-Path -Path $downloadPath -ChildPath $fileName
        
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        $totalSize = [int]$response.Headers["Content-Length"]
        
        $webClient = New-Object System.Net.WebClient
        $stream = $webClient.OpenRead($url)
        $fileStream = [System.IO.File]::Create($destinationPath)
        
        $buffer = New-Object byte[] 8192
        $totalRead = 0
        $lastPercent = 0
        
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            
            if ($totalSize -gt 0) {
                $percent = [math]::Round(($totalRead / $totalSize) * 100)
                if ($percent -ne $lastPercent) {
                    $lastPercent = $percent
                    Show-DownloadProgress -fileName $fileName -percent $percent -status "Downloading"
                }
            }
        }
        
        $stream.Close()
        $fileStream.Close()
        $webClient.Dispose()
        
        $cursorTop = [Console]::WindowHeight - 5
        [Console]::SetCursorPosition(0, $cursorTop)
        
        Write-Host "  ╔" -NoNewline -ForegroundColor DarkGreen
        Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkGreen
        Write-Host "╗" -ForegroundColor DarkGreen
        
        [Console]::SetCursorPosition(0, $cursorTop + 1)
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkGreen
        Write-Host "✓" -NoNewline -ForegroundColor Green
        Write-Host " Downloaded: " -NoNewline -ForegroundColor White
        Write-Host $fileName -NoNewline -ForegroundColor Green
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host "Launching..." -NoNewline -ForegroundColor Yellow
        Write-Host (" " * (56 - $fileName.Length - 27)) -NoNewline
        Write-Host "║" -ForegroundColor DarkGreen
        
        [Console]::SetCursorPosition(0, $cursorTop + 2)
        Write-Host "  ║" -NoNewline -ForegroundColor DarkGreen
        Write-Host (" " * 56) -NoNewline
        Write-Host "║" -ForegroundColor DarkGreen
        
        [Console]::SetCursorPosition(0, $cursorTop + 3)
        Write-Host "  ╚" -NoNewline -ForegroundColor DarkGreen
        Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkGreen
        Write-Host "╝" -ForegroundColor DarkGreen
        
        if ($destinationPath -like "*.exe") {
            Start-Sleep -Milliseconds 500
            
            [Console]::SetCursorPosition(0, $cursorTop + 1)
            Write-Host "  ║ " -NoNewline -ForegroundColor DarkGreen
            Write-Host "✓" -NoNewline -ForegroundColor Green
            Write-Host " Downloaded: " -NoNewline -ForegroundColor White
            Write-Host $fileName -NoNewline -ForegroundColor Green
            Write-Host " | " -NoNewline -ForegroundColor DarkGray
            Write-Host "🚀 Launched!" -NoNewline -ForegroundColor Cyan
            Write-Host (" " * (56 - $fileName.Length - 26)) -NoNewline
            Write-Host "║" -ForegroundColor DarkGreen
            
            Start-Process -FilePath $destinationPath
        }
        
        Start-Sleep -Seconds 2
        
    } catch {
        $cursorTop = [Console]::WindowHeight - 5
        [Console]::SetCursorPosition(0, $cursorTop)
        
        Write-Host "  ╔" -NoNewline -ForegroundColor DarkRed
        Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkRed
        Write-Host "╗" -ForegroundColor DarkRed
        
        [Console]::SetCursorPosition(0, $cursorTop + 1)
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkRed
        Write-Host "✗" -NoNewline -ForegroundColor Red
        Write-Host " Download failed!" -NoNewline -ForegroundColor Red
        Write-Host (" " * 38) -NoNewline
        Write-Host "║" -ForegroundColor DarkRed
        
        [Console]::SetCursorPosition(0, $cursorTop + 2)
        Write-Host "  ║" -NoNewline -ForegroundColor DarkRed
        $errorMsg = $_.Exception.Message
        if ($errorMsg.Length -gt 54) { $errorMsg = $errorMsg.Substring(0, 51) + "..." }
        Write-Host " $errorMsg" -NoNewline -ForegroundColor DarkRed
        Write-Host (" " * (56 - $errorMsg.Length - 1)) -NoNewline
        Write-Host "║" -ForegroundColor DarkRed
        
        [Console]::SetCursorPosition(0, $cursorTop + 3)
        Write-Host "  ╚" -NoNewline -ForegroundColor DarkRed
        Write-Host ("═" * 56) -NoNewline -ForegroundColor DarkRed
        Write-Host "╝" -ForegroundColor DarkRed
        
        Start-Sleep -Seconds 3
    }
}

function Clean-And-Exit {
    Clear-Host
    $width = 60
    Write-Host "`n"
    Write-Host ("  ╔" + "═" * ($width - 4) + "╗") -ForegroundColor DarkRed
    $cleanTitle = "Clean & Exit Sequence"
    $titlePadding = [math]::Floor(($width - 4 - $cleanTitle.Length) / 2)
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed
    Write-Host (" " * $titlePadding) -NoNewline
    Write-Host $cleanTitle -ForegroundColor Red
    Write-Host (" " * ($width - 4 - $titlePadding - $cleanTitle.Length)) -NoNewline
    Write-Host "║" -ForegroundColor DarkRed
    Write-Host ("  ╠" + "═" * ($width - 4) + "╣") -ForegroundColor DarkRed
    
    function Write-Clean-Status {
        param([string]$Message, [bool]$Success)
        Write-Host "  ║ " -NoNewline -ForegroundColor DarkRed
        if ($Success) {
            Write-Host "✓ " -ForegroundColor Green
        } else {
            Write-Host "✗ " -ForegroundColor Red
        }
        Write-Host $Message -NoNewline -ForegroundColor White
        $padding = $width - 8 - $Message.Length
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor DarkRed
    }

    $processesToKill = @(
        'Everything', 'JournalTrace', 'echo-journal', 'WinPrefetchView', 
        'PrefetchView++', 'SystemInformer', 'ShellBagsView', 
        'shellbag_analyzer_cleaner', 'LastActivityView', 'USBDriveLog', 
        'InjGen', 'BAMReveal'
    )
    
    Start-Sleep -Milliseconds 500
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed; Write-Host (" " * ($width - 4)) -NoNewline; Write-Host "║" -ForegroundColor DarkRed
    $allStopped = $true
    foreach ($procName in $processesToKill) {
        $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($processes) {
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 100
            if ((Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
                $allStopped = $false
            }
        }
    }
    Write-Clean-Status -Message "Terminated running tool processes." -Success $allStopped
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed; Write-Host (" " * ($width - 4)) -NoNewline; Write-Host "║" -ForegroundColor DarkRed
    Start-Sleep -Milliseconds 500
    
    try {
        Get-Service -Name "cbdhsvc_*" | Restart-Service -Force -ErrorAction Stop
        Write-Clean-Status -Message "Clipboard User Service restarted." -Success $true
    } catch {
        Write-Clean-Status -Message "Clipboard Service could not be restarted." -Success $false
    }
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed; Write-Host (" " * ($width - 4)) -NoNewline; Write-Host "║" -ForegroundColor DarkRed
    Start-Sleep -Milliseconds 500
    
    try {
        Clear-EventLog -LogName "Windows PowerShell" -ErrorAction Stop
        Write-Clean-Status -Message "Windows PowerShell event log cleared." -Success $true
    } catch {
        Write-Clean-Status -Message "Failed to clear PowerShell event log." -Success $false
    }
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed; Write-Host (" " * ($width - 4)) -NoNewline; Write-Host "║" -ForegroundColor DarkRed
    Start-Sleep -Milliseconds 500

    if (Test-Path $downloadPath) {
        try {
            Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction Stop
            Write-Clean-Status -Message "Removed working directory: $downloadPath" -Success $true
        } catch {
            Write-Clean-Status -Message "Failed to remove directory: $downloadPath" -Success $false
        }
    } else {
        Write-Clean-Status -Message "Working directory not found, nothing to remove." -Success $true
    }
    Write-Host "  ║" -NoNewline -ForegroundColor DarkRed; Write-Host (" " * ($width - 4)) -NoNewline; Write-Host "║" -ForegroundColor DarkRed
    Start-Sleep -Milliseconds 500

    Write-Host ("  ╚" + "═" * ($width - 4) + "╝") -ForegroundColor DarkRed
    Write-Host "`n  Cleanup complete. Exiting in 3 seconds..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 3
    [Console]::CursorVisible = $true
    Clear-Host
    exit
}

while ($true) {
    Write-Menu
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    switch ($key.VirtualKeyCode) {
        38 { 
            if ($selectedIndex -gt 0) { $selectedIndex-- }
        }
        40 { 
            if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex++ }
        }
        37 { 
            if ($menuItems[$selectedIndex].HasSide) {
                $sideSelectedState[$selectedIndex] = $false
            }
        }
        39 { 
            if ($menuItems[$selectedIndex].HasSide) {
                $sideSelectedState[$selectedIndex] = $true
            }
        }
        13 {
            $item = $menuItems[$selectedIndex]
            $isSide = $item.HasSide -and $sideSelectedState[$selectedIndex]
            
            $type = if ($isSide) { $item.SideType } else { $item.Type }
            $command = if ($isSide) { $item.SideCommand } else { $item.Command }
            
            switch ($type) {
                'Cmd' {
                    Start-Process cmd.exe -ArgumentList "/c $command"
                }
                'PsCmd' {
                    $psCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command `"$command`""
                    Start-Process cmd.exe -ArgumentList "/k $psCommand"
                }
                'Download' {
                    Download-File -url $command
                }
                'Clean' {
                    Clean-And-Exit
                }
            }
        }
    }
}
