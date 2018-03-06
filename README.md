# Location Changer

*Please note, this is a fork of the original [Location Changer](https://github.com/eprev/locationchanger) by Anton Eprev*

*Location Changer* automatically changes the macOS [network location](https://support.apple.com/en-us/HT202480)
based on the name of the Wi-Fi network or a manually configured Location. It can also run a custom script to perform
additional actions when changing the Location.


## Installation & Updates

```
curl -L https://github.com/kyletmiller/locationchanger/raw/master/locationchanger.sh | bash
```

You must be an Administrator to install *Location Changer* and it will ask you for your password.
The `locationchanger` executable is installed in `/usr/local/bin` by default. If you would like
to install it elsewhere, please download the source and edit the `INSTALL_DIR` variable (on Line 3)
prior to installation.


## Basic Usage

Basic usage of *Location Changer* involves having Location names that match your Wi-Fi Network SSIDs
(e.g. a macOS Location with the name `Home Wi-Fi` will correspond to the Wi-Fi Network SSID `Home WiFi`).
When joining a Wi-Fi network, *Location Changer* will look for a Location whose name matches that of the
SSID and will switch accordingly.

If *Location Changer* is unable to find a Location name matching the SSID, it will default to 'Automatic'.
The default Location name can be changed by editing the `DEFAULT_LOCATION` variable (on Line 15) prior to installation.


## Advanced Usage

*Location Changer* will select the Location to change to using the following precedence:

1. A manually configured Location
2. A Location name that matches the SSID
3. The default Location


### Manually Configuring Locations

*Location Changer* includes support for manually mapping Locations to Wi-Fi SSIDs. This is useful, e.g., if
you'd like to have a Location name that does not match the SSID or would like to use a Location for more
than one SSID.

One example might be if your home Wi-Fi network is broadcasted on both 2.4GHz and 5GHz as `Home Wi-Fi`
and `Home Wi-Fi 5G`, respectively. Instead of maintaining Locations for each SSID, a user can manually
configure the same Location to be used with both.

Configuration happens in `${HOME}/.locations/locations.conf` by default. The location of this file can be changed
by editing the `CONFIG_FILE` variable (on Line 17) in the `locationchanger.sh` script prior to installation. It should be a plain text
file with key-value pairs in the following format. Spaces are supported for both the SSID as well as the Location name.
However, no spaces should be present on either side of the `=` (unless, of course, on the edge case your SSID ends with
a space or your Location name starts with one). Additionally, do not enclose the SSID or Location in quotes.

```bash
SSID=Location
Home Wi-Fi=Home
SSID With Spaces=Location Name With Spaces
```


### Running Custom Scripts When Changing Locations

*Location Changer* includes support for running custom scripts when switching Locations. Scripts
should be:

* installed into the `SCRIPT_DIR` directory (`${HOME}/.locations/` by default)
* named identically to the Location (e.g. `Home Wi-Fi` and not `Home Wi-Fi.sh`; if using manually configured Locations, please ensure the name matches the Location and not the SSID)
* be executable


#### Examples

You may want to set your computer to require a password to unlock while at work. By creating a script that matches the work Location name (e.g. `${HOME}/.locations/Work`), this script can perform that configuration automatically when changing to the `Work` Location.

```bash
#!/usr/bin/env bash
exec 2>&1

# Require password immediately after sleep or screen saver begins
osascript -e 'tell application "System Events" to set require password to wake of security preferences to true'
```

You may also want to create a script that reverses those changes when you're at home, so you don't have to enter your password to unlock your computer. You can save this as `${HOME}/.locations/Home` if your home's SSID is `Home` or you have manually configured the `Home` Location to be used for your home's Wi-Fi SSID. Alternatively, it could be saved to your default Location (`Automatic`, by default) if using the default location at home: `${HOME}/.locations/Automatic`

```bash
#!/usr/bin/env bash
exec 2>&1

# Don’t require password immediately after sleep or screen saver begins
osascript -e 'tell application "System Events" to set require password to wake of security preferences to false'
```

### Notifications

*Location Changer* includes support for notifications through the macOS Notification system (via the AppleScript/osascript interface). By default, *Location Changer* will display a notification whenever the Location is changed. This behavior can be changed by editing the `ENABLE_NOTIFICATIONS` variable (on Line 16) in the script prior to installation. The following values are accepted:

* `0` - disable notifications
* `1` - enable notifications whenever the Location is changed
* `2` - enable notifications whenever a Wi-Fi network is joined, regardless of if the Location was changed

## Troubleshooting

Logging information is written to `${HOME}/Library/Logs/LocationChanger.log` by default. This can be adjusted by editing the `LOGFILE` variable (on Line 21) in the script prior to installation. Inspecting this log can be helpful when troubleshooting issues.

```bash
tail -f ~/Library/Logs/LocationChanger.log
```

Sample output:

```
[2018-03-05 06:23:18] Connected to 'Home Wi-Fi'
[2018-03-05 06:23:18] Will switch the Location to 'DHCP' (found in configuration file)
[2018-03-05 06:23:18] Changing the Location to 'DHCP'
CurrentSet updated to 3BA418DE-3C72-2EAB-A8A6-B71C42189204 (DHCP)
[2018-03-05 06:23:19] Running script: '/Users/username/.locations/DHCP'
```
