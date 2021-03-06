//
//  PortConfigViewController.swift
//  Mobile Flight
//
//  Created by Raphael Jean-Leconte on 14/01/16.
//  Copyright © 2016 Raphael Jean-Leconte. All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import UIKit

class PortConfigViewController: ConfigChildViewController {
    @IBOutlet weak var enableMSP: UISwitch!
    @IBOutlet weak var mspBaudrateField: UITextField!
    @IBOutlet weak var peripheralsTypeField: UITextField!
    @IBOutlet weak var blackboxBaudrateField: UITextField!
    @IBOutlet weak var telemetryTypeField: UITextField!
    @IBOutlet weak var telemetryBaudrateField: UITextField!
    @IBOutlet weak var enableRx: UISwitch!
    @IBOutlet weak var sensorTypeField: UITextField!
    @IBOutlet weak var gpsBaudrateField: UITextField!

    var mspBaudratePicker: MyDownPicker!
    var peripheralsTypePicker: MyDownPicker!
    var blackboxBaudratePicker: MyDownPicker!
    var telemetryTypePicker: MyDownPicker!
    var telemetryBaudratePicker: MyDownPicker!
    var sensorTypePicker: MyDownPicker!
    var gpsBaudratePicker: MyDownPicker!
    
    var portIndex: Int!
    var portsConfigViewController: PortsConfigViewController!

    var telemetryMAVLink: PortFunction!
    var telemetryIBus: PortFunction!
    var peripheralRuncamSplit: PortFunction!
    
    var baudRates = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = Configuration.theConfig
        telemetryMAVLink = (config.isApiVersionAtLeast("1.31") && !config.isINav) ? .TelemetryMAVLink : .TelemetryMAVLinkOld
        telemetryIBus = config.isINav ? .TelemetryIBusINAV : .TelemetryIBus
        peripheralRuncamSplit = config.isINav ? .RuncamSplitINAV : .RuncamSplit
        
        baudRates.removeAll()
        for e in BaudRate.values() {
            baudRates.append(e.description)
        }
        
        mspBaudratePicker = MyDownPicker(textField: mspBaudrateField, withData: baudRates)
        peripheralsTypePicker = MyDownPicker(textField: peripheralsTypeField, withData: [ "Disabled", "Blackbox", "TBS SmartAudio", "IRC Tramp", "Runcam Split" ])
        blackboxBaudratePicker = MyDownPicker(textField: blackboxBaudrateField, withData: baudRates)
        telemetryTypePicker = MyDownPicker(textField: telemetryTypeField, withData: [ "Disabled", "Frsky", "Hott", "LTM", "SmartPort", "MAVLink", "IBUS" ])
        telemetryBaudratePicker = MyDownPicker(textField: telemetryBaudrateField, withData: baudRates)
        sensorTypePicker = MyDownPicker(textField: sensorTypeField, withData: [ "Disabled", "GPS", "ESC" ])
        gpsBaudratePicker = MyDownPicker(textField: gpsBaudrateField, withData: baudRates)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let port = settings.portConfigs![portIndex]
        
        enableMSP.on = port.functions.contains(.MSP)
        
        let mspBaudRate = port.mspBaudRate.intValue
        setPickerValue(mspBaudratePicker, options: baudRates, selected: mspBaudRate)
        
        if port.functions.contains(.Blackbox) {
            peripheralsTypePicker.selectedIndex = 1
        } else if port.functions.contains(.VTXSmartAudio) {
            peripheralsTypePicker.selectedIndex = 2
        } else if port.functions.contains(.VTXTramp) {
            peripheralsTypePicker.selectedIndex = 3
        } else if port.functions.contains(peripheralRuncamSplit) {
            peripheralsTypePicker.selectedIndex = 4
        } else {
            peripheralsTypePicker.selectedIndex = 0
        }
        setPickerValue(blackboxBaudratePicker, options: baudRates, selected: port.blackboxBaudRate.intValue)
        
        if port.functions.contains(.TelemetryFrsky) {
            telemetryTypePicker.selectedIndex = 1
        } else if port.functions.contains(.TelemetryHott) {
            telemetryTypePicker.selectedIndex = 2
        } else if port.functions.contains(.TelemetryLTM) {
            telemetryTypePicker.selectedIndex = 3
        } else if port.functions.contains(.TelemetrySmartPort) {
            telemetryTypePicker.selectedIndex = 4
        } else if port.functions.contains(telemetryMAVLink) {
            telemetryTypePicker.selectedIndex = 5
        } else if port.functions.contains(telemetryIBus) {
            telemetryTypePicker.selectedIndex = 6
        } else {
            telemetryTypePicker.selectedIndex = 0
        }
        setPickerValue(telemetryBaudratePicker, options: baudRates, selected: port.telemetryBaudRate.intValue)
        
        enableRx.on = port.functions.contains(.RxSerial)
        
        let config = Configuration.theConfig
        if port.functions.contains(.GPS) {
            sensorTypePicker.selectedIndex = 1
        } else if port.functions.contains(.ESCSensor) && !config.isINav {
            sensorTypePicker.selectedIndex = 2
        } else {
            sensorTypePicker.selectedIndex = 0
        }
        setPickerValue(gpsBaudratePicker, options: baudRates, selected: port.gpsBaudRate.intValue)
    }
    
    private func setPickerValue(picker: MyDownPicker, options: [String], selected: Int) {
        if selected < 0 || selected >= options.count {
            if selected < 0 || selected - options.count > 4 {
                picker.enabled = false
                return
            }
            var optionsCopy = options
            for i in options.count ..< selected + 1 {
                optionsCopy.append(String(format: "Unknown (%d)", i))
            }
            picker.setData(optionsCopy)
        }
        picker.enabled = true
        picker.selectedIndex = selected
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        var port = settings.portConfigs![portIndex]
        
        if enableMSP.on {
            port.functions.insert(.MSP)
        } else {
            port.functions.remove(.MSP)
        }
        if mspBaudratePicker.enabled {
            port.mspBaudRate = BaudRate.values()[mspBaudratePicker.selectedIndex]
        }
        
        port.functions.remove(.Blackbox)
        port.functions.remove(.VTXSmartAudio)
        port.functions.remove(.VTXTramp)
        port.functions.remove(peripheralRuncamSplit)
        switch peripheralsTypePicker.selectedIndex {
        case 1:
            port.functions.insert(.Blackbox)
        case 2:
            port.functions.insert(.VTXSmartAudio)
        case 3:
            port.functions.insert(.VTXTramp)
        case 4:
            port.functions.insert(peripheralRuncamSplit)
        default:
            break
        }
        if blackboxBaudratePicker.enabled {
            port.blackboxBaudRate = BaudRate.values()[blackboxBaudratePicker.selectedIndex]
        }
        
        port.functions.remove(.TelemetryFrsky)
        port.functions.remove(.TelemetryHott)
        port.functions.remove(.TelemetryLTM)
        port.functions.remove(.TelemetrySmartPort)
        port.functions.remove(telemetryMAVLink)
        port.functions.remove(telemetryIBus)
        switch telemetryTypePicker.selectedIndex {
        case 1:
            port.functions.insert(.TelemetryFrsky)
        case 2:
            port.functions.insert(.TelemetryHott)
        case 3:
            port.functions.insert(.TelemetryLTM)
        case 4:
            port.functions.insert(.TelemetrySmartPort)
        case 5:
            port.functions.insert(telemetryMAVLink)
        case 6:
            port.functions.insert(telemetryIBus)
        default:
            break
        }
        if telemetryBaudratePicker.enabled {
            port.telemetryBaudRate = BaudRate.values()[telemetryBaudratePicker.selectedIndex]
        }
        
        if enableRx.on {
            port.functions.insert(.RxSerial)
        } else {
            port.functions.remove(.RxSerial)
        }
        
        let config = Configuration.theConfig
        switch sensorTypePicker.selectedIndex {
        case 1:
            port.functions.insert(.GPS)
            if !config.isINav {
                port.functions.remove(.ESCSensor)
            }
        case 2:
            port.functions.remove(.GPS)
            if !config.isINav {
                port.functions.insert(.ESCSensor)
            }
        default:
            port.functions.remove(.GPS)
            if !config.isINav {
                port.functions.remove(.ESCSensor)
            }
        }
        if gpsBaudratePicker.enabled {
            port.gpsBaudRate = BaudRate.values()[gpsBaudratePicker.selectedIndex]
        }

        settings.portConfigs![portIndex] = port
        
        portsConfigViewController.tableView.reloadData()
    }
}
