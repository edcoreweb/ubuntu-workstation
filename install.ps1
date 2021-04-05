# Global settings
$ProgressPreference = 'SilentlyContinue'

$version = $args[0]
$root = $PSScriptRoot
$path = "${root}\temp"
$bin = "${root}\bin"
$releasesUrl = "https://releases.ubuntu.com"

if ("18.04", '20.04' -notcontains $version) {
    throw "Invalid Ubuntu version [$version]."
}

function Find-Release {
    Param ($MajorVersion)
    # ubuntu-18.04.5-live-server-amd64.iso
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
Copy-Item "${root}\${version}\loopback.cfg" -Destination "${path}\unattended\boot\grub\loopback.cfg" -Force | Out-Null

# Repackage Image
Write-Output "Repacking image..."
$newIsoPath = "${path}\unattended-${name}"
Remove-Item -Path $newIsoPath -Force -ErrorAction SilentlyContinue | Out-Null
& "${bin}\xorriso.exe" -as mkisofs -r -V "Ubuntu ${version}" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o $newIsoPath /temp/unattended

# Make a new VM
#Write-Output "Instaling a new VM..."
#$vmName = "Ubuntu Workstation"
#New-VM -Name $vmName -Generation 2 -MemoryStartupBytes 8GB -Path "D:\Hyper-V\${vmName}" -NewVHDPath "D:\Hyper-V\${vmName}\Disk.vhdx" -NewVHDSizeBytes 80GB
#Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
#Add-VMDvdDrive -VMName $vmName -Path $newIsoPath
#Start-VM -Name $vmName

# Install a new VM Switch
#New-VMSwitch -SwitchName "NATSwitch" -SwitchType Internal

# Assign a subnet
#New-NetIPAddress -IPAddress 192.168.20.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
#New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.20.0/24

# Assign a ip address to the vm
# TODO

# Port forward 80, 443
#Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0/24" -ExternalPort 80 -Protocol TCP -InternalIPAddress "192.168.20.128" -InternalPort 80 -NatName NATNetwork
#Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0/24" -ExternalPort 443 -Protocol TCP -InternalIPAddress "192.168.20.128" -InternalPort 443 -NatName NATNetwork
