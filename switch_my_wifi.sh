#!/bin/bash

#_____________________________HELP__________________________________#
# Define the Help function
Help() {
    echo "This script is designed to switch between two WiFi networks."
    echo "Usage: [-a] [-b] [-c] [-d]"
    echo "Options:"
    echo "  -a: Perform action before switching from SSID1 to SSID2"
    echo "  -b: Perform action before switching from SSID2 to SSID1"
    echo "  -c: Perform action after switching from SSID1 to SSID2"
    echo "  -d: Perform action after switching from SSID2 to SSID1"
    echo
    echo "Created By ali93rahmani@gmail.com"
    echo
}

#_____________________________OPTIONS_____________________________#
# Process the input options
while getopts "-abcdh" option; do
   case $option in
       # SSID1
      a)
         ssid1_after=1;;
      b)
         ssid1_before=1;;
      # SSID2
      c)
         ssid2_after=1;;
      d)
         ssid2_before=1;;

      h) # display Help
         Help
         exit ;;
   esac
done

#_____________________________CODE_____________________________#
# Define the SSID and password of the WiFi networks
SSID1="<YOUR SSID>"
PASSWORD1="<YOUR PASSWORD>"
SSID2="<YOUR SSID>"
PASSWORD2="<YOUR PASSWORD>"
VPN1="<YOUR VPN>"
VPN2="<YOUR VPN>"

# Get the current SSID
get_current_ssid() {
     nmcli -t -f active,ssid dev wifi | grep -oP '(?<=yes:)\s*\K[^ ]+'
}

current_ssid="$(get_current_ssid)"
############################
##### SSID 1 to SSID 2 #####
############################
switch_from_ssid2_to_ssid1() {
    tput setaf 4; echo "switch to SSID1 $SSID1 ... "
    nmcli device wifi connect "$SSID1" password "$PASSWORD1"
}

action_before_switch_ssid2_to_ssid1() {
    if [ $ssid1_before  > 0 ]; then
    tput setaf 5; echo "Performing action before switch..."
    nmcli con down id "$VPN1"
    fi
}

action_after_switch_ssid2_to_ssid1() {
    if [ $ssid1_after  > 0 ]; then
    tput setaf 2; echo "Performing action after switch..."
    sleep 1
    echo "connect to Outline ..."
    nmcli con up id outline-tun0
    echo "Outline connected successfully"
    fi
}

############################
##### SSID 1 to SSID 2 #####
############################
switch_from_ssid1_to_ssid2() {
    tput setaf 4; echo "switch to SSID2  $SSID2 ... "
      nmcli device wifi connect "$SSID2" password "$PASSWORD2"
}

action_before_switch_ssid1_to_ssid2() {
    if [ $ssid2_before  > 0 ]; then
    tput setaf 5; echo "Performing action before switch..."
    nmcli con down id "$VPN2"
    fi
}

action_after_switch_ssid1_to_ssid2() {
    if [ $ssid2_after  > 0 ]; then
    tput setaf 2; echo "Performing action after switch..."
    sleep 1
    echo "connect vpn ..."
    nmcli con up id "$VPN1"
    echo "vpn connected successfully"
    fi
}

#_____________________________RUNTIME_____________________________#
echo "current_ssid:" $current_ssid
echo "SSID1:" "$SSID1"
echo "SSID2:" "$SSID2"
echo "-------"

# Determine which SSID to switch to based on the current SSID
if [ "$current_ssid" = "$SSID1" ]; then
    action_before_switch_ssid1_to_ssid2
    switch_from_ssid1_to_ssid2
    action_after_switch_ssid1_to_ssid2
else
    action_before_switch_ssid2_to_ssid1
    switch_from_ssid2_to_ssid1
    action_after_switch_ssid2_to_ssid1
fi

tput setaf 7; echo "Current SSID is  "$(get_current_ssid)""
