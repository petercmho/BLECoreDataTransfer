//
//  CentralViewController.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-02-20.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import UIKit
import CoreBluetooth

class CentralViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var textView: UITextView!
    
    private var centralManager: CBCentralManager?
    private var data: NSMutableData?
    private var discoveredPeripheral: CBPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        data = NSMutableData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.centralManager?.stopScan()
        print("Scanning stopped")
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\(Utils.getCurrentTime()) - centralManagerDidUpdateState(_:)")
        if central.state != .poweredOn {
            return
        }
        
        self.scan()
    }
    
    func scan() {
        self.centralManager?.scanForPeripherals(withServices: [CBUUID(string: TransferService.TransferServiceUUID)], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        print("\(Utils.getCurrentTime()) - Scanning started")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssiString = String(format: "%1.2f", RSSI.floatValue)
        print("\(Utils.getCurrentTime()) - did discover peripheral: \(peripheral.identifier.uuidString), data: \(advertisementData), RSSI: \(rssiString)")
        if RSSI.intValue > -15 || RSSI.intValue < -35 {
            return
        }
        
        print("\(Utils.getCurrentTime()) - Discovered \(peripheral.name) at \(RSSI)")
        
        if self.discoveredPeripheral != peripheral {
            self.discoveredPeripheral = peripheral
            print("\(Utils.getCurrentTime()) - Connecting to peripheral \(peripheral)")
            self.centralManager?.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("\(Utils.getCurrentTime()) - Failed to connect to \(peripheral). (\(error?.localizedDescription)")
        self.cleanup()
    }
    
    /*
     We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\(Utils.getCurrentTime()) - centralManager(_ \(central) :didConnect \(peripheral)) -Peripheral connected")
        
        // Stop scanning
        self.centralManager?.stopScan()
        print("\(Utils.getCurrentTime()) - Scanning stopped")
        
        // Clear the data that we may already have
        self.data?.length = 0
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([CBUUID(string: TransferService.TransferServiceUUID)])
    }
    
    /* The Transfer Service was discovered */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverServices:")
        if let discoverError = error {
            print("\(Utils.getCurrentTime()) - Error discovering services: \(discoverError.localizedDescription)")
            self.cleanup()
            return
        }
        
        // Discover the characteristic we want...
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics([CBUUID(string: TransferService.TransferCharacteristicUUID)], for: service)
            }
        }
    }
    
    /* The Transfer characteristic was discovered.
        Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_:didDiscoverCharacteristicsFor:error:)")
        // Deal with errors (if any)
        if let discoverError = error {
            print("Error discovering characteristics: \(discoverError.localizedDescription)")
            self.cleanup()
            return
        }
        
        // Again, we loop through the array, just in case.
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // And check if it's the right one
                if characteristic.uuid.isEqual(CBUUID(string: TransferService.TransferCharacteristicUUID)) {
                    // If it is, subscribe to it
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /* This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) :didUpdateValueFor \(characteristic) : \(error))")
        if let updateError = error {
            print("\(Utils.getCurrentTime()) - Error discovering characteristics: \(updateError.localizedDescription)")
            return
        }
        
        if let cValue = characteristic.value {
            let stringFromData = String(bytes: cValue, encoding: String.Encoding.utf8)
            
            // Have we got everything we need?
            if stringFromData == "EOM" {
                // We have, so show the data,
                self.textView.text = String(data: self.data! as Data, encoding: String.Encoding.utf8)
                
                // Cancel our subscription to the characteristic
                peripheral.setNotifyValue(false, for: characteristic)
                
                // and disconnect from the peripheral
                self.centralManager?.cancelPeripheralConnection(peripheral)
            }
            
            // Otherwise, just add the data on to what we already have
            self.data?.append(cValue)
            
            // Log it
            print("\(Utils.getCurrentTime()) - Received: \(stringFromData)")
        }
    }
    
    /* The peripheral letting us know whether our subscribe/unsubscribe happened or not
    */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("\(Utils.getCurrentTime()) - peripheral(_ \(peripheral) :didUpdateNotificationStateFor \(characteristic) : \(error))")
        if let notificationError = error {
            print("Error changing notification state: \(notificationError.localizedDescription)")
        }
        
        // Exit if it's not the transfer characteristic
        if !characteristic.uuid.isEqual(CBUUID(string: TransferService.TransferCharacteristicUUID)) {
            return
        }
        
        // Notification has started
        if characteristic.isNotifying {
            print("Notification began on \(characteristic)")
        }
        
        // Notification has stopped
        else {
            // so disconnect from the peripheral
            print("Notification stopped on \(characteristic).  Disconnecting")
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    /* Once the disconnection happens, we need to clean up our local copy of the peripheral
    */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("\(Utils.getCurrentTime()) - centralManager(_ \(central) :didDisconnectPeripheral \(peripheral) : \(error)) - Peripheral Disconnected")
        self.discoveredPeripheral = nil
        
        // We're disconnected, so start scanning again
        self.scan()
    }
    
    /* Call this when things either go wrong, or you're done with the connection.
     This cancels any subscriptions if there are any, or straight disconnects if not.
     (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
    */
    func cleanup() {
        // Don't do anything if we're not connected
        print("\(Utils.getCurrentTime()) - cleanup()")
        if self.discoveredPeripheral?.state == .connected {
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        if let services = self.discoveredPeripheral?.services {
            for service in services {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        if characteristic.uuid.isEqual(CBUUID(string: TransferService.TransferCharacteristicUUID)) {
                            if characteristic.isNotifying {
                                self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                                return
                            }
                        }
                    }
                }
            }
        }
        
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        self.centralManager?.cancelPeripheralConnection(self.discoveredPeripheral!)
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
