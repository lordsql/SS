[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false
$Host.UI.RawUI.WindowTitle = "SS Tools | FunTime 2025"

$menuItems = @(
    [PSCustomObject]@{ Name = 'InjGen'; Type = 'Cmd'; Command = 'curl -OL "https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe" && InjGen.exe && del InjGen.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'Checker'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/Check.ps1)'; HasSide = $false }
    [PSCustomObject]@{ Name = 'Everything'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/ft/Everything15.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'JournalTrace'; Type = 'Download'; Command = 'https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe'; HasSide = $true; SideName = 'Echo Journal'; SideType = 'Download'; SideCommand = 'https://github.com/lordsql/SS/releases/download/funtime/echo-journal.exe' }
    [PSCustomObject]@{ Name = 'WinPrefetchView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/WinPrefetchView.exe'; HasSide = $true; SideName = 'PrefetchView++'; SideType = 'Download'; SideCommand = 'https://github.com/Orbdiff/PrefetchView/releases/download/v1.4/PrefetchView++.exe' }
    [PSCustomObject]@{ Name = 'System Informer'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/systeminformer-build-canary-setup.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'ShellBagsView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/ShellBagsView.exe'; HasSide = $true; SideName = 'ShellBagAnalyzer'; SideType = 'Download'; SideCommand = 'https://github.com/lordsql/SS/releases/download/funtime/shellbag_analyzer_cleaner.exe' }
    [PSCustomObject]@{ Name = 'LastActivityView'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/LastActivityView.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'USBDriveLog'; Type = 'Download'; Command = 'https://github.com/lordsql/SS/releases/download/funtime/USBDriveLog.exe'; HasSide = $false }
    [PSCustomObject]@{ Name = 'ModAnalyzer'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/ModAnalyzer.ps1)'; HasSide = $false }
    [PSCustomObject]@{ Name = 'BamParser'; Type = 'PsCmd'; Command = 'Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/lordsql/SS/refs/heads/main/BamParser.ps1)'; HasSide = $false }
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
            Write-Host "  " -NoNewline
            Write-Host "►" -NoNewline -ForegroundColor Magenta
            Write-Host " " -NoNewline
            
            if ($item.HasSide) {
                if ($sideSelectedState[$i]) {
                    Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor DarkGray
                    Write-Host " • " -NoNewline -ForegroundColor DarkMagenta
                    Write-Host "[$($item.SideName)]" -NoNewline -ForegroundColor Cyan
                } else {
                    Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor Cyan
                    Write-Host " • " -NoNewline -ForegroundColor DarkMagenta
                    Write-Host "[$($item.SideName)]" -NoNewline -ForegroundColor DarkGray
                }
            } else {
                Write-Host "[$($item.Name)]" -NoNewline -ForegroundColor Cyan
            }
            
            $textLength = $item.Name.Length + 6
            if ($item.HasSide) { $textLength += $item.SideName.Length + 6 }
            Write-Host (" " * ($width - 8 - $textLength)) -NoNewline
        } else {
            Write-Host "    " -NoNewline
            
            if ($item.HasSide) {
                Write-Host $item.Name -NoNewline -ForegroundColor Gray
                Write-Host " • " -NoNewline -ForegroundColor DarkGray
                Write-Host $item.SideName -NoNewline -ForegroundColor Gray
                $textLength = $item.Name.Length + $item.SideName.Length + 7
            } else {
                Write-Host $item.Name -NoNewline -ForegroundColor Gray
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
        
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        $totalSize = [int]$response.Headers["Content-Length"]
        
        $webClient = New-Object System.Net.WebClient
        $stream = $webClient.OpenRead($url)
        $fileStream = [System.IO.File]::Create($fileName)
        
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
        
        if ($fileName -like "*.exe") {
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
            
            Start-Process -FilePath $fileName
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
            }
        }
    }
}
