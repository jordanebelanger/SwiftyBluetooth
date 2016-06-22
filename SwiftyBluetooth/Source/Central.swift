//
//  Central.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import Foundation
import CoreBluetooth

public let BluetoothStateChangeEvent = "SwiftyBluetoothBluetoothStateChangeEvent"

public enum BleScanCallback {
    case BleScanStarted
    case BleScanResult(peripheral: Peripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    case BleScanStopped(error: BleError?)
}

public final class Central {
    public static let sharedInstance = Central()
    
    private let centralProxy: CentralProxy = CentralProxy()
    
    private init() {}
    
    func initializeBluetooth(completion: (error: BleError?) -> Void) {
        centralProxy.initializeBluetooth(completion)
    }
    
    public func scanWithTimeout(timeout: NSTimeInterval, serviceUUIDs: [CBUUIDConvertible]?, _ callback: (result: BleScanCallback) -> Void) {
        centralProxy.scanWithTimeout(timeout, serviceUUIDs: serviceUUIDs, callback)
    }
    
    public func stopScan() {
        centralProxy.stopScan()
    }
    
    func connectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        centralProxy.connectPeripheral(peripheral, timeout: timeout, callback)
    }
    
    func disconnectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        centralProxy.disconnectPeripheral(peripheral, timeout: timeout, callback)
    }
}


private final class CentralProxy: NSObject {
    var stateCallbacks: [(error: BleError?) -> Void] = []
    
    var peripherals: [NSUUID: Peripheral] = [:]
    var scanCallback: Box<(result: BleScanCallback) -> Void>?
    
    var connectCallbacks: [NSUUID: [(error: BleError?) -> Void]] = [:]
    var disconnectCallbacks: [NSUUID: [(error: BleError?) -> Void]] = [:]
    
    let centralManager: CBCentralManager = CBCentralManager(delegate: nil, queue: nil)
    override init() {
        super.init()
        centralManager.delegate = self
    }
    
    func invalidatePeripherals() {
        objc_sync_enter(self)
        for (_, peripheral) in peripherals {
            peripheral.valid = false
        }
        peripherals.removeAll()
        objc_sync_exit(self)
    }
    
    func initializeBluetooth(completion: (error: BleError?) -> Void) {
        switch centralManager.state {
            case .Unknown:
                self.invalidatePeripherals()
                registerStateCallback(completion)
            case .Resetting:
                self.invalidatePeripherals()
                registerStateCallback(completion)
            case .Unsupported:
                self.invalidatePeripherals()
                completion(error: .BleUnsupported)
            case .Unauthorized:
                self.invalidatePeripherals()
                completion(error: .BleUnauthorized)
            case .PoweredOff:
                completion(error: .BlePoweredOff)
            case .PoweredOn:
                completion(error: nil)
        }
    }
    private func registerStateCallback(callback: (error: BleError?) -> Void) {
        objc_sync_enter(self)
        stateCallbacks.append(callback)
        objc_sync_exit(self)
    }
    private func callStateCallbacksWithError(error: BleError?) {
        objc_sync_enter(self)
        for callback in stateCallbacks {
            callback(error: error)
        }
        stateCallbacks.removeAll()
        objc_sync_exit(self)
    }
    
    func scanWithTimeout(timeout: NSTimeInterval, serviceUUIDs: [CBUUIDConvertible]?, _ callback: (result: BleScanCallback) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(result: .BleScanStopped(error: error))
            } else {
                
                objc_sync_enter(self)
                if let scanCallback = self.scanCallback?.value {
                    self.scanCallback = nil
                    scanCallback(result: .BleScanStopped(error: nil))
                }
                objc_sync_exit(self)
                
                let boxedCallback = Box(value: callback)
                self.scanCallback = boxedCallback
                
                let cbUUIDs: [CBUUID]? = serviceUUIDs?.map({ (serviceUUID) -> CBUUID in
                    return serviceUUID.CBUUIDRepresentation
                })
                
                callback(result: .BleScanStarted)
                self.centralManager.scanForPeripheralsWithServices(cbUUIDs, options: nil)
        
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onScanTimerTick),
                    userInfo: Weak(value: boxedCallback), 
                    repeats: false)
            }
        }
    }
    
    func stopScan() {
        objc_sync_enter(self)
        self.centralManager.stopScan()
        if let scanCallback = self.scanCallback?.value {
            self.scanCallback = nil
            scanCallback(result: .BleScanStopped(error: nil))
        }
        objc_sync_exit(self)
    }
    
    @objc private func onScanTimerTick(timer: NSTimer) {
        objc_sync_enter(self)
        
        defer {
            if timer.valid { timer.invalidate() }
            objc_sync_exit(self)
        }
        
        let weakBoxedCallback = timer.userInfo as! Weak<Box<(result: BleScanCallback) -> Void>>
        
        guard let scanCallback = weakBoxedCallback.value?.value else {
            return
        }
        
        self.scanCallback = nil
        scanCallback(result: .BleScanStopped(error: nil))
    }
    
    func connectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            objc_sync_enter(self)
            defer {
                objc_sync_exit(self)
            }
            
            if let error = error {
                callback(error: error)
                return
            }
            
            let uuid = peripheral.cbPeripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first
                where cbPeripheral.state == .Connected {
                callback(error: nil)
                return
            }
            
            if var callbacks = self.connectCallbacks[uuid] {
                callbacks.append(callback)
                self.connectCallbacks[uuid] = callbacks
            } else {
                self.connectCallbacks[uuid] = [callback]
                self.centralManager.connectPeripheral(peripheral.cbPeripheral, options: nil)
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onConnectTimerTick),
                    userInfo: ["uuid": uuid, "peripheral": peripheral],
                    repeats: false)
            }
        }
    }
    
    @objc private func onConnectTimerTick(timer: NSTimer) {
        objc_sync_enter(self)
        
        defer {
            if timer.valid { timer.invalidate() }
            objc_sync_exit(self)
        }
        
        let uuid = timer.userInfo!["uuid"] as! NSUUID
        guard let callbacks = self.connectCallbacks[uuid] else {
            return
        }
        
        var bleError: BleError?
        if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first where cbPeripheral.state != .Connected {
            bleError = .BleTimeoutError
        }
        
        self.connectCallbacks[uuid] = nil
        for callback in callbacks {
            callback(error: bleError)
        }
    }
    
    func disconnectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            objc_sync_enter(self)
            defer {
                objc_sync_exit(self)
            }
            
            if let error = error {
                callback(error: error)
                return
            }
            
            let uuid = peripheral.cbPeripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first
                where cbPeripheral.state == .Disconnected || cbPeripheral.state == .Disconnecting {
                callback(error: nil)
                return
            }
            
            if var callbacks = self.disconnectCallbacks[uuid] {
                callbacks.append(callback)
                self.disconnectCallbacks[uuid] = callbacks
            } else {
                let callbacks = [callback]
                self.disconnectCallbacks[uuid] = callbacks
                
                self.centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onDisconnectTimerTick),
                    userInfo: ["uuid": uuid, "peripheral": peripheral],
                    repeats: false)
            }
        }
    }
    
    @objc private func onDisconnectTimerTick(timer: NSTimer) {
        objc_sync_enter(self)
        
        defer {
            if timer.valid { timer.invalidate() }
            objc_sync_exit(self)
        }
        
        let uuid = timer.userInfo!["uuid"] as! NSUUID
        guard let callbacks = self.disconnectCallbacks[uuid] else {
            return
        }
        
        var bleError: BleError?
        if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first where cbPeripheral.state != .Disconnected {
            bleError = .BleTimeoutError
        }
        
        self.disconnectCallbacks[uuid] = nil
        for callback in callbacks {
            callback(error: bleError)
        }
    }
}

extension CentralProxy: CBCentralManagerDelegate {
    @objc private func centralManagerDidUpdateState(central: CBCentralManager) {
        switch centralManager.state {
        case .Unknown:
            self.invalidatePeripherals()
        case .Resetting:
            self.invalidatePeripherals()
        case .Unsupported:
            self.invalidatePeripherals()
            callStateCallbacksWithError(.BleUnsupported)
        case .Unauthorized:
            self.invalidatePeripherals()
            callStateCallbacksWithError(.BleUnauthorized)
        case .PoweredOff:
            callStateCallbacksWithError(.BlePoweredOff)
        case .PoweredOn:
            callStateCallbacksWithError(nil)
        }
        
//        NSNotificationCenter.defaultCenter().postNotificationName(
//            BluetoothStateChangeEvent,
//            object: Central.sharedInstance,
//            userInfo: ["state": centralManager.state])
    }
    
    @objc private func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        let uuid = peripheral.identifier
        guard let callbacks = self.connectCallbacks[uuid] else {
            return
        }
        
        self.connectCallbacks[uuid] = nil
        for callback in callbacks {
            callback(error: nil)
        }
    }
    
    @objc private func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        let uuid = peripheral.identifier
        guard let callbacks = self.disconnectCallbacks[uuid] else {
            return
        }
        
        var bleError: BleError?
        if let error = error {
            bleError = .CoreBluetoothError(error: error)
        }
        
        self.disconnectCallbacks[uuid] = nil
        for callback in callbacks {
            callback(error: bleError)
        }
    }
    
    @objc private func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        let uuid = peripheral.identifier
        guard let callbacks = self.connectCallbacks[uuid] else {
            return
        }
        
        var bleError: BleError?
        if let error = error {
            bleError = .CoreBluetoothError(error: error)
        }
        
        self.connectCallbacks[uuid] = nil
        for callback in callbacks {
            callback(error: bleError)
        }
    }
    
    @objc private func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        guard let scanCallback = scanCallback?.value else {
            return
        }
        
        let peripheral = Peripheral(peripheral: peripheral)
        peripherals[peripheral.cbPeripheral.identifier] = peripheral
        
        scanCallback(result: .BleScanResult(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI))
    }
}