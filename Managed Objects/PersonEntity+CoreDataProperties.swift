//
//  PersonEntity+CoreDataProperties.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-04-04.
//  Copyright © 2017 Peter Ho. All rights reserved.
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension PersonEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersonEntity> {
        return NSFetchRequest<PersonEntity>(entityName: "PersonEntity");
    }

    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var gender: Bool
    @NSManaged public var age: Int16
    @NSManaged public var email: String?
    @NSManaged public var id: Int32

}
