# SAP Azure VM Configuration Generator

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Azure](https://img.shields.io/badge/Platform-Azure-blue)
![SAP](https://img.shields.io/badge/SAP-HANA-orange)
![Maintenance](https://img.shields.io/badge/Maintained-yes-green)
![License](https://img.shields.io/badge/License-MIT-yellow)
![PRs](https://img.shields.io/badge/PRs-welcome-brightgreen)

## Overview

Advanced SAP Azure VM sizing framework that generates Microsoft-compliant configurations using official Azure SAP automation data. This tool provides intelligent sizing with dynamic fallback logic, Microsoft SAP HANA-compliant storage calculations, and comprehensive override capabilities for customized deployments.

## 🚀 Quick Start

### Standard SAP Sizing (Recommended)
```powershell
.\Generate-SAP-Configurations.ps1
```

**What it does:**
- Downloads unified Microsoft SAP data from both HANA and App sizing sources
- Generates 58 SAP systems with intelligent complexity-based sorting
- Prioritizes official Microsoft SAP configurations with memory-based fallback
- Creates Microsoft SAP HANA-compliant storage (1.2× memory data, tiered disk striping: 2/4/8 disks based on size)
- Produces performance-optimized configurations following Azure Premium SSD v2 guidelines

### Custom Customer Sizing  
```powershell
.\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "MyCustom.csv"
```

**What it does:**
- Uses your specific SAP system requirements from CSV
- Generates only the configurations you need
- Supports custom VM sizes and environments
- Creates tailored JSON configuration file

### Show Help
```powershell
.\Generate-SAP-Configurations.ps1 -Help
```

## ✨ What You Get

- **Complete VM Configurations**: Storage profiles with IOPS, throughput, caching settings
- **Microsoft SAP-Certified**: Official performance data from Microsoft SAP automation
- **Flexible Options**: Standard comprehensive sizing or custom focused configurations  
- **Professional Output**: Clean terminal interface with progress tracking
- **JSON Reference File**: Easy programmatic access to all configurations

### 📂 Output Files - All Generated in `outputs/` Folder

All generated files are centrally located in the `outputs/` folder for easy access:

**Standard Mode Output:**
- `SAP_Systems_Complete.csv` - Complete list of 58 SAP systems with environment classifications
- `SAP-VM-Configurations-Master.json` - VM configurations for all 58 systems (37 unique configs)

**Custom Mode Output:**
- `SAP_Systems_Complete.csv` - Only generated if using Standard mode first
- `[YourFilename]-VM-Configurations.json` - VM configurations based on your custom CSV

**File Details:**
- **CSV Files**: Human-readable system lists with memory, environment, and sizing details
- **JSON Files**: Complete VM configurations including compute, storage, IOPS, and caching settings
- **Override Support**: Custom mode files reflect any storage override configurations applied

## 📁 File Structure

```
SAP-Sizing/
├── Generate-SAP-Configurations.ps1    # 🎯 Main entry point
├── README.md                           # This file
├── CHANGELOG.md                        # Version history
├── outputs/                            # 📂 Generated files (all output here)
│   ├── (Standard mode)                # Output from standard mode
│   │   ├── SAP_Systems_Complete.csv   # Generated systems list (58 total)
│   │   └── SAP-VM-Configurations-Master.json # Master VM configurations
│   └── (Custom mode)                  # Output from custom mode
│       └── [CustomFilename]-VM-Configurations.json # Custom VM configurations
├── 01-Generate-Systems/                # SAP system generation
│   └── Generate-SAPSystemsFromHANA.ps1
├── 02-Create-VMConfig/                 # VM configuration creation
│   ├── Create-VMConfigMaster.ps1
│   └── Custom-Sizing.csv      # Custom sizing template
└── reference/                          # 📚 Documentation & guides
    ├── CUSTOM_SIZING_GUIDE.md         # Detailed custom sizing guide
    └── OVERRIDE_COLUMNS_SPECIFICATION.md # Override system documentation
```

## 📋 Configuration Standards

### Storage Configuration (Microsoft SAP HANA Compliant)
- **Data Storage**: 1.2× VM memory following Microsoft SAP HANA guidelines
- **Log Storage**: 0.5× VM memory (or 500GB minimum for VMs >1TB memory)
- **Shared Storage**: 1× VM memory (or 1TB minimum for VMs >1TB memory)
- **Disk Optimization**: Tiered disk striping (2/4/8 disks) for cost efficiency (leveraging free IOPS tier)
- **Performance Rationale**: Based on Azure Premium SSD v2 documentation for SAP HANA
- **IOPS/Throughput**: Dual-path calculation - official Microsoft SAP data preferred, memory-based profiles for fallback
- **Performance Validation**: Configurations exceed Microsoft requirements (e.g., M96ds_2_v3: 10,000 IOPS vs 5,000 required)
- **Backup Caching**: "None" following Microsoft's official SAP recommendations  
- **Backup Multiplier**: 3x data size (configurable with `-BackupMultiplier` parameter)
- **Memory Calculation**: Enhanced with 42+ exact memory values (eliminates estimation errors for common VMs)

### Environment-Based System Sizing

The framework follows a logical progression of system sizes across environments:

#### **Development Environment**
- **Database**: Small to medium systems (Standard-System, Small-E-System, Medium-E-System, Large-E-System, 1TB-System, 2TB-System)
- **Memory Range**: ~160GB to ~3.8TB
- **APP/ACS**: Small (E8ds_v5/E2ds_v5)

#### **Test Environment**
- **Database**: Mid-range systems (3TB-System, 4TB-System)
- **Memory Range**: ~2.8TB to ~5.7TB
- **APP/ACS**: Medium (E16ds_v5/E4ds_v5)

#### **Production Environment**
- **Database**: Large enterprise systems (8TB-System, 12TB-System, 16TB-System, 32TB-System)
- **Memory Range**: ~5.7TB to ~22.8TB
- **APP/ACS**: Large (E32ds_v5/E8ds_v5)

This progression ensures appropriate resource allocation for each environment tier while maintaining cost efficiency for non-production workloads.

### Custom CSV Format
```csv
Moniker,DB_SKU,APP_SKU,ACS_SKU,Environment
Customer-Prod,Standard_M128s,Standard_E16ds_v5,Standard_E8ds_v5,Production
Customer-Dev,Standard_E64ds_v5,Standard_E8ds_v5,Standard_E4ds_v5,Development
Customer-Test,Standard_E32ds_v5,Standard_E4ds_v5,Standard_E4ds_v5,Test
```

**Template available**: Use `.\02-Create-VMConfig\Custom-Sizing.csv` as a starting point if custom configurations are needed.

## 💡 Usage Examples

### Simple Commands (Three Main Scenarios)

```powershell
# Scenario 1: Standard Mode - Official Microsoft SAP sizing (58 systems)
.\Generate-SAP-Configurations.ps1

# Scenario 2: Custom Mode - Your specific VM requirements
.\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "Custom-Sizing.csv"

# Scenario 3: Advanced Custom - Custom VMs with storage overrides in the CSV
.\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "Custom-Sizing.csv" -BackupMultiplier 4
```

### Additional Options

```powershell
# Custom backup multiplier (default is 3x)
.\Generate-SAP-Configurations.ps1 -BackupMultiplier 4

# Custom output file name
.\Generate-SAP-Configurations.ps1 -Mode Custom -CustomCSV "CustomerABC.csv" -OutputJSON "CustomerABC-Config.json"

# Show help and all available parameters
.\Generate-SAP-Configurations.ps1 -Help
```

## 📚 Documentation & Reference


### Custom Sizing Guide
- **Detailed Instructions**: `.\reference\CUSTOM_SIZING_GUIDE.md`
- **Example File**: `.\02-Create-VMConfig\Custom-Sizing.csv`
- **Override Support**: Storage-focused customization (data/backup disk count and sizing)
- **Override Specification**: `.\reference\OVERRIDE_COLUMNS_SPECIFICATION.md`

### Architecture & Data Sources
- **Unified Data Approach**: Merges both HANA and App sizing datasets for comprehensive coverage
- **HANA Sizing**: https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/hana_sizes_v2.json
- **App Sizing**: https://raw.githubusercontent.com/Azure/sap-automation/refs/heads/main/deploy/configs/app_sizes.json
- **Enhanced Memory Database**: Built-in exact memory values for 42+ popular VMs (D-series, E-series, M-series)
- **Dual Performance Calculation**: Official Microsoft IOPS/throughput preferred, tiered memory-based profiles for fallback
- **Microsoft Compliance Validated**: Configurations exceed Microsoft SAP HANA Premium SSD v2 requirements
- **Dynamic Fallback**: Official Microsoft SAP sizing preferred, memory-based calculations when needed
- **Performance Optimization**: Intelligent tiered disk striping for cost and throughput benefits

## 🔄 How It Works

### Standard Mode Workflow
1. **Downloads** unified Microsoft SAP data (HANA + App sizing) from GitHub
2. **Generates** 58 systems with dynamic complexity sorting (no hardcoded dependencies)
3. **Applies** intelligent sizing: Official Microsoft SAP configs prioritized, memory-based fallback
4. **Creates** Microsoft SAP HANA-compliant storage with tiered disk striping optimization
5. **Outputs** comprehensive JSON with performance-tuned configurations

### Custom Mode Workflow
1. **Reads** your custom CSV with specific VM and environment requirements
2. **Downloads** unified Microsoft SAP data for consistency with standard mode
3. **Matches** VM sizes using same intelligent logic (official preferred, memory fallback)
4. **Applies** Microsoft-compliant storage calculations for all configurations
5. **Supports** storage overrides for data/backup disk customization
6. **Outputs** tailored JSON with same architectural quality as standard mode

## 🔧 Advanced Usage (Individual Components)

### Phase 1: SAP Systems Generation
```powershell
# Generate 58 standard SAP systems (rarely needed directly)
cd .\01-Generate-Systems
.\Generate-SAPSystemsFromHANA.ps1
```

### Phase 2: VM Configuration Creation  
```powershell
# Create VM configs from generated systems (rarely needed directly)
cd .\02-Create-VMConfig
.\Create-VMConfigMaster.ps1 -InputCSV "..\outputs\SAP_Systems_Complete.csv"
```

**Note**: Individual component usage is typically only needed for development or troubleshooting. The unified script handles the complete workflow automatically.

## ⚙️ Requirements
- **PowerShell**: 5.1 or later
- **Internet**: Required for downloading Microsoft GitHub SAP data
- **Permissions**: Read/write access to the SAP-Sizing directory

## 🏆 Benefits
- **Microsoft SAP Compliant**: Follows official Azure SAP HANA storage guidelines and Premium SSD v2 best practices
- **Proven Performance**: Configurations validated against Microsoft documentation (exceeds IOPS/throughput requirements)
- **Exact Memory Calculations**: Built-in database with 42+ exact VM memory values eliminates estimation errors
- **Intelligent Architecture**: Dual-path IOPS/throughput calculation with official Microsoft data prioritized
- **Performance Optimized**: Tiered disk striping leverages free IOPS tier for cost efficiency and throughput
- **Always Current**: Downloads latest Microsoft SAP automation data eliminating hardcoded dependencies
- **Production Ready**: Enhanced memory accuracy and validated Microsoft-compliant storage formulas
- **Flexible**: Supports both comprehensive and focused sizing scenarios with override capabilities
- **Validated Quality**: Extensively tested architecture with proper error handling and progress tracking