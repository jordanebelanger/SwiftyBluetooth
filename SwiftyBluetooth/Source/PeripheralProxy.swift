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
    static let defaultTimeoutInS: TimeInterval = 10
    
    fileprivate lazy var readRSSIRequests: [ReadRSSIRequest] = []
    fileprivate lazy var serviceRequests: [ServiceRequest] = []
    fileprivate lazy var includedServicesRequests: [IncludedServicesRequest] = []
    fileprivate lazy var characteristicRequests: [CharacteristicRequest] = []
    fileprivate lazy var descriptorRequests: [DescriptorRequest] = []
    fileprivate lazy var readCharacteristicRequests: [CBUUIDPath: [ReadCharacteristicRequest]] = [:]
    fileprivate lazy var readDescriptorRequests: [CBUUIDPath: [ReadDescriptorRequest]] = [:]
    fileprivate lazy var writeCharacteristicValueRequests: [CBUUIDPath: [WriteCharacteristicValueRequest]] = [:]
    fileprivate lazy var writeDescriptorValueRequests: [CBUUIDPath: [WriteDescriptorValueRequest]] = [:]
    fileprivate lazy var updateNotificationStateRequests: [CBUUIDPath: [UpdateNotificationStateRequest]] = [:]
    
    fileprivate weak var peripheral: Peripheral?
    let cbPeripheral: CBPeripheral
    
    // Peripheral that are no longer valid must be rediscovered again (happens when for example the Bluetooth is turned off
    // from a user's phone and turned back on
    var valid: Bool = true
    
    init(cbPeripheral: CBPeripheral, peripheral: Peripheral) {
        self.cbPeripheral = cbPeripheral
        self.peripheral = peripheral
        
        super.init()
        
        cbPeripheral.delegate = self
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: CentralEvent.CentralStateChange.rawValue),
                                                                object: Central.sharedInstance,
                                                                queue: nil)
        { [weak self] (notification) in
            let boxedState = (notification as NSNotification).userInfo!["state"] as! Box<CBCentralManagerState>
            if boxedState.value.rawValue < CBCentralManagerState.poweredOff.rawValue {
                self?.valid = false
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate func postPeripheralEvent(_ event: PeripheralEvent, userInfo: [AnyHashable: Any]?) {
        guard let peripheral = self.peripheral else {
            return
        }
        
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: event.rawValue),
            object: peripheral,
            userInfo: userInfo)
    }
}

// MARK: Connect/Disconnect Requests
extension PeripheralProxy {
    func connect(_ completion: @escaping ConnectPeripheralCallback) {
        if self.valid {
            Central.sharedInstance.connect(peripheral: self.cbPeripheral, completion: completion)
        } else {
            completion(SBError.invalidPeripheral)
        }
    }
    
    func disconnect(_ completion: @escaping DisconnectPeripheralCallback) {
        Central.sharedInstance.disconnect(peripheral: self.cbPeripheral, completion: completion)
    }
}

// MARK: RSSI Requests
private final class ReadRSSIRequest {
    let callback: ReadRSSIRequestCallback
    
    init(callback: @escaping ReadRSSIRequestCallback) {
        self.callback = callback
    }
}

extension PeripheralProxy {
    func readRSSI(_ completion: @escaping ReadRSSIRequestCallback) {
        self.connect { (error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let request = ReadRSSIRequest(callback: completion)
            
            self.readRSSIRequests.append(request)
            
            if self.readRSSIRequests.count == 1 {
                self.runRSSIRequest()
            }
        }
    }
    
    fileprivate func runRSSIRequest() {
        guard let request = self.readRSSIRequests.first else {
            return
        }
        
        self.cbPeripheral.readRSSI()
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadRSSIOperationTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onReadRSSIOperationTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ReadRSSIRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        self.readRSSIRequests.removeFirst()
        
        request.callback(nil, SBError.operationTimedOut(operation: .readRSSI))
        
        self.runRSSIRequest()
    }
}

// MARK: Service requests
private final class ServiceRequest {
    let serviceUUIDs: [CBUUID]?
    
    let callback: ServiceRequestCallback
    
    init(serviceUUIDs: [CBUUID]?, callback: @escaping ServiceRequestCallback) {
        self.callback = callback
        
        if let serviceUUIDs = serviceUUIDs {
            self.serviceUUIDs = serviceUUIDs
        } else {
            self.serviceUUIDs = nil
        }
    }
}

extension PeripheralProxy {
    func discoverServices(_ serviceUUIDs: [CBUUID]?, completion: @escaping ServiceRequestCallback) {
        self.connect { (error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Checking if the peripheral has already discovered the services requested
            if let serviceUUIDs = serviceUUIDs {
                let servicesTuple = self.cbPeripheral.servicesWithUUIDs(serviceUUIDs)
                
                if servicesTuple.missingServicesUUIDs.count == 0 {
                    completion(servicesTuple.foundServices, nil)
                    return
                }
            }
            
            let request = ServiceRequest(serviceUUIDs: serviceUUIDs) { (services, error) in
                completion(services, error)
            }
            
            self.serviceRequests.append(request)
            
            if self.serviceRequests.count == 1 {
                self.runServiceRequest()
            }
        }
    }
    
    fileprivate func runServiceRequest() {
        guard let request = self.serviceRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverServices(request.serviceUUIDs)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onServiceRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onServiceRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ServiceRequest>
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.serviceRequests.removeFirst()
        
        request.callback(nil, SBError.operationTimedOut(operation: .discoverServices))
        
        self.runServiceRequest()
    }
}

// MARK: Included services Request
private final class IncludedServicesRequest {
    let serviceUUIDs: [CBUUID]?
    let parentService: CBService
    
    let callback: ServiceRequestCallback
    
    init(serviceUUIDs: [CBUUID]?, forService service: CBService, callback: @escaping ServiceRequestCallback) {
        self.callback = callback
        
        if let serviceUUIDs = serviceUUIDs {
            self.serviceUUIDs = serviceUUIDs
        } else {
            self.serviceUUIDs = nil
        }
        
        self.parentService = service
    }
}

extension PeripheralProxy {
    func discoverIncludedServices(_ serviceUUIDs: [CBUUID]?, forService serviceUUID: CBUUID, completion: @escaping ServiceRequestCallback) {
        self.discoverServices([serviceUUID]) { (services, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let parentService = services!.first!
            
            let request = IncludedServicesRequest(serviceUUIDs: serviceUUIDs, forService: parentService) { (services, error) in
                completion(services, error)
            }
            
            self.includedServicesRequests.append(request)
            
            if self.includedServicesRequests.count == 1 {
                self.runIncludedServicesRequest()
            }
        }
    }
    
    fileprivate func runIncludedServicesRequest() {
        guard let request = self.includedServicesRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverIncludedServices(request.serviceUUIDs, for: request.parentService)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onIncludedServicesRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onIncludedServicesRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<IncludedServicesRequest>
        
        // If the original discover included services callback is still there, this means the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.includedServicesRequests.removeFirst()
        
        request.callback(nil, SBError.operationTimedOut(operation: .discoverIncludedServices))
        
        self.runIncludedServicesRequest()
    }
}

// MARK: Discover Characteristic requests
private final class CharacteristicRequest{
    let service: CBService
    let characteristicUUIDs: [CBUUID]?
    
    let callback: CharacteristicRequestCallback
    
    init(service: CBService,
         characteristicUUIDs: [CBUUID]?,
         callback: @escaping CharacteristicRequestCallback)
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
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?,
                                 forService serviceUUID: CBUUID,
                                            completion: @escaping CharacteristicRequestCallback)
    {
        self.discoverServices([serviceUUID]) { (services, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            // It would be a bug if we received an empty service array without an error from the discoverServices function
            // when asking for a specific service
            let service = services!.first!
            
            // Checking if this service already has the characteristic requested
            if let characteristicUUIDs = characteristicUUIDs {
                let characTuple = service.characteristicsWithUUIDs(characteristicUUIDs)
                
                if (characTuple.missingCharacteristicsUUIDs.count == 0) {
                    completion(characTuple.foundCharacteristics, nil)
                    return
                }
            }
            
            let request = CharacteristicRequest(service: service,
                                                characteristicUUIDs: characteristicUUIDs)
            { (characteristics, error) in
                completion(characteristics, error)
            }
            
            self.characteristicRequests.append(request)
            
            if self.characteristicRequests.count == 1 {
                self.runCharacteristicRequest()
            }
        }
    }
    
    fileprivate func runCharacteristicRequest() {
        guard let request = self.characteristicRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverCharacteristics(request.characteristicUUIDs, for: request.service)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onCharacteristicRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onCharacteristicRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<CharacteristicRequest>
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.characteristicRequests.removeFirst()
        
        request.callback(nil, SBError.operationTimedOut(operation: .discoverCharacteristics))
        
        self.runCharacteristicRequest()
    }
}

// MARK: Discover Descriptors requets
private final class DescriptorRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    
    let callback: DescriptorRequestCallback
    
    init(characteristic: CBCharacteristic, callback: @escaping DescriptorRequestCallback) {
        self.callback = callback
        
        self.service = characteristic.service
        self.characteristic = characteristic
    }
    
}

extension PeripheralProxy {
    func discoverDescriptorsForCharacteristic(_ characteristicUUID: CBUUID, serviceUUID: CBUUID, completion: @escaping DescriptorRequestCallback) {
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // It would be a terrible bug in the first place if the discover characteristic returned an empty array
            // with no error message when searching for a specific characteristic, I want to crash if it happens :)
            let characteristic = characteristics!.first!
            
            let request = DescriptorRequest(characteristic: characteristic) { (descriptors, error) in
                completion(descriptors, error)
            }
            
            self.descriptorRequests.append(request)
            
            if self.descriptorRequests.count == 1 {
                self.runDescriptorRequest()
            }
        }
    }
    
    fileprivate func runDescriptorRequest() {
        guard let request = self.descriptorRequests.first else {
            return
        }
        
        self.cbPeripheral.discoverDescriptors(for: request.characteristic)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onDescriptorRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onDescriptorRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<DescriptorRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        self.descriptorRequests.removeFirst()
        
        request.callback(nil, SBError.operationTimedOut(operation: .discoverDescriptors))
        
        self.runDescriptorRequest()
    }
}

// MARK: Read Characteristic value requests
private final class ReadCharacteristicRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    
    let callback: ReadCharacRequestCallback
    
    init(characteristic: CBCharacteristic, callback: @escaping ReadCharacRequestCallback) {
        self.callback = callback
        
        self.service = characteristic.service
        self.characteristic = characteristic
    }
    
}

extension PeripheralProxy {
    func readCharacteristic(_ characteristicUUID: CBUUID,
                            serviceUUID: CBUUID,
                            completion: @escaping ReadCharacRequestCallback) {
        
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug
            let characteristic = characteristics!.first!
            
            let request = ReadCharacteristicRequest(characteristic: characteristic) { (data, error) in
                completion(data, error)
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
    
    fileprivate func runReadCharacteristicRequest(_ readPath: CBUUIDPath) {
        guard let request = self.readCharacteristicRequests[readPath]?.first else {
            return
        }
        
        self.cbPeripheral.readValue(for: request.characteristic)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadCharacteristicTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onReadCharacteristicTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
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
        
        request.callback(nil, SBError.operationTimedOut(operation: .readCharacteristic))
        
        self.runReadCharacteristicRequest(readPath)
    }
}

// MARK: Read Descriptor value requests
private final class ReadDescriptorRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let descriptor: CBDescriptor
    
    let callback: ReadDescriptorRequestCallback
    
    init(descriptor: CBDescriptor, callback: @escaping ReadDescriptorRequestCallback) {
        self.callback = callback
        
        self.descriptor = descriptor
        self.characteristic = descriptor.characteristic
        self.service = descriptor.characteristic.service
    }
    
}

extension PeripheralProxy {
    func readDescriptor(_ descriptorUUID: CBUUID,
                        characteristicUUID: CBUUID,
                        serviceUUID: CBUUID,
                        completion: @escaping ReadDescriptorRequestCallback)
    {
        
        self.discoverDescriptorsForCharacteristic(characteristicUUID, serviceUUID: serviceUUID) { (descriptors, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let descriptor = descriptors?.first else {
                completion(nil, SBError.peripheralDescriptorsNotFound(missingDescriptorsUUIDs: [descriptorUUID]))
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
    
    fileprivate func runReadDescriptorRequest(_ readPath: CBUUIDPath) {
        guard let request = self.readDescriptorRequests[readPath]?.first else {
            return
        }
        
        self.cbPeripheral.readValue(for: request.descriptor)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadDescriptorTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onReadDescriptorTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
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
        
        request.callback(nil, SBError.operationTimedOut(operation: .readDescriptor))
        
        self.runReadDescriptorRequest(readPath)
    }
}

// MARK: Write Characteristic value requests
private final class WriteCharacteristicValueRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let value: Data
    let type: CBCharacteristicWriteType
    
    let callback: WriteRequestCallback
    
    init(characteristic: CBCharacteristic, value: Data, type: CBCharacteristicWriteType, callback: @escaping WriteRequestCallback) {
        self.callback = callback
        self.value = value
        self.type = type
        self.characteristic = characteristic
        self.service = characteristic.service
    }
    
}

extension PeripheralProxy {
    func writeCharacteristicValue(_ characteristicUUID: CBUUID,
                                  serviceUUID: CBUUID,
                                  value: Data,
                                  type: CBCharacteristicWriteType,
                                  completion: @escaping WriteRequestCallback)
    {
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug hence the forced unwrap
            let characteristic = characteristics!.first!
            
            let request = WriteCharacteristicValueRequest(characteristic: characteristic, value: value, type: type) { (error) in
                completion(error)
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
    
    fileprivate func runWriteCharacteristicValueRequest(_ writePath: CBUUIDPath) {
        guard let request = self.writeCharacteristicValueRequests[writePath]?.first else {
            return
        }
        
        self.cbPeripheral.writeValue(request.value, for: request.characteristic, type: request.type)
        
        if request.type == CBCharacteristicWriteType.withResponse {
            Timer.scheduledTimer(
                timeInterval: PeripheralProxy.defaultTimeoutInS,
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
            
            request.callback(nil)
            
            self.runWriteCharacteristicValueRequest(writePath)
        }
        
    }
    
    @objc fileprivate func onWriteCharacteristicValueRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
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
        
        request.callback(SBError.operationTimedOut(operation: .writeCharacteristic))
        
        self.runWriteCharacteristicValueRequest(writePath)
    }
}

// MARK: Write Descriptor value requests
private final class WriteDescriptorValueRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let descriptor: CBDescriptor
    let value: Data
    
    let callback: WriteRequestCallback
    
    init(descriptor: CBDescriptor, value: Data, callback: @escaping WriteRequestCallback) {
        self.callback = callback
        self.value = value
        self.descriptor = descriptor
        self.characteristic = descriptor.characteristic
        self.service = descriptor.characteristic.service
    }
}

extension PeripheralProxy {
    func writeDescriptorValue(_ descriptorUUID: CBUUID,
                              characteristicUUID: CBUUID,
                              serviceUUID: CBUUID,
                              value: Data,
                              completion: @escaping WriteRequestCallback)
    {
        self.discoverDescriptorsForCharacteristic(characteristicUUID, serviceUUID: serviceUUID) { (descriptors, error) in
            
            if let error = error {
                completion(error)
                return
            }
            
            guard let descriptor = descriptors?.filter({ $0.uuid == descriptorUUID }).first else {
                completion(SBError.peripheralDescriptorsNotFound(missingDescriptorsUUIDs: [descriptorUUID]))
                return
            }
            
            let request = WriteDescriptorValueRequest(descriptor: descriptor, value: value) { (error) in
                completion(error)
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
    
    fileprivate func runWriteDescriptorValueRequest(_ writePath: CBUUIDPath) {
        guard let request = self.writeDescriptorValueRequests[writePath]?.first else {
            return
        }
        
        self.cbPeripheral.writeValue(request.value, for: request.descriptor)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onWriteDescriptorValueRequestTimerTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onWriteDescriptorValueRequestTimerTick(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
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
        
        request.callback(SBError.operationTimedOut(operation: .writeDescriptor))
        
        self.runWriteDescriptorValueRequest(writePath)
    }
}

// MARK: Update Characteristic Notification State requests
private final class UpdateNotificationStateRequest {
    let service: CBService
    let characteristic: CBCharacteristic
    let enabled: Bool
    
    let callback: UpdateNotificationStateCallback
    
    init(enabled: Bool, characteristic: CBCharacteristic, callback: @escaping UpdateNotificationStateCallback) {
        self.enabled = enabled
        self.characteristic = characteristic
        self.service = characteristic.service
        self.callback = callback
    }
}

extension PeripheralProxy {
    func setNotifyValueForCharacteristic(_ enabled: Bool, characteristicUUID: CBUUID, serviceUUID: CBUUID, completion: @escaping UpdateNotificationStateCallback) {
        
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Having no error yet not having the characteristic should never happen and would be considered a bug,
            // I'd rather crash here than not notice the bug hence the forced unwrap
            let characteristic = characteristics!.first!
            
            let request = UpdateNotificationStateRequest(enabled: enabled, characteristic: characteristic) { (isNotifying, error) in
                completion(isNotifying, error)
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
    
    fileprivate func runUpdateNotificationStateRequest(_ path: CBUUIDPath) {
        guard let request = self.updateNotificationStateRequests[path]?.first else {
            return
        }
        
        self.cbPeripheral.setNotifyValue(request.enabled, for: request.characteristic)
        
        Timer.scheduledTimer(
            timeInterval: PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onUpdateNotificationStateRequest),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc fileprivate func onUpdateNotificationStateRequest(_ timer: Timer) {
        defer {
            if timer.isValid { timer.invalidate() }
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
        
        request.callback(nil, SBError.operationTimedOut(operation: .updateNotificationStatus))
        
        self.runUpdateNotificationStateRequest(path)
    }
}

// MARK: CBPeripheralDelegate
extension PeripheralProxy: CBPeripheralDelegate {
    @objc func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard let readRSSIRequest = self.readRSSIRequests.first else {
            return
        }
        
        self.readRSSIRequests.removeFirst()
        
        var rssi: Int?
        
        if error == nil {
            rssi = RSSI.intValue
        }
        
        readRSSIRequest.callback(rssi, error)
        
        self.runRSSIRequest()
    }
    
    @objc func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        var userInfo: [AnyHashable: Any]?
        if let name = peripheral.name {
            userInfo = ["name": name]
        }
        
        self.postPeripheralEvent(.PeripheralNameUpdate, userInfo: userInfo)
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        self.postPeripheralEvent(.PeripheralModifedServices, userInfo: ["invalidatedServices": invalidatedServices])
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        guard let includedServicesRequest = self.includedServicesRequests.first else {
            return
        }
        
        defer {
            self.runIncludedServicesRequest()
        }
        
        self.includedServicesRequests.removeFirst()
        
        if let error = error {
            includedServicesRequest.callback(nil, error)
            return
        }
        
        if let serviceUUIDs = includedServicesRequest.serviceUUIDs {
            let servicesTuple = peripheral.servicesWithUUIDs(serviceUUIDs)
            if servicesTuple.missingServicesUUIDs.count > 0 {
                includedServicesRequest.callback(nil, SBError.peripheralServiceNotFound(missingServicesUUIDs: servicesTuple.missingServicesUUIDs))
            } else { // This implies that all the services we're found through Set logic in the servicesWithUUIDs function
                includedServicesRequest.callback(servicesTuple.foundServices, nil)
            }
        } else {
            includedServicesRequest.callback(service.includedServices, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let serviceRequest = self.serviceRequests.first else {
            return
        }
        
        defer {
            self.runServiceRequest()
        }
        
        self.serviceRequests.removeFirst()
        
        if let error = error {
            serviceRequest.callback(nil, error)
            return
        }
        
        if let serviceUUIDs = serviceRequest.serviceUUIDs {
            let servicesTuple = peripheral.servicesWithUUIDs(serviceUUIDs)
            if servicesTuple.missingServicesUUIDs.count > 0 {
                serviceRequest.callback(nil, SBError.peripheralServiceNotFound(missingServicesUUIDs: servicesTuple.missingServicesUUIDs))
            } else { // This implies that all the services we're found through Set logic in the servicesWithUUIDs function
                serviceRequest.callback(servicesTuple.foundServices, nil)
            }
        } else {
            serviceRequest.callback(peripheral.services, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristicRequest = self.characteristicRequests.first else {
            return
        }
        
        defer {
            self.runCharacteristicRequest()
        }
        
        self.characteristicRequests.removeFirst()
        
        if let error = error {
            characteristicRequest.callback(nil, error)
            return
        }
        
        if let characteristicUUIDs = characteristicRequest.characteristicUUIDs {
            let characteristicsTuple = service.characteristicsWithUUIDs(characteristicUUIDs)
            
            if characteristicsTuple.missingCharacteristicsUUIDs.count > 0 {
                characteristicRequest.callback(nil, SBError.peripheralCharacteristicNotFound(missingCharacteristicsUUIDs: characteristicsTuple.missingCharacteristicsUUIDs))
            } else {
                characteristicRequest.callback(characteristicsTuple.foundCharacteristics, nil)
            }
            
        } else {
            characteristicRequest.callback(service.characteristics, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let descriptorRequest = self.descriptorRequests.first else {
            return
        }
        
        defer {
            self.runDescriptorRequest()
        }
        
        self.descriptorRequests.removeFirst()
        
        if let error = error {
            descriptorRequest.callback(nil, error)
        } else {
            descriptorRequest.callback(characteristic.descriptors, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let readPath = characteristic.uuidPath
        
        guard let request = self.readCharacteristicRequests[readPath]?.first else {
            if characteristic.isNotifying {
                var userInfo: [AnyHashable: Any] = ["characteristic": characteristic]
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
            request.callback(nil, error)
        } else {
            request.callback(characteristic.value, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
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
            request.callback(error)
        } else {
            request.callback(nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
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
            request.callback(nil, error)
        } else {
            request.callback(characteristic.isNotifying, nil)
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
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
            request.callback(nil, error)
        } else {
            do {
                let value = try DescriptorValue(descriptor: descriptor)
                request.callback(value, nil)
            } catch let error {
                request.callback(nil, error)
            }
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
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
            request.callback(error)
        } else {
            request.callback(nil)
        }
    }
}
