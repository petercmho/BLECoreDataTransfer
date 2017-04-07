//
//  ContactDetailsViewController.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-04-07.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import UIKit
import CoreData

class ContactDetailsViewController: UIViewController {

    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    
    var managedObjectContext: NSManagedObjectContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func saveContactDetails(_ sender: Any) {
        let firstName = firstNameTextField.text
        let lastName = lastNameTextField.text
        
        if let isEmpty = firstName?.isEmpty,
            let isLastNameEmpty = lastName?.isEmpty, (isEmpty || isLastNameEmpty) == false {
            // Create entity description
            let entityDescription = NSEntityDescription.entity(forEntityName: "PersonEntity", in: self.managedObjectContext)
            
            // Initialize record
            if let record = NSManagedObject(entity: entityDescription!, insertInto: self.managedObjectContext) as? PersonEntity {
                record.firstName = firstName!
                record.lastName = lastName!
                
                do {
                    // Save record
                    try record.managedObjectContext?.save()
                    
//                    dismiss(animated: true, completion: nil)
                    navigationController?.popViewController(animated: true)
                } catch {
                    let saveError = error as NSError
                    print("\(saveError), \(saveError.userInfo)")
                    
                    // Show alert view
                    showAlertWithTitle(title: "Warning", message: "Contact could not be saved", cancelButtonTitle: "OK")
                }
            } else {
                // Show alert view
                showAlertWithTitle(title: "Warning", message: "Contact needs a name", cancelButtonTitle: "OK")
            }
            
        }
    }
    
    // MARK: - Helper methods
    private func showAlertWithTitle(title: String, message: String, cancelButtonTitle: String) {
        // Initialize Alert Controller
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Configure alert controller
        alertController.addAction(UIAlertAction(title: cancelButtonTitle, style: .default, handler: nil))
        
        // Present alert controller
        present(alertController, animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
