#!/bin/sh

### BEGIN INIT INFO
# Short-Description: Driver to send Relays values and read Digital Inputs in loop for ever
# Description:       rgpio is used to connect external Relay box with ModBus/RTU control
### END INIT INFO

exec 2>&1

##
## Handle Dbus Settings
###############################
get_setting()
	{
		dbus-send --print-reply=literal --system --type=method_call --dest=com.victronenergy.settings $1 com.victronenergy.BusItem.GetValue | awk '/int32/ { print $3 }'
	}

set_setting()
	{
		dbus-send --print-reply=literal --system --type=method_call --dest=com.victronenergy.settings $1 com.victronenergy.BusItem.SetValue $2 >> /dev/null
	}

get_string()
	{
		dbus-send --print-reply=literal --system --type=method_call --dest=com.victronenergy.settings $1 com.victronenergy.BusItem.GetValue | awk '/variant/ { print $2 }'
	}

zero=0
nbunit=$(get_setting /Settings/RemoteGPIO/NumberUnits)

declare -a conf_unitx_relay
declare -a conf_unitx_diginp

declare -a prev_relay_status
declare -a prev_diginp_status

declare -a read_relays
declare -a read_diginps

for ((ind_unit=1; ind_unit<=$nbunit; ind_unit++))
do
	conf_unitx_relay[$ind_unit]="/data/RemoteGPIO/FileSets/Conf/Relays_unit"${ind_unit}".conf"
	conf_unitx_diginp[$ind_unit]="/data/RemoteGPIO/FileSets/Conf/Digital_Inputs_unit"${ind_unit}".conf"

	prev_relay_status[$ind_unit]=""
	prev_diginp_status[$ind_unit]=""

	read_relays[$ind_unit]=$(get_setting /Settings/RemoteGPIO/Unit${ind_unit}/ReadRelays)
	read_diginps[$ind_unit]=$(get_setting /Settings/RemoteGPIO/Unit${ind_unit}/ReadDigin)
done 

timer=$(date +%s)

exit

##
## Handle up to 3 units and multi-protocol
###########################################

if [[ $nbunit -gt $zero ]]
then
	# One unit. Reading Protocol, port and IP address
	Protocol_unit1=$(get_setting /Settings/RemoteGPIO/Unit1/Protocol)
	Port_Unit1=$(get_string /Settings/RemoteGPIO/Unit1/USB_Port)
	IP_Unit1=$(get_string /Settings/RemoteGPIO/Unit1/IP)
else
	Protocol_unit1=
	Port_Unit1=
	IP_Unit1=
fi
if [[ $nbunit -gt 1 ]]
then
	# Two unit. Reading Protocol, port and IP address
	Protocol_unit2=$(get_setting /Settings/RemoteGPIO/Unit2/Protocol)
	Port_Unit2=$(get_string /Settings/RemoteGPIO/Unit2/USB_Port)
	IP_Unit2=$(get_string /Settings/RemoteGPIO/Unit2/IP)
else
	Protocol_unit2=
	Port_Unit2=
	IP_Unit2=
fi
if [[ $nbunit -gt 2 ]]
then
	# Three unit. Reading Protocol, port and IP address
	Protocol_unit3=$(get_setting /Settings/RemoteGPIO/Unit3/Protocol)
	Port_Unit3=$(get_string /Settings/RemoteGPIO/Unit3/USB_Port)
	IP_Unit3=$(get_string /Settings/RemoteGPIO/Unit3/IP)
else
	Protocol_unit3=
	Port_Unit3=
	IP_Unit3=
fi			

##
## Main loop
###############################
while true
do


	##
	## Handle Unit1 with up to 8x Relays 
	#################################
	index=1
	i=1
	j=256
	const=0
	declare -a const_array
	const_string=""
	for Relay in `cat $conf_unit1_relay`
	do
		ai=$index-1
		const_array[$ai]=`cat $Relay`
		const_string+=${const_array[$ai]}" "
		if [[ ${const_array[$ai]} -eq $zero ]]
		then
			const=$((const+j))
		else
			const=$((const+j+i))
		fi
		index=$((index+1))
		i=$((i*2))
        j=$((256*i))
	done

	# Trying to limit resources usage so talking to Unit only if relay change
	if [[ $const != $prev_const1 ]]
	then
		case $Protocol_unit1 in
			0) # RS485
				/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -r0 -c$ai -a1 -o1 $Port_Unit1 $const_string >> /dev/null
				;;
			1) # TCP
				/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m enc -1 -r 3 -c 1 -a 1 $IP_Unit1 $const >> /dev/null
				;;
		esac
		prev_const1=$((const))
	fi


	##
	## Latency vs CPU load
	#################################
#    sleep 0.1



	##
	## Heart Beat
	################################
	if (( (timer + 5) < $(date +%s) ))
	then
		timer=$(date +%s)
		set_setting /Settings/Watchdog/RemoteGPIO variant:int32:$timer
		echo "Heartbeat = "$(date -d@$timer)
	fi
done
