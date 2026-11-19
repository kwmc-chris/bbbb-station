#!/bin/bash
# Sets up a new bird station: BirdNET-Pi, MQTT and nature.
# Run once without sudo: bash install.sh
#   1st run: BirdNET-Pi, which reboots the Pi at the end
#   2nd run: runs by itself after that reboot, then reboots again
# Progress of the 2nd run is in ~/install.log
set -e

# set working folder and check normal user, not sudo
cd "$(dirname "$0")"
DIR="$(pwd)"
[ "$(id -u)" -ne 0 ] || { echo "Run without sudo: bash install.sh"; exit 1; }

# check the settings files are here
ls birdnet.conf apprise.txt body.txt > /dev/null || exit 1

# check the hostname was set in Raspberry Pi Imager
[ "$(hostname)" != raspberrypi ] || { echo "Set the hostname in Raspberry Pi Imager first"; exit 1; }

# move station.env from the boot partition to the home folder
if [ -f /boot/firmware/station.env ]; then
    sudo mv /boot/firmware/station.env ~/station.env
    sudo chown "$(id -un):" ~/station.env
    chmod 600 ~/station.env
fi
[ -f ~/station.env ] || { echo "No station.env - see station.env.example"; exit 1; }
source ~/station.env


# 1st run: turn off IPv6, set up the 2nd run, install BirdNET-Pi (it reboots the Pi)
if [ ! -d ~/BirdNET-Pi ]; then
    grep -q ipv6.disable=1 /boot/firmware/cmdline.txt ||
        sudo sed -i '1 s/$/ ipv6.disable=1/' /boot/firmware/cmdline.txt

    sudo apt-get update -qq
    sudo apt-get install -y -qq git curl

    # run this script again at the next boot
    sudo tee /etc/systemd/system/bbbb-station-install.service > /dev/null << EOF
[Unit]
Description=bbbb-station install, 2nd run
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$(id -un)
ExecStartPre=/bin/sleep 60
ExecStart=/bin/bash $DIR/install.sh
StandardOutput=append:$HOME/install.log
StandardError=append:$HOME/install.log

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl enable --quiet bbbb-station-install

    echo "Installing BirdNET-Pi. The Pi then reboots and finishes by itself."
    echo "Log in later: it says READY when done. Progress: tail -f ~/install.log"
    curl -s https://raw.githubusercontent.com/Nachtzuster/BirdNET-Pi/main/newinstaller.sh | bash
    exit 0
fi


# 2nd run
echo "2nd run started $(date)"

# MQTT broker
sudo apt-get update -qq
sudo apt-get install -y -qq mosquitto mosquitto-clients

# BirdNET-Pi settings and notifications
sudo cp birdnet.conf /etc/birdnet/birdnet.conf
sudo sed -i "s/^SITE_NAME=.*/SITE_NAME=\"$(hostname)\"/" /etc/birdnet/birdnet.conf
cp apprise.txt body.txt ~/BirdNET-Pi/

# nature and its service
curl -fsS "$NATURE_URL/nature" -o /tmp/nature
curl -fsS "$NATURE_URL/nature.service" -o /tmp/nature.service
sudo install -m 755 /tmp/nature /usr/local/bin/nature
sudo install -m 644 /tmp/nature.service /etc/systemd/system/nature.service
sudo systemctl daemon-reload
sudo systemctl enable --quiet nature

# turn off BirdNET-Pi's avahi-alias
sudo systemctl disable --quiet avahi-alias@.service || true

# MQTT bridge to the remote server
sudo tee /etc/mosquitto/conf.d/bridge.conf > /dev/null << EOF
connection birdnet
bridge_protocol_version mqttv311
address $MQTT_ADDRESS
remote_username $MQTT_USER
remote_password $MQTT_PASSWORD
topic # out 0
EOF
sudo chgrp mosquitto /etc/mosquitto/conf.d/bridge.conf
sudo chmod 640 /etc/mosquitto/conf.d/bridge.conf
sudo systemctl restart mosquitto

# stop this script running at boot
sudo systemctl disable --quiet bbbb-station-install 2> /dev/null || true
sudo rm -f /etc/systemd/system/bbbb-station-install.service
sudo systemctl daemon-reload

# READY message, shown when logging in
sudo tee /etc/motd > /dev/null << EOF

########################################################
#                                                      #
#   READY - bbbb-station set up $(date '+%a %d %b %H:%M')       #
#                                                      #
#   Next: add the display (see bbbb-display README)    #
#                                                      #
########################################################

EOF

echo "2nd run done $(date). Rebooting."
sudo reboot
