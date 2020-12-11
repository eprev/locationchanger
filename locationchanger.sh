#!/bin/bash

INSTALL_DIR=/usr/local/bin
SCRIPT_NAME=$INSTALL_DIR/locationchanger
LAUNCH_AGENTS_DIR=$HOME/Library/LaunchAgents
PLIST_NAME=$LAUNCH_AGENTS_DIR/LocationChanger.plist

sudo -v

sudo mkdir -p $INSTALL_DIR
cat << "EOT" | sudo tee $SCRIPT_NAME > /dev/null
#!/bin/bash

# This script changes network location based on the name of Wi-Fi network.

exec 2>&1 >> $HOME/Library/Logs/LocationChanger.log

sleep 3

ts() {
    date +"[%Y-%m-%d %H:%M] $*"
}

ID=`whoami`
ts "I am '$ID'"

SSID=`/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep ' SSID' | cut -d : -f 2- | sed 's/^[ ]*//'`

LOCATION_NAMES=`scselect | tail -n +2 | cut -d \( -f 2- | sed 's/)$//'`
CURRENT_LOCATION=`scselect | tail -n +2 | egrep '^\ +\*' | cut -d \( -f 2- | sed 's/)$//'`

ts "Connected to '$SSID'"

CONFIG_FILE=$HOME/.locations/locations.conf
ts "Probing '$CONFIG_FILE'"

if [ -f $CONFIG_FILE ]; then
    ts "Reading to '$CONFIG_FILE'"
    ESSID=`echo "$SSID" | sed 's/[.[\*^$]/\\\\&/g'`
    NEW_SSID=`grep "^$ESSID=" $CONFIG_FILE | cut -d = -f 2`
    if [ "$NEW_SSID" != "" ]; then
        ts "Will switch the location to '$NEW_SSID' (configuration file)"
        SSID=$NEW_SSID
    else
        ts "Will switch the location to '$SSID'"
    fi
fi

ESSID=`echo "$SSID" | sed 's/[.[\*^$]/\\\\&/g'`
if echo "$LOCATION_NAMES" | grep -q "^$ESSID$"; then
    NEW_LOCATION="$SSID"
else
    if echo "$LOCATION_NAMES" | grep -q "^Automatic$"; then
        NEW_LOCATION=Automatic
        ts "Location '$SSID' was not found. Will default to 'Automatic'"
    else
        ts "Location '$SSID' was not found. The following locations are available: $LOCATION_NAMES"
        exit 1
    fi
fi

if [ "$NEW_LOCATION" != "" ]; then
    if [ "$NEW_LOCATION" != "$CURRENT_LOCATION" ]; then
        ts "Changing the location to '$NEW_LOCATION'"
        scselect "$NEW_LOCATION"
        SCRIPT="$HOME/.locations/$NEW_LOCATION"
        if [ -f "$SCRIPT" ]; then
            ts "Running '$SCRIPT'"
            "$SCRIPT"
        fi
    else
        ts "Already at '$NEW_LOCATION'"
    fi
fi
EOT

sudo chmod +x $SCRIPT_NAME

mkdir -p $LAUNCH_AGENTS_DIR
cat > $PLIST_NAME << EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.eprev.locationchanger</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/locationchanger</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOT

launchctl load $PLIST_NAME
