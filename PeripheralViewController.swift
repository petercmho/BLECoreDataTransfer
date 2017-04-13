//
//  PeripheralViewController.swift
//  BLECoreDataTransfer
//
//  Created by Peter Ho on 2017-02-21.
//  Copyright © 2017 Peter Ho. All rights reserved.
//

import UIKit
import CoreBluetooth

class PeripheralViewController: UIViewController, CBPeripheralManagerDelegate, UITextViewDelegate {

    // MARK: UI Properties
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var advertisingSwitch: UISwitch!
    
    // MARK: Constants
    let NotifiyMTU = 20
    
    // MARK: Class properties
    static var sendingEOM = false
    
    // MARK: Properties
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    private var dataToSend: NSData?
    private var sendDataIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.peripheralManager?.stopAdvertising()
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    /* Required protocol method.  A full app should take care of all the possible states, but we're just waiting for to know when the CBPeripheralManager is ready
    */
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Opt out from any other state
        if peripheral.state != .poweredOn {
            return
        }
        
        // We're in CBPeripheralManagerStatePoweredOn state...
        print("\(Utils.getCurrentTime()) - self.peripheralManager powered on.")
        
        // ... so build our service.
        
        // Start with the CBMutableCharacteristic
        self.transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TransferService.TransferCharacteristicUUID), properties: CBCharacteristicProperties.notify, value: nil, permissions: CBAttributePermissions.readable)
        
        // Then the service
        let transferService = CBMutableService(type: CBUUID(string: TransferService.TransferServiceUUID), primary: true)
        
        // Add the characteristic to the service
        transferService.characteristics = [self.transferCharacteristic!]
        
        // And add it to the peripheral manager
        self.peripheralManager?.add(transferService)
    }
    
    /* Catch when someone subscribes to our characteristic, then start sending them data
    */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("\(Utils.getCurrentTime()) - peripheralManager(\(peripheral):central \(central) :didSubscribeTo \(characteristic)) - Central subscribed to characteristic")
        
        // Get the data
        self.dataToSend = self.textView.text.data(using: String.Encoding.utf8) as NSData?
        
        // Reset the index
        self.sendDataIndex = 0
        
        // Start sending
        self.sendData()
    }
    
    /* Recognise when the central unsubscribes
    */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("\(Utils.getCurrentTime()) - Central unsubscribed from characteristic")
    }
    
    /* Sends the next amount of data to the connected central
    */
    func sendData() {
        if peripheralManager == nil { return }
        
        // First up, check if we're meant to be sending an EOM
        if PeripheralViewController.sendingEOM {
            
            // send it
            if let data = "EOM".data(using: .utf8),
                let characteristic = transferCharacteristic,
                let manager = peripheralManager {
                
                // Did it send?
                if manager.updateValue(data, for: characteristic, onSubscribedCentrals: nil) {
                    // It did, so mark it as sent
                    PeripheralViewController.sendingEOM = false
                    
                    print("\(Utils.getCurrentTime()) - Sent: EOM")
                }
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        
        if self.sendDataIndex >= self.dataToSend?.length ?? 0 {
            // No data left. Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        
        var didSend = true
        
        while didSend && self.dataToSend != nil {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = self.dataToSend!.length - self.sendDataIndex
            
            // Can't be longer than 20 bytes
            if amountToSend > NotifiyMTU {
                amountToSend = NotifiyMTU
            }
            
            // Copy out the data we want
            let chunk = NSData(bytes: self.dataToSend!.bytes + self.sendDataIndex, length: amountToSend)
            
            // Send it
            didSend = self.peripheralManager!.updateValue(chunk as Data, for: self.transferCharacteristic!, onSubscribedCentrals: nil)
            
            // If it didn't work, drop out and wait for the callback
            if !didSend { return }
            
            let stringFromData = String(data: chunk as Data, encoding: .utf8)
            print("\(Utils.getCurrentTime()) - Sent: \(String(describing: stringFromData))")
            
            // It did send, so update our index
            self.sendDataIndex += amountToSend
            
            // Was it the last one?
            if self.sendDataIndex >= self.dataToSend!.length {
                // It was - send and EOM
                
                // Set this so if the send fails, we'll send it next time
                PeripheralViewController.sendingEOM = true
                
                // Send it
                if peripheralManager!.updateValue("EOM".data(using: .utf8)!, for: self.transferCharacteristic!, onSubscribedCentrals: nil) {
                    PeripheralViewController.sendingEOM = false
                    print("\(Utils.getCurrentTime()) - Sent: EOM")
                }
                
                return
            }
        }
    }
    
    /* This callback comes in when the PeripheralManager is ready to send the next chunk of data.  This is to ensure that packets will arrive in the order they are sent
    */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        print("\(Utils.getCurrentTime()) - peripheralManagerIsReady(toUpdateSubscribers peripheral: \(peripheral))")
        self.sendData()
    }
    
    // MARK: - TextView methods
    
    /* This is called when a change happens, so we know to stop advertising
    */
    func textViewDidChange(_ textView: UITextView) {
        // If we're already advertising, stop
        if self.advertisingSwitch.isOn {
            self.advertisingSwitch.isOn = false
            self.peripheralManager?.stopAdvertising()
        }
    }
    
    /* Adds the 'Done' button to the title bar
    */
    func textViewDidBeginEditing(_ textView: UITextView) {
        // We need to add this manually so we have a way to dismiss the keyboard
        let rightButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        self.navigationItem.rightBarButtonItem = rightButton
    }
    
    func dismissKeyboard() {
        self.textView.resignFirstResponder()
        self.navigationItem.rightBarButtonItem = nil
    }
    
    // MARK: - Switch methods
    @IBAction func switchChanged(_ sender: Any) {
        if self.advertisingSwitch.isOn {
            print("\(Utils.getCurrentTime()) - Start advertising")
            self.peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: TransferService.TransferServiceUUID)]])
        }
        else {
            print("\(Utils.getCurrentTime()) - Stop advertising")
            self.peripheralManager?.stopAdvertising()
        }
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
