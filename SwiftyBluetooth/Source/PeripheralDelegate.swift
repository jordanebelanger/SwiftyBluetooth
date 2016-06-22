//
//  PeripheralDelegate.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/20/16.
//
//

import Foundation
import CoreBluetooth

private final class ReadRSSIRequest {
    lazy var callbacks: [ReadRSSIRequestCallback] = []
    
    init(callback: ReadRSSIRequestCallback) {
        self.callbacks.append(callback)
    }
    
    func invokeCallbacks(RSSI: Int?, error: BleError?) {
        for callback in callbacks {
            callback(RSSI: RSSI, error: error)
        }
    }
}

private final class ServiceRequest: Hashable {
    let serviceCBUUIDSet: Set<CBUUID>?
    
    lazy var callbacks: [ServiceRequestCallback] = []
    
    init(serviceUUIDs: [CBUUIDConvertible]?, callback: ServiceRequestCallback? = nil) {
        if let callback = callback {
            self.callbacks.append(callback)
        }
        
        guard let serviceCBUUIDs = ExtractCBUUIDs(serviceUUIDs) else {
            self.serviceCBUUIDSet = nil
            self._hashValue = Int.max
            return
        }
        
        let serviceCBUUIDSet = Set(serviceCBUUIDs)
        self.serviceCBUUIDSet = serviceCBUUIDSet
        
        self._hashValue = serviceCBUUIDSet.hashValue
    }
    
    func invokeCallbacks(services: [CBService]?, error: BleError?) {
        for callback in callbacks {
            callback(services: services, error: error)
        }
    }
    
    private let _hashValue: Int
    var hashValue : Int {
        get {
            return self._hashValue
        }
    }
}
private func ==(lhs: ServiceRequest, rhs: ServiceRequest) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

private final class CharacteristicRequest: Hashable {
    let service: CBService
    let characteristicCBUUIDSet: Set<CBUUID>?
    
    lazy var callbacks: [CharacteristicRequestCallback] = []
    
    init(service: CBService,
         characteristicUUIDs: [CBUUIDConvertible]?,
         callback: CharacteristicRequestCallback? = nil)
    {
        if let callback = callback {
            self.callbacks.append(callback)
        }
        
        self.service = service
        
        guard let characteristicCBUUIDs = ExtractCBUUIDs(characteristicUUIDs) else {
            self.characteristicCBUUIDSet = nil
            self._hashValue = service.CBUUIDRepresentation.UUIDString.hashValue
        }
        
        let characteristicCBUUIDSet = Set(characteristicCBUUIDs)
        self.characteristicCBUUIDSet = characteristicCBUUIDSet
        
        self._hashValue = service.CBUUIDRepresentation.hashValue ^ characteristicCBUUIDSet.hashValue
    }
    
    func invokeCallbacks(characteristics: [CBCharacteristic]?, error: BleError?) {
        for callback in callbacks {
            callback(characteristics: characteristics, error: error)
        }
    }
    
    var _hashValue: Int
    var hashValue : Int {
        get {
            return self._hashValue
        }
    }
}
private func ==(lhs: CharacteristicRequest, rhs: CharacteristicRequest) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

private final class DescriptorRequest: Hashable {
    let characteristic: CBCharacteristic
    
    lazy var callbacks: [DescriptorRequestCallback] = []
    
    init(characteristic: CBCharacteristic, callback: DescriptorRequestCallback? = nil) {
        if let callback = callback {
            self.callbacks.append(callback)
        }
        
        self.characteristic = characteristic
    }
    
    func invokeCallbacks(descriptors: [CBDescriptor]?, error: BleError?) {
        for callback in callbacks {
            callback(descriptors: descriptors, error: error)
        }
    }
    
    var hashValue : Int {
        get {
            return self.characteristic.CBUUIDRepresentation.hashValue
        }
    }
}
private func ==(lhs: DescriptorRequest, rhs: DescriptorRequest) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

private final class ReadCharacteristicRequest {
    let characteristic: CBCharacteristic
    
    lazy var callbacks: [ReadRequestCallback] = []
    
    init(characteristic: CBCharacteristic, callback: ReadRequestCallback? = nil) {
        if let callback = callback {
            self.callbacks.append(callback)
        }
        
        self.characteristic = characteristic
    }
    
    func invokeCallbacks(data: NSData?, error: BleError?) {
        for callback in callbacks {
            callback(data: data, error: error)
        }
    }
}

private final class PeripheralProxy: NSObject  {
    static let defaultTimeoutInS: NSTimeInterval = 4
    
    var readRSSIRequest: ReadRSSIRequest?
    var serviceRequests: [ServiceRequest: ServiceRequest] = [:]
    var characteristicRequests: [CharacteristicRequest: CharacteristicRequest] = [:]
    var descriptorRequests: [DescriptorRequest: DescriptorRequest] = [:]
    var readCharacteristicRequest: [CBUUIDPath: [Box<ReadRequestCallback>]] = [:]
    var readDescriptorRequest: [CBUUIDPath: [Box<ReadRequestCallback>]] = [:]
    
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        
        peripheral.delegate = self
    }
    
    func readRSSI(completion: ReadRSSIRequestCallback) {
        if let readRSSIRequest = self.readRSSIRequest {
            readRSSIRequest.callbacks.append(completion)
            return
        }
        
        let request = ReadRSSIRequest(callback: completion)
        
        self.peripheral.readRSSI()
        NSTimer.scheduledTimerWithTimeInterval(
            PeripheralProxy.defaultTimeoutInS,
            target: self,
            selector: #selector(self.onReadRSSIOperationTick),
            userInfo: Weak(value: request),
            repeats: false)
    }
    
    @objc func onReadRSSIOperationTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<ReadRSSIRequest>
        
        guard let request = weakRequest.value else {
            return
        }
        
        self.readRSSIRequest = nil
        
        request.invokeCallbacks(nil, error: BleError.BleTimeoutError)
    }
    
    func discoverServices(serviceUUIDs: [CBUUIDConvertible]?, completion: ServiceRequestCallback) {
        
        // Checking if the peripheral has already discovered the services requested
        if let serviceUUIDs = serviceUUIDs where serviceUUIDs.count > 0 {
            let servicesTuple = self.peripheral.servicesWithUUIDs(serviceUUIDs)
            
            if (servicesTuple.missingServices.count == 0) {
                completion(services: servicesTuple.foundServices, error: nil)
                return
            }
        }
        
        let request = ServiceRequest(serviceUUIDs: serviceUUIDs)
        
        if let existingRequest = self.serviceRequests. {
            
        }
        let CBUUIDs = ExtractCBUUIDs(serviceUUIDs)
        
        let request = ServiceRequest(serviceUUIDs: CBUUIDs) { (services, error) in
            completion(services: services, error: error)
        }
        
        self.serviceRequests.append(request)
        
        if (self.serviceRequests.count == 1) {
            self.runServiceRequest()
        }
    }
    
    func runServiceRequest() {
        guard let request = self.serviceRequests.first else {
            return
        }
        
        self.peripheral.discoverServices(request.serviceUUIDs)
        
        let userInfo = Weak(value: request)
        NSTimer.scheduledTimerWithTimeInterval(
            4.0,
            target: self,
            selector: #selector(self.onServiceRequestTimerTick),
            userInfo: userInfo,
            repeats: false)
    }
    
    @objc func onServiceRequestTimerTick(timer: NSTimer) {
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
        
        request.callback(services: nil, error: BleError.BleTimeoutError)
        
        self.runServiceRequest()
    }
    
    func discoverCharacteristics(characteristicUUIDs: [CBUUIDConvertible]?,
                                 forService serviceUUID: CBUUIDConvertible,
                                            completion: CharacteristicRequestCallback)
    {
        self.discoverServices([serviceUUID]) { (services, error) in
            guard let service = services?.first else {
                completion(characteristics: nil, error: error)
                return
            }
            
            if let characteristicUUIDs = characteristicUUIDs where characteristicUUIDs.count > 0 {
                let characTuple = service.characteristicsWithUUIDs(characteristicUUIDs)
                
                if (characTuple.missingCharacteristics.count == 0) {
                    completion(characteristics: characTuple.foundCharacteristics, error: nil)
                    return
                }
            }
            
            let request = CharacteristicRequest(service: service,
                                                characteristicUUIDs: characteristicUUIDs)
            { (characteristic, error) in
                completion(characteristics: characteristic, error: error)
            }
            
            self.characteristicRequests.append(request)
            
            if (self.characteristicRequests.count == 1) {
                self.runCharacteristicRequest()
            }
        }
    }
    
    func runCharacteristicRequest() {
        guard let request = self.characteristicRequests.first else {
            return
        }
        
        self.peripheral.discoverCharacteristics(request.characteristicUUIDs, forService: request.service)
        
        let userInfo = Weak(value: request)
        NSTimer.scheduledTimerWithTimeInterval(
            4.0,
            target: self,
            selector: #selector(self.onCharacteristicRequestTimerTick),
            userInfo: userInfo,
            repeats: false)
    }
    
    @objc func onCharacteristicRequestTimerTick(timer: NSTimer) {
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
        
        request.callback(characteristics: nil, error: BleError.BleTimeoutError)
        
        self.runCharacteristicRequest()
    }
    
    func discoverDescriptorsForCharacteristic(characteristicUUID: CBUUIDConvertible, serviceUUID: CBUUIDConvertible, completion: DescriptorRequestCallback) {
        let serviceCBUUID = serviceUUID.CBUUIDRepresentation
        let characteristicCBUUID = characteristicUUID.CBUUIDRepresentation
        
        self.discoverServices([serviceUUID]) { (services, error) in
            
            if let error = error {
                completion(descriptors: nil, error: error)
                return
            }
            
            guard let service = services?.first else {
                completion(descriptors: nil, error: BleError.PeripheralServiceNotFound(missingServices: [serviceUUID]))
                return
            }
            
            self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
                
                if let error = error {
                    completion(descriptors: nil, error: error)
                    return
                }
                
                guard let characteristic = characteristics?.first else {
                    completion(descriptors: nil, error: BleError.PeripheralCharacteristicNotFound(missingCharacteristics: [characteristicUUID]))
                    return
                }
                
                let request = DescriptorRequest(characteristic: characteristic) { (descriptors, error) in
                    completion(descriptors: descriptors, error: error)
                }
                
                self.descriptorRequests.append(request)
                
                if (self.descriptorRequests.count == 1) {
                    self.runDescriptorRequest()
                }
            }
        }
    }
    
    func runDescriptorRequest() {
        guard let request = self.descriptorRequests.first else {
            return
        }
        
        self.peripheral.discoverDescriptorsForCharacteristic(request.characteristic)
        
        let userInfo = Weak(value: request)
        NSTimer.scheduledTimerWithTimeInterval(
            4.0,
            target: self,
            selector: #selector(self.onDescriptorRequestTimerTick),
            userInfo: userInfo,
            repeats: false)
    }
    
    @objc func onDescriptorRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let weakRequest = timer.userInfo as! Weak<DescriptorRequest>
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let request = weakRequest.value else {
            return
        }
        
        self.descriptorRequests.removeFirst()
        
        request.callback(descriptors: nil, error: BleError.BleTimeoutError)
        
        self.runDescriptorRequest()
    }
    
    func readCharacteristic(characteristicUUID: CBUUIDConvertible,
                            serviceUUID: CBUUIDConvertible,
                            completion: ReadRequestCallback) {
        
        self.discoverCharacteristics([characteristicUUID], forService: serviceUUID) { (characteristics, error) in
            
            if let error = error {
                completion(data: nil, error: error)
                return
            }
            
            guard let characteristic = characteristics?.first else {
                completion(data: nil, error: BleError.PeripheralCharacteristicNotFound(missingCharacteristics: [characteristicUUID]))
                return
            }
            
            let path = characteristicPath(service: serviceUUID, characteristic: characteristic)
            
            if var callbacks = self.readCharacteristicRequest[path] {
                callbacks.append(completion)
                self.readCharacteristicRequest[path] = callbacks
            } else {
                self.readCharacteristicRequest[path] = [completion]
                
                self.peripheral.readValueForCharacteristic(characteristic)
                NSTimer.scheduledTimerWithTimeInterval(
                    4.0,
                    target: self,
                    selector: #selector(self.onReadRequestTimerTick),
                    userInfo: path,
                    repeats: false)
            }
            
        }
    }
    
    @objc func onReadRequestTimerTick(timer: NSTimer) {
        defer {
            if timer.valid { timer.invalidate() }
        }
        
        let path = timer.userInfo as! CBUUIDPath
        
        // If the original rssi read operation callback is still there, this should mean the operation went
        // through and this timer can be ignored
        guard let callbacks = self.readCharacteristicRequest[path] else {
            return
        }
        
        
        
        request.callback(descriptors: nil, error: BleError.BleTimeoutError)
        
        self.runDescriptorRequest()
    }
    /*
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
     */
}

extension PeripheralProxy: CBPeripheralDelegate {
    @objc private func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        guard let readRSSIRequest = self.readRSSIRequest else {
            return
        }
        
        self.readRSSIRequest = nil
        
        var rssi: Int?
        var bleError: BleError?
        
        if let error = error {
            bleError = .CoreBluetoothError(error: error)
        } else {
            rssi = RSSI.integerValue
        }
        
        readRSSIRequest.invokeCallbacks(rssi, error: bleError)
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard let serviceRequest = self.serviceRequests.first else {
            return
        }
        
        self.serviceRequests.removeFirst()
        
        if let error = error {
            serviceRequest.callback(services: nil, error: BleError.CoreBluetoothError(error: error))
            return
        }
        
        if let serviceUUIDs = serviceRequest.serviceUUIDs {
            let convertibleCBUUIDArrayCast = serviceUUIDs.map { $0 as CBUUIDConvertible }
            let servicesTuple = peripheral.servicesWithUUIDs(convertibleCBUUIDArrayCast)
            if servicesTuple.missingServices.count > 0 {
                serviceRequest.callback(services: nil, error: BleError.PeripheralServiceNotFound(missingServices: servicesTuple.missingServices))
            } else {
                serviceRequest.callback(services: servicesTuple.foundServices, error: nil)
            }
        } else {
            serviceRequest.callback(services: peripheral.services, error: nil)
        }
        
        self.runServiceRequest()
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        guard let characteristicRequest = self.characteristicRequests.first else {
            return
        }
        
        self.characteristicRequests.removeFirst()
        
        if let error = error {
            characteristicRequest.callback(characteristics: nil, error: BleError.CoreBluetoothError(error: error))
            return
        }
        
        if let characteristicUUIDs = characteristicRequest.characteristicUUIDs {
            let convertibleCBUUIDs = characteristicUUIDs.map { $0 as CBUUIDConvertible }
            
            let characteristicsTuple = service.characteristicsWithUUIDs(convertibleCBUUIDs)
            
            if characteristicsTuple.missingCharacteristics.count > 0 {
                characteristicRequest.callback(characteristics: nil, error: BleError.PeripheralCharacteristicNotFound(missingCharacteristics: characteristicsTuple.missingCharacteristics))
            } else {
                characteristicRequest.callback(characteristics: characteristicsTuple.foundCharacteristics, error: nil)
            }
            
        } else {
            characteristicRequest.callback(characteristics: service.characteristics, error: nil)
        }
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        guard let descriptorRequest = self.descriptorRequests.first else {
            return
        }
        
        self.descriptorRequests.removeFirst()
        
        if let error = error {
            descriptorRequest.callback(descriptors: nil, error: BleError.CoreBluetoothError(error: error))
            return
        }
        
        descriptorRequest.callback(descriptors: characteristic.descriptors, error: nil)
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }
    
    @objc private func peripheralDidUpdateName(peripheral: CBPeripheral) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        
    }
    
    @objc private func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        
    }
    
}