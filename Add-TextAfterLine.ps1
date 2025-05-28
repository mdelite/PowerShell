param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [string]$LinePattern, # The text to match (either exactly or as a prefix)
    [Parameter(Mandatory=$true)]
    [string]$textToAdd,
    [Parameter()] # This is a switch parameter
    [switch]$MatchEntireLine # If present, matches the entire line with $LinePattern
)

# Read the entire file content
try {
    $fileContent = Get-Content -Path $Path -ErrorAction Stop
}
catch {
    Write-Error "Error reading file '$Path': $($_.Exception.Message)"
    exit 1
}

$newContent = [System.Collections.Generic.List[string]]::new()
$linesCount = $fileContent.Count
$triggerLineProcessed = $false # Ensures the logic for adding text runs only once for the first match

Write-Host "Processing file: $Path"
if ($MatchEntireLine.IsPresent) {
    Write-Host "Matching mode: Line exactly matches '$LinePattern' (case-insensitive, ignoring leading/trailing spaces on file lines)."
} else {
    Write-Host "Matching mode: Line starts with '$LinePattern' (case-insensitive, ignoring leading/trailing spaces on file lines)."
}

for ($i = 0; $i -lt $linesCount; $i++) {
    $currentLineFromFile = $fileContent[$i]
    $newContent.Add($currentLineFromFile) # Add the original current line to our new content

    # Only attempt to match and process if we haven't already found and processed the trigger line
    if (-not $triggerLineProcessed) {
        $trimmedCurrentLineFromFile = $currentLineFromFile.Trim() # Trim leading/trailing spaces from the file's line

        $lineMatchesCriteria = $false # Flag to indicate if the current line meets the specified matching criteria

        if ($MatchEntireLine.IsPresent) {
            # Check if the trimmed line exactly equals $LinePattern (case-insensitive by default for -eq)
            if ($trimmedCurrentLineFromFile -eq $LinePattern) {
                $lineMatchesCriteria = $true
            }
        } else {
            # Check if the trimmed line starts with $LinePattern (case-insensitive)
            if ($trimmedCurrentLineFromFile.StartsWith($LinePattern, [System.StringComparison]::OrdinalIgnoreCase)) {
                $lineMatchesCriteria = $true
            }
        }

        if ($lineMatchesCriteria) {
            Write-Host "Found matching line at original line number $($i+1): '$currentLineFromFile'"
            $shouldAddText = $true # Assume we need to add the new text

            # Check if there is a line immediately after the trigger line
            if (($i + 1) -lt $linesCount) {
                $nextLineFromFile = $fileContent[$i + 1]
                # If the *next* line (raw, not trimmed) already contains the textToAdd,
                # then we don't need to add it again.
                if ($nextLineFromFile.Contains($textToAdd)) {
                    $shouldAddText = $false
                    Write-Host "Next line already contains '$textToAdd'. No addition needed here."
                }
            }
            # If the trigger line is the last line, $shouldAddText remains true.
            # If the next line exists but does not contain $textToAdd, $shouldAddText remains true.

            if ($shouldAddText) {
                $newContent.Add($textToAdd)
                Write-Host "Added '$textToAdd' after the matching line."
            }
            $triggerLineProcessed = $true # Mark that we've handled the trigger line
        }
    }
}

# Write the modified content back to the original file
try {
    Set-Content -Path $Path -Value $newContent -Force -ErrorAction Stop
    Write-Host "File '$Path' processed and saved successfully."
    if (-not $triggerLineProcessed) {
        Write-Host "No line matching the criteria was found in the file."
    }
}
catch {
    Write-Error "Error writing to file '$Path': $($_.Exception.Message)"
    exit 1
}
