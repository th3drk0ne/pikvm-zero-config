#!/bin/bash

#Step 1) Check if root--------------------------------------
if [[ $EUID -ne 0 ]]; then
   echo "Please execute script as root." 
   exit 1
fi
#-----------------------------------------------------------
rw

#Step 2) Update config.txt----------------------------------
cd /boot/
File=config.txt

if grep -q "avoid_warnings=0" "$File";
        then
		sed -i '/avoid_warnings=0/d' "$File";
fi

if grep -q "avoid_warnings=1" "$File";
        then
                echo "warnings already disable. Doing nothing."
        else
                echo "avoid_warnings=1" >> "$File"
                echo "warnings disable."
fi


if grep -q "dtparam=spi=on" "$File";
        then
                echo "spi dtparam enabled. Doing nothing."
        else
                echo "dtparam=spi=on" >> "$File"
                echo "SPI dtparam enabled."
fi


if grep -q "dtoverlay=w5500,cs=0,speed=39000000" "$File";
        then
                echo "overlay already enabled. Doing nothing."
        else
                echo "dtoverlay=w5500,cs=0,speed=39000000" >> "$File"
                echo "w5500 overlay enabled."
fi

#-----------------------------------------------------------


#Step 4) Install systemd services----------------------------

#Enable HW number gererator
path1=/etc/systemd/system/rngd.service.d

if [ -e $path1 ];
then
cd /etc/systemd/system/rngd.service.d
fi

svc1=params.conf

if [ -e $svc1 ];
	then
		
		echo "rngd already configured."
	else
		mkdir /etc/systemd/system/rngd.service.d
cat > /etc/systemd/system/rngd.service.d/params.conf <<EOF
# disable jitter source
[Service]
ExecStart=
ExecStart=/sbin/rngd --foreground --exclude 5
EOF
systemctl daemon-reload
systemctl restart rngd

                echo "rngd reconfigured."
fi



#setmac.service


cd /etc/systemd/system

svc2=setmac.service

if [ -e $svc2 ];
	then
		
		echo "setmac.service already configured."
	else
echo "set last octet of mac [b8:27:eb:00:00:] 01-FF"
read macaddress1

cat > /etc/systemd/system/setmac.service <<EOF
[Unit]
Description=Set MAC address for W5500
Wants=network-pre.target
Before=network-pre.target
BindsTo=sys-subsystem-net-devices-eth0.device
After=sys-subsystem-net-devices-eth0.device
[Service]
Type=oneshot
ExecStart=/sbin/ip link set dev eth0 address b8:27:eb:00:00:$macaddress1
ExecStart=/sbin/ip link set dev eth0 up
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable setmac.service
systemctl start setmac.service

                echo "setmac.service configured."
fi


#-----------------------------------------------------------


#Step 5) Install gpiozero module----------------------------
pacman -S python-raspberry-gpio --noconfirm
#-----------------------------------------------------------

#Step 6) Download Python script-----------------------------
cd /opt/
sudo mkdir dkn
cd /opt/dkn
script=fan_ctrl-dkn.py

if [ -e $script ];
	then
		echo "Script fan_ctrl-dkn.py already exists. Updating..."
		rm $script
		wget "https://raw.githubusercontent.com/th3drk0ne/DKN-Fan-Controller/main/fan_ctrl-dkn.py"
		echo "Update complete."
	else
		wget "https://raw.githubusercontent.com/th3drk0ne/DKN-Fan-Controller/main/fan_ctrl-dkn.py"
                echo "Download  complete."
fi
#-----------------------------------------------------------

#Step 7) Enable Python script to run on start up------------

#dkn-fan.service

cd /etc/systemd/system

svc3=dkn-fan.service

if [ -e $svc3 ];
	then
		
		echo "dkn-fan.service already configured."
	else
cat > /etc/systemd/system/dkn-fan.service <<EOF
[Unit]
Description=DKN Fan Service
ConditionPathExists=/opt/dkn

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/dkn/fan_ctrl-dkn.py
TimeoutSec=0
StandardOutput=tty

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable dkn-fan.service
systemctl start dkn-fan.service


                echo "dkn-fan.service configured."
fi


#-----------------------------------------------------------

exit 1
#Step 8) Reboot to apply changes----------------------------
ro
echo "Will now reboot after 3 seconds."
sleep 4
sudo reboot
#-----------------------------------------------------------

