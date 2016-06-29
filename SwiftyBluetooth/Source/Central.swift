//
//  Central.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import Foundation
import CoreBluetooth

public let BluetoothPeripheralsInvalidatedEvent = "BluetoothPeripheralsInvalidatedEvent"

public enum PeripheralScanResult {
    case ScanStarted
    case ScanResult(peripheral: Peripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    case ScanStopped(error: BleError?)
}

public typealias InitializeBluetoothCallback = (error: BleError?) -> Void
public typealias PeripheralScanCallback = (result: PeripheralScanResult) -> Void
public typealias PeripheralConnectCallback = (error: BleError?) -> Void
public typealias PeripheralDisconnectCallback = (error: BleError?) -> Void

public final class Central {
    public static let sharedInstance = Central()
    
    private let centralDelegate: CentralDelegate = CentralDelegate()
    
    private init() {}
    
    func initializeBluetooth(completion: InitializeBluetoothCallback) {
        centralDelegate.initializeBluetooth(completion)
    }
    
    public func scanWithTimeout(timeout: NSTimeInterval,
                                serviceUUIDs: [CBUUIDConvertible]?,
                                completion: PeripheralScanCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all peripherals but 
        // it is recommended to pass in nil for those cases similarly to how the CoreBluetooth scan method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        
        centralDelegate.scanWithTimeout(timeout, serviceUUIDs: ExtractCBUUIDs(serviceUUIDs), completion)
    }
    
    public func stopScan() {
        centralDelegate.stopScan()
    }
    
    func connectPeripheral(peripheral: Peripheral,
                           timeout: NSTimeInterval = 5,
                           completion: PeripheralConnectCallback)
    {
        centralDelegate.connectPeripheral(peripheral, timeout: timeout, completion)
    }
    
    func disconnectPeripheral(peripheral: Peripheral,
                              timeout: NSTimeInterval = 5,
                              completion: PeripheralDisconnectCallback)
    {
        centralDelegate.disconnectPeripheral(peripheral, timeout: timeout, completion)
    }
}

private final class PeripheralScanRequest {
    let callback: PeripheralScanCallback
    
    init(callback: PeripheralScanCallback) {
        self.callback = callback
    }
}

private final class ConnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: Peripheral
    
    init(peripheral: Peripheral, callback: PeripheralConnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: BleError?) {
        for callback in callbacks {
            callback(error: error)
        }
    }

}

private final class DisconnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: Peripheral
    
    init(peripheral: Peripheral, callback: PeripheralDisconnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: BleError?) {
        for callback in callbacks {
            callback(error: error)
        }
    }
}

private final class CentralDelegate: NSObject {
    lazy var initializeBluetoothCallbacks: [InitializeBluetoothCallback] = []
    
    var scanRequest: PeripheralScanRequest?
    
    lazy var connectRequests: [NSUUID: ConnectPeripheralRequest] = [:]
    lazy var disconnectRequests: [NSUUID: DisconnectPeripheralRequest] = [:]
    
    let centralManager: CBCentralManager = CBCentralManager(delegate: nil, queue: nil)
    override init() {
        super.init()
        centralManager.delegate = self
    }
    
    func initializeBluetooth(completion: InitializeBluetoothCallback) {
        switch centralManager.state {
            case .Unknown:
                self.initializeBluetoothCallbacks.append(completion)
            case .Resetting:
                self.initializeBluetoothCallbacks.append(completion)
            case .Unsupported:
                completion(error: .BleUnsupported)
            case .Unauthorized:
                completion(error: .BleUnauthorized)
            case .PoweredOff:
                completion(error: .BlePoweredOff)
            case .PoweredOn:
                completion(error: nil)
        }
    }
    
    func callInitializeBluetoothCallbacksWithError(error: BleError?) {
        let callbacks = self.initializeBluetoothCallbacks
        
        self.initializeBluetoothCallbacks.removeAll()
        
        for callback in callbacks {
            callback(error: error)
        }
    }
    
    func scanWithTimeout(timeout: NSTimeInterval, serviceUUIDs: [CBUUID]?, _ callback: PeripheralScanCallback) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(result: PeripheralScanResult.ScanStopped(error: error))
            } else {
                
                if let currentScanRequest = self.scanRequest {
                    self.centralManager.stopScan()
                }
                
                let scanRequest = PeripheralScanRequest(callback: callback)
                self.scanRequest = scanRequest
                
                scanRequest.callback(result: .ScanStarted)
                self.centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: nil)
        
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onScanTimerTick),
                    userInfo: Weak(value: scanRequest),
                    repeats: false)
            }
        }
    }
    
    func stopScan() {
        self.centralManager.stopScan()
        if let scanRequest = self.scanRequest {
            self.scanRequest = nil
            scanRequest.callback(result: .ScanStopped(error: nil))
        }
    }
    
    @objc private func onScanTimerTick(timer: NSTimer) {
        
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<PeripheralScanRequest>
        
        if let request = weakRequest.value {
            self.stopScan()
        }
    }
    
    func connectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            
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
            
            if let request = self.connectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = ConnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.connectRequests[uuid] = request
                
                self.centralManager.connectPeripheral(peripheral.cbPeripheral, options: nil)
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onConnectTimerTick),
                    userInfo: Weak(value: request),
                    repeats: false)
            }
        }
    }
    
    @objc private func onConnectTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ConnectPeripheralRequest>
        guard let request = weakRequest.value else {
            return
        }
        
        let uuid = request.peripheral.identifier
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(BleError.BleTimeoutError)
    }
    
    func disconnectPeripheral(peripheral: Peripheral, timeout: NSTimeInterval = 5, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            
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
            
            if let request = self.disconnectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = DisconnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.disconnectRequests[uuid] = request
                
                self.centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
                NSTimer.scheduledTimerWithTimeInterval(
                    timeout,
                    target: self,
                    selector: #selector(self.onDisconnectTimerTick),
                    userInfo: Weak(value: request),
                    repeats: false)
            }
        }
    }

    @objc private func onDisconnectTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<DisconnectPeripheralRequest>
        guard let request = weakRequest.value else {
            return
        }
        
        let uuid = request.peripheral.identifier
        
        self.disconnectRequests[uuid] = nil
        
        request.invokeCallbacks(BleError.BleTimeoutError)
    }
}

extension CentralDelegate: CBCentralManagerDelegate {
    @objc private func centralManagerDidUpdateState(central: CBCentralManager) {
        
        func sendInvalidatePeripheralsEvent() {
            NSNotificationCenter.defaultCenter().postNotificationName(
                BluetoothPeripheralsInvalidatedEvent,
                object: Central.sharedInstance,
                userInfo: nil)
        }
        
        switch centralManager.state {
            case .Unknown:
                sendInvalidatePeripheralsEvent()
            case .Resetting:
                sendInvalidatePeripheralsEvent()
            case .Unsupported:
                sendInvalidatePeripheralsEvent()
                callInitializeBluetoothCallbacksWithError(.BleUnsupported)
            case .Unauthorized:
                sendInvalidatePeripheralsEvent()
                callInitializeBluetoothCallbacksWithError(.BleUnauthorized)
            case .PoweredOff:
                callInitializeBluetoothCallbacksWithError(.BlePoweredOff)
            case .PoweredOn:
                callInitializeBluetoothCallbacksWithError(nil)
        }
    }
    
    @objc private func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(nil)
    }
    
    @objc private func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        let uuid = peripheral.identifier
        guard let request = self.disconnectRequests[uuid] else {
            return
        }
        
        self.disconnectRequests[uuid] = nil
        
        var bleError: BleError?
        if let error = error {
            bleError = BleError.CoreBluetoothError(error: error)
        }
        
        request.invokeCallbacks(bleError)
    }
    
    @objc private func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        var bleError: BleError?
        if let error = error {
            bleError = .CoreBluetoothError(error: error)
        } else {
            bleError = BleError.PeripheralFailedToConnectReasonUnknown
        }
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(bleError)
    }
    
    @objc private func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {

        guard let scanRequest = scanRequest else {
            return
        }
        
        let peripheral = Peripheral(peripheral: peripheral)
        
        scanRequest.callback(result: .ScanResult(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI))
    }
}