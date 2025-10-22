$ErrorActionPreference = "SilentlyContinue"

function Get-Signature {
    param ([string]$FilePath)

    if (-not (Test-Path -PathType Leaf -Path $FilePath)) { return "File Was Not Found" }

    $Status = (Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue).Status
    switch ($Status) {
        "Valid" { return "Valid Signature" }
        "NotSigned" { return "Invalid Signature (NotSigned)" }
        default { return "Invalid Signature" }
    }
}

try {
    $Users = @("bam", "bam\State") | ForEach-Object {
        Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$_\UserSettings\" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
    } | Sort-Object -Unique
}
catch {
    Write-Warning "Error Parsing BAM Key"
    exit 1
}

$rpath = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")

$Bam = @()
foreach ($Sid in $Users) {
    foreach ($rp in $rpath) {
        $KeyPath = "$rp\UserSettings\$Sid"
        $Props = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
        
        if ($Props) {
            $BamItems = $Props.PSObject.Properties.Name
            
            foreach ($Item in $BamItems) {
                $KeyValue = $Props.$Item
                
                if ($KeyValue -and $KeyValue.Length -eq 24) {
                    $Hex = [System.BitConverter]::ToString($KeyValue[7..0]) -replace "-",""
                    $TimeUTC = Get-Date ([DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))) -Format "dd.MM.yy HH:mm"
                    
                    $SplitPath = Split-Path -Path $Item -Parent
                    $PathParts = $SplitPath -split '\\'
                    if ($PathParts.Count -ge 3 -and $PathParts[2] -match '^\d{1}$') {
                        $path = Join-Path -Path "C:" -ChildPath $Item.Remove(1,23)
                        $sig = Get-Signature -FilePath $path
                        $app = Split-Path -Leaf $Item.TrimStart()
                    } else {
                        $path = ""
                        $sig = "N/A"
                        $app = $Item
                    }
                    
                    $Bam += [PSCustomObject]@{
                        'Time' = $TimeUTC
                        'Application' = $app
                        'Signature' = $sig
                        'Path' = $path
                        'SortDate' = [DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))
                    }
                }
            }
        }
    }
}

$FilteredBam = $Bam | Where-Object { $_.Signature -in @("Invalid Signature (NotSigned)", "File Was Not Found") } | Sort-Object SortDate -Descending

if ($FilteredBam) {
    $FilteredBam | Select-Object 'Time', 'Application', 'Signature', 'Path' | Format-Table -AutoSize | Out-String -Width ([Console]::BufferWidth) | ForEach-Object {
        $lines = $_ -split "`r?`n"
        foreach ($line in $lines) {
            if ($line -match "File Was Not Found") {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($line -match "Invalid Signature") {
                Write-Host $line -ForegroundColor Red
            } else {
                Write-Host $line
            }
        }
    }
} else {
    Write-Host "No filtered entries found." -ForegroundColor Green
}
