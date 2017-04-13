
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

class ContactListViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDataSource, UITableViewDelegate, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static var isRunningBackground = false
    static let NotifyMTU = 20

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receiveButton: UIButton!
    
//    private lazy var peripheralManager: CBPeripheralManager = {
//        return CBPeripheralManager(delegate: self, queue: nil)
//    }()
    
    private var peripheralManager: CBPeripheralManager!
    private var centralManager: CBCentralManager!
    private var discoverdPeripheral: CBPeripheral!
    
    private var contactToSend: Data?
    private var sendContactIndex: Int = 0
    
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
    
    var minRSSI: Int {
        get {
            var result = -127
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                result = ContactListViewController.isRunningBackground ? -40 : -35
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                result = ContactListViewController.isRunningBackground ? -60 : -40
            }
            
            return result
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
        
        // Do any additional setup after loading the view.
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if self.peripheralManager.isAdvertising {
            self.peripheralManager.stopAdvertising()
        }
        
        super.viewWillDisappear(animated)
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
        if !self.peripheralManager.isAdvertising {
            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: TransferService.ContactsTransferServiceUUID)]])
        }
    }
    
    @IBAction func receiveCoreData(_ sender: Any) {
        scan()
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
        
        // Start with the service
        let contactsTransferService = CBMutableService(type: CBUUID(string: TransferService.ContactsTransferServiceUUID), primary: true)
        
        // Add the characteristic to the service
        contactsTransferService.characteristics = [self.contactTransferCharacteristic]
        
        // And add it to the peripheral manager
        self.peripheralManager.add(contactsTransferService)
        
        self.sendButton.isEnabled = true
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("\(Utils.getCurrentTime()) - peripheralManager(_ \(peripheral) :central \(central) :didSubscribeTo: \(characteristic)) - Central subscribed to characteristic")
        
        guard let contact = fetchedResultsController.object(at: IndexPath(row: 0, section: 0)) as? PersonEntity
        else {
                return
        }
        
        let contactPacket = ContactPacket(id: contact.id, firstName: contact.firstName!, lastName: contact.lastName!, age: contact.age, email: contact.email!, gender: contact.gender)
        self.contactToSend = NSKeyedArchiver.archivedData(withRootObject: contactPacket)
        self.sendContactIndex = 0
        
        sendContact()
    }
    
    /* More space in the peripheral's transmit queue becomes available, resend the update. */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("\(Utils.getCurrentTime()) - peripheralManagerIsReady(toUpdateSubscribers \(peripheral))")
    }
    
    func sendContact() {
        guard let peripheralContactManager = self.peripheralManager,
            let dataToSend = self.contactToSend
            else { return }
        
        if self.sendContactIndex >= dataToSend.count {
            return
        }
        
        var doSend = true
        
        while doSend {
            var amountToSend = dataToSend.count - self.sendContactIndex
            
            if amountToSend > ContactListViewController.NotifyMTU {
                amountToSend = ContactListViewController.NotifyMTU
            }
            
            // Copy out the data we want
            
            
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            return
        }
        
        self.receiveButton.isEnabled = true
    }
    
    func scan() {
        self.centralManager.scanForPeripherals(withServices: [CBUUID(string: TransferService.ContactsTransferServiceUUID)], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if RSSI.intValue > -15 || RSSI.intValue < self.minRSSI {
            return
        }
        
        print("\(Utils.getCurrentTime()) - centralManager(_ \(central) didDiscover: \(peripheral) advertisementData: \(advertisementData) rssi: \(RSSI))")
        if self.discoverdPeripheral != peripheral {
            self.discoverdPeripheral = peripheral
            print("   \(Utils.getCurrentTime()) - centralManager.connect(peripheral, nil)")
            self.centralManager.connect(peripheral, options: nil)
        }
        print("\(Utils.getCurrentTime()) - centralManager(_:didDiscover:advertisementData:rssi:) end")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("\(Utils.getCurrentTime()) - Failed to connect to \(peripheral). (\(error?.localizedDescription))")
    }
    
    func cleanup() {
        print("\(Utils.getCurrentTime()) - cleanup")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\(Utils.getCurrentTime()) - centralManager(_ \(central) :didConnect \(peripheral)) - Peripheral connected")
        
        // Stop scanning
        self.centralManager.stopScan()
        print("\(Utils.getCurrentTime()) - Scanning stopped")
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only fro services that match our UUID
        peripheral.discoverServices([CBUUID(string: TransferService.ContactsTransferServiceUUID)])
        print("\(Utils.getCurrentTime()) - centralManager(_:didConnect:) end")
    }
    
    // MARK: - CBPeripheralDelegate
    
    /* The transfer service was discovered.  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains. */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverServices:)")
        if let discoverError = error {
            print("\(Utils.getCurrentTime()) - Error discovering services: \(discoverError.localizedDescription)")
            self.cleanup()
            return
        }
        
        // Discover the characteristic we want...
        // Loop through the newly filled peripheral.service array, just in case there's more than one.
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics([CBUUID(string: TransferService.ContactsTransferCharacteristicUUID)], for: service)
            }
        }
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverServices:) end")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverCharacteristicsFor:error:)")
        // Deal with errors (if any)
        if let discoverError = error {
            print("Error discovering characteristics: \(discoverError.localizedDescription)")
            self.cleanup()
            return
        }
        
        // Again, we loop through the array, just in case.
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(CBUUID(string: TransferService.ContactsTransferCharacteristicUUID)) {
                // If it is, subscribe to it
                print("   peripheral.setNotifyValue(true, for: \(characteristic)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverCharacteristicsFor:error:) end")
    }
    
    /* This callback lets us know more data has arrived via notification on the characteristic. */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) : didUpdateValueFor \(characteristic) : error \(error)")
    }
    
    /* The peripheral letting us know whether our subscribe/unsubscribe happened or not. */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) : didUpdateNotificationStateFor \(characteristic) : error \(error)")
    }
    
    /* If the central is no longer available, peripheral:didModifyServices: will be called. */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("\(Utils.getCurrentTime()) - peripheral(_:didModifyServices:)")
        
        for service in invalidatedServices {
            print("   Invalidated service - \(service)")
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
