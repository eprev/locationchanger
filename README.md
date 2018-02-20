# Location Changer

It automatically changes OS X’s [network location](https://support.apple.com/en-us/HT202480)
based on the name of Wi-Fi network and runs arbitrary scrips when it happens.

## Installation & Update

```
curl -L https://github.com/eprev/locationchanger/raw/master/locationchanger.sh | bash
```

It will ask you for a root password to install `locationchanger` to the */usr/local/bin* directory.

## Basic usage

You have to name network locations after Wi-Fi networks. Let’s say, you need to have
a specific network preferences for “Corp Wi-Fi” wireless network, then you have to create
a location “Corp Wi-Fi”. Now, the network location will change to “Corp Wi-Fi” automatically,
if you connect to that wireless network. And if you connect to the Wi-Fi network that you
don’t have a location for, then the location will change to the default one (“Automatic”).

If you want to run a script every time you connect to a specific Wi-Fi network, then put
those scripts in *~/.locations* and name them after Wi-Fi networks. For instance, you have
a script that changes security preferences when you connect to the “Corp Wi-Fi” network:

```bash
#!/usr/bin/env bash
exec 2>&1

# Require password immediately after sleep or screen saver begins
osascript -e 'tell application "System Events" to set require password to wake of security preferences to true'
```

Then name this script as *~/.locations/Corp Wi-Fi*. And you might want to create
*~/.locations/Automatic* that will reset those changes:

```bash
#!/usr/bin/env bash
exec 2>&1

# Don’t require password immediately after sleep or screen saver begins
osascript -e 'tell application "System Events" to set require password to wake of security preferences to false'
```

## Aliasing

If you want to share one network location between different wireless networks (for instance, you have a wireless router which broadcasts on 2.4 and 5GHz bands simultaneously), then you can create a configuration file *~/.locations/locations.conf* (plain text file with simple key-value pairs, no spaces in between):

```bash
Wi-Fi_5GHz=Wi-Fi
```

Where the keys are the wireless network names and the values are the desired location names.

## Troubleshooting

It writes quite extensive information to the log file every time the wireless network changes:

```bash
tail -f ~/Library/Logs/LocationChanger.log
```

Sample output:

```
Connected to 'Wi-Fi_5GHz'
Will switch the location to 'Wi-Fi' (configuration file)
Changing the location to 'Wi-Fi'
Running '~/.locations/Wi-Fi'
```
