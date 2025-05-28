param (
    [Parameter(ValueFromPipeline=$true)]
    [System.IO.FileInfo[]]$Files,

    [string]$YamlTag,
    [string]$NewItem
)

process {
    foreach ($File in $Files) {
        if (-Not ($File.Exists)) {
            Write-Host "File not found: $($File.FullName)"
            continue
        }

        $lines = Get-Content $File.FullName
        if ($lines.Count -lt 3 -or $lines[0] -ne "---") {
            Write-Host "Skipping $($File.FullName): No valid YAML front matter found"
            continue
        }

        $output = @()
        $inFrontMatter = $false
        $updated = $false
        $inTargetTag = $false
        $yamlList = @()
        $tagExists = $false

        foreach ($line in $lines) {
            if ($line -eq "---") {
                $inFrontMatter = -not $inFrontMatter
                if (-not $tagExists -and -not $inFrontMatter) {
                    $output += "${YamlTag}:"
                    $output += "  - $NewItem"
                    $updated = $true
                }
                $inTargetTag = $false
            }
            if ($inFrontMatter -and $line -match '^' + [regex]::Escape($YamlTag) + ':\s*(""|\s*)$' ) {
                $output += "${YamlTag}:"
                $inTargetTag = $true
                $tagExists = $true
                $updated = $true
                continue
            }

            if ($inTargetTag -and $line -match "^\s*-\s*(.+)") {
                $yamlList += $matches[1]
                continue
            }

            if ($inTargetTag -and ($line -eq "---" -or $line -match "^\S")) {
                if ($NewItem -notin $yamlList) {
                    $yamlList += $NewItem
                    $updated = $true
                }
                
                foreach ($item in $yamlList) {
                    $output += "  - $item"
                }

                $inTargetTag = $false
            }
            $output += $line
        }

        if ($updated) {
            $output | Set-Content $File.FullName
            Write-Host "Updated: $($File.FullName)"
        } else {
            Write-Host "No changes needed for: $($File.FullName)"
        }
    }
}
