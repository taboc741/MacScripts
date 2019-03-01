#!/bin/sh
##  AppleUpdateDefer1.sh
##  Created by Chris Couch (ccouch) on 1/29/19
##  Last Edited 2/10/2019


######### Defined Arguements #########
#$4 ===> arguement for number of deferrals.  Setting the $4 arguement clobbers any prior deferral count

######### End Defined Arguements #########

######### Set variables for the script ############

##Jamf trigger for starting the Apple Update script
trigger=AppleUpdateScript
# you can uncomment the below (and comment out the above) to set the trigger value via a prefernce plist
#default=`defaults read com.YourOrg.SoftwareUpdate.Deferral jamfPolicyTrigger`

##Path to icon used in user messaging.  
icon="/Library/Application Support/YourOrg/AppleSoftwareUpdate.png"
# you can uncomment the below (and comment out the above) to set the icon path value via a prefernce plist
#default=`defaults read com.YourOrg.SoftwareUpdate.Deferral iconPath`

##Set number of allowed deferrals.
default=5 #default number of deferrals
# you can uncomment the below (and comment out the above) to set the default value via a Prefernce plist
#default=`defaults read com.YourOrg.SoftwareUpdate.Deferral defaultDeferrals`

## Path to Log file. Map your own Log Path.  Do not use /tmp as it is emptied on boot.
LogPath=/Library/Logs/YourOrg

##below are settings for the title and heading of the JamfHelper prompts seen by the user logged in
title='Software Update Required'
# you can uncomment the below (and comment out the above) to set the default title value via a prefernce plist
#default=`defaults read com.YourOrg.SoftwareUpdate.Deferral defualtTitle`
heading='Required Mac OS update'
# you can uncomment the below (and comment out the above) to set the default title heading via a prefernce plist
#default=`defaults read com.YourOrg.SoftwareUpdate.Deferral defualtHeading`

######### End set variables for the script ############

######### Create settings for logging and create log file #########

##Verify LogPath exists
if [ ! -d "$LogPath" ]; then
mkdir $LogPath
fi

## Set log file and console to recieve output of commands
Log_File="$LogPath/SoftwareUpdateDefer.log"
function sendToLog ()
{

echo "$(date +"%Y-%b-%d %T") : $1" | tee -a "$Log_File"

}

## begin log file
sendToLog "Script Started"

######### End Create settings for logging and create log file #########

######### Start the hardwork ############

##Check to make sure $icon path is real
if [ ! -e "$icon" ]; then
	icon="/System/Library/CoreServices/Install Command Line Developer Tools.app/Contents/Resources/SoftwareUpdate.icns"
fi

##Determine how many deferrals to give the user this go around
if [ -z "$4" ]; then
	deferral="ns"
else
	deferral="$4"
fi
if [ $deferral = "ns" ];then
	##Calculate remaining deferrals
	##Check the Plist and find remaining deferrals from prior executions
	remainDeferrals=`defaults read com.YourOrg.SoftwareUpdate.Deferral remainingDeferrals`
	##Check that remainDeferrals isn't null (aka pulled back an empty value), if so set it to $default
	[[ -z $remainDeferrals ]] && remainDeferrals=$default
	##Check if remaining defferals is $null
	if [ $remainDeferrals = "" ]; then
		deferral=$default
	else
		if [ $remainDeferrals -lt $default ]; then
			deferral=$remainDeferrals
		else
			deferral=$default
		fi
	fi
fi

##Check if there are any pending OS updates. If not quit to run another day.
updates=`softwareupdate -l`
updatesPending=`echo $updates | grep recommended`
[[ -z $updatesPending ]] && updatesPending="none"
sendToLog="Updates equaled 
	$updates
"
if [[ $updatesPending = "none" ]]; then
	sendToLog "No updates pending. Setting plist remainingDeferral to $default.  It was $remainDeferrals.  Exiting"
	#defaults write com.YourOrg.SoftwareUpdate.Deferral remainingDeferrals $default
	exit 0
else
	echo "Updates found"
fi 

sendToLog "Icon path set to $icon"
sendToLog "Deferral set to $deferral"
## Download all updates before trying to install them to make a smoother user experiance.
softwareupdate --download --force --all --no-scan && sendToLog "Updates downloaded"
####Logic for which deferal the user gets
if [ $deferral = 0 ]; then
	##No deferrals left
	sendToLog "no deferrals left"
	#Map some variables to pretty up the command to prompt the user
	description='A required OS update is available for your Mac.  There are no deferrals left.  You will be prompted again if a reboot is required.'
	button1="Start Updates"
	##prompt the user
	prompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -timeout 14400 -countdown -lockHUD`
	sendToLog "prompt equaled $prompt. 0=start 1=failed to prompt 2=canceled 239=exited"
	##Since they have no other option they get the apple update script kicked off.
	sendToLog "Starting Apple Update Script"
	jamf policy -trigger $trigger &
	sendToLog "update script triggered.  exiting."
	exit 0
else
	##User has a chance for deferral.
	##Map some variables to pretty up the command to prompt the user
	description=`echo "A required OS update is available for your Mac.  You may defer $deferral more days.  Updates can always be started from Self-Service.  If you to proceed you will be prompted again if a reboot is required."`
	button1="Start Updates"
	button2=`echo "Defer ($deferral)"`
	##prompt the user
	prompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$title" -heading "$heading" -alignHeading justified -description "$description" -alignDescription left -icon "$icon" -button1 "$button1" -button2 "$button2" -timeout 14400 -countdown -lockHUD -defaultButton 1 -cancleButton 2`
	sendToLog "prompt equaled $prompt. 0=Start Updates 1=failed to prompt 2=User choose defer 239=exited Null=user force quit jamfHelper"
	if [[ -z $prompt ]];then
		#User ugly closed the prompt.
		deferral=$(( $deferral - 1 ))
		defaults write com.YourOrg.SoftwareUpdate.Deferral remainingDeferrals $deferral
		exit 0
	elif [[ $prompt = 0 ]]; then
		##User elected to start updates or the timer ran out after 4 hours.  Kicking off Apple update script
		sendToLog "Starting Apple Update Script via Jamf trigger"
		jamf policy -trigger $trigger
		exit 0
	elif [[ $prompt = 2 || $prompt = 239 ]]; then
		#User either ugly closed the prompt, or choose the deferral option.
		deferral=$(( $deferral - 1 ))
		defaults write com.YourOrg.SoftwareUpdate.Deferral remainingDeferrals $deferral
		exit 0
	else
		##Something unexpected happened.  I don't really know how the user got here, but for fear of breaking things or abruptly rebooting computers we will set a flag for the mac in Jamf saying something went wrong.
		sendToLog "Something went wrong, the prompt equalled $prompt"
		##Insert API work here at a later data to update JSS that the script is failing.
		exit 0
	fi
fi
