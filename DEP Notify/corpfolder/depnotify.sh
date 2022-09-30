#!/bin/zsh

# My DEP Notify zero touch "sanitised" script
# richard@richard-purves.com

# Version 3.6 - 09-29-2022

# Logging output to a file for testing
# Uncomment the following lines to enable for testing purposes
#time=$( date "+%d%m%y-%H%M" )
#set -x
#logfile=/Users/Shared/depnotify-"$time".log
#exec > $logfile 2>&1

# Set variables here
ld="/Library/LaunchDaemons/com.jamfsoftware.task.1.plist"
branding="/path/to/branding"
workfolder="/path/to/hiddenfolder"
deploc=$( /usr/bin/find /Applications -maxdepth 2 -type d -iname "*DEP*.app" )

# Which OS is this running on?
majver=$( /usr/bin/sw_vers -productVersion | /usr/bin/cut -d "." -f1 )
minver=$( /usr/bin/sw_vers -productVersion | /usr/bin/cut -d "." -f2 )

# Caffeinate the mac
/usr/bin/caffeinate -d -i -m -u &
caffeinatepid=$!

# Wait for enrollment then disable Jamf Check-In
while [ ! -f "$ld" ]; do sleep 0.1; done
/bin/launchctl bootout system "$ld"

# Check to see if we're in a user context or not. Wait if not.
while ! /usr/bin/pgrep -xq Dock; do /bin/sleep 0.1; done

# Who's the current user and their details?
currentuser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
userid=$( /usr/bin/id -u $currentuser )
userhome=$( /usr/bin/dscl . read /Users/${currentuser} NFSHomeDirectory | /usr/bin/awk '{print $NF}' )
userkeychain="${userhome}/Library/Keychains/login.keychain-db"

# Work out some machine details for the Applescript prompts at the end
osa=$( /usr/bin/which osascript )
bootvolname=$( /usr/sbin/diskutil info / | /usr/bin/awk '/Volume Name:/ { print substr($0, index($0,$3)) ; }' )

# Create the depnotify log file
/usr/bin/touch /var/tmp/depnotify.log
/bin/chmod 777 /var/tmp/depnotify.log

# Set up the initial DEP Notify window
/bin/echo "Command: Image: ${branding}/trr-logo.png" >> /var/tmp/depnotify.log
/bin/echo "Command: WindowStyle: NotMovable" >> /var/tmp/depnotify.log
/bin/echo "Command: WindowTitle: Corp Deployment" >> /var/tmp/depnotify.log
/bin/echo "Command: MainTitle: Mac Deployment" >> /var/tmp/depnotify.log

# Load DEP Notify
/bin/launchctl asuser $userid "$deploc/Contents/MacOS/DEPNotify" -jamf -fullScreen &

# Wait for Jamf binary to deploy
while [ ! -f "/usr/local/bin/jamf" ]; do sleep 0.1; done

# Check to see if we can talk to the Jamf server
jsstest=$( /usr/local/bin/jamf checkJSSConnection > /dev/null; echo $? )
while [ "$jsstest" != "0" ]; do jsstest=$( /usr/local/bin/jamf checkJSSConnection >/dev/null; echo $? ); sleep 0.1; done

# Kill any check-in in progress
jamfpid=$( /bin/ps -ax | /usr/bin/grep "jamf policy -randomDelaySeconds" | /usr/bin/grep -v "grep" | /usr/bin/awk '{ print $1 }' )
if [ "$jamfpid" != "" ];
then
	kill -9 "$jamfpid"
fi

# Grab the information we require for the jamf inventory record

# Get current user details from Jamf Connect and put them in Jamf inventory record
/bin/echo "Status: Setting Jamf User Details" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Configuring Jamf computer record with user details. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/user.png" >> /var/tmp/depnotify.log
/usr/local/bin/jamf policy -event getusername
/bin/sleep 4

# Set computer name via auto script in Jamf
/bin/echo "Status: Setting Computer Name" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Automatically setting the computer hostname. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/hostname.png" >> /var/tmp/depnotify.log
/usr/local/bin/jamf policy -event autoname
/bin/sleep 4

# Start the software deployment
/bin/echo "Status: Starting Deployment" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Starting software deployment.\n\nThis process can take some time to complete." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/deploy.png" >> /var/tmp/depnotify.log
/usr/local/bin/jamf policy -event deploy
/bin/sleep 4

# Run a Recon
/bin/echo "Status: Running Inventory Update" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Performing an inventory of the device. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/inventory.png" >> /var/tmp/depnotify.log
/usr/local/bin/jamf recon
/bin/sleep 4

# Now force a checkin for other policies
/bin/echo "Status: Running Periodic Check-In" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Running system checks. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/checks.png" >> /var/tmp/depnotify.log
/usr/local/bin/jamf policy
/bin/sleep 4

# Run a Recon
/bin/echo "Status: Running Inventory Update" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Performing an inventory of the device. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/inventory.png" >> /var/tmp/depnotify.log

# Create a touch file to say we're done
/usr/bin/touch ${workfolder}/.deploycomplete
/usr/local/bin/jamf recon
/bin/sleep 4

# Confirm that the Corp wifi profile has been deployed
/bin/echo "Status: Installing WiFi Profile" >> /var/tmp/depnotify.log
/bin/echo "Command: MainText: Installing Corp WiFi to your device. Please wait." >> /var/tmp/depnotify.log
/bin/echo "Command: MainTextImage: ${branding}/wifi.png" >> /var/tmp/depnotify.log
while [ $( /usr/bin/profiles list -type configuration | /usr/bin/grep -c "UUID of profile goes here") != "1" ]; do sleep 1; done

# Re-enable Jamf check-in
/bin/launchctl bootstrap system "$ld"

# Jamf Manage (to be safe)
/usr/local/bin/jamf manage

# All done with DEPNotify, so order it to quit
/bin/echo "Command: Quit" >> /var/tmp/depnotify.log

# If using deployment wifi then disconnect to force attachment to deployed SSID profile
ssid=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -I \
		| /usr/bin/grep "SSID: " \
		| /usr/bin/tail -n1 \
		| /usr/bin/cut -d" " -f13- )

wfi_name=$( /usr/sbin/networksetup -listnetworkserviceorder \
			| /usr/bin/sed -En 's/^\(Hardware Port: (Wi-Fi|AirPort), Device: (en.)\)$/\2/p' )

# Remove the deploy SSID from the macOS preferred network list
/usr/sbin/networksetup -removepreferredwirelessnetwork "$wfi_name" Deploy

# Now remove all the cached passwords that might be in the system keychain
/usr/bin/security delete-generic-password -l "Deploy" "/Library/Keychains/System.keychain"

# Once more with feeling for the user keychains
/usr/bin/security delete-generic-password -l "Deploy" "$userkeychain"

# Disassociate from any wifi other than the Corporate one
if [ "$ssid" != "Corporate" ];
then
	/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -z
	/usr/sbin/networksetup -setairportpower "$wfi_name" off
	/bin/sleep 2
	/usr/sbin/networksetup -setairportpower "$wfi_name" on
fi

# Find Bomgar icon
icon=$( /usr/bin/find /Applications/.com.bomgar* -iname "appicon.icns" -type f )
iconposix=$( echo $icon | /usr/bin/sed 's/\//:/g' )
iconposix="$bootvolname$iconposix"

/bin/launchctl asuser "$userid" "$osa" -e 'display dialog "Mac Deployment Completed\n\nPlease open System Settings and\nallow Screen Recording access to:\n\nRemote Support Customer Client\n\nOnce enabled, click on OK to finish." with icon file "'"$iconposix"'" giving up after 1200 with title "Deployment Complete" buttons {"OK"} default button 1'

# Force Jamf Connect menu agent to run
/bin/launchctl bootstrap gui/$userid /Library/LaunchAgents/com.jamf.connect.plist

# All done! Delete temporary files, launchdaemons.
/bin/rm /Library/LaunchDaemons/com.corp.depnotify.plist
/bin/rm -rf "$deploc"
/bin/rm /var/tmp/depnotify.log
/bin/rm -rf "${branding}/deployimgs"

# No more caffeinate, I have a headache.
/bin/kill "$caffeinatepid"

# Clean up script and exit
/bin/rm $0
