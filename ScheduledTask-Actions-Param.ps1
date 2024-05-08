#v1.0
-ExecutionPolicy Bypass -File \\cpha-fs1\MDMDiagnostics\EnrollMDM.ps1
-ExecutionPolicy Bypass -File \\cpha-fs1\MDMDiagnostics\FixHAADJPendingReg.ps1

-ExecutionPolicy Bypass -File \\192.168.20.43\MDMDiagnostics\EnrollMDM.ps1
-ExecutionPolicy Bypass -File \\172.16.90.27\_mem\AutoEnrollMDM.ps1

#full path for powershell.exe
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
-ExecutionPolicy Bypass -File C:\code\AutoEnroll-MDM5_LITE.ps1
-ExecutionPolicy Bypass -File C:\Code\AutoEnrollMDM.ps1



#v2.0

C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe

-ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/aollivierre/ResetIntuneEnrollment/main/AutoEnroll-MDM7_LITE.ps1' -UseBasicParsing | Invoke-Expression"