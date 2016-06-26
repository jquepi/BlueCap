//
//  CentralManager.swift
//  BlueCap
//
//  Created by Troy Stribling on 6/4/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import Foundation
import CoreBluetooth

// MARK: - CentralManager -
public class CentralManager : NSObject, CBCentralManagerDelegate {

    internal static var CBCentralManagerStateKVOContext = UInt8()

    // MARK: Serialize Property IO
    static let ioQueue = Queue("us.gnos.blueCap.central-manager.io")

    // MARK: Properties
    private var _afterPowerOnPromise = Promise<Void>()
    private var _afterPowerOffPromise = Promise<Void>()
    private var _afterStateRestoredPromise = StreamPromise<(peripherals: [Peripheral], scannedServices: [CBUUID], options: [String:AnyObject])>()

    private var _isScanning = false
    private var _poweredOn = false
    private var _state = CBCentralManagerState.Unknown

    internal var _afterPeripheralDiscoveredPromise = StreamPromise<Peripheral>()
    internal var discoveredPeripherals = SerialIODictionary<NSUUID, Peripheral>(CentralManager.ioQueue)

    internal let centralQueue: Queue
    public private(set) var cbCentralManager: CBCentralManagerInjectable!

    private var afterPowerOnPromise: Promise<Void> {
        get {
            return CentralManager.ioQueue.sync { return self._afterPowerOnPromise }
        }
        set {
            CentralManager.ioQueue.sync { self._afterPowerOnPromise = newValue }
        }
    }

    private var afterPowerOffPromise: Promise<Void> {
        get {
            return CentralManager.ioQueue.sync { return self._afterPowerOffPromise }
        }
        set {
            CentralManager.ioQueue.sync { self._afterPowerOffPromise = newValue }
        }
    }

    internal var afterPeripheralDiscoveredPromise: StreamPromise<Peripheral> {
        get {
            return CentralManager.ioQueue.sync { return self._afterPeripheralDiscoveredPromise }
        }
        set {
            CentralManager.ioQueue.sync { self._afterPeripheralDiscoveredPromise = newValue }
        }
    }

    private var afterStateRestoredPromise: StreamPromise<(peripherals: [Peripheral], scannedServices: [CBUUID], options: [String:AnyObject])> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterStateRestoredPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterStateRestoredPromise = newValue }
        }
    }

    public var peripherals: [Peripheral] {
        return Array(self.discoveredPeripherals.values).sort() {(p1: Peripheral, p2: Peripheral) -> Bool in
            switch p1.discoveredAt.compare(p2.discoveredAt) {
            case .OrderedSame:
                return true
            case .OrderedDescending:
                return false
            case .OrderedAscending:
                return true
            }
        }
    }

    public private(set) var isScanning: Bool {
        get {
            return PeripheralManager.ioQueue.sync { return self._isScanning }
        }
        set {
            PeripheralManager.ioQueue.sync { self._isScanning = newValue }
        }
    }

    public private(set) var poweredOn: Bool {
        get {
            return PeripheralManager.ioQueue.sync { return self._poweredOn }
        }
        set {
            PeripheralManager.ioQueue.sync { self._poweredOn = newValue }
        }
    }

    public private(set) var state: CBCentralManagerState {
        get {
            return PeripheralManager.ioQueue.sync { return self._state }
        }
        set {
            PeripheralManager.ioQueue.sync { self._state = newValue }
        }
    }

    // MARK: Initializers
    public override init() {
        self.centralQueue = Queue("us.gnos.blueCap.central-manager.main")
        super.init()
        self.cbCentralManager = CBCentralManager(delegate: self, queue: self.centralQueue.queue)
        self.poweredOn = self.cbCentralManager.state == .PoweredOn
        self.startObserving()
    }

    public init(queue:dispatch_queue_t, options: [String:AnyObject]?=nil) {
        self.centralQueue = Queue(queue)
        super.init()
        self.cbCentralManager = CBCentralManager(delegate: self, queue: self.centralQueue.queue, options: options)
        self.poweredOn = self.cbCentralManager.state == .PoweredOn
        self.startObserving()
    }

    public init(centralManager: CBCentralManagerInjectable) {
        self.centralQueue = Queue("us.gnos.blueCap.central-manger.main")
        super.init()
        self.cbCentralManager = centralManager
        self.poweredOn = self.cbCentralManager.state == .PoweredOn
        self.startObserving()
    }

    deinit {
        self.cbCentralManager.delegate = nil
        self.stopObserving()
    }

    // MARK: KVO
    internal func startObserving() {
        guard let cbCentralManager = self.cbCentralManager as? CBCentralManager else {
            return
        }
        let options = NSKeyValueObservingOptions([.New, .Old])
        cbCentralManager.addObserver(self, forKeyPath: "state", options: options, context: &CentralManager.CBCentralManagerStateKVOContext)
    }

    internal func stopObserving() {
        guard let cbCentralManager = self.cbCentralManager as? CBCentralManager else {
            return
        }
        cbCentralManager.removeObserver(self, forKeyPath: "state", context: &CentralManager.CBCentralManagerStateKVOContext)
    }

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath != nil else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        switch (keyPath!, context) {
        case("state", &CentralManager.CBCentralManagerStateKVOContext):
            if let change = change, newValue = change[NSKeyValueChangeNewKey], oldValue = change[NSKeyValueChangeOldKey], newRawState = newValue as? Int, oldRawState = oldValue as? Int, newState = CBCentralManagerState(rawValue: newRawState) {
                if newRawState != oldRawState {
                    self.willChangeValueForKey("state")
                    self.state = newState
                    self.didChangeValueForKey("state")
                }
            }
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    // MARK: Power ON/OFF
    public func whenPowerOn() -> Future<Void> {
        self.afterPowerOnPromise = Promise<Void>()
        if self.poweredOn {
            Logger.debug("Central already powered on")
            self.afterPowerOnPromise.success()
        }
        return self.afterPowerOnPromise.future
    }

    public func whenPowerOff() -> Future<Void> {
        self.afterPowerOffPromise = Promise<Void>()
        if !self.poweredOn {
            self.afterPowerOffPromise.success()
        }
        return self.afterPowerOffPromise.future
    }

    // MARK: Manage Peripherals
    public func connectPeripheral(peripheral: Peripheral, options: [String:AnyObject]? = nil) {
        self.cbCentralManager.connectPeripheral(peripheral.cbPeripheral, options: options)
    }
    
    public func cancelPeripheralConnection(peripheral: Peripheral) {
        self.cbCentralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
    }

    public func disconnectAllPeripherals() {
        for peripheral in self.discoveredPeripherals.values {
            peripheral.disconnect()
        }
    }

    public func removeAllPeripherals() {
        self.discoveredPeripherals.removeAll()
    }

    // MARK: Scan
    public func startScanning(capacity: Int? = nil, options: [String:AnyObject]? = nil) -> FutureStream<Peripheral> {
        return self.startScanningForServiceUUIDs(nil, capacity: capacity)
    }
    
    public func startScanningForServiceUUIDs(uuids: [CBUUID]?, capacity: Int? = nil, options: [String:AnyObject]? = nil) -> FutureStream<Peripheral> {
        if !self.isScanning {
            Logger.debug("UUIDs \(uuids)")
            self.isScanning = true
            if let capacity = capacity {
                self.afterPeripheralDiscoveredPromise = StreamPromise<Peripheral>(capacity: capacity)
            } else {
                self.afterPeripheralDiscoveredPromise = StreamPromise<Peripheral>()
            }
            if self.poweredOn {
                self.cbCentralManager.scanForPeripheralsWithServices(uuids, options: options)
            } else {
                self.afterPeripheralDiscoveredPromise.failure(BCError.centralIsPoweredOff)
            }
        }
        return self.afterPeripheralDiscoveredPromise.future
    }
    
    public func stopScanning() {
        if self.isScanning {
            self.isScanning = false
            self.cbCentralManager.stopScan()
            self.afterPeripheralDiscoveredPromise = StreamPromise<Peripheral>()
        }
    }

    // MARK: State Restoration
    public func whenStateRestored() -> FutureStream<(peripherals: [Peripheral], scannedServices: [CBUUID], options: [String:AnyObject])> {
        self.afterStateRestoredPromise = StreamPromise<(peripherals: [Peripheral], scannedServices: [CBUUID], options: [String:AnyObject])>()
        return self.afterStateRestoredPromise.future
    }

    // MARK: Retrieve Peripherals
    public func retrieveConnectedPeripheralsWithServices(services: [CBUUID]) -> [Peripheral] {
        return self.cbCentralManager.retrieveConnectedPeripheralsWithServices(services).map { cbPeripheral in
            let newBCPeripheral: Peripheral
            if let oldBCPeripheral = self.discoveredPeripherals[cbPeripheral.identifier] {
                newBCPeripheral = Peripheral(cbPeripheral: cbPeripheral, bcPeripheral: oldBCPeripheral)
            } else {
                newBCPeripheral = Peripheral(cbPeripheral: cbPeripheral, centralManager: self)
            }
            self.discoveredPeripherals[cbPeripheral.identifier] = newBCPeripheral
            return newBCPeripheral
        }
    }

    func retrievePeripheralsWithIdentifiers(identifiers: [NSUUID]) -> [Peripheral] {
        return self.cbCentralManager.retrievePeripheralsWithIdentifiers(identifiers).map { cbPeripheral in
            let newBCPeripheral: Peripheral
            if let oldBCPeripheral = self.discoveredPeripherals[cbPeripheral.identifier] {
                newBCPeripheral = Peripheral(cbPeripheral: cbPeripheral, bcPeripheral: oldBCPeripheral)
            } else {
                newBCPeripheral = Peripheral(cbPeripheral: cbPeripheral, centralManager: self)
            }
            self.discoveredPeripherals[cbPeripheral.identifier] = newBCPeripheral
            return newBCPeripheral
        }
    }

    func retrievePeripherals() -> [Peripheral] {
        return self.retrievePeripheralsWithIdentifiers(self.discoveredPeripherals.keys)
    }

    // MARK: CBCentralManagerDelegate
    public func centralManager(_: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.didConnectPeripheral(peripheral)
    }

    public func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.didDisconnectPeripheral(peripheral, error:error)
    }

    public func centralManager(_: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String: AnyObject], RSSI: NSNumber) {
        self.didDiscoverPeripheral(peripheral, advertisementData:advertisementData, RSSI:RSSI)
    }

    public func centralManager(_: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.didFailToConnectPeripheral(peripheral, error:error)
    }

    public func centralManager(_: CBCentralManager, willRestoreState dict: [String: AnyObject]) {
        var injectablePeripherals: [CBPeripheralInjectable]?
        if let cbPeripherals: [CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            injectablePeripherals = cbPeripherals.map { $0 as CBPeripheralInjectable }
        }
        let scannedServices = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID]
        let options = dict[CBCentralManagerRestoredStateScanOptionsKey] as? [String: AnyObject]
        self.willRestoreState(injectablePeripherals, scannedServices: scannedServices, options: options)
    }
    
    public func centralManagerDidUpdateState(_: CBCentralManager) {
        self.didUpdateState()
    }

    // MARK: CBCentralManagerDelegate Shims
    internal func didConnectPeripheral(peripheral: CBPeripheralInjectable) {
        Logger.debug("uuid=\(peripheral.identifier.UUIDString), name=\(peripheral.name)")
        if let bcPeripheral = self.discoveredPeripherals[peripheral.identifier] {
            bcPeripheral.didConnectPeripheral()
        }
    }
    
    internal func didDisconnectPeripheral(peripheral: CBPeripheralInjectable, error: NSError?) {
        Logger.debug("uuid=\(peripheral.identifier.UUIDString), name=\(peripheral.name), error=\(error)")
        if let bcPeripheral = self.discoveredPeripherals[peripheral.identifier] {
            bcPeripheral.didDisconnectPeripheral(error)
        }
    }
    
    internal func didDiscoverPeripheral(peripheral: CBPeripheralInjectable, advertisementData: [String:AnyObject], RSSI: NSNumber) {
        if self.discoveredPeripherals[peripheral.identifier] == nil {
            let bcPeripheral = Peripheral(cbPeripheral: peripheral, centralManager: self, advertisements: advertisementData, RSSI: RSSI.integerValue)
            Logger.debug("uuid=\(bcPeripheral.identifier.UUIDString), name=\(bcPeripheral.name)")
            self.discoveredPeripherals[peripheral.identifier] = bcPeripheral
            self.afterPeripheralDiscoveredPromise.success(bcPeripheral)
        }
    }
    
    internal func didFailToConnectPeripheral(peripheral: CBPeripheralInjectable, error: NSError?) {
        Logger.debug()
        if let bcPeripheral = self.discoveredPeripherals[peripheral.identifier] {
            bcPeripheral.didFailToConnectPeripheral(error)
        }
    }

    internal func willRestoreState(cbPeripherals: [CBPeripheralInjectable]?, scannedServices: [CBUUID]?, options: [String: AnyObject]?) {
        Logger.debug()
        if let cbPeripherals = cbPeripherals, scannedServices = scannedServices, options = options {
            let peripherals = cbPeripherals.map { cbPeripheral -> Peripheral in
                let peripheral = Peripheral(cbPeripheral: cbPeripheral, centralManager: self)
                self.discoveredPeripherals[peripheral.identifier] = peripheral
                if let cbServices = cbPeripheral.getServices() {
                    for cbService in cbServices {
                        let service = Service(cbService: cbService, peripheral: peripheral)
                        peripheral.discoveredServices[service.UUID] = service
                        if let cbCharacteristics = cbService.getCharacteristics() {
                            for cbCharacteristic in cbCharacteristics {
                                let characteristic = Characteristic(cbCharacteristic: cbCharacteristic, service: service)
                                service.discoveredCharacteristics[characteristic.UUID] = characteristic
                                peripheral.discoveredCharacteristics[characteristic.UUID] = characteristic
                            }
                        }
                    }
                }
                return peripheral
            }
            self.afterStateRestoredPromise.success((peripherals, scannedServices, options))
        } else {
            self.afterStateRestoredPromise.failure(BCError.centralRestoreFailed)
        }
    }

    internal func didUpdateState() {
        self.poweredOn = self.cbCentralManager.state == .PoweredOn
        switch(self.cbCentralManager.state) {
        case .Unauthorized:
            Logger.debug("Unauthorized")
            break
        case .Unknown:
            Logger.debug("Unknown")
            break
        case .Unsupported:
            Logger.debug("Unsupported")
            if !self.afterPowerOnPromise.completed {
                self.afterPowerOnPromise.failure(BCError.centralStateUnsupported)
            }
            break
        case .Resetting:
            Logger.debug("Resetting")
            break
        case .PoweredOff:
            Logger.debug("PoweredOff")
            if !self.afterPowerOffPromise.completed {
                self.afterPowerOffPromise.success()
            }
            break
        case .PoweredOn:
            Logger.debug("PoweredOn")
            if !self.afterPowerOnPromise.completed {
                self.afterPowerOnPromise.success()
            }
            break
        }
    }
    
}
