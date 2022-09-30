#!/bin/zsh

# Preinstallation script for installing DEP Notify
# richard@richard-purves.com

# Version 1.1 - 02-28-2022

# We're deploying some branding graphics so let's make sure the folders exist for them to go into!
[ ! -d "/path/to/branding" ] && mkdir /path/to/branding

# Now let's make sure the ownership and permissions are correct
chown -R root:wheel /path/to/branding
chmod -R 755 /path/to/branding