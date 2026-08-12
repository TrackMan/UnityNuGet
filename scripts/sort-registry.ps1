#!/usr/bin/env pwsh

param(
    [string] $Path = (Join-Path $PSScriptRoot "../registry.json")
)

$ErrorActionPreference = "Stop"

$resolvedPath = (Resolve-Path $Path).Path
$json = [IO.File]::ReadAllText($resolvedPath)
$openBrace = $json.IndexOf('{')
$closeBrace = $json.LastIndexOf('}')

if ($openBrace -lt 0 -or $closeBrace -le $openBrace) {
    throw "Registry must be a top-level JSON object."
}

$entries = [Collections.Generic.List[object]]::new()
$entryStart = $openBrace + 1
$depth = 1
$inString = $false
$escaped = $false

for ($index = $entryStart; $index -lt $closeBrace; $index++) {
    $character = $json[$index]

    if ($inString) {
        if ($escaped) {
            $escaped = $false
        } elseif ($character -eq '\') {
            $escaped = $true
        } elseif ($character -eq '"') {
            $inString = $false
        }
        continue
    }

    if ($character -eq '"') {
        $inString = $true
    } elseif ($character -eq '{' -or $character -eq '[') {
        $depth++
    } elseif ($character -eq '}' -or $character -eq ']') {
        $depth--
    } elseif ($character -eq ',' -and $depth -eq 1) {
        $block = $json.Substring($entryStart, $index - $entryStart).Trim()
        if ($block) {
            $match = [regex]::Match($block, '^"((?:\\.|[^"\\])*)"\s*:')
            if (-not $match.Success) {
                throw "Unable to read a registry entry near character $entryStart."
            }

            $name = [Text.Json.JsonSerializer]::Deserialize[string]('"' + $match.Groups[1].Value + '"')
            $entries.Add([pscustomobject]@{ Name = $name; Block = $block })
        }
        $entryStart = $index + 1
    }
}

$lastBlock = $json.Substring($entryStart, $closeBrace - $entryStart).Trim().TrimEnd(',').TrimEnd()
if ($lastBlock) {
    $match = [regex]::Match($lastBlock, '^"((?:\\.|[^"\\])*)"\s*:')
    if (-not $match.Success) {
        throw "Unable to read the final registry entry."
    }

    $name = [Text.Json.JsonSerializer]::Deserialize[string]('"' + $match.Groups[1].Value + '"')
    $entries.Add([pscustomobject]@{ Name = $name; Block = $lastBlock })
}

$sortedEntries = $entries | Sort-Object -Property Name -CaseSensitive -Culture ([Globalization.CultureInfo]::CurrentCulture.Name)
$lines = for ($index = 0; $index -lt $sortedEntries.Count; $index++) {
    $suffix = if ($index -lt $sortedEntries.Count - 1) { ',' } else { '' }
    "  $($sortedEntries[$index].Block)$suffix"
}

$output = "{`n$($lines -join "`n")`n}`n"
[IO.File]::WriteAllText($resolvedPath, $output, [Text.UTF8Encoding]::new($false))
