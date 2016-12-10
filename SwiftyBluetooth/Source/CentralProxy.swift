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
    fileprivate lazy var asyncStateCallbacks: [AsyncCentralStateCallback] = []
    
    fileprivate var scanRequest: PeripheralScanRequest?
    
    fileprivate lazy var connectRequests: [UUID: ConnectPeripheralRequest] = [:]
    fileprivate lazy var disconnectRequests: [UUID: DisconnectPeripheralRequest] = [:]
    
    let centralManager: CBCentralManager
    
    override init() {
        self.centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }
    
    fileprivate func postCentralEvent(_ event: CentralEvent, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: event.rawValue),
            object: Central.sharedInstance,
            userInfo: userInfo)
    }
}

// MARK: Initialize Bluetooth requests
extension CentralProxy {
    func asyncState(_ completion: @escaping AsyncCentralStateCallback) {
        switch centralManager.state {
        case .unknown:
            self.asyncStateCallbacks.append(completion)
        case .resetting:
            self.asyncStateCallbacks.append(completion)
        case .unsupported:
            completion(.unsupported)
        case .unauthorized:
            completion(.unauthorized)
        case .poweredOff:
            completion(.poweredOff)
        case .poweredOn:
            completion(.poweredOn)
        }
    }
    
    func initializeBluetooth(_ completion: @escaping InitializeBluetoothCallback) {
        self.asyncState { (state) in
            switch state {
            case .unsupported:
                completion(.bluetoothUnavailable(reason: .unsupported))
            case .unauthorized:
                completion(.bluetoothUnavailable(reason: .unauthorized))
            case .poweredOff:
                completion(.bluetoothUnavailable(reason: .poweredOff))
            case .poweredOn:
                completion(nil)
            }
        }
    }
    
    func callAsyncCentralStateCallback(_ state: AsyncCentralState) {
        let callbacks = self.asyncStateCallbacks
        
        self.asyncStateCallbacks.removeAll()
        
        for callback in callbacks {
            callback(state)
        }
    }
}

// MARK: Scan requests
private final class PeripheralScanRequest {
    let callback: PeripheralScanCallback
    
    init(callback: @escaping PeripheralScanCallback) {
        self.callback = callback
    }
}

extension CentralProxy {
    func scanWithTimeout(_ timeout: TimeInterval, serviceUUIDs: [CBUUID]?, _ callback: @escaping PeripheralScanCallback) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(PeripheralScanResult.scanStopped(error: error))
            } else {
                if self.scanRequest != nil {
                    self.centralManager.stopScan()
                }
                
                let scanRequest = PeripheralScanRequest(callback: callback)
                self.scanRequest = scanRequest
                
                scanRequest.callback(.scanStarted)
                self.centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
                
                Timer.scheduledTimer(
                    timeInterval: timeout,
                    target: self,
                    selector: #selector(self.onScanTimerTick),
                    userInfo: Weak(value: scanRequest),
                    repeats: false)
            }
        }
    }
    
    func stopScan(error: SBError? = nil) {
        self.centralManager.stopScan()
        if let scanRequest = self.scanRequest {
            self.scanRequest = nil
            scanRequest.callback(.scanStopped(error: error))
        }
    }
    
    @objc fileprivate func onScanTimerTick(_ timer: Timer) {
        
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<PeripheralScanRequest>
        
        if weakRequest.value != nil {
            self.stopScan()
        }
    }
}

// MARK: Connect Peripheral requests
private final class ConnectPeripheralRequest {
    var callbacks: [ConnectPeripheralCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: @escaping ConnectPeripheralCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(result: PeripheralConnectionResult) {
        for callback in callbacks {
            switch result {
            case .failed(let error): callback(.failed(error: error))
            case .success(let peripheral): callback(.success(peripheral: peripheral))
            }
        }
    }
}

extension CentralProxy {
    func connect(peripheral: CBPeripheral, timeout: TimeInterval, _ callback: @escaping ConnectPeripheralCallback) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(.failed(error: error))
                return
            }
            
            let uuid = peripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripherals(withIdentifiers: [uuid]).first , cbPeripheral.state == .connected {
                callback(.success(peripheral: Peripheral(peripheral: cbPeripheral)))
                return
            }
            
            if let request = self.connectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = ConnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.connectRequests[uuid] = request
                
                self.centralManager.connect(peripheral, options: nil)
                Timer.scheduledTimer(
                    timeInterval: timeout,
                    target: self,
                    selector: #selector(self.onConnectTimerTick),
                    userInfo: Weak(value: request),
                    repeats: false)
            }
        }
    }
    
    func connect(peripheralUUID: UUID, serviceUUIDs: [CBUUID], timeout: TimeInterval, _ callback: @escaping ConnectPeripheralCallback) {
        initializeBluetooth { [unowned self] (error) in
            if let error = error {
                callback(.failed(error: error))
                return
            }
            
            let uuid = UUID(uuidString: peripheralUUID.uuidString)!
            
            var peripheral: CBPeripheral?
           
            if let cbPeripheral = self.centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
                if cbPeripheral.state == .connected {
                    callback(.success(peripheral: Peripheral(peripheral: cbPeripheral)))
                    return
                } else {
                    peripheral = cbPeripheral
                    
                    let connectedPeripherals = self.centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs)
                    for cbPeripheral in connectedPeripherals {
                        if cbPeripheral.identifier == peripheralUUID {
                            peripheral = cbPeripheral
                            break
                        }
                    }
                }
            }
            
            if let request = self.connectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                if let peripheral = peripheral {
                    let request = ConnectPeripheralRequest(peripheral: peripheral, callback: callback)
                    self.connectRequests[uuid] = request
                    
                    self.centralManager.connect(peripheral, options: nil)
                    Timer.scheduledTimer(
                        timeInterval: timeout,
                        target: self,
                        selector: #selector(self.onConnectTimerTick),
                        userInfo: Weak(value: request),
                        repeats: false)
                } else {
                    callback(.failed(error: .peripheralFailedToConnectReasonUnknown))
                    return
                }
            }
        }
    }
    
    @objc fileprivate func onConnectTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ConnectPeripheralRequest>
        guard let request = weakRequest.value else {
            return
        }
        
        let uuid = request.peripheral.identifier
        
        self.connectRequests[uuid] = nil
        
        self.centralManager.cancelPeripheralConnection(request.peripheral)
        
        request.invokeCallbacks(result: .failed(error: .operationTimedOut(operation: .connectPeripheral)))
    }
}

// MARK: Disconnect Peripheral requests
private final class DisconnectPeripheralRequest {
    var callbacks: [ConnectPeripheralCallback] = []
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral, callback: @escaping DisconnectPeripheralCallback) {
        self.callbacks.append(callback)
        
        self.peripheral = peripheral
    }
    
    func invokeCallbacks(result: PeripheralConnectionResult) {
        for callback in callbacks {
            switch result {
            case .failed(let error): callback(.failed(error: error))
            case .success(let peripheral): callback(.success(peripheral: peripheral))
            }
        }
    }
}

extension CentralProxy {
    func disconnect(peripheral: CBPeripheral, timeout: TimeInterval, _ callback: @escaping DisconnectPeripheralCallback) {
        initializeBluetooth { [unowned self] (error) in
            
            if let error = error {
                callback(.failed(error: error))
                return
            }
            
            let uuid = peripheral.identifier
            
            if let cbPeripheral = self.centralManager.retrievePeripherals(withIdentifiers: [uuid]).first,
                (cbPeripheral.state == .disconnected || cbPeripheral.state == .disconnecting) {
                callback(.success(peripheral: Peripheral(peripheral: cbPeripheral)))
                return
            }
            
            if let request = self.disconnectRequests[uuid] {
                request.callbacks.append(callback)
            } else {
                let request = DisconnectPeripheralRequest(peripheral: peripheral, callback: callback)
                self.disconnectRequests[uuid] = request
                
                self.centralManager.cancelPeripheralConnection(peripheral)
                Timer.scheduledTimer(
                    timeInterval: timeout,
                    target: self,
                    selector: #selector(self.onDisconnectTimerTick),
                    userInfo: Weak(value: request),
                    repeats: false)
            }
        }
    }
    
    @objc fileprivate func onDisconnectTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<DisconnectPeripheralRequest>
        guard let request = weakRequest.value else {
            return
        }
        
        let uuid = request.peripheral.identifier
        
        self.disconnectRequests[uuid] = nil
        
        request.invokeCallbacks(result: .failed(error: .operationTimedOut(operation: .disconnectPeripheral)))
    }
}

extension CentralProxy: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state.rawValue {
        case 0: // .unknown
            self.stopScan(error: .scanningEndedUnexpectedly)
        case 1: // .resetting
            self.stopScan(error: .scanningEndedUnexpectedly)
        case 2: // .unsupported
            self.callAsyncCentralStateCallback(.unsupported)
            self.stopScan(error: .scanningEndedUnexpectedly)
        case 3: // .unauthorized
            self.callAsyncCentralStateCallback(.unauthorized)
            self.stopScan(error: .scanningEndedUnexpectedly)
        case 4: // .poweredOff
            self.callAsyncCentralStateCallback(.poweredOff)
            self.stopScan(error: .scanningEndedUnexpectedly)
        case 5: // .poweredOn
            self.callAsyncCentralStateCallback(.poweredOn)
        default:
            fatalError("Unsupported BLE CentralState")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        self.connectRequests[uuid] = nil
        
        request.invokeCallbacks(result: .success(peripheral: Peripheral(peripheral: peripheral)))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let uuid = peripheral.identifier
        guard let request = self.disconnectRequests[uuid] else {
            return
        }
        
        self.disconnectRequests[uuid] = nil
        
        if let error = error {
            request.invokeCallbacks(result: .failed(error: .peripheralFailedToDisconnectWithError(error: error)))
        } else {
            request.invokeCallbacks(result: .success(peripheral: Peripheral(peripheral: peripheral)))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let uuid = peripheral.identifier
        guard let request = self.connectRequests[uuid] else {
            return
        }
        
        self.connectRequests[uuid] = nil
        
        let resolvedError: SBError
        if let error = error {
            resolvedError = .peripheralFailedToConnectWithError(error: error)
        } else {
            resolvedError = .peripheralFailedToConnectReasonUnknown
        }

        request.invokeCallbacks(result: .failed(error: resolvedError))
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber)
    {
        guard let scanRequest = scanRequest else {
            return
        }
        
        let peripheral = Peripheral(peripheral: peripheral)
        
        scanRequest.callback(.scanResult(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI))
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        self.postCentralEvent(.CentralManagerWillRestoreState, userInfo: dict)
    }

}
