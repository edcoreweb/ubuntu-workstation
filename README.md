### Installation

Open a Powershell window (with Administrator rights) and run
```powershell
.\install.ps1 -Version 20.04 -VMName "Ubuntu Workstation" -VMPath "D:\Hyper-V"
```

After it's complete you can ssh into the vm
```powershell
ssh fps@192.168.20.128
```

To forward ports from the VM
```powershell
.\foward.ps1 -Ports 80,443,3306
```

To clear all the forwarded ports
```powershell
.\foward.ps1 -Clear
```

To list the forwarded ports
```powershell
.\foward.ps1 -List
```
