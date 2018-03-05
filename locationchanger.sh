#!/bin/bash

INSTALL_DIR=/usr/local/bin # if you change this, you must also edit Line 115 below
SCRIPT_NAME=$INSTALL_DIR/locationchanger
LAUNCH_AGENTS_DIR=$HOME/Library/LaunchAgents
PLIST_NAME=$LAUNCH_AGENTS_DIR/LocationChanger.plist

sudo -v

sudo mkdir -p ${INSTALL_DIR}
cat << "EOT" | sudo tee ${SCRIPT_NAME} > /dev/null
#!/bin/bash

# This script changes network Location based on the name of Wi-Fi network.
DEFAULT_LOCATION='Automatic'
ENABLE_NOTIFICATIONS=1 # To enable notifications, set to 1. For verbose notifications, set to 2. To disable, set to 0.
CONFIG_FILE=${HOME}/.locations/locations.conf
SCRIPT_DIR=${HOME}/.locations # directory for scripts attached to Locations
LOGFILE=${HOME}/Library/Logs/LocationChanger.log

exec 2>&1 >> ${LOGFILE}

sleep 3

ts() {
    date +"[%Y-%m-%d %H:%M:%S] ${*}"
}

# get the SSID of the current Wi-Fi network
SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep ' SSID' | cut -d : -f 2- | sed 's/^[ ]*//')

# escape the SSID string for better string handling in our logic below
ESSID=$(echo "${SSID}" | sed 's/[.[\*^$]/\\\\&/g')

# get a list of Locations configured on this machine
LOCATION_NAMES=$(scselect | tail -n +2 | cut -d \( -f 2- | sed 's/)$//')

# get the currently selected Location
CURRENT_LOCATION=$(scselect | tail -n +2 | egrep '^\ +\*' | cut -d \( -f 2- | sed 's/)$//')


ts "Connected to '${SSID}'"

# if a config file exists, consult it first
if [ -f ${CONFIG_FILE} ]; then
    CONFIG_LOCATION=$(grep "^${ESSID}=" ${CONFIG_FILE} | cut -d = -f 2)
    if [ "${CONFIG_LOCATION}" != "" ]; then
        NEW_LOCATION=${CONFIG_LOCATION}
        NOTIFICATION_STRING="SSID '${SSID}' has a manually configured Location; changing from '${CURRENT_LOCATION}' to '${NEW_LOCATION}'"
        ts "Will switch the Location to '${NEW_LOCATION}' (found in configuration file)"
    fi
fi

# if not found in the config file, check if there's a Location that matches the SSID
if echo "${LOCATION_NAMES}" | grep -q "^${ESSID}$" && [ -z "${NEW_LOCATION}" ]; then
    NEW_LOCATION="${SSID}"
    NOTIFICATION_STRING="Changing from '${CURRENT_LOCATION}' to '${NEW_LOCATION}', as the Location name matches the SSID"
    ts "Location '${SSID}' was found and matches the SSID. Will switch the Location to '${NEW_LOCATION}'"
# if still not found, try to use the DEFAULT_LOCATION
elif echo "${LOCATION_NAMES}" | grep -q "^${DEFAULT_LOCATION}$" && [ -z "${NEW_LOCATION}" ]; then
    NEW_LOCATION=${DEFAULT_LOCATION}
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
        scselect "${NEW_LOCATION}"
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
    osascript -e "display notification \"${NOTIFICATION_STRING}\" with title \"locationchanger\""
fi

exit 0
EOT

sudo chmod +x ${SCRIPT_NAME}

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
        <string>/usr/local/bin/locationchanger</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist</string>
    </array>
</dict>
</plist>
EOT

launchctl load ${PLIST_NAME}
