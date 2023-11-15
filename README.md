# M365 License Assignment and Intune Enrollment Guide

This guide provides step-by-step instructions for managing Microsoft 365 (M365) license assignment and Intune enrollment for a user. Please follow the steps in the given order.

## M365 Admin Center/Entra Side

### Step 1: Assign M365 License
- **Action**: Ensure the user has an M365 license assigned.

## Workstation/Client Side

### Step 2: Adjust User Account Control (UAC) Settings
- **Action**: Set the User Account Control (UAC) slider to the highest level for maximum security.

### Step 3: Create a Code Folder
- **Action**: Create a folder named `code` at the root of the C: drive.

### Step 4: Copy PowerShell Script
- **Action**: Copy the PowerShell script from [GitHub Repository URL](URL to GitHub repo) to `C:\code`.

### Step 5: Launch PowerShell as Administrator
- **Action**: Open PowerShell with administrative privileges.

### Step 6: Navigate to Script Folder
- **Action**: Run `cd C:\code` in PowerShell to change the directory to the script's location.

### Step 7: Execute the Script
- **Action**: Call the script using `.\Reset-IntuneEnrollment_v12_InterActive_CleanupOnly.ps1`.

### Step 8: Share Output and Log Files
- **Action**: Once the script completes, share the output and log files located at `C:\Code\_MEM\logs\ResetIntuneMDMEnrollment`.

### Step 9: Open Task Scheduler
- **Action**: Launch Task Scheduler (`taskschd.msc`) as an administrator.

### Step 10: Run MDM Enrollment Task
- **Action**: Locate and manually run the task named `MDMEnrollmentScripted` under the main library.

### Step 11: Install Company Portal
- **Action**: Download and install the Company Portal from the Microsoft Store.

### Step 12: Sync in Company Portal
- **Action**: Log in to the Company Portal, navigate to settings, and click on `sync`. Restart the Company Portal and perform another sync.

---

Please ensure each step is completed in the order provided for successful setup and configuration.
