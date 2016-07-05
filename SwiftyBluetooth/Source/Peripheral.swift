//
//  Peripheral.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

/**
    The Peripheral notifications sent through the default 'NSNotificationCenter' by Peripherals.
 
    Use the PeripheralEvent enum rawValue as the notification string when registering for notifications.
 
    - PeripheralNameUpdate: Updates to a Peripheral's CBPeripheral name value, userInfo: ["name": String?]
    - PeripheralModifedServices: Update to a peripheral's CBPeripheral services, userInfo: ["invalidatedServices": [CBService]]
    - CharacteristicValueUpdate: An update to the value of a characteristic you're peripherals is subscribed for updates from, userInfo: ["characteristic": CBCharacteristic, "error": BleError?]
*/
public enum PeripheralEvent: String {
    case PeripheralNameUpdate
    case PeripheralModifedServices
    case CharacteristicValueUpdate
}

public typealias ReadRSSIRequestCallback = (RSSI: Int?, error: BleError?) -> Void
public typealias ServiceRequestCallback = (services: [CBService]?, error: BleError?) -> Void
public typealias CharacteristicRequestCallback = (characteristics: [CBCharacteristic]?, error: BleError?) -> Void
public typealias DescriptorRequestCallback = (descriptors: [CBDescriptor]?, error: BleError?) -> Void
public typealias ReadRequestCallback = (data: NSData?, error: BleError?) -> Void
public typealias WriteRequestCallback = (error: BleError?) -> Void
public typealias UpdateNotificationStateCallback = (isNotifying: Bool?, error: BleError?) -> Void

/// An interface on top of a CBPeripheral instance used to run CBPeripheral related functions with closures based callbacks instead of the usual CBPeripheralDelegate interface.
public final class Peripheral {
    private var peripheralProxy: PeripheralProxy!
    
    init(peripheral: CBPeripheral) {
        self.peripheralProxy = PeripheralProxy(cbPeripheral: peripheral, peripheral: self)
    }
}

/// Mark: Public
extension Peripheral {
    /// The underlying CBPeripheral identifier
    public var identifier: NSUUID {
        get {
            return self.peripheralProxy.identifier
        }
    }
    
    /// The underlying CBPeripheral name
    public var name: String? {
        get {
            return self.peripheralProxy.name
        }
    }
    
    /// The underlying CBPeripheral state
    public var state: CBPeripheralState {
        get {
            return self.peripheralProxy.state
        }
    }
    
    /// The underlying CBPeripheral services
    public var services: [CBService]? {
        get {
            return self.peripheralProxy.services
        }
    }
    
    /// The underlying CBPeripheral RSSI
    public var RSSI: Int? {
        get {
            return self.peripheralProxy.RSSI
        }
    }
    
    /// Connect to the peripheral through Ble to our Central sharedInstance
    public func connect(completion: (error: BleError?) -> Void) {
        self.peripheralProxy.connect(completion)
    }
    
    /// Disconnect the peripheral from our Central sharedInstance
    public func disconnect(completion: (error: BleError?) -> Void) {
        self.peripheralProxy.disconnect(completion)
    }
    
    /// Connects to the peripheral and update the Peripheral's RSSI through a 'CBPeripheral' readRSSI() function call
    ///
    /// - Parameter completion: A closure containing the integer value of the updated RSSI or an error.
    public func readRSSI(completion: ReadRSSIRequestCallback) {
        self.peripheralProxy.readRSSI(completion)
    }
    
    ///    Connects to the peripheral and discover the requested services through a 'CBPeripheral' discoverServices(...) function call
    ///
    ///    - Parameter serviceUUIDs: The UUIDs of the services you want to discover or nil if you want to discover all services.
    ///    - Parameter completion: A closures containing an array of the services found or an error.
    public func discoverServices(serviceUUIDs: [CBUUIDConvertible]?,
                                 completion: ServiceRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the services.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverServices method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        self.peripheralProxy.discoverServices(ExtractCBUUIDs(serviceUUIDs), completion: completion)
    }
    
    ///    Connects to the peripheral and discover the requested characteristics through a 'CBPeripheral' discoverCharacteristics(...) function call.
    ///    Will first discover the service of the requested characteristics if necessary.
    ///
    ///    - Parameter serviceUUID: The UUID of the service of the characteristics requested.
    ///    - Parameter characteristicUUIDs: The UUIDs of the characteristics you want to discover or nil if you want to discover all characteristics.
    ///    - Parameter completion: A closures containing an array of the characteristics found or an error.
    public func discoverCharacteristics(characteristicUUIDs: [CBUUIDConvertible]?,
                                        forService serviceUUID: CBUUIDConvertible,
                                                   completion: CharacteristicRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the characteristics.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverCharacteristics method works
        assert(characteristicUUIDs == nil || characteristicUUIDs?.count > 0)
        self.peripheralProxy.discoverCharacteristics(ExtractCBUUIDs(characteristicUUIDs), forService: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    ///    Connects to the peripheral and discover the requested descriptors through a 'CBPeripheral' discoverDescriptorsForCharacteristic(...) function call.
    ///    Will first discover the service and characteristic for which you want to discover descriptors from.
    ///
    ///    - Parameter characteristicUUID: The UUID of the characteristic you want to discover descriptors from.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter completion: A closures containing an array of the descriptors found or an error.
    public func discoverDescriptorsForCharacteristic(characteristicUUID: CBUUIDConvertible,
                                                     serviceUUID: CBUUIDConvertible,
                                                     completion: DescriptorRequestCallback)
    {
        self.peripheralProxy.discoverDescriptorsForCharacteristic(characteristicUUID.CBUUIDRepresentation, serviceUUID: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    ///    Connect to the peripheral and read the value of the characteristic requested through a 'CBPeripheral' readValueForCharacteristic(...) function call.
    ///    Will first discover the service and characteristic you want to read from if necessary.
    ///
    ///    - Parameter characteristicUUID: The UUID of the characteristic you want to read from.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter completion: A closures containing the data read or an error.
    public func readCharacteristicValue(characteristicUUID: CBUUIDConvertible,
                                        serviceUUID: CBUUIDConvertible,
                                        completion: ReadRequestCallback)
    {
        self.peripheralProxy.readCharacteristic(characteristicUUID.CBUUIDRepresentation,
                                                serviceUUID: serviceUUID.CBUUIDRepresentation,
                                                completion: completion)
    }
    
    ///    Connect to the peripheral and read the value of the passed characteristic through a 'CBPeripheral' readValueForCharacteristic(...) function call.
    ///
    ///    - Parameter characteristic: The characteristic you want to read from.
    ///    - Parameter completion: A closures containing the data read or an error.
    public func readCharacteristicValue(characteristic: CBCharacteristic,
                                        completion: ReadRequestCallback)
    {
        self.readCharacteristicValue(characteristic,
                                     serviceUUID: characteristic.service,
                                     completion: completion)
    }
    
    ///    Connect to the peripheral and read the value of the descriptor requested through a 'CBPeripheral' readValueForDescriptor(...) function call.
    ///    Will first discover the service, characteristic and descriptor you want to read from if necessary.
    ///
    ///    - Parameter descriptorUUID: The UUID of the descriptor you want to read from.
    ///    - Parameter characteristicUUID: The UUID of the descriptor above.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter completion: A closures containing the data read or an error.
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
    
    ///    Connect to the peripheral and read the value of the passed descriptor through a 'CBPeripheral' readValueForDescriptor(...) function call.
    ///
    ///    - Parameter descriptor: The descriptor you want to read from.
    ///    - Parameter characteristicUUID: The UUID of the descriptor above.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter completion: A closures containing the data read or an error.
    public func readDescriptorValue(descriptor: CBDescriptor,
                                    completion: ReadRequestCallback)
    {
        self.readDescriptorValue(descriptor,
                                 characteristicUUID: descriptor.characteristic,
                                 serviceUUID: descriptor.characteristic.service,
                                 completion: completion)
    }
    
    ///    Connect to the peripheral and write a value to the characteristic requested through a 'CBPeripheral' writeValue:forCharacteristic(...) function call.
    ///    Will first discover the service and characteristic you want to write to if necessary.
    ///
    ///    - Parameter characteristicUUID: The UUID of the characteristic you want to write to.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter value: The data being written to the characteristic
    ///    - Parameter type: The type of the CBPeripheral write, wither with or without response in which case the closure is called right away
    ///    - Parameter completion: A closures containing an error if something went wrong
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
    
    ///    Connect to the peripheral and write a value to the passed characteristic through a 'CBPeripheral' writeValue:forCharacteristic(...) function call.
    ///
    ///    - Parameter characteristic: The characteristic you want to write to.
    ///    - Parameter value: The data being written to the characteristic
    ///    - Parameter type: The type of the CBPeripheral write, wither with or without response in which case the closure is called right away
    ///    - Parameter completion: A closures containing an error if something went wrong
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
    
    ///    Connect to the peripheral and write a value to the descriptor requested through a 'CBPeripheral' writeValue:forDescriptor(...) function call.
    ///    Will first discover the service, characteristic and descriptor you want to write to if necessary.
    ///
    ///    - Parameter descriptorUUID: The UUID of the descriptor you want to write to.
    ///    - Parameter characteristicUUID: The UUID of the characteristic of the descriptor above.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter value: The data being written to the characteristic.
    ///    - Parameter completion: A closures containing an error if something went wrong.
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
    
    ///    Connect to the peripheral and write a value to the passed descriptor through a 'CBPeripheral' writeValue:forDescriptor(...) function call.
    ///
    ///    - Parameter descriptor: The descriptor you want to write to.
    ///    - Parameter value: The data being written to the descriptor.
    ///    - Parameter completion: A closures containing an error if something went wrong.
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
    
    ///    Connect to the peripheral and set the notification value of the characteristic requested through a 'CBPeripheral' setNotifyValueForCharacteristic function call.
    ///    Will first discover the service and characteristic you want to either, start, or stop, getting notifcations from.
    ///
    ///    - Parameter enabled: If enabled is true, this peripherals will register for change notifcations to the characteristic 
    ///         and notify listeners through the default 'NSNotificationCenter' with a 'PeripheralEvent.CharacteristicValueUpdate' notification.
    ///    - Parameter characteristicUUID: The UUID of the characteristic you want set the notify value of.
    ///    - Parameter serviceUUID: The UUID of the service of the characteristic above.
    ///    - Parameter completion: A closures containing the updated notification value of the characteristic or an error if something went wrong.
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
    
    ///    Connect to the peripheral and set the notification value of the passed characteristic through a 'CBPeripheral' setNotifyValueForCharacteristic function call.
    ///
    ///    - Parameter enabled: If enabled is true, this peripherals will register for change notifcations to the characteristic
    ///         and notify listeners through the default 'NSNotificationCenter' with a 'PeripheralEvent.CharacteristicValueUpdate' notification.
    ///    - Parameter characteristic: The characteristic you want set the notify value of.
    ///    - Parameter completion: A closures containing the updated notification value of the characteristic or an error if something went wrong.
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
