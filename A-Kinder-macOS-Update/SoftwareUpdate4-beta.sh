#!/bin/sh
##  SoftwareUpdate4-beta.sh
##  Created by Chris on 5/31/18. Last edited by Chris 12/20/2020
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
updatesNoRestart=`echo $updates | grep recommended | grep -v restart`
[[ -z $updatesNoRestart ]] && updatesNoRestart="none"
restartRequired=`echo $updates | grep restart | grep -v '\*' | cut -d , -f 1`
[[ -z $restartRequired ]] && restartRequired="none"

################ End Variable Set ################
sendToLog "OS version is $OSVersion"
sendToLog "Logged in user is $LoggedInUser"
##Check to make sure $icon path is real
if [ ! -e "$icon" ]; then
	icon="/System/Library/CoreServices/Install Command Line Developer Tools.app/Contents/Resources/SoftwareUpdate.icns"
fi
## If there are no system updates, quit
if [[ $updatesNoRestart = "none" && $restartRequired = "none" ]]; then
    sendToLog "No updates at this time, updating Jamf inventory"
    jamf recon
    sendToLog "Inventory update complete, script exit."
    exit 0
fi
######### If we get to this point and beyond, there are updates. #########
sendToLog "Updates found."
## Download all updates before trying to install them to make a smoother user experiance.
title='Software Update Required'
heading='Software updates'
description='Downloading and installing the required Apple updates. It is safe to continue using the mac while this happens.'
button1="Ok"
##prompt the user
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -lockHUD > /dev/null 2>&1 &
softwareupdate --download --all --force --no-scan

##Install updates now that they are downloaded.
##trap the output of the softwareupdate command to a variable to be grepped for the words Shut Down
sendToLog "Attempting to install updates"
appliedUpdates=`softwareupdate --install --all --force && sendToLog "Updates Applied"`
##write to log the output for further debugging if required.
sendToLog "$appliedUpdates"
##parse $appliedUpdates looking for shut down
shutDownRequired=`echo $appliedUpdates | grep "shut down" | grep -v '\*' | cut -d , -f 1`
[[ -z $shutDownRequired ]] && shutDownRequired="none"
killall jamfHelper

######### Check if any restart is required and if not exit the update script #########
if [[ $restartRequired = "none" && $shutDownRequired = "none" ]]; then
    sendToLog "no reboot required, alerting user updates are complete"
	##Map some variables to pretty up the command to prompt the user
	title='Software Update'
	heading='Software update'
	description='The Apple updates have been successfully installed. No reboot is required.  Thank you for your time.'
	button1="Ok"
	##prompt the user
	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -timeout 14400 -countdown -lockHUD > /dev/null 2>&1 &
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
	description='Your Mac is now updating your Apple software. These updates should not take longer than 30 to 45 minutes depending on how many updates your Mac needs. If you see this screen for more than 45 minutes please call Service Desk. Your machine may reboot or shutdown.  Please do not manually turn off this computer. This message will go away when updates are complete.'
	button1="Reboot"
    ##This jamfHelper window will persist after the script exits intentionally so users will be less confused about what is going on.
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -heading "$heading" -description "$description" -icon "$icon" > /dev/null 2>&1 &
fi
##Trigger reboot by using the softwareupate --restart flag.  This may result in the reboot happening faster than jamf can exit the script and logs be uploaded to Jamf.  The --restart flag will correctly reboot regardless of if a shutdown for T2 update or a regular reboot is required.
sendToLog "Reboot is required. Attempting to save log to Jamf"
softwareupdate --install --restart --all && exit 0
