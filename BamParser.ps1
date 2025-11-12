cls

Write-Host ""
Write-Host "BAM Parser made by denischifer" -ForegroundColor Cyan
Write-Host ""

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  Write-Warning "This script requires Administrator privileges. Please run as Administrator."
  exit
}

function Get-OldestConnectTime {
    $oldestLogon = Get-CimInstance -ClassName Win32_LogonSession | 
        Where-Object {$_.LogonType -eq 2 -or $_.LogonType -eq 10} | 
        Sort-Object -Property StartTime | 
        Select-Object -First 1
    if ($oldestLogon) {
        return $oldestLogon.StartTime
    } else {
        return $null
    }
}

function Get-DeviceMappings {
    $DynAssembly = New-Object System.Reflection.AssemblyName('SysUtils')
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('SysUtils', $False)
    $TypeBuilder = $ModuleBuilder.DefineType('Kernel32', 'Public, Class')
    $PInvokeMethod = $TypeBuilder.DefinePInvokeMethod('QueryDosDevice', 'kernel32.dll', ([Reflection.MethodAttributes]::Public -bor [Reflection.MethodAttributes]::Static), [Reflection.CallingConventions]::Standard, [UInt32], [Type[]]@([String], [Text.StringBuilder], [UInt32]), [Runtime.InteropServices.CallingConvention]::Winapi, [Runtime.InteropServices.CharSet]::Auto)
    $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
    $SetLastError = [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
    $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('kernel32.dll'), [Reflection.FieldInfo[]]@($SetLastError), @($true))
    $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
    $Kernel32 = $TypeBuilder.CreateType()
    $Max = 65536
    $StringBuilder = New-Object System.Text.StringBuilder($Max)
    $driveMappings = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
        $ReturnLength = $Kernel32::QueryDosDevice($_.DriveLetter, $StringBuilder, $Max)
        if ($ReturnLength) {
            @{
                DriveLetter = $_.DriveLetter
                DevicePath = $StringBuilder.ToString().ToLower()
            }
        }
    }
    return $driveMappings
}

function Convert-DevicePathToDriveLetter {
    param (
        [string]$DevicePath,
        $DeviceMappings
    )
    foreach ($mapping in $DeviceMappings) {
        if ($DevicePath -like ($mapping.DevicePath + "*")) {
            return $DevicePath -replace [regex]::Escape($mapping.DevicePath), $mapping.DriveLetter
        }
    }
    return $DevicePath
}

function Get-FileSignature {
    param (
        [string]$FilePath
    )
    
    $result = @{
        Status = ""
        Details = ""
    }
    
    if (Test-Path $FilePath) {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        if ($signature.Status -eq 'Valid') {
            $subject = $signature.SignerCertificate.Subject
            $issuer = $signature.SignerCertificate.Issuer
            
            if ($subject -like "*Manthe Industries, LLC*") {
                $result.Status = "Not signed (vapeclient)"
                $result.Details = "Vape Client Detection"
            }
            elseif ($subject -like "*Slinkware*") {
                $result.Status = "Not signed (slinky)"
                $result.Details = "Slinky Client Detection"
            } 
            else {
                $result.Status = "Signed"
                $subjectCN = if ($subject -match "CN=([^,]+)") { $matches[1] } else { "Unknown" }
                $issuerCN = if ($issuer -match "CN=([^,]+)") { $matches[1] } else { "Unknown" }
                $result.Details = "Subject: $subjectCN|Issuer: $issuerCN"
            }
        } else {
            $result.Status = "Not signed"
            $result.Details = "No valid signature"
        }
    } else {
        $result.Status = "Deleted"
        $result.Details = "File not found"
    }
    
    return $result
}

Write-Host "Processing BAM entries..." -ForegroundColor Yellow

$oldestConnectTime = Get-OldestConnectTime
$deviceMappings = Get-DeviceMappings
$ErrorActionPreference = 'SilentlyContinue'

if (!(Get-PSDrive -Name HKLM -PSProvider Registry)){
    Try{New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE}
    Catch{}
}

$bv = ("bam", "bam\State")
$Users = @()
foreach($ii in $bv){
    $Users += Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ii)\UserSettings\" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
}

if ($Users.Count -eq 0) {
    Write-Host "No BAM entries found. This system may not be compatible." -ForegroundColor Red
    exit
}

$rpath = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\","HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")

$UserTime = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).TimeZoneKeyName
$UserBias = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).ActiveTimeBias
$UserDay = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).DaylightBias

$Bam = @()
$counter = 0
Foreach ($Sid in $Users) {
    foreach($rp in $rpath){
        $BamItems = Get-Item -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
        
        Try{
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid)
            $User = $objSID.Translate( [System.Security.Principal.NTAccount]) 
            $User = $User.Value
        }
        Catch{$User=""}
        
        ForEach ($Item in $BamItems){
            $Key = Get-ItemProperty -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Item
    
            If($key.length -eq 24){
                $Hex=[System.BitConverter]::ToString($key[7..0]) -replace "-",""
                $Bias = -([convert]::ToInt32([Convert]::ToString($UserBias,2),2))
                $TimeUser = (Get-Date ([DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))).addminutes($Bias) -Format "yyyy-MM-dd HH:mm:ss") 
                
                if ([DateTime]::ParseExact($TimeUser, "yyyy-MM-dd HH:mm:ss", $null) -ge $oldestConnectTime) {
                    $f = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
                    {Split-path -leaf ($item).TrimStart()} else {$item}
                    
                    $path = Convert-DevicePathToDriveLetter -DevicePath $item -DeviceMappings $deviceMappings
                    $signatureInfo = Get-FileSignature -FilePath $path
                    
                    $counter++
                    Write-Host "[$counter] Found: $f" -ForegroundColor Green
                    
                    $Bam += [PSCustomObject]@{
                        'Last Execution User Time' = $TimeUser
                        Path = $path
                        'Digital Signature' = $signatureInfo.Status
                        'Signature Details' = $signatureInfo.Details
                        'File Name' = $f
                    }
                }
            }
        }
    }
}

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "Total entries found: $($Bam.Count)" -ForegroundColor Cyan
Write-Host "Generating HTML report..." -ForegroundColor Yellow

$ContenidoHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BAM Parser Results</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet" />
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        :root {
            --bg-primary: #0a0e1b;
            --bg-secondary: #131825;
            --bg-card: #1a1f2e;
            --text-primary: #ffffff;
            --text-secondary: #94a3b8;
            --accent: #3b82f6;
            --accent-hover: #2563eb;
            --border: #2a3142;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
        }
        
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, var(--bg-primary) 0%, #0f172a 100%);
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .header {
            background: rgba(26, 31, 46, 0.8);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid var(--border);
            padding: 1.5rem;
            position: fixed;
            width: 100%;
            top: 0;
            z-index: 100;
        }
        
        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .title {
            font-size: 1.8rem;
            font-weight: 700;
            background: linear-gradient(135deg, var(--accent), #60a5fa);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .stats {
            display: flex;
            gap: 2rem;
        }
        
        .stat {
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        
        .stat-value {
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--accent);
        }
        
        .stat-label {
            font-size: 0.875rem;
            color: var(--text-secondary);
        }
        
        .container {
            max-width: 1400px;
            width: 100%;
            margin: 7rem auto 2rem;
            padding: 0 1.5rem;
            flex: 1;
        }
        
        .search-box {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 1rem;
            margin-bottom: 2rem;
            display: flex;
            gap: 1rem;
        }
        
        .search-input {
            flex: 1;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 0.75rem 1rem;
            color: var(--text-primary);
            font-size: 0.95rem;
            transition: all 0.3s ease;
        }
        
        .search-input:focus {
            outline: none;
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }
        
        .filter-btn {
            padding: 0.75rem 1.5rem;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            color: var(--text-secondary);
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: 500;
            white-space: nowrap;
        }
        
        .filter-btn.active {
            background: var(--accent);
            color: white;
            border-color: var(--accent);
        }
        
        .filter-btn:hover:not(.active) {
            border-color: var(--accent);
            color: var(--accent);
        }
        
        .table-container {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow: auto;
            max-width: 100%;
        }
        
        .table-wrapper {
            overflow-x: auto;
            overflow-y: visible;
        }
        
        table {
            width: 100%;
            min-width: 900px;
            border-collapse: collapse;
        }
        
        th {
            background: var(--bg-secondary);
            padding: 1rem;
            text-align: left;
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            font-size: 0.75rem;
            letter-spacing: 0.05em;
            cursor: pointer;
            transition: all 0.3s ease;
            user-select: none;
            position: sticky;
            top: 0;
            z-index: 10;
            white-space: nowrap;
        }
        
        th:nth-child(1) { 
            min-width: 150px;
            width: 150px;
        }
        
        th:nth-child(2) { 
            min-width: 200px;
            width: 25%;
        }
        
        th:nth-child(3) { 
            min-width: 350px;
            width: 45%;
        }
        
        th:nth-child(4) { 
            min-width: 150px;
            width: 150px;
        }
        
        th:hover {
            background: rgba(59, 130, 246, 0.1);
            color: var(--accent);
        }
        
        th.sorted-asc::after,
        th.sorted-desc::after {
            margin-left: 0.5rem;
            opacity: 0.5;
        }
        
        th.sorted-asc::after {
            content: '↑';
        }
        
        th.sorted-desc::after {
            content: '↓';
        }
        
        td {
            padding: 1rem;
            border-top: 1px solid var(--border);
            font-size: 0.875rem;
            word-break: break-word;
        }
        
        td:nth-child(1) {
            white-space: nowrap;
        }
        
        td:nth-child(3) {
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
            color: var(--text-secondary);
        }
        
        .path-cell {
            max-width: 450px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            cursor: help;
        }
        
        .path-cell:hover {
            overflow: visible;
            white-space: normal;
            word-break: break-all;
            background: var(--bg-secondary);
            padding: 0.5rem;
            border-radius: 4px;
            position: relative;
            z-index: 5;
        }
        
        tbody tr {
            transition: all 0.2s ease;
        }
        
        tbody tr:hover {
            background: rgba(59, 130, 246, 0.05);
        }
        
        .signature-badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            white-space: nowrap;
            cursor: default;
            position: relative;
        }
        
        .signature-badge.has-tooltip {
            cursor: help;
        }
        
        .signature-signed {
            background: rgba(16, 185, 129, 0.1);
            color: var(--success);
        }
        
        .signature-unsigned {
            background: rgba(245, 158, 11, 0.1);
            color: var(--warning);
        }
        
        .signature-deleted {
            background: rgba(239, 68, 68, 0.1);
            color: var(--danger);
        }
        
        .tooltip {
            position: absolute;
            bottom: 100%;
            left: 50%;
            transform: translateX(-50%) translateY(-5px);
            background: rgba(15, 23, 42, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(59, 130, 246, 0.3);
            border-radius: 8px;
            padding: 0.75rem 1rem;
            white-space: nowrap;
            font-size: 0.75rem;
            font-weight: 400;
            text-transform: none;
            color: var(--text-primary);
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
            pointer-events: none;
            opacity: 0;
            visibility: hidden;
            transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
            z-index: 1000;
            min-width: 200px;
        }
        
        .tooltip::after {
            content: '';
            position: absolute;
            top: 100%;
            left: 50%;
            transform: translateX(-50%);
            border: 6px solid transparent;
            border-top-color: rgba(15, 23, 42, 0.95);
        }
        
        .signature-badge:hover .tooltip {
            opacity: 1;
            visibility: visible;
            transform: translateX(-50%) translateY(-10px);
        }
        
        .tooltip-content {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }
        
        .tooltip-line {
            display: flex;
            gap: 0.5rem;
            align-items: flex-start;
        }
        
        .tooltip-label {
            color: var(--text-secondary);
            font-weight: 600;
        }
        
        .tooltip-value {
            color: var(--text-primary);
            word-break: break-word;
            max-width: 300px;
        }
        
        .footer {
            background: var(--bg-card);
            border-top: 1px solid var(--border);
            padding: 2rem;
            text-align: center;
            color: var(--text-secondary);
            margin-top: auto;
        }
        
        .footer-text {
            font-size: 0.875rem;
        }
        
        .no-results {
            text-align: center;
            padding: 3rem;
            color: var(--text-secondary);
        }
        
        @keyframes tooltipFadeIn {
            0% {
                opacity: 0;
                transform: translateX(-50%) translateY(0px) scale(0.8);
            }
            100% {
                opacity: 1;
                transform: translateX(-50%) translateY(-10px) scale(1);
            }
        }
        
        .signature-badge:hover .tooltip {
            animation: tooltipFadeIn 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55) forwards;
        }
        
        @media (max-width: 768px) {
            .stats {
                display: none;
            }
            
            .search-box {
                flex-direction: column;
            }
            
            .filter-btn {
                width: 100%;
                text-align: center;
            }
            
            .tooltip {
                display: none;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1 class="title">BAM Parser</h1>
            <div class="stats">
                <div class="stat">
                    <div class="stat-value" id="totalCount">0</div>
                    <div class="stat-label">Total Entries</div>
                </div>
                <div class="stat">
                    <div class="stat-value" id="filteredCount">0</div>
                    <div class="stat-label">Filtered</div>
                </div>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="search-box">
            <input type="text" class="search-input" id="searchInput" placeholder="Search by name, path, or signature...">
            <button class="filter-btn" data-filter="all">All</button>
            <button class="filter-btn" data-filter="signed">Signed</button>
            <button class="filter-btn" data-filter="unsigned">Unsigned</button>
            <button class="filter-btn" data-filter="deleted">Deleted</button>
        </div>

        <div class="table-container">
            <div class="table-wrapper">
                <table id="dataTable">
                    <thead>
                        <tr>
                            <th data-column="time">Last Execution</th>
                            <th data-column="fileName">File Name</th>
                            <th data-column="path">Path</th>
                            <th data-column="signature">Digital Signature</th>
                        </tr>
                    </thead>
                    <tbody id="tableBody"></tbody>
                </table>
            </div>
            <div class="no-results" id="noResults" style="display: none;">
                No entries found matching your criteria
            </div>
        </div>
    </div>

    <div class="footer">
        <div class="footer-text">Developed by denischifer</div>
    </div>

    <script>
        const entries = [
'@

foreach ($entry in $Bam) {
    $escapedTime = $entry.'Last Execution User Time'.Replace("\", "\\").Replace('"', '\"')
    $escapedPath = $entry.Path.Replace("\", "\\").Replace('"', '\"')
    $escapedSignature = $entry.'Digital Signature'.Replace("\", "\\").Replace('"', '\"')
    $escapedDetails = $entry.'Signature Details'.Replace("\", "\\").Replace('"', '\"')
    $escapedFileName = $entry.'File Name'.Replace("\", "\\").Replace('"', '\"')
    $ContenidoHtml += @"
            {
                time: "$escapedTime",
                path: "$escapedPath",
                signature: "$escapedSignature",
                details: "$escapedDetails",
                fileName: "$escapedFileName"
            },
"@
}

$ContenidoHtml += @'
        ];

        let currentFilter = 'all';
        let currentSort = { column: 'time', direction: 'desc' };
        let filteredEntries = [...entries];

        function getSignatureBadge(signature, details) {
            const sig = signature.toLowerCase();
            let badgeClass = '';
            let hasTooltip = false;
            let tooltipContent = '';
            
            if (sig === 'signed') {
                badgeClass = 'signature-signed';
                hasTooltip = true;
                if (details && details !== '') {
                    const parts = details.split('|');
                    tooltipContent = `
                        <div class="tooltip">
                            <div class="tooltip-content">
                                ${parts.map(part => {
                                    const [label, value] = part.split(':');
                                    return `
                                        <div class="tooltip-line">
                                            <span class="tooltip-label">${label}:</span>
                                            <span class="tooltip-value">${value ? value.trim() : ''}</span>
                                        </div>
                                    `;
                                }).join('')}
                            </div>
                        </div>
                    `;
                }
            } else if (sig === 'deleted') {
                badgeClass = 'signature-deleted';
            } else {
                badgeClass = 'signature-unsigned';
                if (details && details !== 'No valid signature') {
                    hasTooltip = true;
                    tooltipContent = `
                        <div class="tooltip">
                            <div class="tooltip-content">
                                <div class="tooltip-line">
                                    <span class="tooltip-value">${details}</span>
                                </div>
                            </div>
                        </div>
                    `;
                }
            }
            
            return `<span class="signature-badge ${badgeClass} ${hasTooltip ? 'has-tooltip' : ''}">
                ${signature}
                ${tooltipContent}
            </span>`;
        }

        function renderTable() {
            const tbody = document.getElementById('tableBody');
            const noResults = document.getElementById('noResults');
            
            if (filteredEntries.length === 0) {
                tbody.innerHTML = '';
                noResults.style.display = 'block';
            } else {
                noResults.style.display = 'none';
                tbody.innerHTML = filteredEntries.map(entry => `
                    <tr>
                        <td>${entry.time}</td>
                        <td>${entry.fileName}</td>
                        <td><div class="path-cell" title="${entry.path}">${entry.path}</div></td>
                        <td>${getSignatureBadge(entry.signature, entry.details)}</td>
                    </tr>
                `).join('');
            }
            
            document.getElementById('totalCount').textContent = entries.length;
            document.getElementById('filteredCount').textContent = filteredEntries.length;
        }

        function applyFilters() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            
            filteredEntries = entries.filter(entry => {
                const matchesSearch = !searchTerm || 
                    entry.fileName.toLowerCase().includes(searchTerm) ||
                    entry.path.toLowerCase().includes(searchTerm) ||
                    entry.signature.toLowerCase().includes(searchTerm);
                
                let matchesFilter = true;
                if (currentFilter === 'signed') {
                    matchesFilter = entry.signature.toLowerCase() === 'signed';
                } else if (currentFilter === 'unsigned') {
                    matchesFilter = entry.signature.toLowerCase().includes('not signed');
                } else if (currentFilter === 'deleted') {
                    matchesFilter = entry.signature.toLowerCase() === 'deleted';
                }
                
                return matchesSearch && matchesFilter;
            });
            
            sortEntries();
        }

        function sortEntries() {
            filteredEntries.sort((a, b) => {
                const aVal = a[currentSort.column];
                const bVal = b[currentSort.column];
                const comparison = aVal.localeCompare(bVal);
                return currentSort.direction === 'asc' ? comparison : -comparison;
            });
            
            renderTable();
        }

        document.getElementById('searchInput').addEventListener('input', applyFilters);

        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentFilter = btn.dataset.filter;
                applyFilters();
            });
        });

        document.querySelectorAll('th[data-column]').forEach(th => {
            th.addEventListener('click', () => {
                const column = th.dataset.column;
                
                document.querySelectorAll('th').forEach(t => {
                    t.classList.remove('sorted-asc', 'sorted-desc');
                });
                
                if (currentSort.column === column) {
                    currentSort.direction = currentSort.direction === 'asc' ? 'desc' : 'asc';
                } else {
                    currentSort.column = column;
                    currentSort.direction = 'asc';
                }
                
                th.classList.add(currentSort.direction === 'asc' ? 'sorted-asc' : 'sorted-desc');
                sortEntries();
            });
        });

        document.querySelector('.filter-btn[data-filter="all"]').classList.add('active');
        renderTable();
    </script>
</body>
</html>
'@

$htmlFilePath = Join-Path $env:TEMP "BAMParserResults.html"
$ContenidoHtml | Out-File -FilePath $htmlFilePath -Encoding UTF8

Write-Host "Opening HTML report..." -ForegroundColor Green
Start-Process $htmlFilePath
