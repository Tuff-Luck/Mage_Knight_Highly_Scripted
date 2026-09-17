param(
    [switch]$RequireLua52
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $root

try {
    Write-Host "Validating JSON..."
    $jsonFiles = Get-ChildItem -Path . -Recurse -File -Filter *.json | Where-Object {
        $_.FullName -notmatch "[\\/]\.tts[\\/]bundled[\\/]"
    }
    foreach ($file in $jsonFiles) {
        try {
            Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json | Out-Null
        }
        catch {
            throw "Invalid JSON: $($file.FullName)`n$($_.Exception.Message)"
        }
    }

    Write-Host "Validating TTS XML fragments..."
    $xmlFiles = Get-ChildItem -Path ".tts/objects" -File -Filter *.xml
    foreach ($file in $xmlFiles) {
        $content = Get-Content -Raw -LiteralPath $file.FullName
        if (-not [string]::IsNullOrWhiteSpace($content)) {
            try {
                [xml]("<TTSRoot>`n" + $content + "`n</TTSRoot>") | Out-Null
            }
            catch {
                throw "Invalid XML fragment: $($file.FullName)`n$($_.Exception.Message)"
            }
        }
    }

    Write-Host "Checking Global require() targets..."
    $entry = Get-Content -Raw -LiteralPath ".tts/objects/Global.lua"
    $requires = [regex]::Matches($entry, 'require\(["'']([^"'']+)["'']\)')
    if ($requires.Count -eq 0) {
        throw "No require() statements found in .tts/objects/Global.lua"
    }
    foreach ($match in $requires) {
        $module = $match.Groups[1].Value
        $relative = ($module -replace '\.', '/') + '.lua'
        $target = Join-Path "src" $relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw "Global require('$module') does not resolve to $target"
        }
    }

    Write-Host "Checking Lua 5.2 syntax..."
    $compiler = Get-Command "luac5.2" -ErrorAction SilentlyContinue
    if ($null -eq $compiler) {
        $compiler = Get-Command "luac52" -ErrorAction SilentlyContinue
    }
    if ($null -eq $compiler) {
        if ($RequireLua52) {
            throw "Lua 5.2 compiler not found (expected luac5.2 or luac52)."
        }
        Write-Warning "Lua 5.2 compiler not found locally; skipping Lua parse. GitHub CI requires and runs this check."
    }
    else {
        $luaFiles = @(
            Get-ChildItem -Path "src" -Recurse -File -Filter *.lua
            Get-ChildItem -Path ".tts/objects" -File -Filter *.lua
        )
        foreach ($file in $luaFiles) {
            & $compiler.Source -p $file.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "Lua 5.2 parse failed: $($file.FullName)"
            }
        }
    }

    Write-Host "Checking working-tree whitespace..."
    & git diff --check
    if ($LASTEXITCODE -ne 0) { throw "git diff --check failed" }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw "git diff --cached --check failed" }

    Write-Host "Project validation passed."
}
finally {
    Pop-Location
}
