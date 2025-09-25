# SAP Configuration Override Columns Specification

## Overview
Override columns allow you to customize specific configuration values in the generated VM configurations while preserving standard values for unspecified properties.

## Column Naming Convention
All override columns use the format: `<section>_<property>_override`

## Compute Section Overrides

| Column Name | Data Type | Example Values | Description |
|-------------|-----------|----------------|-------------|
| `compute_vm_size_override` | String | `Standard_M208ms_v2` | Override the VM size for database tier |
| `compute_accelerated_networking_override` | Boolean | `false` | Override accelerated networking (true/false) |

## Storage Section Overrides

### OS Disk
| Column Name | Data Type | Example Values | Description |
|-------------|-----------|----------------|-------------|
| `storage_os_disk_type_override` | String | `Premium_LRS` | Override OS disk type |
| `storage_os_size_gb_override` | Integer | `256` | Override OS disk size in GB |
| `storage_os_caching_override` | String | `ReadOnly` | Override OS disk caching |

### Data Disks
| Column Name | Data Type | Example Values | Description |
|-------------|-----------|----------------|-------------|
| `storage_data_count_override` | Integer | `8` | Override number of data disks |
| `storage_data_disk_type_override` | String | `Premium_LRS` | Override data disk type |
| `storage_data_size_gb_override` | Integer | `512` | Override individual data disk size |
| `storage_data_caching_override` | String | `ReadOnly` | Override data disk caching |
| `storage_data_iops_override` | Integer | `7500` | Override data disk IOPS (PremiumV2_LRS only) |
| `storage_data_throughput_override` | Integer | `250` | Override data disk throughput MB/s (PremiumV2_LRS only) |

### Log Disks
| Column Name | Data Type | Example Values | Description |
|-------------|-----------|----------------|-------------|
| `storage_log_count_override` | Integer | `3` | Override number of log disks |
| `storage_log_disk_type_override` | String | `Premium_LRS` | Override log disk type |
| `storage_log_size_gb_override` | Integer | `256` | Override individual log disk size |
| `storage_log_caching_override` | String | `None` | Override log disk caching |
| `storage_log_iops_override` | Integer | `5000` | Override log disk IOPS (PremiumV2_LRS only) |
| `storage_log_throughput_override` | Integer | `400` | Override log disk throughput MB/s (PremiumV2_LRS only) |

### Backup Disks
| Column Name | Data Type | Example Values | Description |
|-------------|-----------|----------------|-------------|
| `storage_backup_count_override` | Integer | `1` | Override number of backup disks |
| `storage_backup_disk_type_override` | String | `Standard_LRS` | Override backup disk type |
| `storage_backup_size_gb_override` | Integer | `2048` | Override individual backup disk size |
| `storage_backup_caching_override` | String | `None` | Override backup disk caching |

## Valid Values Reference

### Disk Types
- `Premium_LRS` - Premium SSD (P-series)
- `PremiumV2_LRS` - Premium SSD v2 (with configurable IOPS/throughput)
- `Standard_LRS` - Standard HDD

### Caching Options
- `None` - No caching
- `ReadOnly` - Read-only caching
- `ReadWrite` - Read-write caching (OS disk only)

### Boolean Values
- `true` or `false` (case-insensitive)

## Example Usage

```csv
Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment,storage_data_count_override,storage_data_size_gb_override,storage_backup_count_override,storage_backup_size_gb_override
TestSystem,Standard_M96ds_2_v3,Standard_D4ds_v5,Standard_D2ds_v5,Development,4,512,1,1024
ProdSystem,Standard_M416ds_8_v3,Standard_E8ds_v5,Standard_D4ds_v5,Production,,,2,
```

In this example:
- `TestSystem` uses 4 data disks of 512GB each (total: 2048GB), with 1 backup disk of 1024GB
- `ProdSystem` keeps default data disk configuration but uses 2 backup disks with default sizing
- Empty values preserve the standard configuration

## Processing Rules

1. **Empty/Missing Override Columns**: Standard configuration values are used
2. **Invalid Values**: Warning logged, standard value used as fallback
3. **Conflicting Settings**: Override values take precedence over standard calculations
4. **Validation**: All override values are validated against Azure supported options
5. **Disk Count and Size Independence**: 
   - Important: Disk count and disk size overrides are independent of each other.
   - When you change only the disk count (e.g., `storage_data_count_override`), the per-disk size remains unchanged.
   - Example: If the default configuration is 2 disks × 1000GB = 2000GB total, and you set `storage_data_count_override=4` without changing the size, you'll get 4 disks × 1000GB = 4000GB total.
   - To maintain the same total capacity while changing the count, you must also override the size proportionally:
     - Original: 2 disks × 1000GB = 2000GB total
     - Adjusted: 4 disks × 500GB = 2000GB total (requires both `storage_data_count_override=4` and `storage_data_size_gb_override=500`)

## Benefits

- **Selective Customization**: Only override what you need to change
- **Testing Flexibility**: Easily disable features for testing (e.g., accelerated networking)
- **Cost Optimization**: Use different disk types for different environments
- **Performance Tuning**: Fine-tune IOPS and throughput for specific workloads
- **Compliance**: Adjust configurations to meet specific organizational requirements