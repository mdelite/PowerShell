<#
.SYNOPSIS
    Converts a CSV file into Markdown files with YAML front matter.
.DESCRIPTION
    Reads a CSV file, uses a specified column (by index) as the filename, and inserts row data into YAML front matter.
.PARAMETER CsvFile
    The path to the input CSV file.
.PARAMETER OutputDir
    The directory where Markdown files will be created.
.PARAMETER FileNameColumnIndex
    (Optional) The index of the column from the CSV that will be used for Markdown filenames. Defaults to 0 (first column).
.EXAMPLE
    .\Convert-CsvToMarkdown.ps1 -CsvFile "data.csv" -OutputDir "output"
    .\Convert-CsvToMarkdown.ps1 -CsvFile "data.csv" -OutputDir "output" -FileNameColumnIndex 2 -Verbose
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$CsvFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [Parameter()]
    [int]$FileNameColumnIndex = 0  # Default to the first column
)

# Validate CSV file existence
if (!(Test-Path $CsvFile)) {
    Write-Error "CSV file not found: $CsvFile. Please provide a valid file path."
    return
}

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force
    Write-Verbose "Created output directory: $OutputDir"
}

# Import CSV data
$data = Import-Csv -Path $CsvFile

# Extract headers for indexing
$headers = $data[0].PSObject.Properties.Name

# Validate index range
if ($FileNameColumnIndex -ge $headers.Count -or $FileNameColumnIndex -lt 0) {
    Write-Error "Invalid column index: $FileNameColumnIndex. Must be between 0 and $($headers.Count - 1)."
    return
}

# Identify the column name corresponding to the index
$FileNameColumn = $headers[$FileNameColumnIndex]

# Iterate through each row in the CSV
foreach ($row in $data) {
    # Generate a sanitized filename from indexed column
    $fileName = $row.$FileNameColumn -replace '[^a-zA-Z0-9\.\-_\(\)\s]', '_'
    $filePath = "$OutputDir\$fileName.md"

    # Create YAML front matter, excluding the filename column
    $yamlFrontMatter = "---`n"
    foreach ($header in $headers) {
    if ($header -ne $FileNameColumn) {  # Exclude filename column
        $value = $row.$header
        if ($value -ne "") {
            # Only add quotes if the value doesn't already have them
            if ($value -match '^[<"].*[>"]$') {
                $yamlFrontMatter += "${header}: $value`n"
            } else {
                $yamlFrontMatter += "${header}: `"$value`"`n"
            }
        } else {
            $yamlFrontMatter += "${header}: $value`n"
        }
    }
}
    $yamlFrontMatter += "---`n`n"

    # Write to Markdown file
    $yamlFrontMatter | Out-File -FilePath $filePath -Encoding utf8

    Write-Verbose "Created: $filePath"
}

Write-Host "Markdown files generated successfully!"
