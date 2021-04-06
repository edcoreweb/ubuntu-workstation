#requires -Version 3 -Modules Hyper-V
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [String[]]$Ports,

    [Parameter(Mandatory=$false)]
    [Switch]$Clear
)

# Remove forward
if ($Clear) {
    Remove-NetNatStaticMapping -NatName "NATNetwork"
}

# Port forward all the ports
foreach ($port in $Ports) {
    Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0/24" -ExternalPort $port -Protocol TCP -InternalIPAddress "192.168.20.128" -InternalPort $port -NatName "NATNetwork"
}
