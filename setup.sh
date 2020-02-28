#!/bin/bash

print_line() {
	printf "%$(tput cols)s\n"|tr ' ' '-'
}

print_title() {
	clear
	print_line
	echo -e "# ${Bold}$1${Reset}"
	print_line
	echo ""
}
arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}"
}

#替换仓库列表
update_mirrorlist(){
	print_title "update_mirrorlist"
	tmpfile=$(mktemp --suffix=-mirrorlist)	
	url="https://www.archlinux.org/mirrorlist/?country=CN&protocol=http&protocol=https&ip_version=4"
	curl -so ${tmpfile} ${url} 
	sed -i 's/^#Server/Server/g' ${tmpfile}
	mv -f ${tmpfile} /etc/pacman.d/mirrorlist;
        #pacman -Syy --noconfirm
}
#开始分区
create_partitions(){
	print_title "create_partitions"
	parted -s /dev/sda mklabel msdos
	parted -s /dev/sda mkpart primary ext4 1M 525M
	parted -s /dev/sda mkpart primary linux-swap 525M 4800M
	parted -s /dev/sda mkpart primary ext4 4800M 100%
	parted -s /dev/sda set 1 boot on
	parted -s /dev/sda print
}
#开始格式化
format_partitions(){
	print_title "format_partitions"
	mkfs.vfat -F32 /dev/sda1 
	mkswap /dev/sda2 
	mkfs.ext4 /dev/sda3 
}
#挂载分区
mount_partitions(){
	print_title "mount_partitions"
	mount /dev/sda3 /mnt
	swapon /dev/sda2
        mkdir /mnt/boot
	mount /dev/sda1 /mnt/boot
	lsblk
}
#最小安装
install_baseSystem(){
	print_title "install_baseSystem"
        pacstrap /mnt base base-devel linux linux-firmware wqy-zenhei ttf-dejavu wqy-microhei adobe-source-code-pro-fonts   
}

#生成标卷文件表
generate_fstab(){
	print_title "generate_fstab"
	genfstab -U /mnt >> /mnt/etc/fstab
}

#配置系统时间,地区和语言
configure_system(){
	print_title "configure_system"
	arch_chroot "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
	arch_chroot "hwclock --systohc --utc"
	arch_chroot "mkinitcpio -p linux"
	echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
	echo "zh_CN.UTF-8 UTF-8" >> /mnt/etc/locale.gen
	arch_chroot "locale-gen"
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
}

#安装驱动程序
configrue_drive(){
	print_title "configrue_drive"
        arch_chroot "pacman -S --noconfirm xorg-server xorg-twm xorg-xclock xorg-server -y"
	arch_chroot "pacman -S --noconfirm bumblebee -y"
        arch_chroot "systemctl enable bumblebeed"
        arch_chroot "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings xf86-input-synaptics -y"        
        #arch_chroot "pacman -S --noconfirm linux-lts intel-ucode linux-headers -y"
}

#安装网络管理程序
configrue_networkmanager(){
       print_title "configrue_networkmanager"
       arch_chroot "pacman -S --noconfirm iw wireless_tools wpa_supplicant dialog netctl networkmanager networkmanager-openconnect rp-pppoe network-manager-applet net-tools -y"
       arch_chroot "systemctl enable NetworkManager.service"      
}

#安装配置引导程序（efi引导的话，将grub改成grub-efi-x86_64 efibootmgr）
configrue_bootloader(){
       print_title "configrue_bootloader"
       arch_chroot "pacman -S --noconfirm grub -y"
       arch_chroot "grub-install --target=i386-pc /dev/sda"
       #arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=boot" (efi引导)
       arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 
}


#添加本地域名
configure_hostname(){
	print_title "configure_hostname"
	read -p "Hostname [ex: archlinux]: " host_name
	echo "$host_name" > /mnt/etc/hostname
	if [[ ! -f /mnt/etc/hosts.aui ]]; then
	cp /mnt/etc/hosts /mnt/etc/hosts.aui
	else
	cp /mnt/etc/hosts.aui /mnt/etc/hosts
	fi
	arch_chroot "sed -i '/127.0.0.1/s/$/ '${host_name}'/' /etc/hosts"
	arch_chroot "sed -i '/::1/s/$/ '${host_name}'/' /etc/hosts"
	arch_chroot "passwd"
  }
  
#添加本地域名
configure_username(){
        print_title "configure_username"
        read -p "Username [ex: archlinux]: " User
        arch_chroot "pacman -S --noconfirm sudo zsh -y"
        arch_chroot "useradd -m -g users -G wheel -s /bin/zsh $User"
        arch_chroot "passwd $User"
        arch_chroot "sed -i 's/\# \%wheel ALL=(ALL) ALL/\%wheel ALL=(ALL) ALL/g' /etc/sudoers"
	arch_chroot "sed -i 's/\# \%wheel ALL=(ALL) NOPASSWD: ALL/\%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers"
        umount -R /mnt
	clear
	print_title "install has been.please reboot ."
}



update_mirrorlist
create_partitions
format_partitions
mount_partitions
install_baseSystem
generate_fstab
configure_system
configrue_drive
configrue_networkmanager
configrue_bootloader
configure_hostname
configure_username
#!/bin/bash
dhcpcd
#1.select eufi or mbr
export INSTALL
if [ $# = 1 ] &&  [ $1 = "eufi" ];then
	INSTALL=eufi
	echo "you will install eufi system"
else
	echo "you will install mbr system"
fi
#2.part disk
export DISK
echo "begin to part disk......"
echo "parted disk?(G):"
read  DISK
echo "root parted(G):"
read  ROOT
echo "home parted(G):"
read  HOME
dd if=/dev/zero of=/dev/${DISK} seek=1 count=2047 bs=1b
HOME=`expr ${HOME} + ${ROOT}`G
ROOT=${ROOT}G
echo "root part to:${ROOT}"
echo "home part to:${HOME}"
if [ ${INSTALL} = "eufi" ];then
	parted /dev/${DISK} mklabel gpt
	parted /dev/${DISK} mkpart primary 1M 512M 
	parted /dev/${DISK} mkpart primary ext4 512M ${ROOT} 
	parted /dev/${DISK} mkpart primary ext4 ${ROOT} ${HOME} 
	parted /dev/${DISK} mkpart primary linux-swap ${HOME} 100%
	mkfs.vfat /dev/${DISK}1
	mkfs.ext4 /dev/${DISK}2
	mkfs.ext4 /dev/${DISK}3
	mkswap /dev/${DISK}4
	swapon /dev/${DISK}4
	echo "partting disk all done!!!"
	#3.mount
	mount /dev/${DISK}2 /mnt
	mkdir -p /mnt/boot/efi
	mount /dev/${DISK}1 /mnt/boot/efi
	mkdir /mnt/home
	mount /dev/${DISK}3 /mnt/home
else
	parted /dev/${DISK} mklabel msdos
	parted /dev/${DISK} mkpart primary ext4 1M ${ROOT} 
	parted /dev/${DISK} mkpart primary ext4 ${ROOT} ${HOME} 
	parted /dev/${DISK} mkpart primary linux-swap ${HOME} 100%
	mkfs.ext4 /dev/${DISK}1
	mkfs.ext4 /dev/${DISK}2
	mkswap /dev/${DISK}3
	swapon /dev/${DISK}3
	echo "partting disk all done!!!"
	#3.mount
	mount /dev/${DISK}1 /mnt
	mkdir /mnt/home
	mount /dev/${DISK}2 /mnt/home
fi
#4.change urt software sources
echo "begin to change urt software sources......"
sed -i "1iServer = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch\n\
Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch\n\
Server = https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch\n\
Server = https://mirrors.163.com/archlinux/\$repo/os/\$arch\n\
Server = https://mirrors.xjtu.edu.cn/archlinux/\$repo/os/\$arch" /etc/pacman.d/mirrorlist
echo "changging urt software sources have done!!!"
#5.install archlinux
echo "begin to install archlinux......"
pacstrap /mnt base base-devel
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
echo "installing archlinux have done!!!"
cp ./arch_root.sh /mnt/
arch-chroot /mnt
rm /mnt/arch_root.sh
if [ ${INSTALL} = "eufi" ];then
	umount /mnt/boot/efi
fi
umount /mnt/home
umount /mnt
echo "all have done!!!
BEGIN TO ENJOY ARCH LINUX!!!"
#1.set timezone and language
echo "begin to set timezone and language......"
#systemdatectl set-timezone Asia/Shanghai
#systemdatectl set-npt true
tzselect
sed -i s/#en_US.UTF-8/en_US.UTF-8/g /etc/locale.gen
sed -i s/#zh_CN.UTF-8/zh_CN.UTF-8/g /etc/locale.gen
sed -i s/#zh_CN.GBK/zh_CN.GBK/g /etc/locale.gen
sed -i s/#zh_CN.GB2312/zh_CN.GB2312/g /etc/locale.gen
locale-gen
#2.install grub
echo "begin to install grub......"
if [ ${INSTALL} = "eufi" ];then
pacman -S grub-efi-x86_64 #os-prober
pacman -S efibootmgr
grub-install --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg
else
pacman -S grub #os-prober
grub-install /dev/${DISK}
grub-mkconfig -o /boot/grub/grub.cfg
fi
echo "installing grub have done!!!"
#3.install video drive
echo "begin to install video driver......"
echo "which one do you want to install?(default install ALL)"
echo "1)intel"
echo "2)ati"
echo "3)nvidia"
echo "4)all"
while read -p '#? ' NUM
do
	if [ -z "${NUM}" ] || [ ${NUM} -eq 1 ] || [ ${NUM} -eq 2 ] || [ ${NUM} -eq 3 ] || [ ${NUM} -eq 4 ];then
		break;
	fi
done
case ${NUM} in
	1)VIDEODRIVER=xf86-video-intel;;
	2)VIDEODRIVER=xf86-video-ati;;
	3)VIDEODRIVER=nvidia;;
	4)VIDEODRIVER="nvidia xf86-video-intel xf86-video-ati";;
	*)VIDEODRIVER="nvidia xf86-video-intel xf86-video-ati";;
esac
pacman -S ${VIDEODRIVER}
echo "installing video driver have done!!!"
#install desktop
echo "begin to install desktop......"
pacman -S xorg xorg-server
pacman -S gnome gnome-extra
systemctl enable gdm
pacman -S ttf-dejavu wqy-zenhei wqy-microhei
pacman -S ibus-googlepinyin
#pacman -S  fcitx-im fcitx-configtool
#echo 'export GTK_IMMODULE=fcitx\n\
#export XMODIFIERS="@im=fcitx"\n\
#export GT_IM_MODULE=fcitx' >>  /etc/bashrc
#gsettings set \
#org.gnome.settings-daemon.plugins.xsetting overrides \
#"{'Gtk/IMModule':<'fcitx'>}"
pacman -S networkmanager
echo "installing desktop have done!!!"
#windows systemfile
echo "begin to install windows systemfile......"
pacman -S ntfs-3g dosfstools
echo "installing windows systemfile have done!!!"
#yarout
echo "begin to install yaourt..."
echo '[archlinuxcn]
SigLevel = Optional TrustAll
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch' >> /etc/pacman.conf
pacman -Syu yaourt
echo "installing yaourt have done"
#compressed software
echo "begin to install compressed software......"
pacman -S p7zip file-roller unrar
echo "installing compressed software have done!!!"
#browser
echo "begin to install browser......"
pacman -S firefox
echo "installing browser have done!!!"
#vim
echo "begin to install vim"
pacman -S vim
echo "vim has been installed!!!"
#bash-completion
echo "begin to install bash-completion"
pacman -S bash-completion
echo "bash-completion has been installed!!!"
#others
pacman -S mlocate
pacman -S net-tools
#dhcpcd
systemctl enable dhcpcd
#passwd and add user
echo "begin to set passwd and add user......"
echo "please input root passwd:"
passwd
echo "please add user:"
read USER
useradd -m ${USER}
echo "please input ${USER} passwd:"
passwd ${USER}
echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
