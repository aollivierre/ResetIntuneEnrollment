# M365 License Assignment and Intune Enrollment Guide

This guide provides step-by-step instructions for managing Microsoft 365 (M365) license assignment and Intune enrollment for a user. Please follow the steps in the given order.

## M365 Admin Center/Entra Side

### Step 1: Assign M365 License
- **Action**: Ensure the user has an M365 license assigned.

## Workstation/Client Side

### Step 2: Adjust User Account Control (UAC) Settings
- **Action**: Set the User Account Control (UAC) slider to the highest level to ensure the RunAs window runs in secure desktop as opposed to regular user desktop. Otherwise Task Scheduler and Regedit will run under the standard user context if UAC elevation is turned off.

### Step 3: Create a Code Folder
- **Action**: Create a folder named `code` at the root of the C: drive.

### Step 4: Copy PowerShell Script
- **Action**: Download the entire GitHub content using Code > Download Zip or use Git Clone to `C:\code`.

### Step 5: Launch PowerShell as Administrator
- **Action**: Open PowerShell with administrative privileges. (Right click and Run As Admin)

### Step 6: Navigate to Script Folder
- **Action**: Run `cd C:\code\PR4B-ResetIntuneEnrollment-v5` in PowerShell to change the directory to the script's location.

### Step 7: Execute the Script
- **Action**: Call the script using `.\install.ps1`.

### Step 8: Share Output and Log Files
- **Action**: Once the script completes, share the output and log files located at `C:\Code\_MEM\logs\ResetIntuneMDMEnrollment`.

### Step 9: Open Task Scheduler
- **Action**: Launch Task Scheduler (`taskschd.msc`) as an administrator.

### Step 10: Run MDM Enrollment Task
- **Action**: Locate and manually run the task named `PR4B-ResetIntuneEnrollment-[GUID]` under the main library.

### Step 11: Install Company Portal
- **Action**: Download and install the Company Portal from the Microsoft Store.

### Step 12: Sync in Company Portal
- **Action**: Log in to the Company Portal, navigate to settings, and click on `sync`. Restart the Company Portal and perform another sync.

---

Please ensure each step is completed in the order provided for successful setup and configuration.
