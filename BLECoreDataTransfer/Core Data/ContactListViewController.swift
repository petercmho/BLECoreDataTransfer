//
//  ContactListViewController.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-04-03.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import UIKit
import CoreData
import CoreBluetooth

class ContactListViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDataSource, UITableViewDelegate, CBPeripheralManagerDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    private lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: nil)
    }()
    
    private lazy var contactTransferCharacteristic: CBMutableCharacteristic = {
        return CBMutableCharacteristic(type: CBUUID(string: TransferService.ContactsTransferCharacteristicUUID), properties: .notify, value: nil, permissions: .readable)
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let persistentContainer = appDelegate.persistentContainer
        
        return persistentContainer.viewContext
    }()
    
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        // Initialize Fetch Request
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PersonEntity")
        
        // Add Sort Descriptors
        let sortDescriptor = NSSortDescriptor(key: "firstName", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Initialize fetched results controller
        let fetchedResultsController = NSFetchedResultsController<NSFetchRequestResult>(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Configure fetched results controller
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.fetchedResultsController.sections?.count ?? 0 > 0 {
            return self.fetchedResultsController.sections?[section].numberOfObjects ?? 0
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "contactIdentifier", for: indexPath) as! ContactTableViewCell
        if let record = fetchedResultsController.object(at: indexPath) as? PersonEntity,
            let firstName = record.firstName,   
            let lastName = record.lastName {
            cell.contact.text = "\(firstName) \(lastName)"
        }
        return cell
    }
    
    // MARK: - Actions
    
    @IBAction func addNewContact(_ sender: Any) {
        performSegue(withIdentifier: "showContactDetailsIdentifier", sender: sender)
    }
    
    @IBAction func unwindToContactList(sender: UIStoryboardSegue) {
        print("ContactListViewController.unwindToContactList")
    }
    
    @IBAction func sendCoreData(_ sender: Any) {
        // Start with the service
        let contactsTransferService = CBMutableService(type: CBUUID(string: TransferService.ContactsTransferServiceUUID), primary: true)
        
        // Add the characteristic to the service
        contactsTransferService.characteristics = [self.contactTransferCharacteristic]
        
        // And add it to the peripheral manager
        self.peripheralManager.add(contactsTransferService)
    }
    
    @IBAction func receiveCoreData(_ sender: Any) {
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .update:
            if let indexPath = indexPath,
                let cell = tableView.cellForRow(at: indexPath) as? ContactTableViewCell,
                let contact = fetchedResultsController.object(at: indexPath) as? PersonEntity,
                let firstName = contact.firstName,
                let lastName = contact.lastName {
                cell.contact.text = "\(firstName) \(lastName)"
            }
        case .move:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
        }
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn {
            return
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showContactDetailsIdentifier" {
            if let destination = segue.destination as? ContactDetailsViewController {
                destination.managedObjectContext = self.managedObjectContext
            }
        }
    }
    

}
