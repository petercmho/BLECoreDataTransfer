//
//  PersonEntity+CoreDataProperties.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-04-18.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import Foundation
import CoreData


extension PersonEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersonEntity> {
        return NSFetchRequest<PersonEntity>(entityName: "PersonEntity")
    }

    @NSManaged public var age: NSNumber?
    @NSManaged public var email: String?
    @NSManaged public var firstName: String?
    @NSManaged public var gender: NSNumber?
    @NSManaged public var id: Int32
    @NSManaged public var lastName: String?

}
