//
//  CentralProxy.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

final class CentralProxy: NSObject {
    private lazy var initializeBluetoothCallbacks: [InitializeBluetoothCallback] = []
    
    private var scanRequest: PeripheralScanRequest?
    
    private lazy var connectRequests: [NSUUID: ConnectPeripheralRequest] = [:]
    private lazy var disconnectRequests: [NSUUID: DisconnectPeripheralRequest] = [:]
    
    private let centralManager: CBCentralManager
    
    override init() {
        self.centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }
    
    func postPeripheralsInvalidatedEvent() {
        NSNotificationCenter.defaultCenter().postNotificationName(PeripheralsInvalidatedEvent, object: Central.sharedInstance)
    }
    
    var bluetoothState: CBCentralManagerState {
        get {
            return self.centralManager.state
        }
    }
    
    var isScanning: Bool {
        get {
            return self.centralManager.isScanning
        }
    }
}

/// Mark: Initialize Bluetooth requests
extension CentralProxy {
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
}

/// Mark: Scan requests
private final class PeripheralScanRequest {
    let callback: PeripheralScanCallback
    
    init(callback: PeripheralScanCallback) {
        self.callback = callback
    }
}

extension CentralProxy {
    func scanWithTimeout(timeout: NSTimeInterval, serviceUUIDs: [CBUUID]?, _ callback: PeripheralScanCallback) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(scanResult: PeripheralScanResult.ScanStopped(error: error))
            } else {
                if let currentScanRequest = self.scanRequest {
                    self.centralManager.stopScan()
                }
                
                let scanRequest = PeripheralScanRequest(callback: callback)
                self.scanRequest = scanRequest
                
                scanRequest.callback(scanResult: .ScanStarted)
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
            scanRequest.callback(scanResult: .ScanStopped(error: nil))
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
}

/// Mark: Connect Peripheral requests
private final class ConnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: PeripheralConnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: BleError?) {
        for callback in callbacks {
            callback(error: error)
        }
    }
}

extension CentralProxy {
    func connectPeripheral(peripheral: CBPeripheral, timeout: NSTimeInterval, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(error: error)
                return
            }
            
            let uuid = peripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first where cbPeripheral.state == .Connected {
                callback(error: nil)
                return
            }
            
            if let request = self.connectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = ConnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.connectRequests[uuid] = request
                
                self.centralManager.connectPeripheral(peripheral, options: nil)
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
}

/// Mark: Disconnect Peripheral requests
private final class DisconnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: PeripheralDisconnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: BleError?) {
        for callback in callbacks {
            callback(error: error)
        }
    }
}

extension CentralProxy {
    func disconnectPeripheral(peripheral: CBPeripheral, timeout: NSTimeInterval, _ callback: (error: BleError?) -> Void) {
        initializeBluetooth { [unowned self] (error) in
            
            if let error = error {
                callback(error: error)
                return
            }
            
            let uuid = peripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripheralsWithIdentifiers([uuid]).first
                where (cbPeripheral.state == .Disconnected || cbPeripheral.state == .Disconnecting) {
                callback(error: nil)
                return
            }
            
            if let request = self.disconnectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = DisconnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.disconnectRequests[uuid] = request
                
                self.centralManager.cancelPeripheralConnection(peripheral)
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

extension CentralProxy: CBCentralManagerDelegate {
    @objc func centralManagerDidUpdateState(central: CBCentralManager) {
        switch centralManager.state {
            case .Unknown:
                self.postPeripheralsInvalidatedEvent()
            case .Resetting:
                self.postPeripheralsInvalidatedEvent()
            case .Unsupported:
                self.postPeripheralsInvalidatedEvent()
                callInitializeBluetoothCallbacksWithError(.BleUnsupported)
            case .Unauthorized:
                self.postPeripheralsInvalidatedEvent()
                callInitializeBluetoothCallbacksWithError(.BleUnauthorized)
            case .PoweredOff:
                callInitializeBluetoothCallbacksWithError(.BlePoweredOff)
            case .PoweredOn:
                callInitializeBluetoothCallbacksWithError(nil)
        }
    }
    
    @objc func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(nil)
    }
    
    @objc func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
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
    
    @objc func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
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
    
    @objc func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        guard let scanRequest = scanRequest else {
            return
        }
        
        let peripheral = Peripheral(peripheral: peripheral)
        
        scanRequest.callback(scanResult: .ScanResult(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI))
    }
}
