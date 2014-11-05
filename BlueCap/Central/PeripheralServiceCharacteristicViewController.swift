//
//  PeripheralServiceCharacteristicViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 6/23/14.
//  Copyright (c) 2014 gnos.us. All rights reserved.
//

import UIKit
import BlueCapKit

class PeripheralServiceCharacteristicViewController : UITableViewController {

    struct MainStoryboard {
        static let peripheralServiceCharacteristicValueSegue                        = "PeripheralServiceCharacteristicValues"
        static let peripheralServiceCharacteristicEditWriteOnlyDiscreteValuesSegue  = "PeripheralServiceCharacteristicEditWriteOnlyDiscreteValues"
        static let peripheralServiceCharacteristicEditWriteOnlyValueSeque           = "PeripheralServiceCharacteristicEditWriteOnlyValue"
    }
    
    weak var characteristic                                 : Characteristic!
    var peripheralViewController                            : PeripheralViewController!
    
    @IBOutlet var valuesLabel                               : UILabel!

    @IBOutlet var notifySwitch                              : UISwitch!
    @IBOutlet var notifyLabel                               : UILabel!
    
    @IBOutlet var uuidLabel                                 : UILabel!
    @IBOutlet var broadcastingLabel                         : UILabel!
    @IBOutlet var notifyingLabel                            : UILabel!
    
    @IBOutlet var propertyBroadcastLabel                    : UILabel!
    @IBOutlet var propertyReadLabel                         : UILabel!
    @IBOutlet var propertyWriteWithoutResponseLabel         : UILabel!
    @IBOutlet var propertyWriteLabel                        : UILabel!
    @IBOutlet var propertyNotifyLabel                       : UILabel!
    @IBOutlet var propertyIndicateLabel                     : UILabel!
    @IBOutlet var propertyAuthenticatedSignedWritesLabel    : UILabel!
    @IBOutlet var propertyExtendedPropertiesLabel           : UILabel!
    @IBOutlet var propertyNotifyEncryptionRequiredLabel     : UILabel!
    @IBOutlet var propertyIndicateEncryptionRequiredLabel   : UILabel!
    
    required init(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func viewDidLoad()  {
        if let characteristic = self.characteristic {
            self.navigationItem.title = characteristic.name

            self.setUI()
            
            self.uuidLabel.text = characteristic.uuid.UUIDString
            self.notifyingLabel.text = self.booleanStringValue(characteristic.isNotifying)
            self.broadcastingLabel.text = self.booleanStringValue(characteristic.isBroadcasted)
            
            self.propertyBroadcastLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.Broadcast))
            self.propertyReadLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.Read))
            self.propertyWriteWithoutResponseLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.WriteWithoutResponse))
            self.propertyWriteLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.Write))
            self.propertyNotifyLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.Notify))
            self.propertyIndicateLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.Indicate))
            self.propertyAuthenticatedSignedWritesLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.AuthenticatedSignedWrites))
            self.propertyExtendedPropertiesLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.ExtendedProperties))
            self.propertyNotifyEncryptionRequiredLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.NotifyEncryptionRequired))
            self.propertyIndicateEncryptionRequiredLabel.text = self.booleanStringValue(characteristic.propertyEnabled(.IndicateEncryptionRequired))
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.Bordered, target:nil, action:nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.setUI()
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"peripheralDisconnected", name:BlueCapNotification.peripheralDisconnected, object:self.characteristic?.service.peripheral)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didBecomeActive", name:BlueCapNotification.didBecomeActive, object:nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didResignActive", name:BlueCapNotification.didResignActive, object:nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func prepareForSegue(segue:UIStoryboardSegue, sender:AnyObject!) {
        if segue.identifier == MainStoryboard.peripheralServiceCharacteristicValueSegue {
            let viewController = segue.destinationViewController as PeripheralServiceCharacteristicValuesViewController
            viewController.characteristic = self.characteristic
        } else if segue.identifier == MainStoryboard.peripheralServiceCharacteristicEditWriteOnlyDiscreteValuesSegue {
                let viewController = segue.destinationViewController as PeripheralServiceCharacteristicEditDiscreteValuesViewController
                viewController.characteristic = self.characteristic
        } else if segue.identifier == MainStoryboard.peripheralServiceCharacteristicEditWriteOnlyValueSeque {
            let viewController = segue.destinationViewController as PeripheralServiceCharacteristicEditValueViewController
            viewController.characteristic = self.characteristic
            if let stringValues = self.characteristic?.stringValues {
                let selectedIndex = sender as NSIndexPath
                let names = stringValues.keys.array
                viewController.valueName = names[selectedIndex.row]
            }
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier:String?, sender:AnyObject?) -> Bool {
        if let identifier = identifier {
            return (self.characteristic.propertyEnabled(.Read) || self.characteristic.isNotifying) && self.peripheralViewController.peripehealConnected
        } else {
            return false
        }
    }
    
    @IBAction func toggleNotificatons() {
        if let characteristic = self.characteristic {
            if characteristic.isNotifying {
                characteristic.stopNotifying({
                        characteristic.stopUpdates()
                    },
                    notificationStateChangedFailedCallback: {(error) in
                        self.notifySwitch.on = false
                        self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
                    })
            } else {
                characteristic.startNotifying({
                    },
                    notificationStateChangedFailedCallback:{(error) in
                        self.notifySwitch.on = false
                        self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
                    }
                )
            }
        }
    }
    
    func setUI() {
        if !self.characteristic.propertyEnabled(.Read) || !self.peripheralViewController.peripehealConnected {
            self.valuesLabel.textColor = UIColor.lightGrayColor()
        } else {
            self.valuesLabel.textColor = UIColor.blackColor()
        }
        if self.characteristic.propertyEnabled(.Notify)  && self.peripheralViewController.peripehealConnected {
            self.notifyLabel.textColor = UIColor.blackColor()
            self.notifySwitch.enabled = true
            self.notifySwitch.on = self.characteristic.isNotifying
        } else {
            self.notifyLabel.textColor = UIColor.lightGrayColor()
            self.notifySwitch.enabled = false
            self.notifySwitch.on = false
        }
    }
    
    func booleanStringValue(value:Bool) -> String {
        return value ? "YES" : "NO"
    }
    
    func peripheralDisconnected() {
        Logger.debug("PeripheralServiceCharacteristicViewController#peripheralDisconnected")
        if self.peripheralViewController.peripehealConnected {
            self.presentViewController(UIAlertController.alertWithMessage("Peripheral disconnected") {(action) in
                    self.peripheralViewController.peripehealConnected = false
                    self.setUI()
                }, animated:true, completion:nil)
        }
    }

    func didResignActive() {
        self.navigationController?.popToRootViewControllerAnimated(false)
       Logger.debug("PeripheralServiceCharacteristicViewController#didResignActive")
    }
    
    func didBecomeActive() {
        Logger.debug("PeripheralServiceCharacteristicViewController#didBecomeActive")
    }
    
    override func tableView(tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        if indexPath.row == 0 {
            if let characteristic = self.characteristic {
                if (characteristic.propertyEnabled(.Write) || characteristic.propertyEnabled(.WriteWithoutResponse)) && !characteristic.propertyEnabled(.Read) {
                    if characteristic.discreteStringValues.isEmpty {
                        self.performSegueWithIdentifier(MainStoryboard.peripheralServiceCharacteristicEditWriteOnlyValueSeque, sender:indexPath)
                    } else {
                        self.performSegueWithIdentifier(MainStoryboard.peripheralServiceCharacteristicEditWriteOnlyDiscreteValuesSegue, sender:indexPath)
                    }
                }
            }
        }
    }

}
