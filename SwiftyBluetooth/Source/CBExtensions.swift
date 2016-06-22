//
//  CBExtensions.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/15/16.
//
//

import Foundation
import CoreBluetooth

extension CBPeripheral {
    public func serviceWithUUID(UUIDConvertible: CBUUIDConvertible) -> CBService? {
        guard let services = self.services else {
            return nil
        }
        
        return services.filter { (CBService) -> Bool in
            if (CBService.UUID == UUIDConvertible.CBUUIDRepresentation) {
                return true
            }
            return false
        }.first
    }
    
    public func servicesWithUUIDs(serviceUUIDs: [CBUUIDConvertible]) -> (foundServices: [CBService], missingServices: [CBUUIDConvertible]) {
        assert(serviceUUIDs.count > 0)
        
        guard let services = self.services where services.count > 0 else {
            return (foundServices: [], missingServices: serviceUUIDs)
        }
        
        var foundServices: [CBService] = []
        var missingServices: [CBUUIDConvertible] = []
        
        for serviceUUID in serviceUUIDs.reverse() {
            if let service = self.serviceWithUUID(serviceUUID) {
                foundServices.append(service)
            } else {
                missingServices.append(serviceUUID)
            }
        }
        
        return (foundServices: foundServices, missingServices: missingServices)
    }
    
}

extension CBService {
    public func characteristicWithUUID(UUIDConvertible: CBUUIDConvertible) -> CBCharacteristic? {
        guard let characteristics = self.characteristics else {
            return nil
        }
        
        return characteristics.filter { (CBCharacteristic) -> Bool in
            if (CBCharacteristic.UUID == UUIDConvertible.CBUUIDRepresentation) {
                return true
            }
            return false
            }.first
    }
    
    public func characteristicsWithUUIDs(characteristicsUUIDs: [CBUUIDConvertible]) -> (foundCharacteristics: [CBCharacteristic], missingCharacteristics: [CBUUIDConvertible]) {
        
        assert(characteristicsUUIDs.count > 0)
        
        guard let characteristics = self.characteristics where characteristics.count > 0 else {
            return (foundCharacteristics: [], missingCharacteristics: characteristicsUUIDs)
        }
        
        var foundCharacteristics: [CBCharacteristic] = []
        var missingCharacteristics: [CBUUIDConvertible] = []
        
        for characteristicUUID in characteristicsUUIDs.reverse() {
            if let characteristic = self.characteristicWithUUID(characteristicUUID) {
                foundCharacteristics.append(characteristic)
            } else {
                missingCharacteristics.append(characteristicUUID)
            }
        }
        
        return (foundCharacteristics: foundCharacteristics, missingCharacteristics: missingCharacteristics)
    }
}

extension CBCharacteristic {
    public func descriptorWithUUID(UUIDConvertible: CBUUIDConvertible) -> CBDescriptor? {
        guard let descriptors = self.descriptors else {
            return nil
        }
        
        return descriptors.filter { (CBDescriptor) -> Bool in
            if (CBDescriptor.UUID == UUIDConvertible.CBUUIDRepresentation) {
                return true
            }
            return false
        }.first
    }
    
    public func descriptorsWithUUIDs(descriptorsUUIDs: [CBUUIDConvertible]) -> (foundDescriptors: [CBDescriptor], missingDescriptors: [CBUUIDConvertible]) {
        
        assert(descriptorsUUIDs.count > 0)
        
        guard let descriptors = self.descriptors where descriptors.count > 0 else {
            return (foundDescriptors: [], missingDescriptors: descriptorsUUIDs)
        }
        
        var foundDescriptors: [CBDescriptor] = []
        var missingDescriptors: [CBUUIDConvertible] = []
        
        for descriptorUUID in descriptorsUUIDs.reverse() {
            if let descriptor = self.descriptorWithUUID(descriptorUUID) {
                foundDescriptors.append(descriptor)
            } else {
                missingDescriptors.append(descriptorUUID)
            }
        }
        
        return (foundDescriptors: foundDescriptors, missingDescriptors: missingDescriptors)
    }
}
