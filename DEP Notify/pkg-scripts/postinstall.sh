#!/bin/zsh

# Post installation script for installing DEP Notify
# richard@richard-purves.com - 10/08/2022

# Find the LaunchDaemon
ld=$( find /Library/LaunchDaemons -iname "*depnotify*.plist" -type f -maxdepth 1 )

# Check for OS version. Undo if not supported.
majver=$( /usr/bin/sw_vers -productVersion | /usr/bin/cut -d"." -f1 )

# For some reason best known to Apple, our files occasionally have quarantine attributes set. Fix this.
/usr/bin/xattr -r -d com.apple.quarantine /path/to/hiddenfolder
/usr/bin/xattr -r -d com.apple.quarantine $ld
/usr/bin/xattr -r -d com.apple.quarantine /Applications/DEPNotify.app

# Look for a user
loggedinuser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )

# If loginwindow, setup assistant or no user, then we're in a DEP environment. Load the LaunchDaemon.
if [[ "$loggedinuser" = "loginwindow" ]] || [[ "$loggedinuser" = "_mbsetupuser" ]] || [[ -z "$loggedinuser" ]];
then
	/bin/launchctl bootstrap system "$ld"
fi

# User initiated enrollment devices excluded. We'll pick them up after a restart via Jamf.

exit