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

    Write-Host "Checking duplicate global function definitions..."
    $functionOwners = @{}
    $sourceLuaFiles = Get-ChildItem -Path "src" -Recurse -File -Filter *.lua
    foreach ($file in $sourceLuaFiles) {
        $content = Get-Content -Raw -LiteralPath $file.FullName
        # Lua treats "local" followed by line breaks and "function" as a local-function declaration.
        # Normalize that form before scanning so it is not mistaken for a global.
        $scanContent = [regex]::Replace($content, '(?m)^[ \t]*local[ \t]*(?:\r?\n[ \t]*)+function[ \t]+', 'local function ')
        $matches = [regex]::Matches($scanContent, '(?m)^[ \t]*(local[ \t]+)?function[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')
        foreach ($match in $matches) {
            if ($match.Groups[1].Success) { continue }
            $name = $match.Groups[2].Value
            $relative = $file.FullName.Substring($root.Length + 1)
            if (-not $functionOwners.ContainsKey($name)) { $functionOwners[$name] = @() }
            if ($functionOwners[$name] -notcontains $relative) { $functionOwners[$name] += $relative }
        }
    }
    $duplicateGlobals = @($functionOwners.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object Name)
    if ($duplicateGlobals.Count -gt 0) {
        $details = ($duplicateGlobals | ForEach-Object { "$($_.Key): $($_.Value -join ', ')" }) -join "`n"
        throw "Duplicate global function definitions found across source modules:`n$details"
    }

    Write-Host "Checking risky local state/context shadowing..."
    $shadowingIssues = @()
    foreach ($file in $sourceLuaFiles) {
        $lines = @(Get-Content -LiteralPath $file.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $declaration = [regex]::Match($lines[$i], '^(?<indent>[ \t]*)local[ \t]+(?<name>state|context)[ \t]*=[ \t]*\{')
            if (-not $declaration.Success) { continue }

            $indent = $declaration.Groups['indent'].Value
            $name = $declaration.Groups['name'].Value
            $keys = @{}
            $keyIndent = $null
            $tableEnd = -1
            for ($j = $i + 1; $j -lt [Math]::Min($lines.Count, $i + 80); $j++) {
                if ([regex]::IsMatch($lines[$j], '^' + [regex]::Escape($indent) + '\}[,;]?[ \t]*$')) {
                    $tableEnd = $j
                    break
                }
                $keyMatch = [regex]::Match($lines[$j], '^(?<ws>[ \t]+)(?<key>[A-Za-z_][A-Za-z0-9_]*)[ \t]*=')
                if ($keyMatch.Success) {
                    if ($null -eq $keyIndent) { $keyIndent = $keyMatch.Groups['ws'].Value }
                    if ($keyMatch.Groups['ws'].Value -eq $keyIndent) {
                        $keys[$keyMatch.Groups['key'].Value] = $true
                    }
                }
            }
            if ($tableEnd -lt 0 -or $keys.Count -eq 0) { continue }

            $loopPattern = 'for[ \t]+[^,\r\n]+,[ \t]*' + [regex]::Escape($name) + '[ \t]+in[ \t]+pairs\('
            $memberPattern = '\b' + [regex]::Escape($name) + '\.(?<member>[A-Za-z_][A-Za-z0-9_]*)'
            for ($j = $tableEnd + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^(?:local[ \t]+)?function[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(') { break }
                if (-not [regex]::IsMatch($lines[$j], $loopPattern)) { continue }

                for ($k = $j + 1; $k -lt [Math]::Min($lines.Count, $j + 40); $k++) {
                    $memberMatch = [regex]::Match($lines[$k], $memberPattern)
                    if ($memberMatch.Success -and $keys.ContainsKey($memberMatch.Groups['member'].Value)) {
                        $relative = $file.FullName.Substring($root.Length + 1)
                        $shadowingIssues += "${relative}:$($j + 1) loop variable '$name' shadows an outer table and later reads '$name.$($memberMatch.Groups['member'].Value)'."
                        break
                    }
                }
            }
        }
    }
    if ($shadowingIssues.Count -gt 0) {
        throw "Risky local state/context shadowing found:`n$($shadowingIssues -join "`n")"
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
