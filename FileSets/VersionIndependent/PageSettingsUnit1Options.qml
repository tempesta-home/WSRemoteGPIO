import QtQuick 1.1
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
	id: root

        property string rgpioSettings: "dbus/com.victronenergy.settings/Settings/WSRemoteGPIO/Unit1"
        property string serviceSetting: "dbus/com.victronenergy.settings/Settings/Services/WSRemoteGPIO"

	title: qsTr("Unit 1 Options")


	model: VisualModels {
		VisibleItemModel {
          

        	MbSwitch {                                  
            	id: readdigin                           
            	name: qsTr("Enable Digital Inputs")                 
				bind: [rgpioSettings, "/ReadDigin"]
        	} 

        	MbSwitch {                                  
            	id: readrelay                           
            	name: qsTr("Enable Reading Relay State")                 
				bind: [rgpioSettings, "/ReadRelays"]
        	}

			MbSwitch {                                  
            	id: reboot                           
            	name: qsTr("Reboot Unit 1?")                 
				bind: [rgpioSettings, "/Reboot"]
        	}         
		
			MbItemOptions {
            	id: confirm
            	description: qsTr("PLEASE CONFIRM")
				bind: serviceSetting
            	show: reboot.checked
            	possibleValues: [
                	MbOption {description: qsTr("Don't reboot Unit"); value: 1},
                	MbOption {description: qsTr("Yes, Reboot please"); value: 2}
            	]
        	}
		}
	}
}