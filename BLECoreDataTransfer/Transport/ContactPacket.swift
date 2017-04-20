//
//  ContactPacket.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-04-12.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import Foundation

class ContactPacket: NSObject, NSCoding {
    var id: Int32!
    var createdTime: NSDate!
    var modifiedTime: NSDate!
    var firstName: String?
    var lastName: String?
    var age: Int16?
    var email: String?
    var gender: Bool?
    
    init(id: Int32, createdTime: NSDate = NSDate(), modifiedTime: NSDate = NSDate(), firstName: String? = nil, lastName: String? = nil, age: Int16? = nil, email: String? = nil, gender: Bool? = nil) {
        self.id = id
        self.createdTime = createdTime
        self.modifiedTime = modifiedTime
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.email = email
        self.gender = gender
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: "id") as? Int32,
            let createdTime = aDecoder.decodeObject(forKey: "createdTime") as? NSDate,
            let modifiedTime = aDecoder.decodeObject(forKey: "modifiedTime") as? NSDate
        else { return nil }
        
        self.init(
            id: id,
            createdTime: createdTime,
            modifiedTime: modifiedTime,
            firstName: aDecoder.decodeObject(forKey: "firstName") as? String,
            lastName: aDecoder.decodeObject(forKey: "lastName") as? String,
            age: aDecoder.decodeObject(forKey: "age") as? Int16,
            email: aDecoder.decodeObject(forKey: "email") as? String,
            gender: aDecoder.decodeObject(forKey: "gender") as? Bool
        )
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        aCoder.encode(self.createdTime, forKey: "createdTime")
        aCoder.encode(self.modifiedTime, forKey: "modifiedTime")
        if let firstName = self.firstName { aCoder.encode(firstName, forKey: "firstName") }
        if let lastName = self.lastName { aCoder.encode(lastName, forKey: "lastName") }
        if let age = self.age { aCoder.encode(age, forKey: "age") }
        if let email = self.email { aCoder.encode(email, forKey: "email") }
        if let gender = self.gender { aCoder.encode(gender, forKey: "gender") }
    }
}
