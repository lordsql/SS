$dps = @("CortexClient:::2023/11/11:12:57:00", "PhasmaClient:::2024/01/10:14:28:11","NoRender:::2023/09/05:20:12:29","AvaloneClient:::2023/05/09:19:10:04","AvaloneGreen:::2023/10/04:16:07:05","AvaloneBlue:::2023/07/03:22:01:11","AnapaV4:::2022/06/07:07:45:55","TakkerProxy:::2022/07/08:23:42:38","UsbCleaner:::2021/11/29:17:36:29","Hider:::2024/01/11:21:51:35", "Blast3xStringRemover:::2022/07/06:20:23:42","R-WipeCleaner:::2024/08/14:18:46:25","ResourceHacker:::2023/11/19:10:07:11","RevoCleaner:::2023/06/06:06:27:09","WiseFolderHider:::2024/03/15:02:10:26","HideFolders:::2023/11/26:21:51:07","Nemezida:::2024/05/31:21:46:54","OceanBypass:::2024/09/29:19:06:37","Hider2:::2024/04/07:19:32:29","WhiteGhostInt:::!2024/11/16:18:35:38","DpsChanger:::!2023/08/28:19:45:41","StringCleaner:::!2024/05/12:10:17:07","StubbornCleaner:::!2023/08/08:13:23:36","Vanish:::!2100/01/16:16:45:26","MicoHitBoxes:::!2024/09/11:23:23:32","MerzlotaCleaner:::!2024/09/08:19:10:30","SizeChanger:::!2024/09/19:16:34:40","Unicorn:::!2076/05/18:04:53:15","FakeJT:::!2066/10/01:22:12:07", "CortexNew:::2025/08/29:03:57:16")
$pca = @("CortexClient:::0x16ed000","TroxillClient:::0x1b44000","PhasmaClient:::0x16a4000","VapeV4:::0xbcb000","VapeLite:::0x1709000","AmmitDLC:::0x3a23000","NobiumClient:::0x1c06000","NoRender:::0x82ed000","AvaloneClient:::0x19f2000","AvaloneGreen:::0x140b000","AvaloneBlue:::0x13f9000","BlessedClient:::0x2335000","AnapaV4:::0xe96000","DripLite:::0x192a000","TakkerProxy:::0x268f000","UsbCleaner:::0x2d3000","Hider:::0x16000","Blast3xStringRemover:::0x5c000","R-WipeCleaner:::0x112000","ResourceHacker:::0x61b000","RevoCleaner:::0xe79000","WiseFolderHider:::0xadf000","HideFolders:::0xe0c000","Nemezida:::0x2199000","OceanBypass:::0xe000","Hider2:::0x88000","WhiteGhostInt:::0x349f000","DpsChanger:::0x54000","StringCleaner:::0x76000","StubbornCleaner:::0x1bf2000","Vanish:::0x15e000","MicoHitBoxes:::0x18be000","MerzlotaCleaner:::0x50000","SizeChanger:::0x2b000","Unicorn:::0xa20000")

$toolPath = "xxstrings64.exe"
if (-not (Test-Path $toolPath)) {
    Invoke-WebRequest -Uri "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe" -OutFile $toolPath -ErrorAction SilentlyContinue
}

$dpsHash = @{}
foreach ($str in $dps) {
    $parts = $str -split ":::"
    $dpsHash[$parts[1]] = $parts[0]
}

$pcaHash = @{}
foreach ($str in $pca) {
    $parts = $str -split ":::"
    $pcaHash[$parts[1]] = $parts[0]
}

function Get-ServicePID {
    param([string]$ServiceName)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        $wmiproc = Get-WmiObject Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $ServiceName }
        return $wmiproc.ProcessId
    }
    return $null
}

function Get-ProcessStrings {
    param([int]$PID)
    if ($PID) {
        $output = & $toolPath -p $PID 2>$null
        return $output | Out-String | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    return @()
}

function Test-ModifiedExtension {
    param([string]$Line)
    $filter = '^\\device\\harddiskvolume((?!.*\.(exe|dll)).)*\..*$'
    return [System.Text.RegularExpressions.Regex]::IsMatch($Line, $filter)
}

function Test-DpsDetection {
    param([string]$Line, [hashtable]$Hash)
    foreach ($key in $Hash.Keys) {
        if ($Line.Contains($key)) {
            $pukpart = ($Line -split "!")[2]
            return @{ Detected = $true; Name = $Hash[$key]; Detail = $pukpart }
        }
    }
    return @{ Detected = $false }
}

function Test-ExeSignature {
    param([string]$Line, [string]$Prefix, [array]$ProcessedPaths)
    $filters = @{
        Explorer = "^file:///.+\.exe$"
        PcaSvc   = "^\\\?\?\\.+\.exe$"
    }
    $regex = $filters[$Prefix]
    if (-not $regex -or -not [System.Text.RegularExpressions.Regex]::IsMatch($Line, $regex)) { return }

    switch ($Prefix) {
        "Explorer" { $path = $Line.Replace("file:///", "").Replace("%20", " ") }
        "PcaSvc"   { $path = $Line.Replace("\??\", "") }
    }

    if ($path -notin $ProcessedPaths) {
        $ProcessedPaths += $path
        if (Test-Path $path -PathType Leaf) {
            $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction SilentlyContinue
            if ($sig.Status -ne 'Valid') {
                Write-Host "[$Prefix] Detected .exe with invalid signature: $path" -ForegroundColor Yellow
            } else {
                Write-Host "[$Prefix] Valid signature: $path" -ForegroundColor Green
            }
        } else {
            Write-Host "[$Prefix] Detected deleted .exe: $path" -ForegroundColor DarkYellow
        }
    }
}

$pid = Get-ServicePID "DPS"
if ($pid) {
    Write-Host "Scanning DPS Service (PID: $pid)..." -ForegroundColor Cyan
    $strings = Get-ProcessStrings $pid
    $processed = @()
    foreach ($line in $strings) {
        if (Test-ModifiedExtension $line) {
            Write-Host "[DPS] Detected modified extension: $line" -ForegroundColor Yellow
        }
        $det = Test-DpsDetection $line $dpsHash
        if ($det.Detected) {
            Write-Host "[DPS] Detected $($det.Name) ($($det.Detail))" -ForegroundColor Red
        }
        Test-ExeSignature $line "DPS" $processed
    }
} else {
    Write-Host "Service DPS disabled or not found." -ForegroundColor Gray
}

$pid = Get-ServicePID "DiagTrack"
if ($pid) {
    Write-Host "Scanning DiagTrack Service (PID: $pid)..." -ForegroundColor Cyan
    $strings = Get-ProcessStrings $pid
    $processed = @()
    foreach ($line in $strings) {
        if (Test-ModifiedExtension $line) {
            Write-Host "[DiagTrack] Detected modified extension: $line" -ForegroundColor Yellow
        }
        $det = Test-DpsDetection $line $dpsHash
        if ($det.Detected) {
            $pukpart = ($line -split "!")[2]
            Write-Host "[DiagTrack] Detected $($det.Name) ($pukpart)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Service DiagTrack disabled or not found." -ForegroundColor Gray
}

$explorerPid = (Get-Process -Name "explorer" -ErrorAction SilentlyContinue).Id
if ($explorerPid) {
    Write-Host "Scanning Explorer Process (PID: $explorerPid)..." -ForegroundColor Cyan
    $strings = Get-ProcessStrings $explorerPid
    $processed = @()
    foreach ($line in $strings) {
        Test-ExeSignature $line "Explorer" $processed
    }
} else {
    Write-Host "Explorer process not found." -ForegroundColor Gray
}

$pid = Get-ServicePID "PcaSvc"
if ($pid) {
    Write-Host "Scanning PcaSvc Service (PID: $pid)..." -ForegroundColor Cyan
    $strings = Get-ProcessStrings $pid
    $processed = @()
    foreach ($line in $strings) {
        Test-ExeSignature $line "PcaSvc" $processed
        $det = Test-DpsDetection $line $pcaHash
        if ($det.Detected) {
            Write-Host "[PcaSvc] Detected $($det.Name)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Service PcaSvc disabled or not found." -ForegroundColor Gray
}

if (Test-Path $toolPath) {
    Remove-Item -Path $toolPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Scan complete." -ForegroundColor Green
