param(
    [ValidateSet("Standard", "Custom")]
    [string]$Mode = "Standard",
    
    [string]$CustomCSV = "",
    [string]$OutputJSON = ".\outputs\SAP-VM-Configurations-Master.json",
    [int]$BackupMultiplier = 3,
    [switch]$Help
)

if ($Help) {
    Write-Host @"

SAP VM Configuration Generator
=============================

USAGE:
    .\Generate-SAP-Configurations.ps1 [OPTIONS]

OPTIONS:
    -Mode <Standard|Custom>     Generation mode (default: Standard)
    -CustomCSV <path>          Path to custom CSV file (required for Custom mode)
    -OutputJSON <path>         Output JSON file path (default: .\outputs\SAP-VM-Configurations-Master.json)
    -BackupMultiplier <int>    Backup storage multiplier (default: 3)
    -Help                      Show this help message

EXAMPLES:
    # Generate standard SAP configurations (58 systems)
    .\Generate-SAP-Configurations.ps1

    # Generate from custom CSV file
    .\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "MyCustom.csv"

    # Standard with custom output file
    .\Generate-SAP-Configurations.ps1 -OutputJSON "Production-SAP-Config.json"
    
    # Custom with backup multiplier (default is 3x)
    .\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "MyCustom.csv" -BackupMultiplier 4

MODES:
    Standard - Uses Microsoft's complete SAP sizing data (58 systems)
    Custom   - Uses your custom CSV file with specific requirements

"@ -ForegroundColor Green
    return
}

Write-Host "SAP VM Configuration Generator" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

switch ($Mode) {
    "Standard" {
        Write-Host "`nMode: Standard SAP Sizing" -ForegroundColor Cyan
        Write-Host "Generating systems from Microsoft SAP data..." -ForegroundColor Yellow
        
        # Step 1: Generate standard systems
        $step1Path = ".\01-Generate-Systems\Generate-SAPSystemsFromHANA.ps1"
        if (-not (Test-Path $step1Path)) {
            Write-Error "Standard generation script not found: $step1Path"
            return
        }
        
        Push-Location ".\01-Generate-Systems"
        try {
            & ".\Generate-SAPSystemsFromHANA.ps1"
            if (-not (Test-Path "..\outputs\SAP_Systems_Complete.csv")) {
                Write-Error "Failed to generate standard systems CSV"
                return
            }
        }
        finally {
            Pop-Location
        }
        
        $inputCSV = "..\outputs\SAP_Systems_Complete.csv"
    }
    
    "Custom" {
        Write-Host "`nMode: Custom Customer Sizing" -ForegroundColor Cyan
        
        if (-not $CustomCSV) {
            Write-Error "Custom mode requires -CustomCSV parameter"
            Write-Host "Example: .\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV 'MyCustom.csv'" -ForegroundColor Yellow
            return
        }
        
        if (-not (Test-Path $CustomCSV)) {
            Write-Error "Custom CSV file not found: $CustomCSV"
            Write-Host "`nCreate a CSV file with columns: Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment" -ForegroundColor Yellow
            Write-Host "Example: Customer-Prod,Standard_M128s,Standard_E16ds_v5,Standard_E8ds_v5,Production" -ForegroundColor Gray
            return
        }
        
        # Generate intelligent output filename if not specified
        if (-not $PSBoundParameters.ContainsKey('OutputJSON')) {
            $csvBaseName = [System.IO.Path]::GetFileNameWithoutExtension($CustomCSV)
            $OutputJSON = ".\outputs\$csvBaseName-VM-Configurations.json"
        }
        
        # Convert to absolute path for the VM config script
        $inputCSV = Join-Path (Get-Location) $CustomCSV
        if (-not (Test-Path $inputCSV)) {
            $inputCSV = $CustomCSV  # Use as-is if join failed
        }
        Write-Host "Using custom sizing file: $CustomCSV" -ForegroundColor Yellow
    }
}

# Step 2: Generate VM configurations
Write-Host "`nGenerating VM configurations..." -ForegroundColor Yellow

Push-Location ".\02-Create-VMConfig"
try {
    # Convert to absolute path for the VM config script
    $parentPath = Split-Path (Get-Location) -Parent
    $outputJsonAbsolute = Join-Path $parentPath $OutputJSON
    & ".\Create-VMConfigMaster.ps1" -InputCSV $inputCSV -OutputJSON $outputJsonAbsolute -BackupMultiplier $BackupMultiplier
    
    if (Test-Path $outputJsonAbsolute) {
        Write-Host "`nSuccess! Configuration completed:" -ForegroundColor Green
        Write-Host "  Output file: $OutputJSON" -ForegroundColor Cyan
        Write-Host "  Mode: $Mode" -ForegroundColor Cyan
        if ($Mode -eq "Custom") {
            Write-Host "  Custom CSV: $CustomCSV" -ForegroundColor Cyan
        }
    }
}
finally {
    Pop-Location
}