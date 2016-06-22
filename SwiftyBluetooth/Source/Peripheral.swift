//
//  Peripheral.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

public let PeripheralStateChangeEvent = "SwiftyBluetoothPeripheralStateChangeEvent"
public let PeripheralRSSIUpdateEvent = "SwiftyBluetoothPeripheralRSSIUpdateEvent"

public typealias ReadRSSIRequestCallback = (RSSI: Int?, error: BleError?) -> Void

public typealias ServiceRequestCallback = (services: [CBService]?, error: BleError?) -> Void
public typealias CharacteristicRequestCallback = (characteristics: [CBCharacteristic]?, error: BleError?) -> Void
public typealias DescriptorRequestCallback = (descriptors: [CBDescriptor]?, error: BleError?) -> Void

public typealias ReadRequestCallback = (data: NSData?, error: BleError?) -> Void

public final class Peripheral {
    public var identifier: NSUUID {
        get {
            return self.cbPeripheral.identifier
        }
    }
    
    public var name: String? {
        get {
            return self.cbPeripheral.name
        }
    }
    
    public var state: CBPeripheralState {
        get {
            return self.cbPeripheral.state
        }
    }
    
    public var services: [CBService]? {
        get {
            return self.cbPeripheral.services
        }
    }
    
    public var RSSI: Int? {
        get {
            return self.cbPeripheral.RSSI?.integerValue
        }
    }
    
    let cbPeripheral: CBPeripheral
    
    // Set by the central to false if the central states state goes beyond powered off
    // during this peripheral's lifetime
    var valid = true
    
    private let peripheralProxy: PeripheralProxy
    
    init(peripheral: CBPeripheral) {
        self.cbPeripheral = peripheral
        self.peripheralProxy = PeripheralProxy(peripheral: peripheral)
    }
    
    public func connect(completion: (error: BleError?) -> Void) {
        Central.sharedInstance.connectPeripheral(self, timeout: 15, completion)
    }
    
    public func disconnect(completion: (error: BleError?) -> Void) {
        Central.sharedInstance.disconnectPeripheral(self, timeout: 15, completion)
    }
    
    public func readRSSI(completion: ReadRequestCallback) {
        self.peripheralProxy.readRSSI(completion)
    }
    
    public func discoverServices(
        serviceUUIDs: [CBUUIDConvertible]?,
        completion: ServiceRequestCallback)
    {
        self.peripheralProxy.discoverServices(serviceUUIDs, completion: completion)
    }
    
    public func discoverCharacteristics(
        characteristicUUIDs: [CBUUIDConvertible]?,
        forService serviceUUID: CBUUIDConvertible,
        completion: CharacteristicRequestCallback)
    {
        self.peripheralProxy.discoverCharacteristics(characteristicUUIDs, forService: serviceUUID, completion: completion)
    }
    
    public func discoverDescriptorsForCharacteristic(characteristicUUID: CBUUIDConvertible,
                                                     serviceUUID: CBUUIDConvertible,
                                                     completion: DescriptorRequestCallback)
    {
        self.peripheralProxy.discoverDescriptorsForCharacteristic(characteristicUUID, serviceUUID: serviceUUID, completion: completion)
    }
    
    public func readCharacteristic(characteristicUUID: CBUUIDConvertible,
                                   serviceUUID: CBUUIDConvertible,
                                   completion: ReadRequestCallback) {
        
    }
    
    public func readCharacteristic(characteristic: CBCharacteristic, completion: ReadRequestCallback) {
        self.readCharacteristic(characteristic, serviceUUID: characteristic.service, completion: completion)
    }
    
}

