param(
    [string]$OutputPath = "..\outputs\SAP_Systems_Complete.csv",
    [switch]$IncludeAllSizes,
    [string[]]$SizeCategories = @("Production", "Development", "Test")
)

# Function to get sorting priority for VM sizes based on configuration complexity
function Get-VMSortPriority {
    param([string]$VMSize, [object]$StorageConfig)
    
    # Calculate a priority score based on storage configuration complexity
    # Higher scores = more complex/larger systems
    $priority = 0
    
    # Base score from VM series and size
    switch -Regex ($VMSize) {
        "M1792" { $priority += 10000 }  # 32TB systems
        "M896"  { $priority += 8000 }   # 16TB systems  
        "M832"  { $priority += 6000 }   # 12TB systems
        "M416"  { $priority += 4000 }   # 8TB systems
        "M208"  { $priority += 3000 }   # 4TB systems
        "M176"  { $priority += 2500 }   # 3TB systems
        "M128"  { $priority += 2000 }   # 2TB systems
        "M(64|96)" { $priority += 1000 } # 1TB systems
        "M(32|48)" { $priority += 500 }  # Standard M-series
        "E96"   { $priority += 400 }     # Large E-series
        "E64"   { $priority += 300 }     # Medium E-series
        "E(32|48)" { $priority += 200 }  # Small E-series
        "E20"   { $priority += 100 }     # Entry E-series
        default { $priority += 50 }      # Other
    }
    
    # Add complexity score from storage configuration
    if ($StorageConfig -and $StorageConfig.Count -gt 0) {
        foreach ($disk in $StorageConfig) {
            if ($disk.name -eq "data") {
                $priority += [int]($disk.size_gb / 1000)  # Data disk size contribution
            }
        }
    }
    
    return $priority
}

# Load the HANA sizes data directly from GitHub
Write-Host "Downloading SAP sizing data from GitHub..." -ForegroundColor Yellow
try {
    # Download HANA sizing data
    $hanaResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/hana_sizes_v2.json" -UseBasicParsing
    $hanaData = $hanaResponse.Content | ConvertFrom-Json
    
    # Download APP sizing data for additional VM types
    $appResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/app_sizes.json" -UseBasicParsing
    $appData = $appResponse.Content | ConvertFrom-Json
    
    Write-Host "Successfully downloaded Microsoft SAP sizing data" -ForegroundColor Green
} catch {
    Write-Error "Failed to download SAP sizing data: $($_.Exception.Message)"
    return
}

# Define typical APP and ACS SKUs based on DB size categories
$sizeMapping = @{
    # Small systems (up to M128)
    "Small" = @{
        APP_SKU = "E8ds_v5"
        ACS_SKU = "E2ds_v5"
        Environment = "Development"
    }
    # Medium systems (M176-M208)
    "Medium" = @{
        APP_SKU = "E16ds_v5"
        ACS_SKU = "E4ds_v5"
        Environment = "Test"
    }
    # Large systems (M416)
    "Large" = @{
        APP_SKU = "E32ds_v5"
        ACS_SKU = "E8ds_v5"
        Environment = "Production"
    }
    # Ultra Large systems (M832+)
    "XLarge" = @{
        APP_SKU = "E64ds_v5"
        ACS_SKU = "E16ds_v5"
        Environment = "Production"
    }
}

function Get-SizeCategory {
    param([string]$VMSize)
    
    switch -Regex ($VMSize) {
        "M(32|48|64|96|128)" { return "Small" }
        "M(176|192|208)" { return "Medium" }
        "M416" { return "Large" }
        "M(832|896|1792)" { return "XLarge" }
        "E(20|32|48|64|96)" { return "Small" }
        default { return "Small" }
    }
}

function Generate-SID {
    param([string]$VMSize, [int]$Counter)
    
    $prefix = switch -Regex ($VMSize) {
        "M832|M896|M1792" { "QX" }  # Ultra large
        "M416" { "QP" }             # Production large
        "M(176|192|208)" { "QT" }   # Test/medium
        "M(128|96|64)" { "QD" }     # Development
        "E" { "QE" }                # E-series
        default { "QS" }            # Standard/other
    }
    
    return "$prefix$Counter"
}

# Extract and process ALL VM sizes from both HANA and APP sizing data
$systems = @()
$counter = 1

# Get all DB VM sizes from HANA data (excluding Demo/Test entries)
$dbSizes = $hanaData.db.PSObject.Properties | Where-Object { 
    $_.Name -notmatch "(Default|Demo|S4Demo)" 
} | Sort-Object Name

Write-Host "Processing VM configurations from Microsoft SAP sizing data..." -ForegroundColor Yellow

foreach ($dbConfig in $dbSizes) {
    $vmSize = $dbConfig.Value.compute.vm_size
    $sizeCategory = Get-SizeCategory -VMSize $vmSize
    $mapping = $sizeMapping[$sizeCategory]
    
    # Generate a meaningful moniker based on VM characteristics
    $memory = switch -Regex ($vmSize) {
        "M1792" { "32TB-System" }
        "M896" { "16TB-System" }
        "M832" { "12TB-System" }
        "M416" { "8TB-System" }
        "M208" { "4TB-System" }
        "M176" { "3TB-System" }
        "M128" { "2TB-System" }
        "M(64|96)" { "1TB-System" }
        "E96" { "Large-E-System" }
        "E64" { "Medium-E-System" }
        "E(32|48)" { "Small-E-System" }
        default { "Standard-System" }
    }
    
    $sortPriority = Get-VMSortPriority -VMSize $vmSize -StorageConfig $dbConfig.Value.storage
    
    $systems += [PSCustomObject]@{
        Moniker = $memory
        DB_SKU = $vmSize
        APP_SKU = $mapping.APP_SKU
        ACS_SKU = $mapping.ACS_SKU
        Environment = $mapping.Environment
        SortPriority = $sortPriority
        ConfigSource = $dbConfig.Name
    }
    
    $counter++
}

# Display summary
Write-Host "Generated $($systems.Count) SAP systems:" -ForegroundColor Green
$systems | Group-Object Environment | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) systems" -ForegroundColor Cyan
}

# Sort systems by complexity/size (smallest to largest) for easier navigation
$systemsSorted = $systems | Sort-Object SortPriority, DB_SKU

# Export to CSV file (excluding internal sorting and source columns)
$systemsSorted | Select-Object Moniker, DB_SKU, APP_SKU, ACS_SKU, Environment | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "Systems exported to: $OutputPath (sorted by system complexity)" -ForegroundColor Green
Write-Host "All systems are based on official Microsoft SAP sizing configurations" -ForegroundColor Cyan