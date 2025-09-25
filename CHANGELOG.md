# Changelog - SAP Azure VM Sizing Framework

## Version 2.0 - Major Architectural Improvements (Current)

### 🚀 Unified Data Architecture
- **Eliminated Hardcoded Dependencies**: Complete removal of static VM-to-memory mappings
- **Unified Microsoft SAP Data**: Merges both HANA and App sizing datasets from Microsoft GitHub
- **Dynamic System Generation**: All 58 SAP systems generated dynamically from live Microsoft data
- **Intelligent Prioritization**: Official Microsoft SAP configurations preferred with memory-based fallback

### 🔧 Critical Fixes
- **Memory Calculation Bug**: Fixed fundamental error treating VM cores as memory (M96: 96GB→1946GB)
- **Corrected Core-to-Memory Ratios**: M-series: 20GB/core, E-series: 8GB/core
- **Microsoft SAP HANA Compliance**: Storage calculations follow official guidelines
  - Data: 1.2× VM memory
  - Log: 0.5× VM memory (or 500GB minimum for VMs >1TB)
  - Shared: 1× VM memory (or 1TB minimum for VMs >1TB)

### ⚡ Performance Optimization
- **Tiered Disk Striping**: Validated approach (2/4/8 disks based on VM size) following Azure Premium SSD v2 documentation
- **Cost Efficiency**: Leverages free baseline IOPS (e.g., 4 × 3,000 IOPS per disk for medium VMs)
- **Throughput Benefits**: Overcomes single disk 1,200 MB/sec limitation
- **Microsoft-Compliant Design**: Follows official SAP HANA storage best practices

### 🎯 Enhanced Functionality
- **Comprehensive Override System**: Storage-focused customization capabilities
- **Centralized Outputs**: All generated files in outputs/ folder
- **Progress Tracking**: Professional terminal interface with clear status
- **Error Handling**: Robust validation and informative error messages

### 📊 Data Sources
- **HANA Sizing**: https://github.com/Azure/sap-automation/.../hana_sizes_v2.json
- **App Sizing**: https://github.com/Azure/sap-automation/.../app_sizes.json
- **Fresh Data**: Downloaded dynamically on each execution
- **No Local Dependencies**: Eliminates static configuration files

### 🧪 Validation & Testing
- **Comprehensive Testing**: Standard, Custom, and Override modes validated
- **Memory Calculation Verification**: Extensive testing of corrected formulas
- **Microsoft Compliance Validation**: Storage calculations verified against official guidelines
- **Performance Impact Analysis**: Disk count rationale confirmed with Microsoft documentation

---

## Version 1.0 - Initial Framework (Legacy)

### Initial Features
- Basic SAP system generation from static data
- VM configuration creation with standard storage profiles
- Custom CSV input support
- Override capabilities for storage customization

### Known Issues (Resolved in v2.0)
- Hardcoded VM-to-memory mappings causing inconsistencies
- Memory calculation treating cores as memory values
- Storage formulas not following Microsoft SAP HANA guidelines
- Local data dependencies requiring manual maintenance

---

## Migration Notes

### Upgrading from v1.0 to v2.0
- **No breaking changes**: Same command-line interface and parameters
- **Improved accuracy**: Corrected memory calculations and Microsoft compliance
- **Enhanced performance**: Better storage configurations and validation
- **Eliminated maintenance**: No more local data file management required

### File Structure Changes
- All outputs now centralized in `outputs/` folder
- Reference documentation moved to `reference/` folder
- Cleaner workspace organization with logical file grouping

---

## Architecture Evolution Summary

| Component | v1.0 | v2.0 |
|-----------|------|------|
| Data Sources | Static local files | Dynamic Microsoft GitHub |
| Memory Calculation | Hardcoded mappings (incorrect) | Core-based formulas (correct) |
| SAP Compliance | Basic storage sizing | Microsoft SAP HANA compliant |
| System Generation | Static 58-system list | Dynamic complexity-based |
| Disk Configuration | Simple approach | 4-disk striping optimization |
| Validation | Basic | Comprehensive with Microsoft docs |