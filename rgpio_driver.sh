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

cmd_write_relay_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -t0 -r0 -c\$ai -a\$ind_unit -o\$timeout \${port_unitx[\$ind_unit]} \$const_string"
cmd_read_relay_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -t0 -r0 -c\$ai -a\$ind_unit -o\$timeout \${port_unitx[\$ind_unit]}"
cmd_read_diginp_status["WAVESHARE",0]="/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b115200 -p none -d8 -s1 -0 -1 -t1 -r0 -c\$ai -a\$ind_unit -o\$timeout \${port_unitx[\$ind_unit]}"

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
		ai=0
		for Relay in `cat ${conf_unitx_relay[$ind_unit]}`
		do
			const_string+=`cat $Relay`" "
			((ai++))
		done
		if [[ ${const_string} != ${prev_relay_status[$ind_unit]} ]]; then
			cmd=${cmd_write_relay_status[${hw_type[$ind_unit]},${protocol_unitx[$ind_unit]}]}
			eval "$cmd"
			prev_relay_status[$ind_unit]=${const_string}
		fi

		declare -a msg
		if [[ ${read_diginps[$ind_unit]} -eq 1 ]]; then
			cmd=${cmd_read_diginp_status[${hw_type[$ind_unit]},${protocol_unitx[$ind_unit]}]}
			msg=$(eval "$cmd" | grep "\[" | awk -F'[^0-9]*' '{print $3}')
			const_string=echo "$msg" | tr '\n' ' '
			
			echo "ind_unit "$ind_unit
			echo "const_string "$const_string
			echo "prev " ${prev_diginp_status[$ind_unit]}

			if [[ ${const_string} != ${prev_diginp_status[$ind_unit]} ]]; then
				ii=1
				for Digital_Input in `cat ${conf_unitx_diginp[$ind_unit]}`
				do
					echo ${const_string:(($ii*2-1)):1}
					echo ${const_string:(($ii*2-1)):1} > $Digital_Input
				done
				prev_diginp_status[$ind_unit]=${const_string}
			fi
		fi

		#		case $Protocol_unit1 in
		#			0) # RS485
		#				msg=$(echo -n $(/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m rtu -b 115200 -p none -d 8 -1 -r 11 -s 1 -c 1 -a 1 $Port_Unit1) | awk '{print $NF}')
		#				number=$(($msg))
		#				;;
		#			1) # TCP
		#				msg=$(echo -n $(/data/RemoteGPIO/bin/modpoll/arm-linux-gnueabihf/modpoll -m enc -1 -r 11 -c 1 -a 1 $IP_Unit1) | awk '{print $NF}')
		#				number=$(($msg))
		#				;;
		#		esac
#
#			if ((number >= 0 && number <= 255)); then
#
#				# Parsing number for writing the Input Devices
#					i=1
#					for Digital_Input in `cat $conf_unit1_digitalinput`
#					do
#						echo $((($number & $i) != 0)) > $Digital_Input
#						i=$((i*2))
#					done
#			fi
#		fi



	done 

	##
	## Latency vs CPU load
	#################################
    sleep 0.5

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
