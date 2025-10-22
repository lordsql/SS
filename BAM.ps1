$ErrorActionPreference = "SilentlyContinue"

function Get-Signature {
    param ([string]$FilePath)

    if (-not (Test-Path $FilePath -PathType Leaf)) {
        return "File Was Not Found"
    }

    $sigStatus = (Get-AuthenticodeSignature -FilePath $FilePath).Status
    switch ($sigStatus) {
        "Valid" { return "Valid Signature" }
        "NotSigned" { return "Invalid Signature (NotSigned)" }
        default { return "Invalid Signature" }
    }
}

function Convert-FileTimeToUTC {
    param ([byte[]]$bytes)
    if ($bytes.Length -ne 24) { return $null }
    $hex = [System.BitConverter]::ToString($bytes[7..0]) -replace "-",""
    return [DateTime]::FromFileTimeUtc([Convert]::ToInt64($hex,16))
}

$rpath = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\",
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\"
)

try {
    $Users = foreach ($ii in @("bam","bam\State")) {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\$ii\UserSettings" | Select-Object -ExpandProperty PSChildName
    }
} catch {
    Write-Warning "Error Parsing BAM Key"
    Exit
}

$Bam = foreach ($Sid in $Users) {
    foreach ($rp in $rpath) {
        $keyPath = Join-Path $rp "UserSettings\$Sid"
        $BamItems = Get-ItemProperty -Path $keyPath | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

        foreach ($Item in $BamItems) {
            $keyValue = (Get-ItemProperty -Path $keyPath).$Item
            $utcTime = Convert-FileTimeToUTC -bytes $keyValue
            if (-not $utcTime) { continue }

            if (($Item -match '\d{1}') -and ($Item.Length -gt 23)) {
                $filePath = Join-Path "C:" ($Item.Substring(24))
                $sig = Get-Signature -FilePath $filePath
                $app = Split-Path $filePath -Leaf
            } else {
                $filePath = ""
                $sig = "N/A"
                $app = $Item
            }

            [PSCustomObject]@{
                Time        = $utcTime.ToString("dd.MM.yy HH:mm")
                Application = $app
                Signature   = $sig
                Path        = $filePath
                SortDate    = $utcTime
            }
        }
    }
}

$FilteredBam = $Bam | Where-Object { $_.Signature -in @("Invalid Signature (NotSigned)", "File Was Not Found") } |
                Sort-Object SortDate -Descending

if ($FilteredBam) {
    foreach ($entry in $FilteredBam) {
        $color = switch ($entry.Signature) {
            "File Was Not Found" { "Yellow" }
            "Invalid Signature (NotSigned)" { "Red" }
            default { "White" }
        }
        Write-Host ("{0,-16} {1,-30} {2,-25} {3}" -f $entry.Time, $entry.Application, $entry.Signature, $entry.Path) -ForegroundColor $color
    }
} else {
    Write-Host "No filtered entries found." -ForegroundColor Green
}
