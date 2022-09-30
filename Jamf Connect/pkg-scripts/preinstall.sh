#!/bin/zsh

# Preinstallation script for installing Jamf Connect 2.x
# richard@richard-purves.com

# We're deploying some branding graphics so let's make sure the folders exist for them to go into!
[ ! -d "/path/to/imgs" ] && mkdir -p /path/to/imgs

# Clean out any existing graphics before we replace them
find /path/to/imgs -iname "*.png" -type f -exec rm {} \;

# Now let's make sure the ownership and permissions are correct
chown -R root:wheel /path/to/
chmod -R 755 /path/to/

exit 0