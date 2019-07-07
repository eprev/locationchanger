#!/bin/bash

INSTALL_DIR=/usr/local/bin
SCRIPT_NAME=$INSTALL_DIR/locationchanger
LAUNCH_AGENTS_DIR=$HOME/Library/LaunchAgents
PLIST_NAME=$LAUNCH_AGENTS_DIR/LocationChanger.plist

sudo -v

sudo mkdir -p ${INSTALL_DIR}
cat << "EOT" | sudo tee ${SCRIPT_NAME} > /dev/null
#!/bin/bash

# This script changes network Location based on the name of Wi-Fi network.
DEFAULT_LOCATION='Automatic'
ENABLE_NOTIFICATIONS=1
CONFIG_FILE="$HOME/Library/Application Support/LocationChanger/LocationChanger.conf"
SCRIPT_DIR="$HOME/Library/Application Support/LocationChanger" # directory for scripts attached to Locations
LOGFILE=${HOME}/Library/Logs/LocationChanger.log

# truncate logfile
lines=$(cat "$LOGFILE" | wc -l)
if [ $lines -gt 300 ]; then
    temp=$(mktemp)
    tail -n +200 "$LOGFILE" > "$temp"
    rm "$LOGFILE"
    mv "$temp" "$LOGFILE"
fi

exec 2>&1 >> ${LOGFILE}

sleep 3

ts() {
    date +"[%Y-%m-%d %H:%M:%S] ${*}"
}

parse_config() {
    local myresult=$(sed -e 's/[[:space:]]*=[[:space:]]*/=/g'           \
                                                 -e 's/[;#].*$//'       \
                                                 -e 's/[[:space:]]*$//' \
                                                 -e 's/^[[:space:]]*//' \
                                         <  "${CONFIG_FILE}"              \
                                         | sed  -n -e "/^\[$1\]/,/^s*\[/{/^[^;[]/p;}")
    echo "${myresult}"
}

# get the SSID of the current Wi-Fi network
SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep ' SSID' | cut -d : -f 2- | sed 's/^[ ]*//')

# get the currently selected Location
CURRENT_LOCATION=$(scselect | tail -n +2 | egrep '^\ +\*' | cut -d \( -f 2- | sed 's/)$//')

if [ -z "${SSID}" ]; then
    ts "No active Wi-Fi network in the current location '${CURRENT_LOCATION}' found; not changing"
    exit 1
fi

ts "Connected to '${SSID}'"

# read some default variables from config file, if they exist
if [ -e "${CONFIG_FILE}" ]; then
    VALUE=$(parse_config General | grep ENABLE_NOTIFICATIONS= | cut -d = -f 2)
    if [ "$VALUE" != "" ]; then
        ENABLE_NOTIFICATIONS=$VALUE
    fi
    VALUE=$(parse_config General | grep DEFAULT_LOCATION= | cut -d = -f 2)
    if [ "$VALUE" != "" ]; then
        DEFAULT_LOCATION="$VALUE"
    fi
fi

# escape the SSID string for better string handling in our logic below
ESSID=$(echo "${SSID}" | sed 's/[.[\*^$]/\\\\&/g')

# if a config file exists, consult it first
if [ -f "${CONFIG_FILE}" ]; then
    # check if the current location is marked as manual (no autodetection required)
    if echo "$(parse_config Manual)" | grep -q "^${CURRENT_LOCATION}$" ; then
        NEW_LOCATION=${CURRENT_LOCATION}
        NOTIFICATION_STRING="Current Location is defined as manual and will not be changed automatically"
        ts "Current Location '${CURRENT_LOCATION}' is configured as manual and will not be changed"
    else
        CONFIG_LOCATION=$(echo "$(parse_config Automatic)" | grep "^${ESSID}=" | cut -d = -f 2)
        if [ "${CONFIG_LOCATION}" != "" ]; then
            NEW_LOCATION=${CONFIG_LOCATION}
            NOTIFICATION_STRING="SSID '${SSID}' has a configured Location; changing from '${CURRENT_LOCATION}' to '${NEW_LOCATION}'"
            ts "Will switch the Location to '${NEW_LOCATION}' (found in configuration file)"
        fi
    fi
fi


# get a list of Locations configured on this machine
LOCATION_NAMES=$(scselect | tail -n +2 | cut -d \( -f 2- | sed 's/)$//')


# if not found in the config file, check if there's a Location that matches the SSID
if [ -z "${NEW_LOCATION}"] && echo "${LOCATION_NAMES}" | grep -q "^${ESSID}$"; then
    NEW_LOCATION="${SSID}"
    NOTIFICATION_STRING="Changing from '${CURRENT_LOCATION}' to '${NEW_LOCATION}', as the Location name matches the SSID"
    ts "Location '${SSID}' was found and matches the SSID. Will switch the Location to '${NEW_LOCATION}'"
# if still not found, try to use the DEFAULT_LOCATION
elif [ -z "${NEW_LOCATION}"] && echo "${LOCATION_NAMES}" | grep -q "^${DEFAULT_LOCATION}$"; then
    NEW_LOCATION="${DEFAULT_LOCATION}"
    NOTIFICATION_STRING="Changing from '${CURRENT_LOCATION}' to default Location '${DEFAULT_LOCATION}'"
    ts "Location '${SSID}' was not found. Will default to '${DEFAULT_LOCATION}'"
# if we arrived here, something went awry
elif [ -z "${NEW_LOCATION}" ]; then
    NOTIFICATION_STRING="Something went wrong trying to automatically switch Locations. Please consult the log at: ${LOGFILE}"
    ts "Location '${SSID}' and default Location ${DEFAULT_LOCATION} were not found. The following Locations are available:%n${LOCATION_NAMES}"
    exit 1
fi

if [ "${NEW_LOCATION}" != "" ]; then
    if [ "${NEW_LOCATION}" != "${CURRENT_LOCATION}" ]; then
        ts "Changing the Location to '${NEW_LOCATION}'"
        ts $(scselect "${NEW_LOCATION}")
        if [ ${?} -ne 0 ]; then
            NOTIFICATION_STRING="Something went wrong trying to automatically switch Location. Please consult the log at: ${LOGFILE}"
        fi
        SCRIPT="${SCRIPT_DIR}/${NEW_LOCATION}"
        if [ -f "${SCRIPT}" ]; then
            ts "Running script: '${SCRIPT}'"
            $(${SCRIPT})
        fi
    else
        ts "System is already set to the requested Location '${NEW_LOCATION}'. No change required."
        # only notify on this event if verbose notifications are enabled
        if [ ${ENABLE_NOTIFICATIONS} -eq 2 ]; then
            NOTIFICATION_STRING="Location already set to '${NEW_LOCATION}'; not changing"
        # otherwise, disable the notification for this run
        elif [ ${ENABLE_NOTIFICATIONS} -eq 1 ]; then
            ENABLE_NOTIFICATIONS=0
        fi
    fi
fi

# if notifications are enabled, let 'em know what's happenin'!
if [ ${ENABLE_NOTIFICATIONS} -ge 1 ]; then
    osascript -e "display notification \"${NOTIFICATION_STRING}\" with title \"LocationChanger\""
fi

exit 0
EOT

sudo chmod +x ${SCRIPT_NAME}

# generate a default config file if it doesn't exists
APP_SUPPORT_DIR="$HOME/Library/Application Support/LocationChanger"
if [ ! -e "${APP_SUPPORT_DIR}/LocationChanger.conf" ]; then
mkdir -p "${APP_SUPPORT_DIR}"
cat > "$APP_SUPPORT_DIR/LocationChanger.conf" << EOT
[General]
# specify the default Location to use. The default is 'Automatic'
#DEFAULT_LOCATION=Automatic
# To enable notifications, set to 1. For verbose notifications, set to 2. To disable, set to 0.
#ENABLE_NOTIFICATIONS=1

[Automatic]
# [Automatic] defines a mapping for Wi-Fi Network SSIDs to Location names as key-value pairs.
# Spaces are supported for both the SSID as well as the Location name, but all spaces
# around the '=' will be trimmed. Additionally, do not enclose the SSID or Location in quotes
# SSID=Location name

[Manual]
# This section contains a list of Location names for which autodetection and Location
# switching should be ignored.
# Wi-Fi Only

EOT
fi

mkdir -p ${LAUNCH_AGENTS_DIR}
cat > ${PLIST_NAME} << EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>locationchanger</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPT_NAME}</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist</string>
    </array>
</dict>
</plist>
EOT

launchctl load ${PLIST_NAME}
