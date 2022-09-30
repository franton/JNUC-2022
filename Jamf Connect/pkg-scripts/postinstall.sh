#!/bin/zsh

# Install script for installing Jamf Connect
# richard@richard-purves.com

# Full paths on all commands because PATH may not be set, or set correctly.

# Logging output to a file for later diagnostics
#time=$( date "+%d%m%y-%H%M" )
#set -x
#logfile=/Users/Shared/jc2postinstall-"$time".log
#exec > $logfile 2>&1

# Install Jamf Connect
/usr/sbin/installer -pkg "/private/tmp/JamfConnect.pkg" -target "$3"
/bin/rm -rf "/private/tmp/JamfConnect.pkg"

# Install Jamf Connect LaunchAgent
/usr/sbin/installer -pkg "/private/tmp/JamfConnectLaunchAgent.pkg" -target "$3"
/bin/rm -rf "/private/tmp/JamfConnectLaunchAgent.pkg"

exit