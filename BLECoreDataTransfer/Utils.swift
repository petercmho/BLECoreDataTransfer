//
//  Utils.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-02-22.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import Foundation

class Utils {
    
    // MARK: - Time methods
    
    static func getCurrentTime() -> String {
        let date = NSDate()
        let calendar = NSCalendar.current
        return String(format: "%02d:%02d:%02d.%2d",
                      calendar.component(.hour, from: date as Date),
                      calendar.component(.minute, from: date as Date),
                      calendar.component(.second, from: date as Date),
                      calendar.component(.nanosecond, from: date as Date))
    }
}
