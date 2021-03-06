//
//  UserDefaults.swift
//  Mobile Flight
//
//  Created by Raphael Jean-Leconte on 30/12/15.
//  Copyright © 2015 Raphael Jean-Leconte. All rights reserved.
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

import Foundation

enum UnitSystem {
    case Default
    case Metric
    case Imperial
    case Aviation
}

enum UserDefault : String {
    case RecordFlightlog = "record_flightlog"
    case ConnectionLostAlarm = "connection_lost_alarm"
    case GPSFixLostAlarm = "gps_fix_lost_alarm"
    case BatteryLowAlarm = "battery_low_alarm"
    case UnitSystem = "unit_system"
    case RSSIAlarm = "rssialarm_enabled"
    case RSSIAlarmLow = "rssialarm_low"
    case RSSIAlarmCritical = "rssialarm_critical"
    case DisableIdleTimer = "disable_idle_timer"
    case FlightModeAlert = "flight_mode_alert"
    case OSDFont = "osd_font"
    case INavAlert = "inav_alert"
    case UsageReporting = "usage_reporting"
    
    var stringValue: String? {
        get {
            return NSUserDefaults.standardUserDefaults().stringForKey(self.rawValue)
        }
    }
    
    func setValue(string: String) {
        setUserDefault(self, string: string)
    }
}

func registerInitialUserDefaults(plistFile: String)  -> [String:AnyObject] {
    let baseUrl = NSBundle.mainBundle().bundleURL
    let settingsBundleUrl = baseUrl.URLByAppendingPathComponent("Settings.bundle")
    let plistUrl = settingsBundleUrl!.URLByAppendingPathComponent(plistFile)
    let settingsDict = NSDictionary(contentsOfFile: plistUrl!.path!)
    let prefSpecifierArray = settingsDict!.objectForKey("PreferenceSpecifiers") as! NSArray
    
    var defaults:[String:AnyObject] = [:]
    
    for prefItem in prefSpecifierArray {
        if prefItem.objectForKey("Type") as? String == "PSChildPaneSpecifier" {
            for (k,v) in registerInitialUserDefaults((prefItem.objectForKey("File") as! String) + ".plist") {
                defaults[k] = v
            }
        }
        else if let key = prefItem.objectForKey("Key") as? String {
            defaults[key] = prefItem.objectForKey("DefaultValue")
        }
    }
    
    return defaults
}

func registerInitialUserDefaults() {
    let defaults = registerInitialUserDefaults("Root.plist")
    
    NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
}

func userDefaultEnabled(userDefault: UserDefault) -> Bool {
    return NSUserDefaults.standardUserDefaults().boolForKey(userDefault.rawValue)
}

func userDefaultAsString(userDefault: UserDefault) -> String {
    return NSUserDefaults.standardUserDefaults().stringForKey(userDefault.rawValue)!
}

func userDefaultAsInt(userDefault: UserDefault) -> Int {
    return NSUserDefaults.standardUserDefaults().integerForKey(userDefault.rawValue)
}

func setUserDefault(userDefault: UserDefault, string: String?) {
    return NSUserDefaults.standardUserDefaults().setValue(string, forKey: userDefault.rawValue)
}

func selectedUnitSystem() -> UnitSystem {
    switch userDefaultAsString(.UnitSystem) {
    case "imperial":
        return .Imperial
    case "metric":
        return .Metric
    case "aviation":
        return .Aviation
    default:
        return (NSLocale.currentLocale().objectForKey(NSLocaleUsesMetricSystem) as? Bool ?? true) ? .Metric : .Imperial
    }
    
}
