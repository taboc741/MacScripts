#!/bin/sh
##  SoftwareUpdate4.sh
##  Created by Chris on 5/31/18. Last edited by Chris 2/8/2019
##### Special thanks to mm2270, cstout, nvandam from JamfNation for helping me with some testing and code suggestions to problems I couldn't solve on my own.#####

######### Create settings for logging and create log file #########
## Path to Log file. Map your Own Log Path.  Do not use /tmp as it is emptied on boot.
LogPath=/Library/Logs/YourOrg
##Verify LogPath exists
if [ ! -d "$LogPath" ]; then
    mkdir $LogPath
fi
## Set log file and console to recieve output of commands
Log_File="$LogPath/SoftwareUpdateScript.log"
function sendToLog ()
{

echo "$(date +"%Y-%b-%d %T") : $1" | tee -a "$Log_File"

}
## begin log file
sendToLog "Script Started"
######### Set variables for the script ############
icon=/Library/Application\ Support/YourOrg/AppleSoftwareUpdate.png
## Determine OS version
OSVersion=`sw_vers -productVersion`
## Get the currently logged in user, if any.
LoggedInUser=`who | grep console | awk '{print $1}'`
## Check for updates that require a restart and ones that do not.
updates=`softwareupdate -l`
sendToLog "updates that were found were: $updates"
updatesNoRestart=`echo $updates | grep recommended | grep -v restart`
[[ -z $updatesNoRestart ]] && updatesNoRestart="none"
restartRequired=`echo $updates | grep restart | grep -v '\*' | cut -d , -f 1`
[[ -z $restartRequired ]] && restartRequired="none"
shutDownRequired=`echo $updates | grep shutdown | grep -v '\*' | cut -d , -f 1`
[[ -z $shutDownRequired ]] && shutDownRequired="none"

################ End Variable Set ################
sendToLog "OS version is $OSVersion"
sendToLog "Logged in user is $LoggedInUser"

## If there are no system updates, quit
if [[ $updatesNoRestart = "none" && $restartRequired = "none" && $shutDownRequired = "none" ]]; then
    sendToLog "No updates at this time, updating Jamf inventory"
    jamf policy -trigger recon
    sendToLog "Inventory update complete, script exit."
    exit 0
fi
######### If we get to this point and beyond, there are updates. #########
sendToLog "Updates found."
## Download all updates before trying to install them to make a smoother user experiance.
title='Software Update Required'
heading='Software updates'
description='Downloading the required Software updates. This prompt will change when it is time to install them. It is safe to continue using the mac while this happens.'
button1="Ok"
##prompt the user
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -lockHUD > /dev/null 2>&1 &
softwareupdate --download --all --force --no-scan
killall jamfHelper
##Map some variables to pretty up the command to prompt the user
title='Software Update Required'
heading='Required Software update'
description='The Apple Updates are ready to install. Please press start.'
button1="Start Updates"
##prompt the user
prompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -timeout 14400 -countdown -lockHUD`
sendToLog "prompt equaled $prompt. 0=start 1=failed to prompt 2=canceled 239=exited"
softwareupdate --install --all --force && sendToLog "Updates Applied"
if [[ $restartRequired = "none" && $shutDownRequired = "none" ]]; then
    sendToLog "no reboot required, exiting"
    sendToLog "Script exit"
    exit 0
fi
######### If we get to this point a reboot is required #########

if [[ $restartRequired != "none" || $shutDownRequired != "none" ]]; then
	##Map some variables to pretty up the command to prompt the user
	title='Software Update Required'
	heading='Required Software update'
	description='A reboot is required to apply the OS updates to your Mac.  Please close all open applications before restarting your mac.'
	button1="Reboot"
    prompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -timeout 21600 -countdown -lockHUD`
    sendToLog "prompt equaled $prompt."
    sendToLog "placing reboot message"
	##Map some variables to pretty up the command to prompt the user
	title='Software Update Required'
	heading='Required Mac OS update'
	description='We are now updating your Mac System software. These updates should not take longer than 30 to 45 minutes depending on how many updates your Mac needs. If you see this screen for more than 45 minutes please call Service Desk. Your machine may reboot or shutdown.  Please do not manually turn off this computer. This message will go away when updates are complete.'
	button1="Reboot"
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -heading "$heading" -description "$description" -icon "$icon" > /dev/null 2>&1 &
fi
if [[ $shutDownRequired != "none" ]]; then
    sendToLog "Starting softwareupdate --install --all --restart --force --no-scan"
    sendToLog `softwareupdate --install --all --restart --force --no-scan` & exit 0
else
    sendToLog "starting reboot"
    ## using the Jamf restart process because it increases the odds of Jamf receiveing the logs back from the completed policy.
    jamf reboot -minutes 1 -background -startTimerImmediately & sendToLog "Script exit"
    exit 0
fi
