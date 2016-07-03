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
    public func serviceWithUUID(uuid: CBUUID) -> CBService? {
        guard let services = self.services else {
            return nil
        }
        
        return services.filter { (CBService) -> Bool in
            if (CBService.UUID == uuid) {
                return true
            }
            return false
        }.first
    }
    
    public func servicesWithUUIDs(servicesUUIDs: [CBUUID]) -> (foundServices: [CBService], missingServicesUUIDs: [CBUUID]) {
        assert(servicesUUIDs.count > 0)
        
        guard let currentServices = self.services where currentServices.count > 0 else {
            return (foundServices: [], missingServicesUUIDs: servicesUUIDs)
        }
        
        let currentServicesUUIDs = currentServices.map { (CBService) -> CBUUID in
            return CBService.UUID
        }
        
        let currentServicesUUIDsSet = Set(currentServicesUUIDs)
        let requestedServicesUUIDsSet = Set(servicesUUIDs)
        
        let foundServicesUUIDsSet = requestedServicesUUIDsSet.intersect(currentServicesUUIDsSet)
        let missingServicesUUIDsSet = requestedServicesUUIDsSet.subtract(currentServicesUUIDsSet)
        
        let foundServices = currentServices.filter { (CBService) -> Bool in
            if foundServicesUUIDsSet.contains(CBService.UUID) {
                return true
            }
            return false
        }
        
        return (foundServices: foundServices, missingServicesUUIDs: Array(missingServicesUUIDsSet))
    }
    
}

extension CBService {
    public func characteristicWithUUID(uuid: CBUUID) -> CBCharacteristic? {
        guard let characteristics = self.characteristics else {
            return nil
        }
        
        return characteristics.filter { (CBCharacteristic) -> Bool in
            if (CBCharacteristic.UUID == uuid) {
                return true
            }
            return false
        }.first
    }
    
    public func characteristicsWithUUIDs(characteristicsUUIDs: [CBUUID]) -> (foundCharacteristics: [CBCharacteristic], missingCharacteristicsUUIDs: [CBUUID]) {
        assert(characteristicsUUIDs.count > 0)
        
        guard let currentCharacteristics = self.characteristics where currentCharacteristics.count > 0 else {
            return (foundCharacteristics: [], missingCharacteristicsUUIDs: characteristicsUUIDs)
        }
        
        let currentCharacteristicsUUID = currentCharacteristics.map { (CBCharacteristic) -> CBUUID in
            return CBCharacteristic.UUID
        }
        
        let currentCharacteristicsUUIDSet = Set(currentCharacteristicsUUID)
        let requestedCharacteristicsUUIDSet = Set(characteristicsUUIDs)
        
        let foundCharacteristicsUUIDSet = requestedCharacteristicsUUIDSet.intersect(currentCharacteristicsUUIDSet)
        let missingCharacteristicsUUIDSet = requestedCharacteristicsUUIDSet.subtract(currentCharacteristicsUUIDSet)
        
        let foundCharacteristics = currentCharacteristics.filter { (CBCharacteristic) -> Bool in
            if foundCharacteristicsUUIDSet.contains(CBCharacteristic.UUID) {
                return true
            }
            return false
        }
        
        return (foundCharacteristics: foundCharacteristics, missingCharacteristicsUUIDs: Array(missingCharacteristicsUUIDSet))
    }
}

extension CBCharacteristic {
    public func descriptorWithUUID(uuid: CBUUID) -> CBDescriptor? {
        guard let descriptors = self.descriptors else {
            return nil
        }
        
        return descriptors.filter { (CBDescriptor) -> Bool in
            if (CBDescriptor.UUID == uuid) {
                return true
            }
            return false
        }.first
    }
    
    public func descriptorsWithUUIDs(descriptorsUUIDs: [CBUUID]) -> (foundDescriptors: [CBDescriptor], missingDescriptorsUUIDs: [CBUUID]) {
        assert(descriptorsUUIDs.count > 0)
        
        guard let currentDescriptors = self.descriptors where currentDescriptors.count > 0 else {
            return (foundDescriptors: [], missingDescriptorsUUIDs: descriptorsUUIDs)
        }
        
        let currentDescriptorsUUIDs = currentDescriptors.map { (CBCharacteristic) -> CBUUID in
            return CBCharacteristic.UUID
        }
        
        let currentDescriptorsUUIDsSet = Set(currentDescriptorsUUIDs)
        let requestedDescriptorsUUIDsSet = Set(descriptorsUUIDs)
        
        let foundDescriptorsUUIDsSet = requestedDescriptorsUUIDsSet.intersect(currentDescriptorsUUIDsSet)
        let missingDescriptorsUUIDsSet = requestedDescriptorsUUIDsSet.subtract(currentDescriptorsUUIDsSet)
        
        let foundDescriptors = currentDescriptors.filter { (CBDescriptor) -> Bool in
            if foundDescriptorsUUIDsSet.contains(CBDescriptor.UUID) {
                return true
            }
            return false
        }
        
        return (foundDescriptors: foundDescriptors, missingDescriptorsUUIDs: Array(missingDescriptorsUUIDsSet))
    }
}
