$dps = @("CortexClient:::2023/11/11:12:57:00", "PhasmaClient:::2024/01/10:14:28:11","NoRender:::2023/09/05:20:12:29","AvaloneClient:::2023/05/09:19:10:04","AvaloneGreen:::2023/10/04:16:07:05","AvaloneBlue:::2023/07/03:22:01:11","AnapaV4:::2022/06/07:07:45:55","TakkerProxy:::2022/07/08:23:42:38","UsbCleaner:::2021/11/29:17:36:29","Hider:::2024/01/11:21:51:35", "Blast3xStringRemover:::2022/07/06:20:23:42","R-WipeCleaner:::2024/08/14:18:46:25","ResourceHacker:::2023/11/19:10:07:11","RevoCleaner:::2023/06/06:06:27:09","WiseFolderHider:::2024/03/15:02:10:26","HideFolders:::2023/11/26:21:51:07","Nemezida:::2024/05/31:21:46:54","OceanBypass:::2024/09/29:19:06:37","Hider2:::2024/04/07:19:32:29","WhiteGhostInt:::!2024/11/16:18:35:38","DpsChanger:::!2023/08/28:19:45:41","StringCleaner:::!2024/05/12:10:17:07","StubbornCleaner:::!2023/08/08:13:23:36","Vanish:::!2100/01/16:16:45:26","MicoHitBoxes:::!2024/09/11:23:23:32","MerzlotaCleaner:::!2024/09/08:19:10:30","SizeChanger:::!2024/09/19:16:34:40","Unicorn:::!2076/05/18:04:53:15","FakeJT:::!2066/10/01:22:12:07", "CortexNew:::2025/08/29:03:57:16")
$pca = @("CortexClient:::0x16ed000","TroxillClient:::0x1b44000","PhasmaClient:::0x16a4000","VapeV4:::0xbcb000","VapeLite:::0x1709000","AmmitDLC:::0x3a23000","NobiumClient:::0x1c06000","NoRender:::0x82ed000","AvaloneClient:::0x19f2000","AvaloneGreen:::0x140b000","AvaloneBlue:::0x13f9000","BlessedClient:::0x2335000","AnapaV4:::0xe96000","DripLite:::0x192a000","TakkerProxy:::0x268f000","UsbCleaner:::0x2d3000","Hider:::0x16000","Blast3xStringRemover:::0x5c000","R-WipeCleaner:::0x112000","ResourceHacker:::0x61b000","RevoCleaner:::0xe79000","WiseFolderHider:::0xadf000","HideFolders:::0xe0c000","Nemezida:::0x2199000","OceanBypass:::0xe000","Hider2:::0x88000","WhiteGhostInt:::0x349f000","DpsChanger:::0x54000","StringCleaner:::0x76000","StubbornCleaner:::0x1bf2000","Vanish:::0x15e000","MicoHitBoxes:::0x18be000","MerzlotaCleaner:::0x50000","SizeChanger:::0x2b000","Unicorn:::0xa20000")

$xxstringsPath = "$PSScriptRoot\xxstrings64.exe"
if (-not (Test-Path $xxstringsPath)) { Invoke-WebRequest -Uri "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe" -OutFile $xxstringsPath -UseBasicParsing }

function Check-ServiceStrings {
    param ([string]$ServiceName, [array]$StringsList, [string]$Prefix)
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) { Write-Host "$Prefix Service $ServiceName not found or disabled" -ForegroundColor Gray; return }
    if ($service.Status -ne 'Running') { Write-Host "$Prefix Service $ServiceName is not running" -ForegroundColor Gray; return }
    $svcProcess = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    if (-not $svcProcess) { Write-Host "$Prefix Service $ServiceName info not available" -ForegroundColor Gray; return }
    $pid = $svcProcess.ProcessId
    Write-Host "$Prefix Service $ServiceName PID: $pid" -ForegroundColor Cyan
    $output = (& $xxstringsPath -p $pid | Out-String) -split "`n"
    foreach ($line in $output) {
        $l = $line.Trim()
        foreach ($entry in $StringsList) {
            $parts = $entry -split ":::"
            if ($l.Contains($parts[1])) {
                $token = ($l -split "!" | Select-Object -Last 1)
                Write-Host "$Prefix Detected $($parts[0]) $token" -ForegroundColor Red
            }
        }
    }
}

function Check-ExplorerOrPCA {
    param ([string]$ProcessName, [string]$Prefix, [string]$Pattern, [array]$StringsList=@())
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (-not $proc) { Write-Host "$Prefix process $ProcessName not found" -ForegroundColor Gray; return }
    $pid = $proc.Id
    Write-Host "$Prefix process $ProcessName PID: $pid" -ForegroundColor Cyan
    $output = (& $xxstringsPath -p $pid | Out-String) -split "`n"
    $seen = @{}
    foreach ($line in $output) {
        $l = $line.Trim()
        if ($l -match $Pattern) {
            $path = $l -replace '^(file:///|\\\?\?)', '' -replace '%20',' '
            if (-not $seen.ContainsKey($path)) {
                if (Test-Path $path) {
                    $sig = (Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue).Status
                    if ($sig -ne 'Valid') { Write-Host "$Prefix Invalid signature: $path" -ForegroundColor Yellow } else { Write-Host "$Prefix Valid signature: $path" -ForegroundColor Green }
                } else { Write-Host "$Prefix Deleted/NotFound: $path" -ForegroundColor DarkYellow }
                $seen[$path] = $true
            }
            foreach ($entry in $StringsList) {
                $parts = $entry -split ":::"
                if ($l.Contains($parts[1])) { Write-Host "$Prefix Detected $($parts[0])" -ForegroundColor Red }
            }
        }
    }
}

function CustomCheck {
    $donkeyFound = $false
    $ezInjectFound = $false
    $childKeyPattern = "childKey"
    $javaProcs = Get-Process -Name javaw -ErrorAction SilentlyContinue
    foreach ($proc in $javaProcs) {
        $pid = $proc.Id
        Write-Host "Analyzing javaw PID: $pid" -ForegroundColor Cyan
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -and $cmd.Contains("OgUwQPNl")) { $donkeyFound = $true }
            if ($cmd -and $cmd.ToLower().Contains($childKeyPattern.ToLower())) { $ezInjectFound = $true }

            $output = (& $xxstringsPath -p $pid | Out-String) -split "`n"
            foreach ($line in $output) {
                $l = $line.Trim()
                if (-not $donkeyFound -and $l.Contains("OgUwQPNl")) { $donkeyFound = $true }
                if (-not $ezInjectFound -and $l.ToLower().Contains($childKeyPattern.ToLower())) { $ezInjectFound = $true }
            }
        } catch { }
    }
    Write-Host "Donkey: $(if($donkeyFound){"Yes"}else{"No"})" -ForegroundColor Cyan
    Write-Host "EzInject: $(if($ezInjectFound){"Yes"}else{"No"})" -ForegroundColor Cyan
}

Check-ServiceStrings -ServiceName "DPS" -StringsList $dps -Prefix "DPS"
Check-ServiceStrings -ServiceName "DiagTrack" -StringsList $dps -Prefix "DiagTrack"
Check-ExplorerOrPCA -ProcessName "explorer" -Prefix "Explorer" -Pattern "^file:///.+exe*$"
Check-ExplorerOrPCA -ProcessName "PcaSvc" -Prefix "PCA" -Pattern "^\\\?\?\\.+\.exe*$" -StringsList $pca
CustomCheck
Remove-Item -Path $xxstringsPath -Force -ErrorAction SilentlyContinue
