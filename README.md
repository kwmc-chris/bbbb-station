# bbbb-station

Sets up the base of a new bird station on a Raspberry Pi 4 with one script:

1. **BirdNET-Pi** ([Nachtzuster](https://github.com/Nachtzuster/BirdNET-Pi)) hears and names the birds
2. **MQTT and nature**: each detection goes to the Pi's own MQTT broker, which passes it on to the remote server; `nature` and `nature.service` come from nature's web folder

Every Pi gets the same base. The display is added afterwards with [bbbb-display](https://github.com/kwmc-chris/bbbb-display), set up for each Pi.

## Files

| | |
|---|---|
| `install.sh` | Sets up the Pi. Run once: it runs itself again after BirdNET-Pi reboots the Pi |
| `birdnet.conf` | BirdNET-Pi's settings, copied from a working Pi |
| `apprise.txt` | Where BirdNET-Pi sends notifications (the local MQTT broker) |
| `body.txt` | The notification message (JSON, all on one line) |
| `station.env.example` | Example MQTT login and nature web folder. Copy to `station.env` and fill in, don’t save this in GitHub |

## Settings files

The settings files are copied onto each Pi as they are. To change them, set things up on one Pi, then copy the files back here:

After a BirdNET-Pi update, copy `birdnet.conf` back from a freshly installed Pi, in case it has new settings.

Keep `station.env` on the Mac, outside the GitHub repo.

## Setting up a Pi

**1. Image the card** with Raspberry Pi Imager: 
Raspberry Pi OS (Legacy, 64-bit) Lite. [Bookworm]
In the OS customisation settings, set:
- hostname (unique, e.g. `birdnet-kwmc-XX`)
- username `pi` and a password
- KWMC Visitor Wi-Fi
- SSH on

**3. Copy and customise `station.env`.** Add the MQTT address and username/password, and the address for the nature tool.

**2. Add `station.env`.** With the card still in the Mac, copy `station.env` onto the card's `bootfs` drive. Eject it.

**3. Boot the Pi** with the mic fitted, wait a couple of minutes, then:
```
ssh pi@birdnet-kwmc-XX.local
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/kwmc-chris/bbbb-station.git
bash bbbb-station/install.sh
```
BirdNET-Pi installs (about 20 minutes) and reboots the Pi. The script then runs again by itself, sets up MQTT, the settings and nature, and reboots once more.

**4. Leave it.** Log in after about half an hour:
```
ssh pi@birdnet-kwmc-XX.local
```
A big **READY** message shows when it's done. To watch it working: `tail -f ~/install.log`.

No READY message? Look at the end of `~/install.log`. Fix the problem and reboot: the 2nd run tries again at each boot until it finishes.

**5. Add the display** by following the [bbbb-display README](https://github.com/kwmc-chris/bbbb-display).

## Checks after setting up

```
ip a | grep inet6                              # nothing = IPv6 off
mosquitto_sub -v -h localhost -p 1883 -t '#'   # watch detections (Ctrl+C stops)
sudo systemctl status mosquitto nature         # both running?
systemctl list-unit-files 'avahi-alias*'       # should be disabled
```
- Open `http://<hostname>.local` for the BirdNET-Pi web UI.
- In the web UI, Tools > Settings > Notifications > **Send test notification**: it should show up in `mosquitto_sub`.
- Play a bird (e.g. a blackbird in Merlin) close to the mic, with no talking or noise. It should show in the web UI and in `mosquitto_sub`.

## Notes

- The MQTT bridge is made from `station.env`. The `bridge.conf` in nature's web folder isn't used.
- Each Pi connects to the remote server as `<hostname>.birdnet`, so hostnames must be unique, or two Pis will keep knocking each other off.
- Add `log_type all` to `/etc/mosquitto/conf.d/bridge.conf` only while testing: it logs every message.