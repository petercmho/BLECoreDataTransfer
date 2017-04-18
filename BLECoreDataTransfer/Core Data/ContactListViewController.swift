
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
    
    private var _peripheralManager: CBPeripheralManager? = nil
    private var _centralManager: CBCentralManager? = nil
    
    private var peripheralManager: CBPeripheralManager {
        get {
            if self._centralManager != nil {
                self._centralManager = nil
            }
            if self._peripheralManager == nil {
                self._peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            }
            
            return self._peripheralManager!
        }
    }
    private var centralManager: CBCentralManager {
        get {
            if self._peripheralManager != nil {
                self._peripheralManager = nil
            }
            if self._centralManager == nil {
                self._centralManager = CBCentralManager(delegate: self, queue: nil)
            }
            
            return self._centralManager!
        }
    }
    private var discoverdPeripheral: CBPeripheral!
    
    private var contactToSend: Data?
    private var contactToReceive: Data?
    private var sendContactIndex: Int = 0
    private var receiveContactIndex: Int = 0
    private var receiveAlertView: UIAlertController?
    private var receiveProgressView: UIProgressView?
    
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
//        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
//        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if self._peripheralManager != nil {
            if self._peripheralManager!.isAdvertising {
                self._peripheralManager!.stopAdvertising()
            }
            self._peripheralManager?.removeAllServices()
            self._peripheralManager?.delegate = nil
            self._peripheralManager = nil
        }
        
        if self._centralManager != nil {
            self._centralManager?.delegate = nil
            self._centralManager = nil
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
        let testContact = ContactPacket(id: 0, firstName: "Peter", lastName: "Ho", age: 46, email: "petercmho@yahoo.ca", gender: true)
        let testPacketData = NSKeyedArchiver.archivedData(withRootObject: testContact)
        if let loadedContact = NSKeyedUnarchiver.unarchiveObject(with: testPacketData) as? ContactPacket {
            print("\(loadedContact.firstName) \(loadedContact.lastName)")
        }
        
        self.sendButton.isEnabled = false
        self.receiveButton.isEnabled = false
        if self.peripheralManager.state ==  .poweredOn && !self.peripheralManager.isAdvertising {
            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: TransferService.ContactsTransferServiceUUID)]])
        }
    }
    
    @IBAction func receiveCoreData(_ sender: Any) {
        self.sendButton.isEnabled = false
        self.receiveButton.isEnabled = false
        
        self.receiveAlertView = UIAlertController(title: "Receiving contact(s)", message: "Waiting for sending device...", preferredStyle: .alert)
        self.receiveAlertView?.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(self.receiveAlertView!, animated: true, completion: {
            let margin:CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: self.receiveAlertView!.view.frame.width - margin * 2.0, height: 2.0)
            let progressView = UIProgressView(frame: rect)
            progressView.progress = 0.0
            progressView.tintColor = UIColor.blue
            self.receiveProgressView = progressView
            self.receiveAlertView?.view.addSubview(progressView)
        })
        
        if self.centralManager.state == .poweredOn {
            scan()
        }
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
        print("peripheralManagerDidUpdateState( \(peripheral.state.rawValue) )")
        if peripheral.state != .poweredOn {
            return
        }
        
        // Start with the service
        let contactsTransferService = CBMutableService(type: CBUUID(string: TransferService.ContactsTransferServiceUUID), primary: true)
        
        // Add the characteristic to the service
        contactsTransferService.characteristics = [self.contactTransferCharacteristic]
        
        // And add it to the peripheral manager
        self.peripheralManager.add(contactsTransferService)
        
//        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: TransferService.ContactsTransferServiceUUID)]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheralManager(_ \(peripheral): didAdd: \(service) error: \(String(describing: error))")
        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: TransferService.ContactsTransferServiceUUID)]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("\(Utils.getCurrentTime()) - peripheralManager(_ \(peripheral) :central \(central) :didSubscribeTo: \(characteristic)) - Central subscribed to characteristic")
        
        guard let contact = fetchedResultsController.object(at: IndexPath(row: 0, section: 0)) as? PersonEntity
        else {
                return
        }
        
//        let contactPacket = ContactPacket(id: contact.id, firstName: contact.firstName!, lastName: contact.lastName!, age: contact.age, email: contact.email!, gender: contact.gender)
        let contactPacket = ContactPacket(id: contact.id, firstName: contact.firstName!, lastName: contact.lastName!, age: 46, email: "petercmho@yahoo.ca", gender: true)
        var contactPacketData = NSKeyedArchiver.archivedData(withRootObject: contactPacket)
        var contactPacketSize = contactPacketData.count + MemoryLayout<Int>.size
        self.contactToSend = Data(bytes: &contactPacketSize, count: MemoryLayout<Int>.size)
        self.contactToSend!.append(contactPacketData)
        self.sendContactIndex = 0
        
        if let deserializedContact = NSKeyedUnarchiver.unarchiveObject(with: contactPacketData) as? ContactPacket {
            print("\(deserializedContact.firstName) \(deserializedContact.lastName)")
        }
        
        sendContact()
    }
    
    /* More space in the peripheral's transmit queue becomes available, resend the update. */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("\(Utils.getCurrentTime()) - peripheralManagerIsReady(toUpdateSubscribers \(peripheral))")
        sendContact()
    }
    
    func sendContact() {
        guard let dataToSend = self.contactToSend
            else { return }
        
        if self.sendContactIndex >= dataToSend.count {
            return
        }
        
        var didSend = true
        
        while didSend {
            var amountToSend = dataToSend.count - self.sendContactIndex
            
            if amountToSend > ContactListViewController.NotifyMTU {
                amountToSend = ContactListViewController.NotifyMTU
            }
            
            // Copy out the data we want
            let chunk = dataToSend.subdata(in: self.sendContactIndex..<self.sendContactIndex+amountToSend)
            
            // Send it
            didSend = peripheralManager.updateValue(chunk, for: self.contactTransferCharacteristic, onSubscribedCentrals: nil)
            
            // If it didn't work, drop out and wait for peripheralManagerIsReady(toUpdateSubscribers:) callback
            if !didSend { return }
            
            print("\(Utils.getCurrentTime()) - Sent: \(chunk)")
            
            // It did send, so update our index
            self.sendContactIndex += amountToSend
            
            // Was it the last one?
            if self.sendContactIndex >= dataToSend.count {
                self.sendButton.isEnabled = true
                self.receiveButton.isEnabled = true
                return
            }
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralManagerDidUpdateState( \(central.state.rawValue) )")
        if central.state != .poweredOn {
            return
        }
        
        scan()
    }
    
    func scan() {
        self.centralManager.scanForPeripherals(withServices: [CBUUID(string: TransferService.ContactsTransferServiceUUID)], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        
        self.receiveContactIndex = 0
        self.contactToReceive = Data()
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
        print("\(Utils.getCurrentTime()) - Failed to connect to \(peripheral). (\(String(describing: error?.localizedDescription)))")
    }
    
    func cleanup() {
        print("\(Utils.getCurrentTime()) - cleanup")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\(Utils.getCurrentTime()) - centralManager(_ \(central) :didConnect \(peripheral)) - Peripheral connected")
        
        // Stop scanning
        self.centralManager.stopScan()
        print("\(Utils.getCurrentTime()) - Scanning stopped")
        
        guard let alertView = self.receiveAlertView
            else { return }
        
        alertView.title = "Receiving from \(peripheral.name ?? "Unknown")"
        alertView.message = "Calculating..."
        
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
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) : didUpdateValueFor \(characteristic) : error \(String(describing: error))")
        if let updateError = error {
            print("\(Utils.getCurrentTime()) - Error discovering characteristics: \(updateError.localizedDescription)")
            return
        }
        
        if self.contactToReceive == nil {
            return
        }
        
        if let cValue = characteristic.value {
            self.contactToReceive!.append(cValue)
        }
        
        let count = self.contactToReceive!.withUnsafeBytes { (ptr: UnsafePointer<Int>) -> Int in
            return ptr.pointee
        }
        
        self.receiveAlertView?.message = "Receiving"
        self.receiveProgressView?.progress = Float(self.contactToReceive!.count / count)
        
        if count == self.contactToReceive!.count {
            self.sendButton.isEnabled = true
            self.receiveButton.isEnabled = true
            
            // Reconstruct contact from data
            let contactPacketData = self.contactToReceive!.subdata(in: MemoryLayout<Int>.size..<self.contactToReceive!.count)
            let contactPacket = NSKeyedUnarchiver.unarchiveObject(with: contactPacketData) as? ContactPacket
            
            print("contactPacket is \(String(describing: contactPacket))")
            peripheral.setNotifyValue(false, for: characteristic)
        }
    }
    
    /* The peripheral letting us know whether our subscribe/unsubscribe happened or not. */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) : didUpdateNotificationStateFor \(characteristic) : error \(String(describing: error))")
        if let notificationError = error {
            print("Error changing notification state: \(notificationError.localizedDescription)")
        }
        
        // Exit if it is not the transfer characteristic
        if !characteristic.uuid.isEqual(CBUUID(string: TransferService.ContactsTransferCharacteristicUUID)) {
            return
        }
        
        if characteristic.isNotifying {
            // Notification has started
            print("Notification began on \(characteristic)")
        }
        else {
            // Notification has stopped
            // so disconnect from the peripheral
            print("Notification stopped on \(characteristic).  Disconnecting...")
            self.centralManager.cancelPeripheralConnection(peripheral)
        }
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
