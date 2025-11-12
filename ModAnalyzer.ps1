Clear-Host
$Host.UI.RawUI.WindowTitle = "FunTime Mod Analyzer"

Write-Host ""
Write-Host "    ╔════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
Write-Host "    ║                                                ║" -ForegroundColor DarkMagenta
Write-Host "    ║" -ForegroundColor DarkMagenta -NoNewline
Write-Host "        ✨ FunTime Mod Analyzer ✨" -ForegroundColor Cyan -NoNewline
Write-Host "          ║" -ForegroundColor DarkMagenta
Write-Host "    ║" -ForegroundColor DarkMagenta -NoNewline
Write-Host "              created by denischifer" -ForegroundColor Gray -NoNewline
Write-Host "           ║" -ForegroundColor DarkMagenta
Write-Host "    ║                                                ║" -ForegroundColor DarkMagenta
Write-Host "    ╚════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta
Write-Host ""

Write-Host "  📁 " -NoNewline
Write-Host "Путь до папки модов " -ForegroundColor White -NoNewline
Write-Host "[Enter = default]" -ForegroundColor DarkGray
Write-Host "  └─➤ " -ForegroundColor DarkCyan -NoNewline
$mods = Read-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host ""
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Используется путь по умолчанию" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "→ " -ForegroundColor DarkGray -NoNewline
    Write-Host $mods -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "  ❌ " -ForegroundColor Red -NoNewline
    Write-Host "Неверный путь!" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) {
    $process = Get-Process java -ErrorAction SilentlyContinue
}

if ($process) {
    if ($process.Count -gt 1) {
        $process = $process[0]
    }
    
    try {
        $startTime = $process.StartTime
        $elapsedTime = (Get-Date) - $startTime
        
        Write-Host "  🎮 " -NoNewline
        Write-Host "Minecraft Status" -ForegroundColor Cyan
        Write-Host "    ├─ " -ForegroundColor DarkGray -NoNewline
        Write-Host "Process: " -ForegroundColor Gray -NoNewline
        Write-Host "$($process.Name).exe " -ForegroundColor White -NoNewline
        Write-Host "(PID: $($process.Id))" -ForegroundColor DarkGray
        Write-Host "    ├─ " -ForegroundColor DarkGray -NoNewline
        Write-Host "Started: " -ForegroundColor Gray -NoNewline
        Write-Host "$($startTime.ToString('HH:mm:ss'))" -ForegroundColor White
        Write-Host "    └─ " -ForegroundColor DarkGray -NoNewline
        Write-Host "Uptime:  " -ForegroundColor Gray -NoNewline
        Write-Host "$($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s" -ForegroundColor Green
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
    } catch {}
}

function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Get-ZoneIdentifier {
    param (
        [string]$filePath
    )
    $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
    if ($ads -match "HostUrl=(.+)") {
        return $matches[1]
    }
    
    return $null
}

function Fetch-Modrinth {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $projectData.title; Slug = $projectData.slug }
        }
    } catch {}
    
    return @{ Name = ""; Slug = "" }
}

function Fetch-Megabase {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $response.error) {
            return $response.data
        }
    } catch {}
    
    return $null
}

$cheatStrings = @(
    "AimAssist",
    "AnchorTweaks",
    "AutoAnchor",
    "AutoCrystal",
    "AutoAnchor",
    "AutoDoubleHand",
    "AutoHitCrystal",
    "AutoPot",
    "AutoTotem",
    "AutoArmor",
    "InventoryTotem",
    "Hitboxes",
    "JumpReset",
    "AutoBuy",
    "AutoFish",
    "AutoMyst",
    "LegitTotem",
    "PingSpoof",
    "SelfDestruct",
    "ShieldBreaker",
    "TriggerBot",
    "Velocity",
    "AxeSpam",
    "WebMacro",
    "SelfDestruct",
    "FastPlace"
)

function Check-Strings {
    param (
        [string]$filePath
    )
    
    $stringsFound = [System.Collections.Generic.HashSet[string]]::new()
    
    $fileContent = Get-Content -Raw $filePath
    
    foreach ($line in $fileContent) {
        foreach ($string in $cheatStrings) {
            if ($line -match $string) {
                $stringsFound.Add($string) | Out-Null
                continue
            }
        }
    }
    
    return $stringsFound
}

function Show-Progress {
    param(
        [int]$current,
        [int]$total,
        [string]$status
    )
    
    $percent = [math]::Round(($current / $total) * 100)
    $filled = [math]::Round($percent / 2)
    $empty = 50 - $filled
    
    $bar = "█" * $filled + "░" * $empty
    
    Write-Host "`r  " -NoNewline
    Write-Host "[$bar]" -ForegroundColor Cyan -NoNewline
    Write-Host " $percent% " -ForegroundColor White -NoNewline
    Write-Host "│ $status" -ForegroundColor Gray -NoNewline
}

$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$totalMods = $jarFiles.Count
$counter = 0

Write-Host "  🔍 " -NoNewline
Write-Host "Анализ модов" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $jarFiles) {
    $counter++
    
    Show-Progress -current $counter -total $totalMods -status "Проверка: $($file.Name.Substring(0, [Math]::Min($file.Name.Length, 30)))..."
    
    $hash = Get-SHA1 -filePath $file.FullName
    
    $modDataModrinth = Fetch-Modrinth -hash $hash
    if ($modDataModrinth.Slug) {
        $verifiedMods += [PSCustomObject]@{ ModName = $modDataModrinth.Name; FileName = $file.Name; Source = "Modrinth" }
        continue;
    }
    
    $modDataMegabase = Fetch-Megabase -hash $hash
    if ($modDataMegabase.name) {
        $verifiedMods += [PSCustomObject]@{ ModName = $modDataMegabase.Name; FileName = $file.Name; Source = "Megabase" }
        continue;
    }
    
    $zoneId = Get-ZoneIdentifier $file.FullName
    $unknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneId }
}

if ($unknownMods.Count -gt 0) {
    $tempDir = Join-Path $env:TEMP "ftmodanalyzer"
    
    $counter = 0
    
    try {
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    
        foreach ($mod in $unknownMods) {
            $counter++
            
            Show-Progress -current $counter -total $unknownMods.Count -status "Глубокий анализ: $($mod.FileName.Substring(0, [Math]::Min($mod.FileName.Length, 25)))..."
            
            $modStrings = Check-Strings $mod.FilePath
            if ($modStrings.Count -gt 0) {
                $unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
                $cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; StringsFound = $modStrings }
                continue
            }
            
            $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($mod.FileName)
            $extractPath = Join-Path $tempDir $fileNameWithoutExt
            New-Item -ItemType Directory -Path $extractPath | Out-Null
            
            [System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FilePath, $extractPath)
            
            $depJarsPath = Join-Path $extractPath "META-INF/jars"
            if (-not $(Test-Path $depJarsPath)) {
                continue
            }
            
            $depJars = Get-ChildItem -Path $depJarsPath
            foreach ($jar in $depJars) {
                $depStrings = Check-Strings $jar.FullName
                if (-not $depStrings) {
                    continue
                }
                $unknownMods = @($unknownMods | Where-Object -FilterScript {$_ -ne $mod})
                $cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = $jar.Name; StringsFound = $depStrings }
            }
            
        }
    } catch {
        Write-Host "`r  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

Write-Host "`r$(' ' * 100)`r" -NoNewline
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  📊 " -NoNewline
Write-Host "РЕЗУЛЬТАТЫ СКАНИРОВАНИЯ" -ForegroundColor Cyan
Write-Host ""

if ($verifiedMods.Count -gt 0) {
    Write-Host "  ✅ " -NoNewline
    Write-Host "Официальные моды " -ForegroundColor Green -NoNewline
    Write-Host "($($verifiedMods.Count))" -ForegroundColor DarkGreen
    Write-Host ""
    foreach ($mod in $verifiedMods) {
        Write-Host "     • " -ForegroundColor DarkGreen -NoNewline
        Write-Host "$($mod.ModName)" -ForegroundColor White -NoNewline
        Write-Host " [$($mod.Source)]" -ForegroundColor DarkGray
        Write-Host "       " -NoNewline
        Write-Host "└─ " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "  ⚠️  " -NoNewline
    Write-Host "Неизвестные моды " -ForegroundColor Yellow -NoNewline
    Write-Host "($($unknownMods.Count))" -ForegroundColor DarkYellow
    Write-Host ""
    foreach ($mod in $unknownMods) {
        Write-Host "     • " -ForegroundColor DarkYellow -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor White
        if ($mod.ZoneId) {
            Write-Host "       " -NoNewline
            Write-Host "└─ " -ForegroundColor DarkGray -NoNewline
            Write-Host "Источник: " -ForegroundColor Gray -NoNewline
            Write-Host "$($mod.ZoneId)" -ForegroundColor DarkCyan
        }
    }
    Write-Host ""
}

if ($cheatMods.Count -gt 0) {
    Write-Host "  🚫 " -NoNewline
    Write-Host "ОБНАРУЖЕНЫ ЧИТ-МОДЫ! " -ForegroundColor Red -NoNewline
    Write-Host "($($cheatMods.Count))" -ForegroundColor DarkRed
    Write-Host ""
    foreach ($mod in $cheatMods) {
        Write-Host "     ⚠ " -ForegroundColor Red -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor Yellow
        if ($mod.DepFileName) {
            Write-Host "       " -NoNewline
            Write-Host "├─ " -ForegroundColor DarkRed -NoNewline
            Write-Host "Вложенный файл: " -ForegroundColor Gray -NoNewline
            Write-Host "$($mod.DepFileName)" -ForegroundColor Red
        }
        Write-Host "       " -NoNewline
        Write-Host "└─ " -ForegroundColor DarkRed -NoNewline
        Write-Host "Обнаружено: " -ForegroundColor Gray -NoNewline
        Write-Host "$($mod.StringsFound -join ', ')" -ForegroundColor Magenta
    }
    Write-Host ""
}

Write-Host "  ═══════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  💡 " -NoNewline
Write-Host "Сканирование завершено" -ForegroundColor Cyan
Write-Host ""
