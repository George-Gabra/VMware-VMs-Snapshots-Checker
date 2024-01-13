# Management Snapshots Checker

## Overview
This script is designed to check for snapshots on VMs deployed on management vCenter servers listed in Ralph3 inventory. It connects to Ralph3 to obtain a list of vCenter servers tagged with "mgmt" and then queries each vCenter server to retrieve information about VMs' snapshots. The script generates an HTML report containing details about the snapshots, such as VM name, snapshot name, size, and creation date. The report is then sent to predefined email with HTML format.

Removing unnecessary snapshots is crucial for optimizing storage utilization.

## Usage
Run the script by executing it in a PowerShell environment.

```powershell
.\list_management_snapshots.ps1
```


## Script Information
- **Script Name:** list_management_snapshots.ps1
- **Version:** 1.0
- **Author:** George Gabra
- **Creation Date:** January 2, 2024, 11:03 AM
- **Additional Information:** [TDB]
