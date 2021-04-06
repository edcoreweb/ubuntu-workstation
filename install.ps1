#requires -Version 3 -Modules Hyper-V
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [String]$Version,

    [Parameter(Mandatory=$true)]
    [String]$VMName,

    [Parameter(Mandatory=$true)]
    [String]$VMPath
)

# Global settings
$ProgressPreference = 'SilentlyContinue'

$version = $Version
$root = $PSScriptRoot
$path = "${root}\temp"
$bin = "${root}\bin"
$releasesUrl = "https://releases.ubuntu.com"
$certificatesUrl = "https://raw.githubusercontent.com/edcoreweb/tools/master/vm/config/ssl"

if ('20.04' -notcontains $version) {
    throw "Invalid Ubuntu version [$version]."
}

function Find-Release {
    Param ($MajorVersion)
    # ubuntu-20.04.5-live-server-amd64.iso
    $html = (Invoke-WebRequest "${releasesUrl}/${MajorVersion}" -UseBasicParsing).rawcontent

    if ($html -match "ubuntu-${MajorVersion}(.*)-live-server-amd64.iso") {
        return "${releasesUrl}/${version}/" + $matches[0]
    }

    throw "Could not find a Ubuntu release for version [${MajorVersion}]."
}

# Enusre we are in the script dir
Set-Location $PSScriptRoot

# Ensure working directory exists
New-Item -Path $path -ItemType "directory" -Force | Out-Null

# Download image
$release = Find-Release -MajorVersion $version
$name = $release.Split('/')[-1]
$isoPath = "${path}\${name}"

if (Test-Path $isoPath -PathType Leaf) {
    Write-Output "Latest release is already downloaded..."
} else {
    Write-Output "Downloading Ubuntu ${version}..."
    Invoke-WebRequest -Uri $release -OutFile $isoPath
}

# Extract Image
Write-Output "Extracting image..."
Remove-Item -Path "${path}\unattended" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "${path}\unattended" -ItemType "directory" -Force | Out-Null
$letter = (Mount-DiskImage -ImagePath $isoPath -StorageType ISO | Get-Volume).DriveLetter
Copy-Item "${letter}:\*" -Destination "${path}\unattended\" -Force -Recurse | Out-Null
Dismount-DiskImage -ImagePath $isoPath | Out-Null
#& "${bin}\xorriso.exe" -xattr off -acl off -osirrox on -indev $isoPath -report_about NOTE -extract / /temp/unattended

# Patch Image
Write-Output "Patching image..."
New-Item -Path "${path}\unattended\nocloud" -ItemType "directory" -Force | Out-Null
New-Item -Path "${path}\unattended\nocloud\meta-data" -ItemType "file" -Force | Out-Null
Copy-Item "${root}\${version}\user-data.yml" -Destination "${path}\unattended\nocloud\user-data" -Force | Out-Null
Copy-Item "${root}\${version}\txt.cfg" -Destination "${path}\unattended\isolinux\txt.cfg" -Force | Out-Null
Copy-Item "${root}\${version}\grub.cfg" -Destination "${path}\unattended\boot\grub\grub.cfg" -Force | Out-Null

# By-Pass MD5 check
$hash = (Get-FileHash -Path "${path}\unattended\.disk\info" -Algorithm MD5).Hash
Set-Content -Path "${path}\unattended\md5sum.txt" -Value "${hash}  ./.disk/info" -Force

# Repackage Image
Write-Output "Repacking image..."
$newIsoPath = "${path}\unattended-${name}"
Remove-Item -Path $newIsoPath -Force -ErrorAction SilentlyContinue | Out-Null
& "${bin}\xorriso.exe" -as mkisofs -r -V "Ubuntu ${version}" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -isohybrid-mbr "/${version}/isohdpfx.bin" -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o $newIsoPath /temp/unattended 2> $null

# Install a new VM Switch
$switch = "NATSwitch"
If (-Not (Get-VMSwitch -SwitchName $switch -ErrorAction SilentlyContinue)) {
    Write-Output "Instaling a new NAT adapter..."
    New-VMSwitch -SwitchName $switch -SwitchType Internal
    New-NetIPAddress -IPAddress 192.168.20.1 -PrefixLength 24 -InterfaceAlias "vEthernet (${switch})"
    New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.20.0/24
}

# Make a new VM
Write-Output "Instaling a new VM..."
New-VM -Name $VMName -Generation 2 -Path "${VMPath}\${VMName}" -NewVHDPath "${VMPath}\${VMName}\Disk.vhdx" -NewVHDSizeBytes 80GB -SwitchName $switch
Set-VMProcessor -VMName $VMName -Count 8
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes 4GB -MaximumBytes 8GB
$dvd = Add-VMDvdDrive -VMName $VMName -Path $newIsoPath -Passthru
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off -FirstBootDevice $dvd
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
Start-VM -Name $VMName

# Wait for it to stop
Write-Output "Provisioning the VM..."
while ((Get-VM -name $VMName).state -eq 'Running') {
    start-sleep -s 5
}

# Allow traffic from the same subnet
Write-Output "Adding firewall rule..."
Remove-NetFirewallRule -DisplayName "Allow ${switch} traffic" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Allow ${switch} traffic" -Direction Inbound -RemoteAddress 192.168.20.0/24 -Action Allow | Out-Null

Write-Output "Importing certificates..."
$ca = "ca.crt"
Invoke-WebRequest -Uri "${certificatesUrl}/${ca}" -OutFile "${path}/${ca}"
certutil -addstore "Root" "${path}\${ca}" 2> $null

Start-VM -Name $VMName
Write-Output "Done."
