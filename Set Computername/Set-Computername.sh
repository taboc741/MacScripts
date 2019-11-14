#!/bin/sh

#  SetComputerName.sh
#Find current computername
current=`sudo jamf getComputerName`
echo "The current computername is $current"
#Prompt User for computer Name
COMPNAME="$(osascript -e 'Tell application "System Events" to display dialog " Enter the computer name:" default answer ""' -e 'text returned of result' 2>/dev/null)"
#verify user did not press cancel
if [ $? -ne 0 ]; then
# The user pressed Cancel
echo "User pressed cancel"
exit 1 # exit with an error status
#verify user entered a value
elif [ -z "$COMPNAME" ]; then
# The user left the project name blank
osascript -e 'Tell application "System Events" to display alert "You must enter a computer name; cancelling..." as warning'
echo "User did not enter computer name"
exit 1 # exit with an error status
fi
echo "$COMPNAME entered as computer name"

#Set Hostname using variable created above
sudo scutil --set ComputerName $COMPNAME
sudo scutil --set LocalHostName $COMPNAME
sudo scutil --set HostName $COMPNAME
sudo jamf setComputerName -name "$COMPNAME"
sudo jamf recon
exit 0
