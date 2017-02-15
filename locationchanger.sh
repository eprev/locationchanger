#!/bin/bash

INSTALL_DIR=/usr/local/bin
SCRIPT_NAME=$INSTALL_DIR/locationchanger
PLIST_NAME=$HOME/Library/LaunchAgents/LocationChanger.plist

sudo -v

mkdir -p $INSTALL_DIR
cat > $SCRIPT_NAME << "EOT"
#!/bin/bash

# This script changes network location based on the name of Wi-Fi network.

exec 2>&1 >> $HOME/Library/Logs/LocationChanger.log

sleep 3

ts() {
    date +"[%Y-%m-%d %H:%M] $*"
}

SSID_FULL=`/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep ' SSID' | awk '{print $2}'`
SSID=${SSID_FULL%_5GHz}

LOCATION_NAMES=`scselect | tail -n +2 | awk '{print ($1 == "*") ? $3 : $2}' | sed 's/[()]//g'`
CURRENT_LOCATION=`scselect | tail -n +2 | awk '{if ($1 == "*") print $3}' | sed 's/[()]//g'`

ts "Connected to '$SSID'"

CONFIG_FILE=$HOME/.locations/locations.conf

if [ -f $CONFIG_FILE ]; then
    NEW_SSID=`egrep "^$SSID=" $CONFIG_FILE | cut -d = -f 2`
    if [ "$NEW_SSID" != "" ]; then
        ts "Will switch the location to '$NEW_SSID' (configuration file)"
        SSID=$NEW_SSID
    else
        ts "Will switch the location to '$SSID'"
    fi
fi

if echo "$LOCATION_NAMES" | egrep -q "^$SSID$"; then
    NEW_LOCATION="$SSID"
else
    if echo "$LOCATION_NAMES" | egrep -q "^Automatic$"; then
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
        if [ -f $SCRIPT ]; then
            ts "Running '$SCRIPT'"
            $SCRIPT
        fi
    else
        ts "Already at '$NEW_LOCATION'"
    fi
fi
EOT

chmod +x $SCRIPT_NAME

cat > $PLIST_NAME << EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>locationchanger</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/locationchanger</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist</string>
    </array>
</dict>
</plist>
EOT

launchctl load $PLIST_NAME
