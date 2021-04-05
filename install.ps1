# Install a new VM Switch
New-VMSwitch -SwitchName "NATSwitch" -SwitchType Internal

# Assign a subnet
New-NetIPAddress -IPAddress 192.168.20.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.20.0/24

# Assign a ip address to the vm
# TODO

# Port forward 80, 443
Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0/24" -ExternalPort 80 -Protocol TCP -InternalIPAddress "192.168.20.128" -InternalPort 80 -NatName NATNetwork
Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0/24" -ExternalPort 443 -Protocol TCP -InternalIPAddress "192.168.20.128" -InternalPort 443 -NatName NATNetwork

# Create iso image
.\bin\xorriso.exe -as mkisofs -r -V "ubuntu_1804_netboot_unattended" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o "E:\ubuntu-iso.iso" .
