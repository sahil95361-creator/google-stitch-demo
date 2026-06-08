$projectDir = "c:\Users\kumar\OneDrive\Desktop\Eli Google Stitch\amalfi-jets"
$assetsDir = Join-Path $projectDir "assets"
if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir | Out-Null; Write-Host "Created /assets" }

$htmlFiles = Get-ChildItem -Path $projectDir -Filter "*.html" -File
$allAssets = @{}

Write-Host "=== PHASE 1: Scanning HTML files ===" -ForegroundColor Cyan
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $patterns = @('https://lh3\.googleusercontent\.com/aida[^\s">\x27]+','https://lh3\.googleusercontent\.com/aida-public[^\s">\x27]+','https://amalfijets\.com/build/assets/[^\s">\x27]+')
    foreach ($pattern in $patterns) {
        $ms = [regex]::Matches($content, $pattern)
        foreach ($m in $ms) {
            $url = $m.Value -replace '[`"''\s>)]+$',''
            if (-not $allAssets.ContainsKey($url)) {
                $urlPath = ($url -split '\?')[0]
                $ext = [System.IO.Path]::GetExtension($urlPath)
                if (-not $ext -or $ext.Length -gt 6) { $ext = ".jpg" }
                $hash = [System.Math]::Abs($url.GetHashCode()).ToString()
                $allAssets[$url] = "asset_$hash$ext"
            }
        }
    }
    Write-Host "  Scanned: $($file.Name)"
}
Write-Host "Total unique assets: $($allAssets.Count)" -ForegroundColor Yellow

Write-Host "`n=== PHASE 2: Downloading assets ===" -ForegroundColor Cyan
$ok=0; $fail=0; $skip=0
foreach ($kv in $allAssets.GetEnumerator()) {
    $url=$kv.Key; $fname=$kv.Value; $dest=Join-Path $assetsDir $fname
    if (Test-Path $dest) { $skip++; continue }
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","Mozilla/5.0")
        $wc.Headers.Add("Referer","https://stitch.withgoogle.com/")
        $wc.DownloadFile($url,$dest)
        $sz = [math]::Round((Get-Item $dest).Length/1KB,1)
        Write-Host "  OK: $fname ($sz KB)" -ForegroundColor Green
        $ok++
    } catch {
        Write-Host "  FAIL: $fname" -ForegroundColor Red; $fail++
    }
}
Write-Host "Downloaded:$ok  Skipped:$skip  Failed:$fail" -ForegroundColor Cyan

Write-Host "`n=== PHASE 3: Patching HTML to use local paths ===" -ForegroundColor Cyan
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $orig = $content; $count=0
    foreach ($kv in $allAssets.GetEnumerator()) {
        if ($content.Contains($kv.Key)) {
            $content = $content.Replace($kv.Key, "assets/$($kv.Value)")
            $count++
        }
    }
    if ($content -ne $orig) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "  Patched: $($file.Name) ($count URLs)" -ForegroundColor Green
    } else {
        Write-Host "  Unchanged: $($file.Name)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Done! ===" -ForegroundColor Green
$af = Get-ChildItem -Path $assetsDir -File
$totalMB = [math]::Round(($af|Measure-Object -Property Length -Sum).Sum/1MB,2)
Write-Host "Assets folder: $($af.Count) files, $totalMB MB total"
