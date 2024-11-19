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

declare -a protocol_unitx
declare -a port_unitx
declare -a ip_unitx
declare -a hw_type

for ((ind_unit=1; ind_unit<=$nbunit; ind_unit++))
do
	conf_unitx_relay[$ind_unit]="/data/RemoteGPIO/FileSets/Conf/Relays_unit"${ind_unit}".conf"
	conf_unitx_diginp[$ind_unit]="/data/RemoteGPIO/FileSets/Conf/Digital_Inputs_unit"${ind_unit}".conf"

	prev_relay_status[$ind_unit]=""
	prev_diginp_status[$ind_unit]=""

	read_relays[$ind_unit]=$(get_setting /Settings/RemoteGPIO/Unit${ind_unit}/ReadRelays)
	read_diginps[$ind_unit]=$(get_setting /Settings/RemoteGPIO/Unit${ind_unit}/ReadDigin)

	protocol_unitx[$ind_unit]=$(get_setting /Settings/RemoteGPIO/Unit${ind_unit}/Protocol)
	port_unitx[$ind_unit]=$(get_string /Settings/RemoteGPIO/Unit${ind_unit}/USB_Port)
	ip_unitx[$ind_unit]=$(get_string /Settings/RemoteGPIO/Unit${ind_unit}/IP)	
	hw_type[$ind_unit]="WAVESHARE"
done 

declare -a cmd_write_relay_status
declare -a cmd_read_relay_status
declare -a cmd_read_diginp_status

cmd_write_relay_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -r0 -c\$ai -a\$ind_unit -o\$timeout \$Port_Unit1 \$const_string"
cmd_read_relay_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -r0 -c\$ai -a\$ind_unit -o\$timeout \$Port_Unit1"
cmd_read_diginp_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -r0 -c\$ai -a\$ind_unit -o\$timeout \$Port_Unit1"

timer=$(date +%s)
#timeout constant in sec (0.01-10)
timeout=1

##
## Main loop
###############################
while true
do
	for ((ind_unit=1; ind_unit<=$nbunit; ind_unit++))	
	do 
		#Write Relay Status
		const_string=""
		for Relay in `cat ${conf_unitx_relay[$ind_unit]}`
		do
			const_string+=`cat $Relay`" "
		done
		if [[ ${const_string} != ${prev_relay_status[$ind_unit]} ]]; then
			echo ${hw_type[$ind_unit]}
			echo ${protocol_unitx[$ind_unit]}
			echo `$((${cmd_write_relay_status[${hw_type[$ind_unit]},${protocol_unitx[$ind_unit]}]}))` 
			prev_relay_status[$ind_unit]=${const_string}
		fi
	done 

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
