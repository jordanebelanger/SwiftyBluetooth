//
//  Peripheral.swift
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

/**
    The Peripheral notifications sent through the default 'NSNotificationCenter' by Peripherals.
 
    Use the PeripheralEvent enum rawValue as the notification string when registering for notifications.
 
    - PeripheralNameUpdate: Updates to a Peripheral's CBPeripheral name value, userInfo: ["name": String?]
    - PeripheralModifedServices: Update to a peripheral's CBPeripheral services, userInfo: ["invalidatedServices": [CBService]]
    - CharacteristicValueUpdate: An update to the value of a characteristic you're peripherals is subscribed for updates from, userInfo: ["characteristic": CBCharacteristic, "error": Error?]
*/
public enum PeripheralEvent: String {
    case PeripheralNameUpdate
    case PeripheralModifedServices
    case CharacteristicValueUpdate
}

public typealias ReadRSSIRequestCallback = (RSSI: Int?, error: Error?) -> Void
public typealias ServiceRequestCallback = (services: [CBService]?, error: Error?) -> Void
public typealias CharacteristicRequestCallback = (characteristics: [CBCharacteristic]?, error: Error?) -> Void
public typealias DescriptorRequestCallback = (descriptors: [CBDescriptor]?, error: Error?) -> Void
public typealias ReadCharacRequestCallback = (data: NSData?, error: Error?) -> Void
public typealias ReadDescriptorRequestCallback = (value: DescriptorValue?, error: Error?) -> Void
public typealias WriteRequestCallback = (error: Error?) -> Void
public typealias UpdateNotificationStateCallback = (isNotifying: Bool?, error: Error?) -> Void

/// An interface on top of a CBPeripheral instance used to run CBPeripheral related functions with closures based callbacks instead of the usual CBPeripheralDelegate interface.
public final class Peripheral {
    private var peripheralProxy: PeripheralProxy!
    
    init(peripheral: CBPeripheral) {
        self.peripheralProxy = PeripheralProxy(cbPeripheral: peripheral, peripheral: self)
    }
}

// MARK: Public
extension Peripheral {
    /// The underlying CBPeripheral identifier
    public var identifier: NSUUID {
        get {
            return self.peripheralProxy.cbPeripheral.identifier
        }
    }
    
    /// The underlying CBPeripheral name
    public var name: String? {
        get {
            return self.peripheralProxy.cbPeripheral.name
        }
    }
    
    /// The underlying CBPeripheral state
    public var state: CBPeripheralState {
        get {
            return self.peripheralProxy.cbPeripheral.state
        }
    }
    
    /// The underlying CBPeripheral services
    public var services: [CBService]? {
        get {
            return self.peripheralProxy.cbPeripheral.services
        }
    }
    
    /// Returns the service requested if it exists and has been discovered
    public func serviceWithUUID(serviceUUID: CBUUIDConvertible) -> CBService? {
        return self.peripheralProxy.cbPeripheral
            .serviceWithUUID(serviceUUID.CBUUIDRepresentation)
    }
    
    /// Returns the characteristic requested if it exists and has been discovered
    public func characteristicWithUUID(characUUID: CBUUIDConvertible, serviceUUID: CBUUIDConvertible) -> CBCharacteristic? {
        return self.peripheralProxy.cbPeripheral
            .serviceWithUUID(serviceUUID.CBUUIDRepresentation)?
            .characteristicWithUUID(characUUID.CBUUIDRepresentation)
    }
    
    /// Returns the descriptor requested if it exists and has been discovered
    public func descriptorWithUUID(descriptorUUID: CBUUIDConvertible, characUUID: CBUUIDConvertible, serviceUUID: CBUUIDConvertible) -> CBDescriptor? {
        return self.peripheralProxy.cbPeripheral
            .serviceWithUUID(serviceUUID.CBUUIDRepresentation)?
            .characteristicWithUUID(characUUID.CBUUIDRepresentation)?
            .descriptorWithUUID(descriptorUUID.CBUUIDRepresentation)
    }
    
    /// Connect to the peripheral through Ble to our Central sharedInstance
    public func connect(completion: (error: Error?) -> Void) {
        self.peripheralProxy.connect(completion)
    }
    
    /// Disconnect the peripheral from our Central sharedInstance
    public func disconnect(completion: (error: Error?) -> Void) {
        self.peripheralProxy.disconnect(completion)
    }
    
    /// Connects to the peripheral and update the Peripheral's RSSI through a 'CBPeripheral' readRSSI() function call
    ///
    /// - Parameter completion: A closure containing the integer value of the updated RSSI or an error.
    public func readRSSI(completion: ReadRSSIRequestCallback) {
        self.peripheralProxy.readRSSI(completion)
    }
    
    /// Connects to the peripheral and discover the requested services through a 'CBPeripheral' discoverServices(...) function call
    ///
    /// - Parameter serviceUUIDs: The UUIDs of the services you want to discover or nil if you want to discover all services.
    /// - Parameter completion: A closures containing an array of the services found or an error.
    public func discoverServices(serviceUUIDs serviceUUIDs: [CBUUIDConvertible]?,
                                 completion: ServiceRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the services.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverServices method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        self.peripheralProxy.discoverServices(ExtractCBUUIDs(serviceUUIDs), completion: completion)
    }
    
    /// Connects to the peripheral and discover the requested included services of a service through a 'CBPeripheral' discoverIncludedServices(...) function call
    ///
    /// - Parameter serviceUUIDs: The UUIDs of the included services you want to discover or nil if you want to discover all included services.
    /// - Parameter serviceUUID: The service to request included services from.
    /// - Parameter completion: A closures containing an array of the services found or an error.
    public func discoverIncludedServices(serviceUUIDs serviceUUIDs: [CBUUIDConvertible]?,
                                         forService serviceUUID: CBUUIDConvertible,
                                                    completion: ServiceRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the services.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverServices method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        self.peripheralProxy.discoverIncludedServices(ExtractCBUUIDs(serviceUUIDs), forService: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    /// Connects to the peripheral and discover the requested included services of a service through a 'CBPeripheral' discoverIncludedServices(...) function call
    ///
    /// - Parameter serviceUUIDs: The UUIDs of the included services you want to discover or nil if you want to discover all included services.
    /// - Parameter service: The service to request included services from.
    /// - Parameter completion: A closures containing an array of the services found or an error.
    public func discoverIncludedServices(serviceUUIDs serviceUUIDs: [CBUUIDConvertible]?,
                                         forService service: CBService,
                                                    completion: ServiceRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the services.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverServices method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        self.discoverIncludedServices(serviceUUIDs: serviceUUIDs, forService: service, completion: completion)
    }
    
    
    /// Connects to the peripheral and discover the requested characteristics through a 'CBPeripheral' discoverCharacteristics(...) function call.
    /// Will first discover the service of the requested characteristics if necessary.
    ///
    /// - Parameter serviceUUID: The UUID of the service of the characteristics requested.
    /// - Parameter characteristicUUIDs: The UUIDs of the characteristics you want to discover or nil if you want to discover all characteristics.
    /// - Parameter completion: A closures containing an array of the characteristics found or an error.
    public func discoverCharacteristics(characteristicUUIDs characteristicUUIDs: [CBUUIDConvertible]?,
                                        forService serviceUUID: CBUUIDConvertible,
                                                   completion: CharacteristicRequestCallback)
    {
        // Passing in an empty array will act the same as if you passed nil and discover all the characteristics.
        // But it is recommended to pass in nil for those cases similarly to how the CoreBluetooth discoverCharacteristics method works
        assert(characteristicUUIDs == nil || characteristicUUIDs?.count > 0)
        self.peripheralProxy.discoverCharacteristics(ExtractCBUUIDs(characteristicUUIDs), forService: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    /// Connects to the peripheral and discover the requested descriptors through a 'CBPeripheral' discoverDescriptorsForCharacteristic(...) function call.
    /// Will first discover the service and characteristic for which you want to discover descriptors from.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic you want to discover descriptors from.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing an array of the descriptors found or an error.
    public func discoverDescriptorsForCharacteristic(characteristicUUID characteristicUUID: CBUUIDConvertible,
                                                     serviceUUID: CBUUIDConvertible,
                                                     completion: DescriptorRequestCallback)
    {
        self.peripheralProxy.discoverDescriptorsForCharacteristic(characteristicUUID.CBUUIDRepresentation, serviceUUID: serviceUUID.CBUUIDRepresentation, completion: completion)
    }
    
    /// Connects to the peripheral and discover the requested descriptors through a 'CBPeripheral' discoverDescriptorsForCharacteristic(...) function call.
    /// Will first discover the service and characteristic for which you want to discover descriptors from.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic you want to discover descriptors from.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing an array of the descriptors found or an error.
    public func discoverDescriptorsForCharacteristic(characteristic: CBCharacteristic,
                                                     completion: DescriptorRequestCallback)
    {
        self.discoverDescriptorsForCharacteristic(characteristicUUID: characteristic, serviceUUID: characteristic.service, completion: completion)
    }
    
    /// Connect to the peripheral and read the value of the characteristic requested through a 'CBPeripheral' readValueForCharacteristic(...) function call.
    /// Will first discover the service and characteristic you want to read from if necessary.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic you want to read from.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing the data read or an error.
    public func readCharacteristicValue(characteristicUUID characteristicUUID: CBUUIDConvertible,
                                        serviceUUID: CBUUIDConvertible,
                                        completion: ReadCharacRequestCallback)
    {
        self.peripheralProxy.readCharacteristic(characteristicUUID.CBUUIDRepresentation,
                                                serviceUUID: serviceUUID.CBUUIDRepresentation,
                                                completion: completion)
    }
    
    /// Connect to the peripheral and read the value of the passed characteristic through a 'CBPeripheral' readValueForCharacteristic(...) function call.
    ///
    /// - Parameter characteristic: The characteristic you want to read from.
    /// - Parameter completion: A closures containing the data read or an error.
    public func readCharacteristicValue(characteristic: CBCharacteristic,
                                        completion: ReadCharacRequestCallback)
    {
        self.readCharacteristicValue(characteristicUUID: characteristic,
                                     serviceUUID: characteristic.service,
                                     completion: completion)
    }
    
    /// Connect to the peripheral and read the value of the descriptor requested through a 'CBPeripheral' readValueForDescriptor(...) function call.
    /// Will first discover the service, characteristic and descriptor you want to read from if necessary.
    ///
    /// - Parameter descriptorUUID: The UUID of the descriptor you want to read from.
    /// - Parameter characteristicUUID: The UUID of the descriptor above.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing the data read or an error.
    public func readDescriptorValue(descriptorUUID descriptorUUID: CBUUIDConvertible,
                                    characteristicUUID: CBUUIDConvertible,
                                    serviceUUID: CBUUIDConvertible,
                                    completion: ReadDescriptorRequestCallback)
    {
        self.peripheralProxy.readDescriptor(descriptorUUID.CBUUIDRepresentation,
                                            characteristicUUID: characteristicUUID.CBUUIDRepresentation,
                                            serviceUUID: serviceUUID.CBUUIDRepresentation,
                                            completion: completion)
    }
    
    /// Connect to the peripheral and read the value of the passed descriptor through a 'CBPeripheral' readValueForDescriptor(...) function call.
    ///
    /// - Parameter descriptor: The descriptor you want to read from.
    /// - Parameter characteristicUUID: The UUID of the descriptor above.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing the data read or an error.
    public func readDescriptorValue(descriptor: CBDescriptor,
                                    completion: ReadDescriptorRequestCallback)
    {
        self.readDescriptorValue(descriptorUUID: descriptor,
                                 characteristicUUID: descriptor.characteristic,
                                 serviceUUID: descriptor.characteristic.service,
                                 completion: completion)
    }
    
    /// Connect to the peripheral and write a value to the characteristic requested through a 'CBPeripheral' writeValue:forCharacteristic(...) function call.
    /// Will first discover the service and characteristic you want to write to if necessary.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic you want to write to.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter value: The data being written to the characteristic
    /// - Parameter type: The type of the CBPeripheral write, wither with or without response in which case the closure is called right away
    /// - Parameter completion: A closures containing an error if something went wrong
    public func writeCharacteristicValue(characteristicUUID characteristicUUID: CBUUIDConvertible,
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
    
    /// Connect to the peripheral and write a value to the passed characteristic through a 'CBPeripheral' writeValue:forCharacteristic(...) function call.
    ///
    /// - Parameter characteristic: The characteristic you want to write to.
    /// - Parameter value: The data being written to the characteristic
    /// - Parameter type: The type of the CBPeripheral write, wither with or without response in which case the closure is called right away
    /// - Parameter completion: A closures containing an error if something went wrong
    public func writeCharacteristicValue(characteristic: CBCharacteristic,
                                         value: NSData,
                                         type: CBCharacteristicWriteType = .WithResponse,
                                         completion: WriteRequestCallback)
    {
        self.writeCharacteristicValue(characteristicUUID: characteristic.UUID,
                                      serviceUUID: characteristic.service.UUID,
                                      value: value,
                                      type: type,
                                      completion: completion)
    }
    
    /// Connect to the peripheral and write a value to the descriptor requested through a 'CBPeripheral' writeValue:forDescriptor(...) function call.
    /// Will first discover the service, characteristic and descriptor you want to write to if necessary.
    ///
    /// - Parameter descriptorUUID: The UUID of the descriptor you want to write to.
    /// - Parameter characteristicUUID: The UUID of the characteristic of the descriptor above.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter value: The data being written to the characteristic.
    /// - Parameter completion: A closures containing an error if something went wrong.
    public func writeDescriptorValue(descriptorUUID descriptorUUID: CBUUIDConvertible,
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
    
    /// Connect to the peripheral and write a value to the passed descriptor through a 'CBPeripheral' writeValue:forDescriptor(...) function call.
    ///
    /// - Parameter descriptor: The descriptor you want to write to.
    /// - Parameter value: The data being written to the descriptor.
    /// - Parameter completion: A closures containing an error if something went wrong.
    public func writeDescriptorValue(descriptor: CBDescriptor,
                                     value: NSData,
                                     completion: WriteRequestCallback)
    {
        self.writeDescriptorValue(descriptorUUID: descriptor.UUID,
                                  characteristicUUID: descriptor.characteristic.UUID,
                                  serviceUUID: descriptor.characteristic.service.UUID,
                                  value: value,
                                  completion: completion)
    }
    
    /// Connect to the peripheral and set the notification value of the characteristic requested through a 'CBPeripheral' setNotifyValueForCharacteristic function call.
    /// Will first discover the service and characteristic you want to either, start, or stop, getting notifcations from.
    ///
    /// - Parameter enabled: If enabled is true, this peripherals will register for change notifcations to the characteristic
    ///      and notify listeners through the default 'NSNotificationCenter' with a 'PeripheralEvent.CharacteristicValueUpdate' notification.
    /// - Parameter characteristicUUID: The UUID of the characteristic you want set the notify value of.
    /// - Parameter serviceUUID: The UUID of the service of the characteristic above.
    /// - Parameter completion: A closures containing the updated notification value of the characteristic or an error if something went wrong.
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
    
    /// Connect to the peripheral and set the notification value of the passed characteristic through a 'CBPeripheral' setNotifyValueForCharacteristic function call.
    ///
    /// If set to true, this peripheral will emit characteristic change updates through the default NSNotificationCenter using the "CharacteristicValueUpdate" notification.
    ///
    /// - Parameter enabled: The notify state of the charac, set enabled to true to receive change notifications through the default NSNotification center
    /// - Parameter characteristic: The characteristic you want set the notify value of.
    /// - Parameter completion: A closures containing the updated notification value of the characteristic or an error if something went wrong.
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
