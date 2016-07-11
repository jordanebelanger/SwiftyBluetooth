//
//  CentralProxy.swift
//
//  Copyright (c) 2016 Jordane Belanger
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import CoreBluetooth

final class CentralProxy: NSObject {
    private lazy var asyncCentralStateCallbacks: [AsyncCentralStateCallback] = []
    
    private var scanRequest: PeripheralScanRequest?
    
    private lazy var connectRequests: [NSUUID: ConnectPeripheralRequest] = [:]
    private lazy var disconnectRequests: [NSUUID: DisconnectPeripheralRequest] = [:]
    
    let centralManager: CBCentralManager
    
    override init() {
        self.centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }
    
    private func postCentralEvent(event: CentralEvent, userInfo: [NSObject: AnyObject]? = nil) {
        NSNotificationCenter.defaultCenter().postNotificationName(
            event.rawValue,
            object: Central.sharedInstance,
            userInfo: userInfo)
    }
}

// MARK: Initialize Bluetooth requests
extension CentralProxy {
    func asyncCentralState(completion: AsyncCentralStateCallback) {
        switch centralManager.state {
        case .Unknown:
            self.asyncCentralStateCallbacks.append(completion)
        case .Resetting:
            self.asyncCentralStateCallbacks.append(completion)
        case .Unsupported:
            completion(state: .Unsupported)
        case .Unauthorized:
            completion(state: .Unauthorized)
        case .PoweredOff:
            completion(state: .PoweredOff)
        case .PoweredOn:
            completion(state: .PoweredOn)
        }
    }
    
    func initializeBluetooth(completion: InitializeBluetoothCallback) {
        self.asyncCentralState { (state) in
            switch state {
            case .Unsupported:
                completion(error: .BluetoothUnsupported)
            case .Unauthorized:
                completion(error: .BluetoothUnauthorized)
            case .PoweredOff:
                completion(error: .BluetoothPoweredOff)
            case .PoweredOn:
                completion(error: nil)
            }
        }
    }
    
    func callAsyncCentralStateCallback(state: AsyncCentralState) {
        let callbacks = self.asyncCentralStateCallbacks
        
        self.asyncCentralStateCallbacks.removeAll()
        
        for callback in callbacks {
            callback(state: state)
        }
    }
}

// MARK: Scan requests
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
                if self.scanRequest != nil {
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
    
    func stopScan(error: Error? = nil) {
        self.centralManager.stopScan()
        if let scanRequest = self.scanRequest {
            self.scanRequest = nil
            scanRequest.callback(scanResult: .ScanStopped(error: error))
        }
    }
    
    @objc private func onScanTimerTick(timer: NSTimer) {
        
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<PeripheralScanRequest>
        
        if weakRequest.value != nil {
            self.stopScan()
        }
    }
}

// MARK: Connect Peripheral requests
private final class ConnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: PeripheralConnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: Error?) {
        for callback in callbacks {
            callback(error: error)
        }
    }
}

extension CentralProxy {
    func connectPeripheral(peripheral: CBPeripheral, timeout: NSTimeInterval, _ callback: (error: Error?) -> Void) {
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
        
        request.invokeCallbacks(Error.OperationTimeoutError(operationName: "connect peripheral"))
    }
}

// MARK: Disconnect Peripheral requests
private final class DisconnectPeripheralRequest {
    var callbacks: [PeripheralConnectCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: PeripheralDisconnectCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(error: Error?) {
        for callback in callbacks {
            callback(error: error)
        }
    }
}

extension CentralProxy {
    func disconnectPeripheral(peripheral: CBPeripheral, timeout: NSTimeInterval, _ callback: (error: Error?) -> Void) {
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
        
        request.invokeCallbacks(Error.OperationTimeoutError(operationName: "disconnect peripheral"))
    }
}

extension CentralProxy: CBCentralManagerDelegate {
    @objc func centralManagerDidUpdateState(central: CBCentralManager) {
        self.postCentralEvent(.CentralStateChange, userInfo: ["state": Box(value: central.state)])
        switch centralManager.state {
            case .Unknown:
                self.stopScan(Error.ScanTerminatedUnexpectedly(invalidState: centralManager.state))
            case .Resetting:
                self.stopScan(Error.ScanTerminatedUnexpectedly(invalidState: centralManager.state))
            case .Unsupported:
                self.callAsyncCentralStateCallback(.Unsupported)
                self.stopScan(Error.ScanTerminatedUnexpectedly(invalidState: centralManager.state))
            case .Unauthorized:
                self.callAsyncCentralStateCallback(.Unauthorized)
                self.stopScan(Error.ScanTerminatedUnexpectedly(invalidState: centralManager.state))
            case .PoweredOff:
                self.callAsyncCentralStateCallback(.PoweredOff)
                self.stopScan(Error.ScanTerminatedUnexpectedly(invalidState: centralManager.state))
            case .PoweredOn:
                self.callAsyncCentralStateCallback(.PoweredOn)
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
        
        var swiftyError: Error?
        if let error = error {
            swiftyError = Error.CoreBluetoothError(operationName: "disconnect peripheral", error: error)
        }
        
        request.invokeCallbacks(swiftyError)
    }
    
    @objc func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        var swiftyError: Error?
        if let error = error {
            swiftyError = .CoreBluetoothError(operationName: "connect peripheral", error: error)
        } else {
            swiftyError = Error.PeripheralFailedToConnectReasonUnknown
        }
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(swiftyError)
    }
    
    @objc func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        guard let scanRequest = scanRequest else {
            return
        }
        
        let peripheral = Peripheral(peripheral: peripheral)
        
        scanRequest.callback(scanResult: .ScanResult(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI))
    }
    
    @objc func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        self.postCentralEvent(.CentralManagerWillRestoreState, userInfo: dict)
    }
}
