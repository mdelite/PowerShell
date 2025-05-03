<#
.SYNOPSIS
Reads a CSV file and creates a separate YAML file for each row of data.
The first row of the CSV is used as the headers for the YAML structure.

.DESCRIPTION
This script takes a CSV file as input, reads its contents, and for each data row,
creates a new YAML file. The filename of each YAML file will be based on a
value in the row (you can customize which column is used for the filename).
The YAML content within each file will represent the data from that row,
using the headers from the first row of the CSV as keys.

.PARAMETER InputCsvPath
The path to the input CSV file.

.PARAMETER OutputDirectory
The directory where the individual YAML files will be created.
If the directory does not exist, it will be created.

.PARAMETER FilenameColumn
The name or index (0-based) of the column to use for generating the YAML filenames.
Defaults to the first column (index 0).

.EXAMPLE
.\ConvertTo-YamlFiles.ps1 -InputCsvPath "C:\Data\input.csv" -OutputDirectory "C:\YamlOutput"

.EXAMPLE
.\ConvertTo-YamlFiles.ps1 -InputCsvPath ".\data.csv" -OutputDirectory ".\yaml_files" -FilenameColumn "ID"

.NOTES
Requires the 'powershell-yaml' PowerShell module to be installed.
You can install it using: Install-Module -Name powershell-yaml
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter()]
    [string]$FilenameColumn = "0"
)

# Check if the YamlDotNet module is installed
if (-not (Get-Module -Name powershell-yaml)) {
    Write-Error "The 'powershell-yaml' PowerShell module is required. Please install it using: Install-Module -Name powershell-yaml"
    exit 1
}

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $OutputDirectory -PathType Container)) {
    try {
        Write-Verbose "Creating output directory: '$OutputDirectory'"
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    } catch {
        Write-Error "Failed to create output directory: '$OutputDirectory' - $($_.Exception.Message)"
        exit 1
    }
}

try {
    # Import the CSV data
    $CsvData = Import-Csv -Path $InputCsvPath

    # Get the headers from the first row (property names)
    $Headers = $CsvData[0].psobject.Properties | Select-Object -ExpandProperty Name

    # Determine the filename column index
    if ($FilenameColumn -as [int] -ne $null) {
        $FilenameColumnIndex = [int]$FilenameColumn
        if ($FilenameColumnIndex -lt 0 -or $FilenameColumnIndex -ge $Headers.Count) {
            Write-Error "Invalid FilenameColumn index: '$FilenameColumn'. It must be between 0 and $($Headers.Count - 1)."
            exit 1
        }
        $FilenameHeader = $Headers[$FilenameColumnIndex]
    } else {
        if ($Headers -notcontains $FilenameColumn) {
            Write-Error "Invalid FilenameColumn name: '$FilenameColumn'. Header not found in the CSV."
            exit 1
        }
        $FilenameHeader = $FilenameColumn
    }

    # Loop through each row of the CSV data
    foreach ($Row in $CsvData) {
        # Create a hashtable to represent the YAML content for the current row
        $YamlObject = @{}
        foreach ($Header in $Headers) {
            $YamlObject[$Header] = $Row.$Header
        }

        # Determine the filename for the YAML file
        $FilenameValue = $Row.$FilenameHeader -replace '[^a-zA-Z0-9_-]', '_' # Sanitize filename
        $YamlFileName = Join-Path -Path $OutputDirectory -ChildPath "$FilenameValue.yaml"

        # Convert the hashtable to YAML and write it to the file
        try {
            Write-Verbose "Creating YAML file: '$YamlFileName'"
            $YamlObject | ConvertTo-Yaml | Out-File -Path $YamlFileName -Encoding UTF8
        } catch {
            Write-Error "Error writing YAML file '$YamlFileName': $($_.Exception.Message)"
        }
    }

    Write-Host "Successfully processed '$InputCsvPath' and created YAML files in '$OutputDirectory'."

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
