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
    var firstName: String!
    var lastName: String!
    var age: Int16!
    var email: String!
    var gender: Bool!
    
    init(id: Int32, firstName: String, lastName: String, age: Int16, email: String, gender: Bool) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.email = email
        self.gender = gender
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let firstName = aDecoder.decodeObject(forKey: "firstName") as? String,
            let lastName = aDecoder.decodeObject(forKey: "lastName") as? String,
            let email = aDecoder.decodeObject(forKey: "email") as? String
            else { return nil }
        
        self.init(
            id: aDecoder.decodeInt32(forKey: "id"),
            firstName: firstName,
            lastName: lastName,
            age: Int16(aDecoder.decodeInt32(forKey: "age")),
            email: email,
            gender: aDecoder.decodeBool(forKey: "gender")
        )
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        aCoder.encode(self.firstName, forKey: "firstName")
        aCoder.encode(self.lastName, forKey: "lastName")
        aCoder.encode(self.age, forKey: "age")
        aCoder.encode(self.email, forKey: "email")
        aCoder.encode(self.gender, forKey: "gender")
    }
}