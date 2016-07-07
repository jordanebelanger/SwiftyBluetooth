//
//  PeripheralProxy.swift
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

final class PeripheralProxy: NSObject  {
    static let defaultTimeoutInS: NSTimeInterval = 10
    
    private lazy var readRSSIRequests: [ReadRSSIRequest] = []
    private lazy var serviceRequests: [ServiceRequest] = []
    private lazy var characteristicRequests: [CharacteristicRequest] = []
    private lazy var descriptorRequests: [DescriptorRequest] = []
    private lazy var readCharacteristicRequests: [CBUUIDPath: [ReadCharacteristicRequest]] = [:]
    private lazy var readDescriptorRequests: [CBUUIDPath: [ReadDescriptorRequest]] = [:]
    private lazy var writeCharacteristicValueRequests: [CBUUIDPath: [WriteCharacteristicValueRequest]] = [:]
    private lazy var writeDescriptorValueRequests: [CBUUIDPath: [WriteDescriptorValueRequest]] = [:]
    private lazy var updateNotificationStateRequests: [CBUUIDPath: [UpdateNotificationStateRequest]] = [:]
    
    private weak var peripheral: Peripheral?
    let cbPeripheral: CBPeripheral
    
    // Peripheral that are no longer valid must be rediscovered again (happens when for example the Bluetooth is turned off
    // from a user's phone and turned back on
    var valid: Bool = true
    
    init(cbPeripheral: CBPeripheral, peripheral: Peripheral) {
        self.cbPeripheral = cbPeripheral
        self.peripheral = peripheral
        
        super.init()
        
        cbPeripheral.delegate = self
        
        NSNotificationCenter.defaultCenter().addObserverForName(CentralEvent.PeripheralsInvalidated.rawValue,
                                                                object: Central.sharedInstance,
                                                                queue: nil)
        { [weak self] (notification) in
            self?.valid = false
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func postPeripheralEvent(event: PeripheralEvent, userInfo: [NSObject: AnyObject]?) {
        guard let peripheral = self.peripheral else {
            return
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(
            event.rawValue,
            object: peripheral,
            userInfo: userInfo)
    }
}

// Connect/Disconnect Requests
extension PeripheralProxy {
    func connect(completion: (error: Error?) -> Void) {
        if self.valid {
            Central.sharedInstance.connectPeripheral(self.cbPeripheral, completion: completion)
        } else {
            completion(error: .InvalidPeripheral)            
        }
    }
    
    func disconnect(completion: (error: Error?) -> Void) {
        Central.sharedInstance.disconnectPeripheral(self.cbPeripheral, completion: completion)
    }
}

// RSSI Requests
private final class ReadRSSIRequest {
    let callback: ReadRSSIRequestCallback
    
    init(callback: ReadRSSIRequestCallback) {
        self.callback = callback
    }
}

extension PeripheralProxy {
    func readRSSI(completion: ReadRSSIRequestCallback) {
        self.connect { (error) in
            if let error = error {
                completion(RSSI: nil, error: error)
                return
            }
            
            let request = ReadRSSIRequest(callback: completion)
            
            self.readRSSIRequests.append(request)
            
            if self.readRSSIRequests.count == 1 {
                self.runRSSIRequest()
            }
        }
    }
    
    private func runRSSIRequest() {
        guard let request = self.readRSSIRequests.first else {
            return
        }
        
        self.cbPeripheral.readRSSI()
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadRSSIOperationTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onReadRSSIOperationTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ReadRSSIRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        self.readRSSIRequests.removeFirst()
        
        request.callback(RSSI: nil, error: Error.OperationTimeoutError(operationName: "read RSSI"))
        
        self.runRSSIRequest()
    }
}

// Service requests
private final class ServiceRequest {
    let serviceUUIDs: [CBUUID]?
    
    let callback: ServiceRequestCallback
    
    init(serviceUUIDs: [CBUUID]?, callback: ServiceRequestCallback) {
        self.callback = callback
        
        if let serviceUUIDs = serviceUUIDs {
            self.serviceUUIDs = serviceUUIDs
        } else {
            self.serviceUUIDs = nil
        }
    }
}

extension PeripheralProxy {
    func discoverServices(serviceUUIDs: [CBUUID]?, completion: ServiceRequestCallback) {
        self.connect { (error) in
            if let error = error {
                completion(services: nil, error: error)
                return
            }
            
            // Checking if the peripheral has already discovered the services requested
            if let serviceUUIDs = serviceUUIDs {
                let servicesTuple = self.cbPeripheral.servicesWithUUIDs(serviceUUIDs)
                
                if servicesTuple.missingServicesUUIDs.count == 0 {
                    completion(services: servicesTuple.foundServices, error: nil)
                    return
                }
            }
            
            let request = ServiceRequest(serviceUUIDs: serviceUUIDs) { (services, error) in
                completion(services: services, error: error)
            }
            
            self.serviceRequests.append(request)
            
            if self.serviceRequests.count == 1 {
                self.runServiceRequest()
            }
        }
    }
    
    private func runServiceRequest() {
        guard let request = self.serviceRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverServices(request.serviceUUIDs)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onServiceRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onServiceRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ServiceRequest>
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.serviceRequests.removeFirst()
        
        request.callback(services: nil, error: Error.OperationTimeoutError(operationName: "discover services"))
        
        self.runServiceRequest()
    }
}

// Discover Characteristic requests
private final class CharacteristicRequest{
    let service: CBService
    let characteristicUUIDs: [CBUUID]?
    
    let callback: CharacteristicRequestCallback
    
    init(service: CBService,
         characteristicUUIDs: [CBUUID]?,
         callback: CharacteristicRequestCallback)
    {
        self.callback = callback
        
        self.service = service
        
        if let characteristicUUIDs = characteristicUUIDs {
            self.characteristicUUIDs = characteristicUUIDs
        } else {
            self.characteristicUUIDs = nil
        }
    }
    
}

extension PeripheralProxy {
    func discoverCharacteristics(characteristicUUIDs: [CBUUID]?,
                                 forService serviceUUID: CBUUID,
                                            completion: CharacteristicRequestCallback)
    {
        self.discoverServices([serviceUUID]) { (services, error) in
            if let error = error {
                completion(characteristics: nil, error: error)
                return
            }
            
            // It would be a bug if we received an empty service array without an error from the discoverServices function
            // when asking for a specific service
            let service = services!.first!
            
            // Checking if this service already has the characteristic requested
            if let characteristicUUIDs = characteristicUUIDs {
                let characTuple = service.characteristicsWithUUIDs(characteristicUUIDs)
                
                if (characTuple.missingCharacteristicsUUIDs.count == 0) {
                    completion(characteristics: characTuple.foundCharacteristics, error: nil)
                    return
                }
            }
            
            let request = CharacteristicRequest(service: service,
                                                characteristicUUIDs: characteristicUUIDs)
            { (characteristics, error) in
                completion(characteristics: characteristics, error: error)
            }
            
            self.characteristicRequests.append(request)
            
            if self.characteristicRequests.count == 1 {
                self.runCharacteristicRequest()
            }
        }
    }
    
    private func runCharacteristicRequest() {
        guard let request = self.characteristicRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverCharacteristics(request.characteristicUUIDs, forService: request.service)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onCharacteristicRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onCharacteristicRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<CharacteristicRequest>
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.characteristicRequests.removeFirst()
        
        request.callback(characteristics: nil, error: Error.OperationTimeoutError(operationName: "discover characteristics"))
        
        self.runCharacteristicRequest()
    }
}

// Discover Descriptors requets
private final class DescriptorRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    
    let callback: DescriptorRequestCallback
    
    init(characteristic: CBCharacteristic, callback: DescriptorRequestCallback) {
        self.callback = callback
        
        self.service = characteristic.service
        self.characteristic = characteristic
    }
    
}

extension PeripheralProxy {
    func discoverDescriptorsForCharacteristic(characteristicUUID: CBUUID, serviceUUID: CBUUID, completion: DescriptorRequestCallback) {
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(descriptors: nil, error: error)
                return
            }
            
            // It would be a terrible bug in the first place if the discover characteristic returned an empty array
            // with no error message when searching for a specific characteristic, I want to crash if it happens :)
            let characteristic = characteristics!.first!
            
            let request = DescriptorRequest(characteristic: characteristic) { (descriptors, error) in
                completion(descriptors: descriptors, error: error)
            }
            
            self.descriptorRequests.append(request)
            
            if self.descriptorRequests.count == 1 {
                self.runDescriptorRequest()
            }
        }
    }
    
    private func runDescriptorRequest() {
        guard let request = self.descriptorRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverDescriptorsForCharacteristic(request.characteristic)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onDescriptorRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onDescriptorRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<DescriptorRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        self.descriptorRequests.removeFirst()
        
        request.callback(descriptors: nil, error: Error.OperationTimeoutError(operationName: "discover descriptors"))
        
        self.runDescriptorRequest()
    }
}

// Read Characteristic value requests
private final class ReadCharacteristicRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    
    let callback: ReadRequestCallback
    
    init(characteristic: CBCharacteristic, callback: ReadRequestCallback) {
        self.callback = callback
        
        self.service = characteristic.service
        self.characteristic = characteristic
    }
    
}

extension PeripheralProxy {
    func readCharacteristic(characteristicUUID: CBUUID,
                            serviceUUID: CBUUID,
                            completion: ReadRequestCallback) {
        
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(data: nil, error: error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug
            let characteristic = characteristics!.first!
            
            let request = ReadCharacteristicRequest(characteristic: characteristic) { (data, error) in
                completion(data: data, error: error)
            }
            
            let readPath = characteristic.uuidPath
            
            if var currentPathRequests = self.readCharacteristicRequests[readPath] {
                currentPathRequests.append(request)
                self.readCharacteristicRequests[readPath] = currentPathRequests
            } else {
                self.readCharacteristicRequests[readPath] = [request]
                
                self.runReadCharacteristicRequest(readPath)
            }
        }
    }
    
    private func runReadCharacteristicRequest(readPath: CBUUIDPath) {
        guard let request = self.readCharacteristicRequests[readPath]?.first else {
            return
        }
        
        self.cbPeripheral.readValueForCharacteristic(request.characteristic)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadCharacteristicTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onReadCharacteristicTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ReadCharacteristicRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        let readPath = request.characteristic.uuidPath
        
        self.readCharacteristicRequests[readPath]?.removeFirst()
        if self.readCharacteristicRequests[readPath]?.count == 0 {
            self.readCharacteristicRequests[readPath] = nil
        }
        
        request.callback(data: nil, error: Error.OperationTimeoutError(operationName: "read characteristic"))
        
        self.runReadCharacteristicRequest(readPath)
    }
}

// Read Descriptor value requests
private final class ReadDescriptorRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let descriptor: CBDescriptor
    
    let callback: ReadRequestCallback
    
    init(descriptor: CBDescriptor, callback: ReadRequestCallback) {
        self.callback = callback
        
        self.descriptor = descriptor
        self.characteristic = descriptor.characteristic
        self.service = descriptor.characteristic.service
    }
    
}

extension PeripheralProxy {
    func readDescriptor(descriptorUUID: CBUUID,
                        characteristicUUID: CBUUID,
                        serviceUUID: CBUUID,
                        completion: ReadRequestCallback)
    {
        
        self.discoverDescriptorsForCharacteristic(characteristicUUID, serviceUUID: serviceUUID) { (descriptors, error) in
            if let error = error {
                completion(data: nil, error: error)
                return
            }
            
            guard let descriptor = descriptors?.first else {
                completion(data: nil, error: Error.PeripheralDescriptorsNotFound(missingDescriptorsUUIDs: [descriptorUUID]))
                return
            }
            
            let request = ReadDescriptorRequest(descriptor: descriptor, callback: completion)
            
            let readPath = descriptor.uuidPath
            
            if var currentPathRequests = self.readDescriptorRequests[readPath] {
                currentPathRequests.append(request)
                self.readDescriptorRequests[readPath] = currentPathRequests
            } else {
                self.readDescriptorRequests[readPath] = [request]
                
                self.runReadDescriptorRequest(readPath)
            }
        }
    }
    
    private func runReadDescriptorRequest(readPath: CBUUIDPath) {
        guard let request = self.readDescriptorRequests[readPath]?.first else {
            return
        }
        
        self.cbPeripheral.readValueForDescriptor(request.descriptor)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadDescriptorTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onReadDescriptorTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ReadDescriptorRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        let readPath = request.descriptor.uuidPath
        
        self.readDescriptorRequests[readPath]?.removeFirst()
        if self.readDescriptorRequests[readPath]?.count == 0 {
            self.readDescriptorRequests[readPath] = nil
        }
        
        request.callback(data: nil, error: Error.OperationTimeoutError(operationName: "read descriptor"))
        
        self.runReadDescriptorRequest(readPath)
    }
}

// Write Characteristic value requests
private final class WriteCharacteristicValueRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let value: NSData
    let type: CBCharacteristicWriteType
    
    let callback: WriteRequestCallback
    
    init(characteristic: CBCharacteristic, value: NSData, type: CBCharacteristicWriteType, callback: WriteRequestCallback) {
        self.callback = callback
        self.value = value
        self.type = type
        self.characteristic = characteristic
        self.service = characteristic.service
    }
    
}

extension PeripheralProxy {
    func writeCharacteristicValue(characteristicUUID: CBUUID,
                                  serviceUUID: CBUUID,
                                  value: NSData,
                                  type: CBCharacteristicWriteType,
                                  completion: WriteRequestCallback)
    {
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(error: error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug hence the forced unwrap
            let characteristic = characteristics!.first!
            
            let request = WriteCharacteristicValueRequest(characteristic: characteristic, value: value, type: type) { (error) in
                completion(error: error)
            }
            
            let writePath = characteristic.uuidPath
            
            if var currentPathRequests = self.writeCharacteristicValueRequests[writePath] {
                currentPathRequests.append(request)
                self.writeCharacteristicValueRequests[writePath] = currentPathRequests
            } else {
                self.writeCharacteristicValueRequests[writePath] = [request]
                
                self.runWriteCharacteristicValueRequest(writePath)
            }
        }
    }
    
    private func runWriteCharacteristicValueRequest(writePath: CBUUIDPath) {
        guard let request = self.writeCharacteristicValueRequests[writePath]?.first else {
            return
        }
        
        self.cbPeripheral.writeValue(request.value, forCharacteristic: request.characteristic, type: request.type)
        
        if request.type == CBCharacteristicWriteType.WithResponse {
            NSTimer.scheduledTimerWithTimeInterval(
                PeripheralProxy.defaultTimeoutInS,
                target: self,
                selector: #selector(self.onWriteCharacteristicValueRequestTimerTick),
                userInfo: Weak(value: request),
                repeats: false)
        } else {
            // If no response is expected, we execute the callback and clear the request right away
            self.writeCharacteristicValueRequests[writePath]?.removeFirst()
            if self.writeCharacteristicValueRequests[writePath]?.count == 0 {
                self.writeCharacteristicValueRequests[writePath] = nil
            }
            
            request.callback(error: nil)
            
            self.runWriteCharacteristicValueRequest(writePath)
        }
        
    }
    
    @objc private func onWriteCharacteristicValueRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<WriteCharacteristicValueRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        let writePath = request.characteristic.uuidPath
        
        self.writeCharacteristicValueRequests[writePath]?.removeFirst()
        if self.writeCharacteristicValueRequests[writePath]?.count == 0 {
            self.writeCharacteristicValueRequests[writePath] = nil
        }
        
        request.callback(error: Error.OperationTimeoutError(operationName: "write characteristic value"))
        
        self.runWriteCharacteristicValueRequest(writePath)
    }
}

// Write Descriptor value requests
private final class WriteDescriptorValueRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let descriptor: CBDescriptor
    let value: NSData
    
    let callback: WriteRequestCallback
    
    init(descriptor: CBDescriptor, value: NSData, callback: WriteRequestCallback) {
        self.callback = callback
        self.value = value
        self.descriptor = descriptor
        self.characteristic = descriptor.characteristic
        self.service = descriptor.characteristic.service
    }
}

extension PeripheralProxy {
    func writeDescriptorValue(descriptorUUID: CBUUID,
                              characteristicUUID: CBUUID,
                              serviceUUID: CBUUID,
                              value: NSData,
                              completion: WriteRequestCallback)
    {
        self.discoverDescriptorsForCharacteristic(characteristicUUID, serviceUUID: serviceUUID) { (descriptors, error) in
            
            if let error = error {
                completion(error: error)
                return
            }
            
            guard let descriptor = descriptors?.filter({ $0.UUID == descriptorUUID }).first else {
                completion(error: Error.PeripheralDescriptorsNotFound(missingDescriptorsUUIDs: [descriptorUUID]))
                return
            }
            
            let request = WriteDescriptorValueRequest(descriptor: descriptor, value: value) { (error) in
                completion(error: error)
            }
            
            let writePath = descriptor.uuidPath
            
            if var currentPathRequests = self.writeDescriptorValueRequests[writePath] {
                currentPathRequests.append(request)
                self.writeDescriptorValueRequests[writePath] = currentPathRequests
            } else {
                self.writeDescriptorValueRequests[writePath] = [request]
                
                self.runWriteDescriptorValueRequest(writePath)
            }
        }
    }
    
    private func runWriteDescriptorValueRequest(writePath: CBUUIDPath) {
        guard let request = self.writeDescriptorValueRequests[writePath]?.first else {
            return
        }
        
        self.cbPeripheral.writeValue(request.value, forDescriptor: request.descriptor)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onWriteDescriptorValueRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onWriteDescriptorValueRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<WriteDescriptorValueRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        let writePath = request.descriptor.uuidPath
        
        self.writeDescriptorValueRequests[writePath]?.removeFirst()
        if self.writeDescriptorValueRequests[writePath]?.count == 0 {
            self.writeDescriptorValueRequests[writePath] = nil
        }
        
        request.callback(error: Error.OperationTimeoutError(operationName: "write to decriptor"))
        
        self.runWriteDescriptorValueRequest(writePath)
    }
}

// Update Characteristic Notification State requests
private final class UpdateNotificationStateRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let enabled: Bool
    
    let callback: UpdateNotificationStateCallback
    
    init(enabled: Bool, characteristic: CBCharacteristic, callback: UpdateNotificationStateCallback) {
        self.enabled = enabled
        self.characteristic = characteristic
        self.service = characteristic.service
        self.callback = callback
    }
}

extension PeripheralProxy {
    func setNotifyValueForCharacteristic(enabled: Bool, characteristicUUID: CBUUID, serviceUUID: CBUUID, completion: UpdateNotificationStateCallback) {
        
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(isNotifying: nil, error: error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug hence the forced unwrap
            let characteristic = characteristics!.first!
            
            let request = UpdateNotificationStateRequest(enabled: enabled, characteristic: characteristic) { (isNotifying, error) in
                completion(isNotifying: isNotifying, error: error)
            }
            
            let path = characteristic.uuidPath
            
            if var currentPathRequests = self.updateNotificationStateRequests[path] {
                currentPathRequests.append(request)
                self.updateNotificationStateRequests[path] = currentPathRequests
            } else {
                self.updateNotificationStateRequests[path] = [request]
                
                self.runUpdateNotificationStateRequest(path)
            }
        }
    }
    
    private func runUpdateNotificationStateRequest(path: CBUUIDPath) {
        guard let request = self.updateNotificationStateRequests[path]?.first else {
            return
        }
        
        self.cbPeripheral.setNotifyValue(request.enabled, forCharacteristic: request.characteristic)
        
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onUpdateNotificationStateRequest),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc private func onUpdateNotificationStateRequest(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<UpdateNotificationStateRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        let path = request.characteristic.uuidPath
        
        self.updateNotificationStateRequests[path]?.removeFirst()
        if self.updateNotificationStateRequests[path]?.count == 0 {
            self.updateNotificationStateRequests[path] = nil
        }
        
        request.callback(isNotifying: nil, error: Error.OperationTimeoutError(operationName: "update notification status"))
        
        self.runUpdateNotificationStateRequest(path)
    }
}

// CBPeripheralProxy
extension PeripheralProxy: CBPeripheralDelegate {
    @objc func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        guard let readRSSIRequest = self.readRSSIRequests.first else {
            return
        }
        
        self.readRSSIRequests.removeFirst()
        
        var rssi: Int?
        var swiftyError: Error?
        
        if let error = error {
            swiftyError = .CoreBluetoothError(operationName: "read RSSI", error: error)
        } else {
            rssi = RSSI.integerValue
        }
        
        readRSSIRequest.callback(RSSI: rssi, error: swiftyError)
        
        self.runRSSIRequest()
    }
    
    @objc func peripheralDidUpdateName(peripheral: CBPeripheral) {
        var userInfo: [NSObject: AnyObject]?
        if let name = peripheral.name {
            userInfo = ["name": name]
        }
        
        self.postPeripheralEvent(.PeripheralNameUpdate, userInfo: userInfo)
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        self.postPeripheralEvent(.PeripheralModifedServices, userInfo: ["invalidatedServices": invalidatedServices])
    }
    
    //    @objc private func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
    //
    //    }
    
    @objc func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard let serviceRequest = self.serviceRequests.first else {
            return
        }
        
        defer {
            self.runServiceRequest()
        }
        
        self.serviceRequests.removeFirst()
        
        if let error = error {
            serviceRequest.callback(services: nil, error: Error.CoreBluetoothError(operationName: "discover services", error: error))
            return
        }
        
        if let serviceUUIDs = serviceRequest.serviceUUIDs {
            let servicesTuple = peripheral.servicesWithUUIDs(serviceUUIDs)
            if servicesTuple.missingServicesUUIDs.count > 0 {
                serviceRequest.callback(services: nil, error: Error.PeripheralServiceNotFound(missingServicesUUIDs: servicesTuple.missingServicesUUIDs))
            } else { // This implies that all the services we're found through Set logic in the servicesWithUUIDs function
                serviceRequest.callback(services: servicesTuple.foundServices, error: nil)
            }
        } else {
            serviceRequest.callback(services: peripheral.services, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        guard let characteristicRequest = self.characteristicRequests.first else {
            return
        }
        
        defer {
            self.runCharacteristicRequest()
        }
        
        self.characteristicRequests.removeFirst()
        
        if let error = error {
            characteristicRequest.callback(characteristics: nil, error: Error.CoreBluetoothError(operationName: "discover characteristics", error: error))
            return
        }
        
        if let characteristicUUIDs = characteristicRequest.characteristicUUIDs {
            let characteristicsTuple = service.characteristicsWithUUIDs(characteristicUUIDs)
            
            if characteristicsTuple.missingCharacteristicsUUIDs.count > 0 {
                characteristicRequest.callback(characteristics: nil, error: Error.PeripheralCharacteristicNotFound(missingCharacteristicsUUIDs: characteristicsTuple.missingCharacteristicsUUIDs))
            } else {
                characteristicRequest.callback(characteristics: characteristicsTuple.foundCharacteristics, error: nil)
            }
            
        } else {
            characteristicRequest.callback(characteristics: service.characteristics, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard let descriptorRequest = self.descriptorRequests.first else {
            return
        }
        
        defer {
            self.runDescriptorRequest()
        }
        
        self.descriptorRequests.removeFirst()
        
        if let error = error {
            descriptorRequest.callback(descriptors: nil, error: Error.CoreBluetoothError(operationName: "discover descriptors", error: error))
        } else {
            descriptorRequest.callback(descriptors: characteristic.descriptors, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let readPath = characteristic.uuidPath
        
        guard let request = self.readCharacteristicRequests[readPath]?.first else {
            if characteristic.isNotifying {
                var userInfo: [NSObject: AnyObject] = ["characteristic": characteristic]
                if let error = error {
                    userInfo["error"] = error
                }
                
                self.postPeripheralEvent(.CharacteristicValueUpdate, userInfo: userInfo)
            }
            return
        }
        
        defer {
            self.runReadCharacteristicRequest(readPath)
        }
        
        self.readCharacteristicRequests[readPath]?.removeFirst()
        if self.readCharacteristicRequests[readPath]?.count == 0 {
            self.readCharacteristicRequests[readPath] = nil
        }
        
        if let error = error {
            request.callback(data: nil, error: Error.CoreBluetoothError(operationName: "read characteristic", error: error))
        } else {
            request.callback(data: characteristic.value, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let writePath = characteristic.uuidPath
        
        guard let request = self.writeCharacteristicValueRequests[writePath]?.first else {
            return
        }
        
        defer {
            self.runWriteCharacteristicValueRequest(writePath)
        }
        
        self.writeCharacteristicValueRequests[writePath]?.removeFirst()
        if self.writeCharacteristicValueRequests[writePath]?.count == 0 {
            self.writeCharacteristicValueRequests[writePath] = nil
        }
        
        if let error = error {
            request.callback(error: Error.CoreBluetoothError(operationName: "write characteristic value", error: error))
        } else {
            request.callback(error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let path = characteristic.uuidPath
        
        guard let request = self.updateNotificationStateRequests[path]?.first else {
            return
        }
        
        defer {
            self.runUpdateNotificationStateRequest(path)
        }
        
        self.updateNotificationStateRequests[path]?.removeFirst()
        if self.updateNotificationStateRequests[path]?.count == 0 {
            self.updateNotificationStateRequests[path] = nil
        }
        
        if let error = error {
            request.callback(isNotifying: nil, error: Error.CoreBluetoothError(operationName: "update characteristic notification state", error: error))
        } else {
            request.callback(isNotifying: characteristic.isNotifying, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        let readPath = descriptor.uuidPath
        
        guard let request = self.readDescriptorRequests[readPath]?.first else {
            return
        }
        
        defer {
            self.runReadCharacteristicRequest(readPath)
        }
        
        self.readDescriptorRequests[readPath]?.removeFirst()
        if self.readDescriptorRequests[readPath]?.count == 0 {
            self.readDescriptorRequests[readPath] = nil
        }
        
        if let error = error {
            request.callback(data: nil, error: Error.CoreBluetoothError(operationName: "read descriptor", error: error))
        } else {
            request.callback(data: nil, error: nil)
        }
    }
    
    @objc func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        let writePath = descriptor.uuidPath
        
        guard let request = self.writeDescriptorValueRequests[writePath]?.first else {
            return
        }
        
        defer {
            self.runWriteDescriptorValueRequest(writePath)
        }
        
        self.writeDescriptorValueRequests[writePath]?.removeFirst()
        if self.writeDescriptorValueRequests[writePath]?.count == 0 {
            self.writeDescriptorValueRequests[writePath] = nil
        }
        
        if let error = error {
            request.callback(error: Error.CoreBluetoothError(operationName: "write descriptor value", error: error))
        } else {
            request.callback(error: nil)
        }
    }
}
