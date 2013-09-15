## Adblock for TomatoUSB by haarp
A clean, lean, and mean adblocking script.
[Upstream URL](http://www.linksysinfo.org/index.php?threads/script-clean-lean-and-mean-adblocking.68464/)

## Features
* Takes public blocklists for known ad hosts and redirects them via DNS poisoning.
* Pixelserv (optional) through a second router IP (Web GUI on port 80 still works)! Or if pixelserv is not desired, redirect to 0.0.0.0, which will also kill ads (but might produce error messages).
* Does not interfere with normal dnsmasq operation.
* Does not try to "optimize" it (that's what the "Custom configuration" box on the web GUI is for, people)!
* Does not break Tomato's ability to restart dnsmasq should it crash.
* Additional blocklist sources can easily be added.
* Easy blacklist and whitelist.
* Very optimized: Updates as quickly and with as little CPU/memory usage as possible.
* Small and lean: Only does what it needs to do, then gets out of the way.
* Readable code.

## Setup Instructions
Note -- Users of Adblock pre-v4.0 need to completely remove it.

### 1. Setup the router
* Verify that your Tomato supports custom dnsmasq configs (i.e. shows this line under Advanced->DHCP/DNS: "Note: The file /etc/dnsmasq.custom is also added to the end of Dnsmasq's configuration file if it exists.")
* Set up some kind of non-volatile storage. This is up to you, options are JFFS, CIFS, SD card, USB and possibly more. Note the path.
* Designate a directory on your storage for adblock, e.g. /jffs/adblock/ (as seen by the router). Avoid spaces! This is the PREFIX.

### 2. Install Adblock
* Place both files in this github repo on the filesystem of your target device. For example: /opt/adblock
* Make adblock.sh executable `chmod +x /opt/adblock.sh`
* Edit /opt/adblock/config adjusting the PREFIX variable to match that path chosen.
* Optionally comment or uncomment the various sources in the config file per your perferences.

## Running Adblock
Users can call the script from the shell (or the TomatoUSB GUI under Tools>System>Execute System Commands) or a cronjob.

## Command-line Options
`/opt/adblock/adblock.sh`	Default, update and enable adblocker.

`/opt/adblock/adblock.sh stop`	Disable the adblocker.

`/opt/adblock/adblock.sh restart`	Restart adblocker e.g. for config changes and script updates.

`/opt/adblock/adblock.sh force`	Force updating of filters, even in not updated.

`/opt/adblock/adblock.sh toggle`	Disable the adlocker if active, enable if inactive. Perfect for one of the custom buttons on your router.

### Example starting the script when the router boot
Administration>Scripts>WAN Up
`[[ -x /opt/adblock/adblock.sh ]] && /opt/adblock/adblock.sh &`

### Example updating once per week
Administration>Scheduler>Custom x
`[[ -x /opt/adblock/adblock.sh ]] && /opt/adblock/adblock.sh restart`

### Notes
* The script, pixelserv and all data reside on PREFIX. If you have other means of accessing that storage, those will probably be more convenient than pasting into boxes on the web GUI.
* The script will automatically block anything bound for the pixelserv IP that is not intended for pixelserv itself.
* Subsequent updates will only fetch blocklists that have changed, this however only works when the source server runs http on port 80.
* You will need 2x-3x as much non-volatile storage as all filters combined. If your storage is too small, set RAMLIST to 1. Obviously, you now need enough free RAM to hold the filters instead! Additionally, the script will now have to redownload the filters when the router reboots.
* If you change settings or update the script, please run the script with the restart option afterwards!
* If you experience problems, check the router logs!
