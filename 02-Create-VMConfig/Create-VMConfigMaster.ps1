param(
    [string]$InputCSV = "..\01-Generate-Systems\SAP_Systems_Complete.csv",
    [string]$OutputJSON = "..\outputs\SAP-VM-Configurations.json",
    [int]$BackupMultiplier = 3
)

# Override Functions - Must be defined before use
function Get-OverrideColumns {
    param([array]$CsvData)
    
    if ($CsvData.Count -eq 0) { return @() }
    
    # Get all property names from the first row
    $allColumns = $CsvData[0].PSObject.Properties.Name
    
    # Filter for override columns (ending with '_override')
    $overrideColumns = $allColumns | Where-Object { $_ -match '_override$' }
    
    if ($overrideColumns.Count -gt 0) {
        Write-Host "  Found override columns: $($overrideColumns -join ', ')" -ForegroundColor Cyan
    }
    
    return $overrideColumns
}

function Set-ConfigurationOverrides {
    param(
        [hashtable]$BaseConfig,
        [object]$SystemRow,
        [array]$OverrideColumns,
        [string]$SystemName
    )
    
    if ($OverrideColumns.Count -eq 0) { return $BaseConfig }
    
    $appliedOverrides = @()
    
    foreach ($overrideCol in $OverrideColumns) {
        $overrideValue = $SystemRow.$overrideCol
        
        # Skip empty override values
        if ([string]::IsNullOrWhiteSpace($overrideValue)) { continue }
        
        # Parse the override column name to determine target property
        $overrideParts = $overrideCol -replace '_override$', '' -split '_', 2
        if ($overrideParts.Count -lt 2) { continue }
        
        $section = $overrideParts[0]  # compute, storage
        $property = $overrideParts[1]  # vm_size, accelerated_networking, etc.
        
        try {
            switch ($section.ToLower()) {
                "compute" {
                    $appliedOverrides += Set-ComputeOverride -Config $BaseConfig -Property $property -Value $overrideValue
                }
                "storage" {
                    $appliedOverrides += Set-StorageOverride -Config $BaseConfig -Property $property -Value $overrideValue
                }
                default {
                    Write-Warning "Unknown override section: $section"
                }
            }
        }
        catch {
            Write-Warning "Failed to apply override $overrideCol with value '$overrideValue': $($_.Exception.Message)"
        }
    }
    
    if ($appliedOverrides.Count -gt 0) {
        Write-Host "    → Applied overrides for $SystemName`: $($appliedOverrides -join ', ')" -ForegroundColor Green
    }
    
    return $BaseConfig
}

function Set-ComputeOverride {
    param(
        [hashtable]$Config,
        [string]$Property,
        [string]$Value
    )
    
    switch ($Property.ToLower()) {
        "vm_size" {
            $Config.compute.vm_size = $Value
            return "vm_size"
        }
        "accelerated_networking" {
            $boolValue = [System.Convert]::ToBoolean($Value)
            $Config.compute.accelerated_networking = $boolValue
            return "accelerated_networking"
        }
        default {
            Write-Warning "Unknown compute property: $Property"
            return ""
        }
    }
}

function Set-StorageOverride {
    param(
        [hashtable]$Config,
        [string]$Property,
        [string]$Value
    )
    
    # Parse storage property (e.g., "os_disk_type", "data_count", "log_size_gb")
    $storageParts = $Property -split '_', 2
    if ($storageParts.Count -lt 2) {
        Write-Warning "Invalid storage property format: $Property"
        return ""
    }
    
    $storageType = $storageParts[0]  # os, data, log, backup
    $storageProperty = $storageParts[1]  # disk_type, count, size_gb, etc.
    
    # Find the storage array element to modify
    $storageArray = $Config.storage
    $targetStorage = $storageArray | Where-Object { $_.name -eq $storageType }
    
    if (-not $targetStorage) {
        Write-Warning "Storage type not found: $storageType"
        return ""
    }
    
    # Apply the override based on property type
    switch ($storageProperty.ToLower()) {
        "disk_type" {
            $targetStorage.disk_type = $Value
            return "$storageType.disk_type"
        }
        "count" {
            $targetStorage.count = [int]$Value
            return "$storageType.count"
        }
        "size_gb" {
            $targetStorage.size_gb = [int]$Value
            return "$storageType.size_gb"
        }
        "caching" {
            $targetStorage.caching = $Value
            return "$storageType.caching"
        }
        "iops" {
            if ($targetStorage.PSObject.Properties.Name -contains "disk_iops_read_write") {
                $targetStorage.disk_iops_read_write = [int]$Value
                return "$storageType.iops"
            }
        }
        "throughput" {
            if ($targetStorage.PSObject.Properties.Name -contains "disk_mbps_read_write") {
                $targetStorage.disk_mbps_read_write = [int]$Value
                return "$storageType.throughput"
            }
        }
        default {
            Write-Warning "Unknown storage property: $storageProperty"
            return ""
        }
    }
    
    return ""
}

Write-Host "Creating consolidated SAP VM configuration reference..." -ForegroundColor Green
Write-Host "Input: $InputCSV" -ForegroundColor Cyan
Write-Host "Output: $OutputJSON" -ForegroundColor Cyan

# Validate input file exists
if (-not (Test-Path $InputCSV)) {
    Write-Error "Input CSV file not found: $InputCSV"
    Write-Host "`nAvailable options:" -ForegroundColor Yellow
    Write-Host "  Standard: ..\01-Generate-Systems\SAP_Systems_Complete.csv" -ForegroundColor Gray
    Write-Host "  Custom:   .\Custom-Sizing.csv" -ForegroundColor Gray
    return
}

# Read the systems data
try {
    $systemsData = Import-Csv $InputCSV
    Write-Host "Loaded $($systemsData.Count) systems from CSV" -ForegroundColor Yellow
    
    # Detect override columns
    $overrideColumns = Get-OverrideColumns -CsvData $systemsData
    if ($overrideColumns.Count -gt 0) {
        Write-Host "Override mode enabled with $($overrideColumns.Count) override columns" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Failed to read CSV file: $($_.Exception.Message)"
    return
}

# Download SAP sizing data (both HANA and App components)
Write-Host "Downloading SAP sizing data from GitHub..." -ForegroundColor Yellow
try {
    # Download HANA (DB) sizing data
    $hanaResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/hana_sizes_v2.json" -UseBasicParsing
    $hanaData = $hanaResponse.Content | ConvertFrom-Json
    
    # Download App/SCS/Web sizing data
    $appResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/app_sizes.json" -UseBasicParsing
    $appData = $appResponse.Content | ConvertFrom-Json
    
    Write-Host "Successfully downloaded SAP sizing data" -ForegroundColor Green
    $sapSizingData = @{
        db = $hanaData.db
        app = $appData.app
        scs = $appData.scs
        scsha = $appData.scsha
        web = $appData.web
    }
} catch {
    Write-Error "Failed to download SAP sizing data: $($_.Exception.Message)"
    return
}

# Built-in VM memory database (key VM sizes)
$vmMemoryDB = @{
    "Standard_M32ts" = 192
    "Standard_M32ls" = 256
    "Standard_M48s_1_v3" = 974
    "Standard_M48ds_1_v3" = 974
    "Standard_M64ls" = 512
    "Standard_M64s" = 1024
    "Standard_M64ms" = 1792
    "Standard_M96s_1_v3" = 974
    "Standard_M96ds_1_v3" = 974
    "Standard_M128s" = 2048
    "Standard_M128ms" = 3892
    "Standard_M176s_3_v3" = 2794
    "Standard_M176ds_3_v3" = 2794
    "Standard_M176s_3_v4" = 2794
    "Standard_M176ds_3_v4" = 2794
    "Standard_M176s_4_v3" = 3892
    "Standard_M176ds_4_v3" = 3892
    "Standard_M208s_v2" = 2850
    "Standard_M208ms_v2" = 5700
    "Standard_M416s_v2" = 5700
    "Standard_M416ms_v2" = 11400
    "Standard_M416s_6_v3" = 5696
    "Standard_M416ds_6_v3" = 5696
    "Standard_M416s_8_v3" = 7600
    "Standard_M416ds_8_v3" = 7600
    "Standard_M832is_v16_v3" = 15200
    "Standard_M832ids_v16_v3" = 15200
    "Standard_M896ixds_24_v3" = 23088
    "Standard_M896ixds_32_v3" = 30400
    "Standard_M1792ixds_32_v3" = 30400
    "Standard_E20ds_v4" = 160
    "Standard_E20ds_v5" = 160
    "Standard_E32ds_v4" = 256
    "Standard_E32ds_v5" = 256
    "Standard_E48ds_v4" = 384
    "Standard_E48ds_v5" = 384
    "Standard_E64ds_v4" = 504
    "Standard_E64ds_v5" = 512
    "Standard_E64s_v3" = 432
    "Standard_E96ds_v5" = 672
    # Additional exact memory values for common VMs
    "Standard_D2ds_v5" = 8
    "Standard_D4ds_v5" = 16
    "Standard_E8ds_v5" = 64
    "Standard_E16ds_v5" = 128
    "Standard_M96ds_2_v3" = 1946
}

function Get-VMMemory {
    param([string]$VMSize)
    
    if ($vmMemoryDB.ContainsKey($VMSize)) {
        return $vmMemoryDB[$VMSize]
    }
    
    # Estimation based on VM name patterns (CORES to MEMORY mapping)
    # M-series: More accurate memory-to-core ratios
    if ($VMSize -match "M(\d+)") {
        $cores = [int]$Matches[1]
        # M-series VMs have varying memory-to-core ratios
        # Conservative estimation: ~20GB per core for M-series
        return $cores * 20
    } elseif ($VMSize -match "E(\d+)") {
        $cores = [int]$Matches[1]
        # E-series VMs typically have ~8GB per core
        return $cores * 8
    }
    
    return 256  # Default fallback
}

function Get-StorageTier {
    param([int]$MemoryGB)
    
    $storageTiers = @(
        @{Name="0-1TB"; MaxMemory=1024; DataThroughput=500; DataIOPS=5000; LogThroughput=300; LogIOPS=3000}
        @{Name="1TB-2TB"; MaxMemory=2048; DataThroughput=750; DataIOPS=10000; LogThroughput=400; LogIOPS=4000}
        @{Name="2TB-4TB"; MaxMemory=4096; DataThroughput=1000; DataIOPS=15000; LogThroughput=500; LogIOPS=5000}
        @{Name="4TB-8TB"; MaxMemory=8192; DataThroughput=1250; DataIOPS=30000; LogThroughput=600; LogIOPS=8000}
        @{Name="8TB+"; MaxMemory=999999; DataThroughput=2000; DataIOPS=50000; LogThroughput=800; LogIOPS=12000}
    )
    
    $storageConfig = $storageTiers | Where-Object { $MemoryGB -le $_.MaxMemory } | Select-Object -First 1
    if (-not $storageConfig) {
        $storageConfig = $storageTiers[-1]  # Use largest tier
    }
    
    return $storageConfig
}

function Get-PremiumSSDv1Performance {
    param([int]$SizeGB)
    
    # Azure Premium SSD v1 performance tiers based on provisioned size
    # Source: https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types#premium-ssds
    
    if ($SizeGB -le 4) { return @{IOPS=120; Throughput=25; Tier="P1"} }
    elseif ($SizeGB -le 8) { return @{IOPS=120; Throughput=25; Tier="P2"} }
    elseif ($SizeGB -le 16) { return @{IOPS=120; Throughput=25; Tier="P3"} }
    elseif ($SizeGB -le 32) { return @{IOPS=120; Throughput=25; Tier="P4"} }
    elseif ($SizeGB -le 64) { return @{IOPS=240; Throughput=50; Tier="P6"} }
    elseif ($SizeGB -le 128) { return @{IOPS=500; Throughput=100; Tier="P10"} }
    elseif ($SizeGB -le 256) { return @{IOPS=1100; Throughput=125; Tier="P15"} }
    elseif ($SizeGB -le 512) { return @{IOPS=2300; Throughput=150; Tier="P20"} }
    elseif ($SizeGB -le 1024) { return @{IOPS=5000; Throughput=200; Tier="P30"} }
    elseif ($SizeGB -le 2048) { return @{IOPS=7500; Throughput=250; Tier="P40"} }
    elseif ($SizeGB -le 4096) { return @{IOPS=7500; Throughput=250; Tier="P50"} }
    elseif ($SizeGB -le 8192) { return @{IOPS=16000; Throughput=500; Tier="P60"} }
    elseif ($SizeGB -le 16384) { return @{IOPS=18000; Throughput=750; Tier="P70"} }
    else { return @{IOPS=20000; Throughput=900; Tier="P80"} }
}

function Get-MicrosoftPremiumSSDv2Requirements {
    param([int]$MemoryGB)
    
    # Microsoft's official Premium SSD v2 requirements by VM memory tier
    # Source: https://learn.microsoft.com/en-us/azure/sap/workloads/hana-vm-premium-ssd-v2
    
    $requirements = @{}
    
    if ($MemoryGB -lt 1024) {           # Below 1 TiB
        $requirements.DataThroughput = 425
        $requirements.DataIOPS = 3000
        $requirements.LogThroughput = 275
        $requirements.LogIOPS = 3000
    }
    elseif ($MemoryGB -lt 2048) {       # 1 TiB to below 2 TiB
        $requirements.DataThroughput = 600
        $requirements.DataIOPS = 5000
        $requirements.LogThroughput = 300
        $requirements.LogIOPS = 4000
    }
    elseif ($MemoryGB -lt 4096) {       # 2 TiB to below 4 TiB
        $requirements.DataThroughput = 800
        $requirements.DataIOPS = 12000
        $requirements.LogThroughput = 300
        $requirements.LogIOPS = 4000
    }
    elseif ($MemoryGB -lt 8192) {       # 4 TiB to below 8 TiB
        $requirements.DataThroughput = 1200
        $requirements.DataIOPS = 20000
        $requirements.LogThroughput = 400
        $requirements.LogIOPS = 5000
    }
    elseif ($MemoryGB -eq 11400) {      # M416ms_v2, M624(d)s_12_v3, M832(d)s_12_v3 (11,400 GiB)
        if ($MemoryGB -eq 11400) {
            # Check specific VM types - for now treat all as M832(d)s_12_v3 (highest spec)
            $requirements.DataThroughput = 1300
            $requirements.DataIOPS = 40000
            $requirements.LogThroughput = 600
            $requirements.LogIOPS = 6000
        }
    }
    elseif ($MemoryGB -eq 14902) {      # M832ixs (14,902 GiB)
        $requirements.DataThroughput = 2000
        $requirements.DataIOPS = 40000
        $requirements.LogThroughput = 600
        $requirements.LogIOPS = 9000
    }
    elseif ($MemoryGB -eq 15200) {      # M832i(d)s_16_v3 (15,200 GiB)
        $requirements.DataThroughput = 4000
        $requirements.DataIOPS = 60000
        $requirements.LogThroughput = 600
        $requirements.LogIOPS = 10000
    }
    elseif ($MemoryGB -eq 23088) {      # M832ixs_v2 (23,088 GiB)
        $requirements.DataThroughput = 2000
        $requirements.DataIOPS = 60000
        $requirements.LogThroughput = 600
        $requirements.LogIOPS = 10000
    }
    elseif ($MemoryGB -eq 30400) {      # M896ixds_32_v3, M1792ixds_32_v3 (30,400 GiB)
        $requirements.DataThroughput = 2000
        $requirements.DataIOPS = 80000
        $requirements.LogThroughput = 600
        $requirements.LogIOPS = 10000
    }
    else {
        # For memory sizes not explicitly listed, use tier-based approach
        if ($MemoryGB -ge 30400) {
            # Largest tier requirements
            $requirements.DataThroughput = 2000
            $requirements.DataIOPS = 80000
            $requirements.LogThroughput = 600
            $requirements.LogIOPS = 10000
        }
        elseif ($MemoryGB -ge 15200) {
            # High-end tier
            $requirements.DataThroughput = 2000
            $requirements.DataIOPS = 60000
            $requirements.LogThroughput = 600
            $requirements.LogIOPS = 10000
        }
        else {
            # Default to 4-8TB tier for unlisted medium VMs
            $requirements.DataThroughput = 1200
            $requirements.DataIOPS = 20000
            $requirements.LogThroughput = 400
            $requirements.LogIOPS = 5000
        }
    }
    
    return $requirements
}

function Get-OptimalDiskCount {
    param([int]$DataSizeGB)
    
    # Tiered disk strategy based on data size for cost optimization
    # Leverages free 3K IOPS + 125 MBps per Premium SSD v2 disk
    # Maximum caps: 8 data disks, 2 log disks for optimal performance
    if ($DataSizeGB -lt 2048) {        # < 2TB
        return @{ DataCount = 2; LogCount = 2 }
    } elseif ($DataSizeGB -lt 8192) {   # 2TB - 8TB  
        return @{ DataCount = 4; LogCount = 2 }
    } else {                           # >= 8TB (including >20TB SKUs)
        return @{ DataCount = 8; LogCount = 2 }
    }
}

function Get-StorageConfig {
    param(
        [string]$VMSize,
        [int]$MemoryGB,
        [int]$BackupMultiplier = 3
    )
    
    # Remove Standard_ prefix from VMSize for SAP data lookup
    $vmKey = $VMSize -replace "^Standard_", ""
    
    # Get Microsoft's official Premium SSD v2 requirements for this VM memory tier
    $msRequirements = Get-MicrosoftPremiumSSDv2Requirements -MemoryGB $MemoryGB
    
    # Initialize variables for both paths
    $totalDataSize = 0
    $logSize = 0
    $source = ""
    
    # Check for official SAP sizing data first (for capacity, not performance)
    if ($sapSizingData -and $sapSizingData.db -and $sapSizingData.db.PSObject.Properties.Name -contains $vmKey) {
        $sapSizing = $sapSizingData.db.$vmKey
        $dataStorage = $sapSizing.storage | Where-Object { $_.name -eq "data" }
        $logStorage = $sapSizing.storage | Where-Object { $_.name -eq "log" }
        
        if ($dataStorage -and $logStorage) {
            # Use SAP Official data for capacity sizing
            $totalDataSize = $dataStorage.count * $dataStorage.size_gb
            $logSize = $logStorage.size_gb * $logStorage.count
            $source = "SAP Official capacity + Microsoft PremiumSSDv2 performance"
        }
    }
    
    # If no official data, use memory-based capacity calculation
    if ($totalDataSize -eq 0) {
        # Microsoft official SAP HANA storage sizing:
        # /hana/data: 1.2 x VM memory, larger if necessary
        # /hana/log: 0.5 x VM memory, or 500 GiB if VM > 1 TiB memory  
        
        $totalDataSize = $MemoryGB * 1.2
        $logSize = if ($MemoryGB -gt 1024) { 500 } else { $MemoryGB * 0.5 }
        $source = "Memory-based capacity + Microsoft PremiumSSDv2 performance"
    }
    
    # Apply consistent optimal disk count strategy for both paths
    $diskStrategy = Get-OptimalDiskCount -DataSizeGB $totalDataSize
    
    # Calculate per-disk values using optimal disk counts
    $dataCount = $diskStrategy.DataCount
    $logCount = $diskStrategy.LogCount
    
    # Distribute capacity across optimal disk counts
    $dataSizePerDisk = [Math]::Round($totalDataSize / $dataCount)
    $logSizePerDisk = [Math]::Round($logSize / $logCount)
    
    # Distribute Microsoft's official performance requirements across disks
    # Use Ceiling to ensure we always meet or exceed requirements (avoid rounding down)
    $dataIOPSPerDisk = [Math]::Ceiling($msRequirements.DataIOPS / $dataCount)
    $dataThroughputPerDisk = [Math]::Ceiling($msRequirements.DataThroughput / $dataCount)
    $logIOPSPerDisk = [Math]::Ceiling($msRequirements.LogIOPS / $logCount)
    $logThroughputPerDisk = [Math]::Ceiling($msRequirements.LogThroughput / $logCount)
    
    # Ensure we don't go below Premium SSD v2 minimums (3K IOPS, 125 MBps per disk)
    $dataIOPSPerDisk = [Math]::Max($dataIOPSPerDisk, 3000)
    $dataThroughputPerDisk = [Math]::Max($dataThroughputPerDisk, 125)
    $logIOPSPerDisk = [Math]::Max($logIOPSPerDisk, 3000)
    $logThroughputPerDisk = [Math]::Max($logThroughputPerDisk, 125)
    
    # Shared storage sizing
    $sharedSize = if ($MemoryGB -gt 1024) { 1024 } else { $MemoryGB }
    
    return @{
        DataSizeGB = $dataSizePerDisk
        DataCount = $dataCount
        DataIOPS = $dataIOPSPerDisk
        DataThroughput = $dataThroughputPerDisk
        LogSizeGB = $logSizePerDisk
        LogCount = $logCount
        LogIOPS = $logIOPSPerDisk
        LogThroughput = $logThroughputPerDisk
        SharedSizeGB = $sharedSize
        BackupSizeGB = [Math]::Round(($totalDataSize * $BackupMultiplier) / 4)
        BackupCount = 4
        Source = $source
        MSRequirements = $msRequirements  # Include for validation
    }
}

# Master configuration object - complete SAP landscape structure
$masterConfig = [ordered]@{
    db = @{}
    app = @{}
    scs = @{}
    scsha = @{}
    web = @{}
}

# Process each unique DB_SKU (preserve all columns including overrides)
$uniqueSKUs = $systemsData | Sort-Object DB_SKU, Moniker | Group-Object DB_SKU | ForEach-Object { $_.Group | Select-Object -First 1 }

Write-Host "Processing $($uniqueSKUs.Count) unique VM configurations..." -ForegroundColor Yellow

foreach ($system in $uniqueSKUs) {
    Write-Host "  Processing: $($system.DB_SKU) ($($system.Moniker))" -ForegroundColor Gray
    
    # Get VM memory
    $vmMemory = Get-VMMemory -VMSize $system.DB_SKU
    
    # Calculate storage configuration
    $storageConfig = Get-StorageConfig -VMSize $system.DB_SKU -MemoryGB $vmMemory -BackupMultiplier $BackupMultiplier
    
    # Show data source for transparency
    $sourceColor = if ($storageConfig.Source -eq "SAP Official") { "Green" } else { "DarkYellow" }
    Write-Host "    → Using $($storageConfig.Source) sizing data" -ForegroundColor $sourceColor
        
        # Create the configuration for this VM SKU - matching hana_sizes_v2.json structure
        $vmConfig = [ordered]@{
            compute = [ordered]@{
                vm_size = $system.DB_SKU
                accelerated_networking = $true
            }
            storage = @(
                    [ordered]@{
                        name = "os"
                        fullname = ""
                        count = 1
                        disk_type = "Premium_LRS"
                        size_gb = 256
                        caching = "ReadWrite"
                        write_accelerator = $false
                    },
                    [ordered]@{
                        name = "data"
                        fullname = ""
                        count = $storageConfig.DataCount
                        disk_type = "PremiumV2_LRS"
                        size_gb = $storageConfig.DataSizeGB
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 0
                        disk_iops_read_write = $storageConfig.DataIOPS
                        disk_mbps_read_write = $storageConfig.DataThroughput
                    },
                    [ordered]@{
                        name = "log"
                        fullname = ""
                        count = $storageConfig.LogCount
                        disk_type = "PremiumV2_LRS"
                        size_gb = $storageConfig.LogSizeGB
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 10
                        disk_iops_read_write = $storageConfig.LogIOPS
                        disk_mbps_read_write = $storageConfig.LogThroughput
                    },
                    [ordered]@{
                        name = "shared"
                        fullname = ""
                        count = 1
                        disk_type = "Premium_LRS"
                        size_gb = $storageConfig.SharedSizeGB
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 20
                    },
                    [ordered]@{
                        name = "sap"
                        fullname = ""
                        count = 1
                        disk_type = "Premium_LRS"
                        size_gb = 128
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 30
                    },
                    [ordered]@{
                        name = "backup"
                        fullname = ""
                        count = $storageConfig.BackupCount
                        disk_type = "Premium_ZRS"
                        size_gb = $storageConfig.BackupSizeGB
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 40
                    }
                )
        }
        
        # Apply configuration overrides if any exist for this system
        if ($overrideColumns.Count -gt 0) {
            $vmConfig = Set-ConfigurationOverrides -BaseConfig $vmConfig -SystemRow $system -OverrideColumns $overrideColumns -SystemName $system.Moniker
        }
        
        # Add to master configuration using VM SKU without "Standard_" prefix as key (matching reference format)
        $vmKey = $system.DB_SKU -replace "^Standard_", ""
        $masterConfig.db[$vmKey] = $vmConfig
        
        # Create APP server configuration using APP_SKU
        $appKey = $system.APP_SKU -replace "^Standard_", ""
        $masterConfig.app[$appKey] = [ordered]@{
            compute = [ordered]@{
                vm_size = $system.APP_SKU
                accelerated_networking = $true
            }
            storage = @(
                [ordered]@{
                    name = "os"
                    fullname = ""
                    count = 1
                    disk_type = "Premium_LRS"
                    size_gb = 256
                    caching = "ReadWrite"
                    write_accelerator = $false
                },
                [ordered]@{
                    name = "sap"
                    fullname = ""
                    count = 1
                    disk_type = "Premium_LRS"
                    size_gb = 128
                    caching = "None"
                    write_accelerator = $false
                    lun_start = 0
                }
            )
        }
        
        # Create SCS server configuration using ACS_SKU
        $scsKey = $system.ACS_SKU -replace "^Standard_", ""
        $masterConfig.scs[$scsKey] = [ordered]@{
            compute = [ordered]@{
                vm_size = $system.ACS_SKU
                accelerated_networking = $true
            }
            storage = @(
                [ordered]@{
                    name = "os"
                    fullname = ""
                    count = 1
                    disk_type = "Premium_LRS"
                    size_gb = 256
                    caching = "ReadWrite"
                    write_accelerator = $false
                },
                [ordered]@{
                    name = "sap"
                    fullname = ""
                    count = 1
                    disk_type = "Premium_LRS"
                    size_gb = 128
                    caching = "None"
                    write_accelerator = $false
                    lun_start = 0
                }
            )
        }
        
        # Create SCSHA (SCS High Availability) configuration - same as SCS
        $masterConfig.scsha[$scsKey] = $masterConfig.scs[$scsKey]
        
        # Create Web Dispatcher configuration - only for Standard mode or if WEB_SKU column exists
        $isStandardMode = $InputCSV -like "*SAP_Systems_Complete.csv"
        $hasWebSKUColumn = $systemsData[0].PSObject.Properties.Name -contains "WEB_SKU"
        
        if ($isStandardMode -or $hasWebSKUColumn) {
            # Use WEB_SKU if available, otherwise fall back to APP_SKU (for Standard mode)
            $webKey = if ($hasWebSKUColumn -and $system.WEB_SKU) { $system.WEB_SKU } else { $system.APP_SKU }
            $webKey = $webKey -replace "^Standard_", ""
            
            $masterConfig.web[$webKey] = [ordered]@{
                compute = [ordered]@{
                    vm_size = $webKey
                    accelerated_networking = $true
                }
                storage = @(
                    [ordered]@{
                        name = "os"
                        fullname = ""
                        count = 1
                        disk_type = "Premium_LRS"
                        size_gb = 256
                        caching = "ReadWrite"
                        write_accelerator = $false
                    },
                    [ordered]@{
                        name = "sap"
                        fullname = ""
                        count = 1
                        disk_type = "Premium_LRS"
                        size_gb = 128
                        caching = "None"
                        write_accelerator = $false
                        lun_start = 0
                    }
                )
            }
        }
}

# Sort all component configurations by VM SKU name for consistent ordering
foreach ($component in @('db', 'app', 'scs', 'scsha', 'web')) {
    $sortedConfigs = [ordered]@{}
    $masterConfig[$component].GetEnumerator() | Sort-Object Key | ForEach-Object {
        $sortedConfigs[$_.Key] = $_.Value
    }
    $masterConfig[$component] = $sortedConfigs
}

# Ensure proper compute/storage ordering in output file
foreach ($componentName in @('db', 'app', 'scs', 'scsha', 'web')) {
    $component = $masterConfig[$componentName]
    if ($component) {
        # Create a list of keys to avoid modifying collection during enumeration
        $skuKeys = @($component.Keys)
        foreach ($skuName in $skuKeys) {
            $skuConfig = $component[$skuName]
            # If storage appears before compute, reorder the properties
            if ($skuConfig.Keys[0] -eq "storage" -and $skuConfig.ContainsKey("compute")) {
                # Create a new ordered hashtable with compute first, then storage
                $reorderedConfig = [ordered]@{
                    compute = $skuConfig.compute
                    storage = $skuConfig.storage
                }
                $masterConfig[$componentName][$skuName] = $reorderedConfig
            }
        }
    }
}

# Save the consolidated JSON file
try {
    $masterConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputJSON -Encoding UTF8
    Write-Host "`nSuccess! Created consolidated configuration file:" -ForegroundColor Green
    Write-Host "  File: $OutputJSON" -ForegroundColor Cyan
    Write-Host "  Total configurations: DB=$($masterConfig.db.Count), APP=$($masterConfig.app.Count), SCS=$($masterConfig.scs.Count), WEB=$($masterConfig.web.Count)" -ForegroundColor Cyan
    
} catch {
    Write-Error "Failed to save configuration file: $($_.Exception.Message)"
}