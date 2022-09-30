#!/bin/zsh

# Account demobilisation and AD unbind script
# Based heavily on work by Rich Trouton
# richard@richard-purves.com

# Provided as an example, used to be part of the Jamf Connect preinstall script

#
## Demobilize any user accounts on this mac and unbind from AD if required
#

# Check for AD bind
if [ "$( dsconfigad -show | grep "Active Directory Domain" | awk '{ print $5 }' )" ];
then

	# Ok we're bound to AD proceed.
	# Delete the Active Directory domain from the custom /Search and /Search/Contacts paths
    searchPath=$( /usr/bin/dscl /Search -read . CSPSearchPath | grep Active\ Directory | sed 's/^ //' )
	/usr/bin/dscl /Search/Contacts -delete . CSPSearchPath "$searchPath"
	/usr/bin/dscl /Search -delete . CSPSearchPath "$searchPath"

	# Changes the /Search and /Search/Contacts path type from Custom to Automatic
	/usr/bin/dscl /Search -change . SearchPolicy dsAttrTypeStandard:CSPSearchPath dsAttrTypeStandard:NSPSearchPath
	/usr/bin/dscl /Search/Contacts -change . SearchPolicy dsAttrTypeStandard:CSPSearchPath dsAttrTypeStandard:NSPSearchPath

	# Find all user accounts with UIDs over 1000. Likely AD accounts.
	useraccounts=($( dscl . -list /Users UniqueID | awk -F" " '$2 > 1000 { print $1 }' ))

	# let the hack work begin
	for ((loop=1;loop<=${#useraccounts[@]};loop++));
	do 
		netname="${useraccounts[$loop]}"
		accounttype=$( /usr/bin/dscl . -read /Users/"$netname" AuthenticationAuthority | head -2 | awk -F'/' '{print $2}' | tr -d '\n' )
		# Test for admin rights
		id -Gn "$netname" | grep -q -w admin
		[ "$?" = "0" ] && adminuser="admin" || adminuser="notadmin"

		# Account type
		if [[ "$accounttype" = "Active Directory" ]];
		then
			mobileusercheck=$( /usr/bin/dscl . -read /Users/"$netname" AuthenticationAuthority | head -2 | awk -F'/' '{print $1}' | tr -d '\n' | sed 's/^[^:]*: //' | sed s/\;/""/g )
			if [[ "$mobileusercheck" != "LocalCachedUser" ]];
			then
			   # Account is not a AD mobile account
			   break
			fi
		else
			# Account is not a AD mobile account
			break
		fi

		# Remove the account attributes that identify it as an Active Directory mobile account
		/usr/bin/dscl . -delete /users/$netname cached_groups
		/usr/bin/dscl . -delete /users/$netname cached_auth_policy
		/usr/bin/dscl . -delete /users/$netname CopyTimestamp
		/usr/bin/dscl . -delete /users/$netname AltSecurityIdentities
		/usr/bin/dscl . -delete /users/$netname SMBPrimaryGroupSID
		/usr/bin/dscl . -delete /users/$netname OriginalAuthenticationAuthority
		/usr/bin/dscl . -delete /users/$netname OriginalNodeName
		/usr/bin/dscl . -delete /users/$netname SMBSID
		/usr/bin/dscl . -delete /users/$netname SMBScriptPath
		/usr/bin/dscl . -delete /users/$netname SMBPasswordLastSet
		/usr/bin/dscl . -delete /users/$netname SMBGroupRID
		/usr/bin/dscl . -delete /users/$netname PrimaryNTDomain
		/usr/bin/dscl . -delete /users/$netname AppleMetaRecordName
		/usr/bin/dscl . -delete /users/$netname PrimaryNTDomain
		/usr/bin/dscl . -delete /users/$netname MCXSettings
		/usr/bin/dscl . -delete /users/$netname MCXFlags

		# Migrate password and remove AD-related attributes
		# macOS 10.14.4 will remove the the actual ShadowHashData key immediately 
		# if the AuthenticationAuthority array value which references the ShadowHash
		# is removed from the AuthenticationAuthority array. To address this, the
		# existing AuthenticationAuthority array will be modified to remove the Kerberos
		# and LocalCachedUser user values.
		AuthenticationAuthority=$( /usr/bin/dscl -plist . -read /Users/$netname AuthenticationAuthority )
		Kerberosv5=$( echo "${AuthenticationAuthority}" | xmllint --xpath 'string(//string[contains(text(),"Kerberosv5")])' - )
		LocalCachedUser=$( echo "${AuthenticationAuthority}" | xmllint --xpath 'string(//string[contains(text(),"LocalCachedUser")])' - )

		# Remove Kerberosv5 and LocalCachedUser
		if [[ ! -z "${Kerberosv5}" ]];
		then
			/usr/bin/dscl -plist . -delete /Users/$netname AuthenticationAuthority "${Kerberosv5}"
		fi
		if [[ ! -z "${LocalCachedUser}" ]];
		then
			/usr/bin/dscl -plist . -delete /Users/$netname AuthenticationAuthority "${LocalCachedUser}"
		fi

		# Refresh Directory Services
		/usr/bin/killall opendirectoryd
		sleep 20

		accounttype=$( /usr/bin/dscl . -read /Users/"$netname" AuthenticationAuthority | head -2 | awk -F'/' '{print $2}' | tr -d '\n' )
		if [[ "$accounttype" = "Active Directory" ]];
		then
			/usr/bin/printf "Something went wrong with the conversion process.\nThe $netname account is still an AD mobile account.\n"
			exit 1
		else
		   	/usr/bin/printf "Conversion process was successful.\nThe $netname account is now a local account.\n"
		fi
		homedir=$( /usr/bin/dscl . -read /Users/"$netname" NFSHomeDirectory  | awk '{print $2}' )
		if [[ "$homedir" != "" ]];
		then
			/usr/sbin/chown -R "$netname":staff "$homedir"
		fi

		# Add user to the staff group on the Mac	
		/usr/sbin/dseditgroup -o edit -a "$netname" -t user staff	
		# Auto add user to admin group if detected earlier.
		if [ "$adminuser" = "admin" ];
		then
			/usr/sbin/dseditgroup -o edit -a "$netname" -t user admin
		fi
	done

	# Finally unbind from AD.
	/usr/sbin/dsconfigad -force -remove -u serviceaccount -p 'password'
fi
