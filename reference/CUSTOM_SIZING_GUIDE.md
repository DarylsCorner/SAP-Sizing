# Custom SAP Sizing Guide

## Overview
The `Create-VMConfigMaster.ps1` script supports both standard SAP sizing from Microsoft's official data and custom customer-specific sizing requirements.

## Custom CSV Format

### Basic Format
Your custom CSV file must have these exact columns. Environment is optional for future use:
```csv
Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment
```

### Advanced Format with Overrides
You can include override columns to customize specific configuration values:
```csv
Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment,storage_data_count_override,storage_data_size_gb_override,storage_backup_count_override,storage_backup_size_gb_override
```

## Configuration Overrides

The custom mode now supports **configuration overrides** that allow you to modify specific values while preserving standard configurations for everything else.

### Override Column Format
All override columns follow the pattern: `<section>_<property>_override`

### Common Override Examples:

| Override Column | Purpose | Example Values | Limits |
|-----------------|---------|----------------|--------|
| `storage_data_count_override` | Number of data disks | `2`, `4`, `6`, `8` | Max: 8 disks |
| `storage_data_size_gb_override` | Individual data disk size | `1024`, `2048`, `4096` | Min: 32GB |
| `storage_log_count_override` | Number of log disks | `2` | Max: 2 disks |
| `storage_backup_count_override` | Number of backup disks | `1`, `2`, `4` | Recommended: 4 |
| `storage_backup_size_gb_override` | Individual backup disk size | `1024`, `2048`, `4096` | Based on data size |

### Override Benefits:
- ✅ **Selective Customization**: Only override what you need to change
- ✅ **Storage Flexibility**: Adjust data and backup disk configurations
- ✅ **Cost Optimization**: Right-size storage for specific environments
- ✅ **Performance Tuning**: Scale disk count and size for workload requirements
- ✅ **Backup Strategy**: Customize backup storage based on retention needs

### Override Rules:
- **Empty Values**: Standard configuration is used (no override)
- **Invalid Values**: Warning logged, standard value used as fallback
- **Validation**: All values validated against Azure supported options

### Disk Count Strategy:
The framework uses an optimized tiered disk count strategy for Premium SSD v2:
- **< 2TB data**: 2 data disks, 2 log disks
- **2TB - 8TB data**: 4 data disks, 2 log disks  
- **≥ 8TB data**: 8 data disks, 2 log disks (maximum)

This strategy leverages Premium SSD v2's free 3K IOPS + 125 MBps baseline per disk while maintaining optimal performance and manageability.

For complete override documentation, see: `OVERRIDE_COLUMNS_SPECIFICATION.md`

### Example Custom CSV (with Optional Overrides):
```csv
Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment,compute_accelerated_networking_override,storage_data_disk_type_override,storage_log_count_override,storage_backup_size_gb_override
M96ds_2_v3,Standard_M96ds_2_v3,Standard_D4ds_v5,Standard_D2ds_v5,Development,,,2,512
E64ds_v5,Standard_E64ds_v5,Standard_D4ds_v5,Standard_D2ds_v5,Development,false,Premium_LRS,,1024
M416ds_8_v3,Standard_M416ds_8_v3,Standard_E8ds_v5,Standard_D4ds_v5,Development,,PremiumV2_LRS,4,
M96ds_2_v3-Prod,Standard_M96ds_2_v3,Standard_E8ds_v5,Standard_D4ds_v5,Production,true,,3,2048
M832ixs_v2,Standard_M832ixs_v2,Standard_E16ds_v5,Standard_D4ds_v5,Development,,PremiumV2_LRS,6,4096
```

### Column Definitions:
- **Moniker**: Descriptive name for the system configuration
- **DB_SKU**: Database server VM size (e.g., Standard_M128s, Standard_E64ds_v5)
- **APP_SKU**: Application server VM size (e.g., Standard_E16ds_v5)
- **ACS_SKU**: SCS (Central Services) VM size (e.g., Standard_E8ds_v5)
- **Environment**: Development, Test, or Production

## Supported VM SKUs

### Database (DB_SKU) - Memory Optimized:
- **E-series**: E20ds_v4, E20ds_v5, E32ds_v4, E32ds_v5, E48ds_v4, E48ds_v5, E64ds_v4, E64ds_v5, E96ds_v5
- **M-series**: M32ts, M32ls, M48ds_1_v3, M48s_1_v3, M64ls, M64s, M64ms, M96ds_1_v3, M96s_1_v3
- **Large M-series**: M128s, M128ms, M176ds_3_v3, M176s_3_v3, M208s_v2, M208ms_v2
- **Ultra M-series**: M416s_v2, M416ms_v2, M832is_v16_v3, M896ixds_32_v31, M1792ixds_32_v31

### Application/SCS (APP_SKU, ACS_SKU) - General Purpose:
- **E-series**: E2ds_v5, E4ds_v5, E8ds_v5, E16ds_v5, E32ds_v5, E64ds_v5
- **D-series**: D4s_v3, D4ds_v5, D8s_v3, D16s_v3

## Benefits of Custom Sizing

- ✅ Tailored to specific customer requirements
- ✅ Custom system naming conventions
- ✅ Specific environment designations
- ✅ Optimized for actual workloads
- ✅ Reduced configuration count (focus on what's needed)

## Best Practices

1. **Validate SKUs**: Ensure all VM SKUs are supported in your target Azure region
2. **Environment Alignment**: Match Environment values to your deployment stages
3. **Naming Convention**: Use consistent, descriptive Moniker names
4. **Backup Multiplier**: Adjust `-BackupMultiplier` parameter if needed (default: 3)

## Example Commands

### Unified Script (Recommended)
```powershell
# Custom: Use your custom sizing file to generate VM configurations  
.\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "02-Create-VMConfig\Custom-Sizing.csv"
```

### Direct Script (Advanced Users)
```powershell
# Change to the script directory
cd <project-root-directory>\02-Create-VMConfig

# Generate custom configurations (outputs to fixed filename: ..\outputs\SAP-VM-Configurations.json)
.\Create-VMConfigMaster.ps1 -InputCSV ".\Custom-Sizing.csv"

# Custom with different backup sizing
.\Create-VMConfigMaster.ps1 -InputCSV ".\Custom-Sizing.csv" -BackupMultiplier 4

# Custom output location
.\Create-VMConfigMaster.ps1 -InputCSV ".\Custom-Sizing.csv" -OutputJSON "..\outputs\CustomerXYZ-Config.json"
```

### Output Files
- **Direct Script Default**: `..\outputs\SAP-VM-Configurations.json` (fixed name regardless of input file)
- **Direct Script Custom**: Use `-OutputJSON` parameter for custom name (e.g., `-OutputJSON "..\outputs\CustomerXYZ-Config.json"`)
- **Unified Script Output**: `.\outputs\Custom-Sizing-VM-Configurations.json` (named based on input CSV file)
