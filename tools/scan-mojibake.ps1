# Scan UTF-8 mojibake / broken Vietnamese in source frontend & Java
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -ErrorAction SilentlyContinue
if (-not $root) { $root = (Get-Location).Path }
# workspace root = parent of tools
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

$extensions = @('*.jsp','*.jspf','*.js','*.css','*.html','*.java','*.xml','*.properties','*.md','*.txt','*.sql')
$excludeDirs = @('\build\','\node_modules\','\out\','\playwright-report\','\test-results\','\.git\')

# Classic UTF-8 misread as Latin-1/Windows-1252 patterns for Vietnamese
$patterns = @(
    'Ã¡','Ã ','Ã¢','Ã£','Ã©','Ã¨','Ãª','Ã­','Ã¬','Ã³','Ã²','Ã´','Ãµ','Ãº','Ã¹','Ã½',
    'Ä‘','Ä','Æ¡','Æ°','Æ°','Æ°','áº','á»','á»','Ã½','Ã½',
    'Ã„','Ã¡','Ã','â€','â€™','â€œ','â€','Â·','Â ','Â»','Â«',
    'Äƒ','Äƒ','Ãª','Ã´','Æ°','Æ¡'
)

# Also detect replacement char and double-encoded sequences
$regex = [regex]'Ã[\x80-\xBF]|Ä[\x80-\xBF]|áº[\x80-\xBF]|á»[\x80-\xBF]|Æ[\xA0-\xBF]|â€.|Â[\xA0-\xFF]|\uFFFD|Ã¡|Ã |Ã¢|Ã£|Ã©|Ã¨|Ãª|Ã­|Ã¬|Ã³|Ã²|Ã´|Ãµ|Ãº|Ã¹|Ã½|Ä‘|Ä|Æ¡|Æ°|áº|á»'

$results = New-Object System.Collections.Generic.List[object]

foreach ($ext in $extensions) {
    Get-ChildItem -Path $root -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | ForEach-Object {
        $full = $_.FullName
        $rel = $full.Substring($root.Path.Length).TrimStart('\','/')
        $skip = $false
        foreach ($ex in $excludeDirs) {
            if ($full -like "*$ex*") { $skip = $true; break }
        }
        if ($skip) { return }

        try {
            $bytes = [System.IO.File]::ReadAllBytes($full)
        } catch { return }

        # Skip binary-ish large files
        if ($bytes.Length -gt 5MB) { return }

        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $utf8 = New-Object System.Text.UTF8Encoding $false, $true
        $isValidUtf8 = $true
        try {
            [void]$utf8.GetString($bytes)
        } catch {
            $isValidUtf8 = $false
        }

        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $matches = $regex.Matches($text)
        $count = $matches.Count

        if ($count -gt 0 -or -not $isValidUtf8) {
            # sample first few match values
            $samples = @()
            $i = 0
            foreach ($m in $matches) {
                if ($i -ge 5) { break }
                $start = [Math]::Max(0, $m.Index - 20)
                $len = [Math]::Min(60, $text.Length - $start)
                $snippet = $text.Substring($start, $len) -replace "`r|`n", ' '
                $samples += $snippet
                $i++
            }
            $results.Add([PSCustomObject]@{
                Path = $rel
                Count = $count
                ValidUtf8 = $isValidUtf8
                HasBOM = $hasBom
                Samples = ($samples -join ' || ')
            }) | Out-Null
        }
    }
}

Write-Host "=== MOJIBAKE SCAN RESULTS ($($results.Count) files) ==="
$results | Sort-Object Count -Descending | Format-Table -AutoSize Path, Count, ValidUtf8, HasBOM
Write-Host ""
Write-Host "=== SAMPLES ==="
foreach ($r in ($results | Sort-Object Count -Descending | Select-Object -First 40)) {
    Write-Host ("--- {0} (count={1}) ---" -f $r.Path, $r.Count)
    Write-Host $r.Samples
    Write-Host ""
}

# Also export CSV
$out = Join-Path $PSScriptRoot 'mojibake-scan-report.csv'
$results | Sort-Object Count -Descending | Export-Csv -Path $out -NoTypeInformation -Encoding UTF8
Write-Host "Report written: $out"
