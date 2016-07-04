//
//  Peripheral.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

public enum PeripheralEvent: String {
    case PeripheralStateChange
    case PeripheralRSSIUpdate
    case PeripheralNameUpdate
    case PeripheralModifedServices
    case CharacteristicValueUpdate
    case CharacteristicNotificationStateUpdate
}

public typealias ReadRSSIRequestCallback = (RSSI: Int?, error: BleError?) -> Void
public typealias ServiceRequestCallback = (services: [CBService]?, error: BleError?) -> Void
public typealias CharacteristicRequestCallback = (characteristics: [CBCharacteristic]?, error: BleError?) -> Void
public typealias DescriptorRequestCallback = (descriptors: [CBDescriptor]?, error: BleError?) -> Void
public typealias ReadRequestCallback = (data: NSData?, error: BleError?) -> Void
public typealias WriteRequestCallback = (error: BleError?) -> Void
public typealias UpdateNotificationStateCallback = (isNotifying: Bool?, error: BleError?) -> Void

public final class Peripheral {
    private var peripheralProxy: PeripheralProxy!
    
    init(peripheral: CBPeripheral) {
        self.peripheralProxy = PeripheralProxy(cbPeripheral: peripheral, peripheral: self)
    }
}

// Public
extension Peripheral {
    public var identifier: NSUUID {
        get {
            return self.peripheralProxy.identifier
        }
    }
    
    public var name: String? {
        get {
            return self.peripheralProxy.name
        }
    }
    
    public var state: CBPeripheralState {
        get {
            return self.peripheralProxy.state
        }
    }
    
    public var services: [CBService]? {
        get {
            return self.peripheralProxy.services
        }
    }
    
    public var RSSI: Int? {
        get {
            return self.peripheralProxy.RSSI
        }
    }
    
    public func connect(completion: (error: BleError?) -> Void) {
        self.peripheralProxy.connect(completion)
    }
    
    public func disconnect(completion: (error: BleError?) -> Void) {
        self.peripheralProxy.disconnect(completion)
    }
    
    public func readRSSI(completion: ReadRSSIRequestCallback) {
        self.peripheralProxy.readRSSI(completion)
    }
    
    public func discoverServices(serviceUUIDs: [CBUUIDConvertible]?,
                                 completion: ServiceRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the services.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverServices method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        self.peripheralProxy.discoverServices(ExtractCBUUIDs(serviceUUIDs), completion: completion)
    }
    
    public func discoverCharacteristics(characteristicUUIDs: [CBUUIDConvertible]?,
                                        forService serviceUUID: CBUUIDConvertible,
                                                   completion: CharacteristicRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the characteristics.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverCharacteristics method works
        assert(characteristicUUIDs == nil || characteristicUUIDs?.count > 0)
        self.peripheralProxy.discoverCharacteristics(ExtractCBUUIDs(characteristicUUIDs), forService: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    public func discoverDescriptorsForCharacteristic(characteristicUUID: CBUUIDConvertible,
                                                     serviceUUID: CBUUIDConvertible,
                                                     completion: DescriptorRequestCallback)
    {
        self.peripheralProxy.discoverDescriptorsForCharacteristic(characteristicUUID.CBUUIDRepresentation, serviceUUID: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    public func readCharacteristicValue(characteristicUUID: CBUUIDConvertible,
                                        serviceUUID: CBUUIDConvertible,
                                        completion: ReadRequestCallback)
    {
        self.peripheralProxy.readCharacteristic(characteristicUUID.CBUUIDRepresentation,
                                                serviceUUID: serviceUUID.CBUUIDRepresentation,
                                                completion: completion)
    }
    
    public func readCharacteristicValue(characteristic: CBCharacteristic,
                                        completion: ReadRequestCallback)
    {
        self.readCharacteristicValue(characteristic,
                                     serviceUUID: characteristic.service,
                                     completion: completion)
    }
    
    public func readDescriptorValue(descriptorUUID: CBUUIDConvertible,
                                    characteristicUUID: CBUUIDConvertible,
                                    serviceUUID: CBUUIDConvertible,
                                    completion: ReadRequestCallback)
    {
        self.peripheralProxy.readDescriptor(descriptorUUID.CBUUIDRepresentation,
                                            characteristicUUID: characteristicUUID.CBUUIDRepresentation,
                                            serviceUUID: serviceUUID.CBUUIDRepresentation,
                                            completion: completion)
    }
    
    public func readDescriptorValue(descriptor: CBDescriptor,
                                    completion: ReadRequestCallback)
    {
        self.readDescriptorValue(descriptor,
                                 characteristicUUID: descriptor.characteristic,
                                 serviceUUID: descriptor.characteristic.service,
                                 completion: completion)
    }
    
    public func writeCharacteristicValue(characteristicUUID: CBUUIDConvertible,
                                         serviceUUID: CBUUIDConvertible,
                                         value: NSData,
                                         type: CBCharacteristicWriteType = .WithResponse,
                                         completion: WriteRequestCallback)
    {
        self.peripheralProxy.writeCharacteristicValue(characteristicUUID.CBUUIDRepresentation,
                                                      serviceUUID: serviceUUID.CBUUIDRepresentation,
                                                      value: value,
                                                      type: type,
                                                      completion: completion)
    }
    
    public func writeCharacteristicValue(characteristic: CBCharacteristic,
                                         value: NSData,
                                         type: CBCharacteristicWriteType = .WithResponse,
                                         completion: WriteRequestCallback)
    {
        self.writeCharacteristicValue(characteristic.UUID,
                                      serviceUUID: characteristic.service.UUID,
                                      value: value,
                                      type: type,
                                      completion: completion)
    }
    
    public func writeDescriptorValue(descriptorUUID: CBUUIDConvertible,
                                     characteristicUUID: CBUUIDConvertible,
                                     serviceUUID: CBUUIDConvertible,
                                     value: NSData,
                                     completion: WriteRequestCallback)
    {
        self.peripheralProxy.writeDescriptorValue(descriptorUUID.CBUUIDRepresentation,
                                                  characteristicUUID: characteristicUUID.CBUUIDRepresentation,
                                                  serviceUUID: serviceUUID.CBUUIDRepresentation,
                                                  value: value,
                                                  completion: completion)
    }
    
    public func writeDescriptorValue(descriptor: CBDescriptor,
                                     value: NSData,
                                     completion: WriteRequestCallback)
    {
        self.writeDescriptorValue(descriptor.UUID,
                                  characteristicUUID: descriptor.characteristic.UUID,
                                  serviceUUID: descriptor.characteristic.service.UUID,
                                  value: value,
                                  completion: completion)
    }
    
    public func setNotifyValueForCharacteristic(enabled: Bool,
                                                characteristicUUID: CBUUIDConvertible,
                                                serviceUUID: CBUUIDConvertible,
                                                completion: UpdateNotificationStateCallback)
    {
        self.peripheralProxy.setNotifyValueForCharacteristic(enabled,
                                                             characteristicUUID: characteristicUUID.CBUUIDRepresentation,
                                                             serviceUUID: characteristicUUID.CBUUIDRepresentation,
                                                             completion: completion)
    }
    
    public func setNotifyValueForCharacteristic(enabled: Bool,
                                                characteristic: CBCharacteristic,
                                                completion: UpdateNotificationStateCallback)
    {
        self.setNotifyValueForCharacteristic(enabled,
                                             characteristicUUID: characteristic,
                                             serviceUUID: characteristic.service,
                                             completion: completion)
    }
}
