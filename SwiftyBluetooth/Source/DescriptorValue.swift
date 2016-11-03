//
//  DescriptorValue.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 7/8/16.
//
//

import CoreBluetooth

/**
    Wrapper around common GATT descriptor values. Automatically unwrap and cast your descriptor values for
    standard GATT descriptor UUIDs.

    - CharacteristicExtendedProperties: Case for Descriptor with UUID CBUUIDCharacteristicExtendedPropertiesString
    - CharacteristicUserDescription: Case for Descriptor with UUID CBUUIDCharacteristicUserDescriptionString
    - ClientCharacteristicConfigurationString: Case for Descriptor with UUID CBUUIDClientCharacteristicConfigurationString
    - ServerCharacteristicConfigurationString: Case for Descriptor with UUID CBUUIDServerCharacteristicConfigurationString
    - CharacteristicFormatString: Case for Descriptor with UUID CBUUIDCharacteristicFormatString
    - CharacteristicAggregateFormatString: Case for Descriptor with UUID CBUUIDCharacteristicAggregateFormatString
    - CustomValue: Case for descriptor with a non standard UUID
*/
public enum DescriptorValue {
    case characteristicExtendedProperties(value: UInt16)
    case characteristicUserDescription(value: String)
    case clientCharacteristicConfigurationString(value: UInt16)
    case serverCharacteristicConfigurationString(value: UInt16)
    case characteristicFormatString(value: Data)
    case characteristicAggregateFormatString(value: UInt16)
    case customValue(value: AnyObject)
    
    init(descriptor: CBDescriptor) throws {
        guard let value = descriptor.value else {
            throw SBError.invalidDescriptorValue(descriptor: descriptor)
        }
        
        switch descriptor.CBUUIDRepresentation.uuidString {
        case CBUUIDCharacteristicExtendedPropertiesString:
            guard let value = UInt16(uncastedUnwrappedNSNumber: descriptor.value as AnyObject?) else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .characteristicExtendedProperties(value: value)
            
        case CBUUIDCharacteristicUserDescriptionString:
            guard let value = descriptor.value as? String else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .characteristicUserDescription(value: value)
            
        case CBUUIDClientCharacteristicConfigurationString:
            guard let value = UInt16(uncastedUnwrappedNSNumber: descriptor.value as AnyObject?) else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .clientCharacteristicConfigurationString(value: value)
            
        case CBUUIDServerCharacteristicConfigurationString:
            guard let value = UInt16(uncastedUnwrappedNSNumber: descriptor.value as AnyObject?) else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .serverCharacteristicConfigurationString(value: value)
            
        case CBUUIDCharacteristicFormatString:
            guard let value = descriptor.value as? Data else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .characteristicFormatString(value: value)
            
        case CBUUIDCharacteristicAggregateFormatString:
            guard let value = UInt16(uncastedUnwrappedNSNumber: descriptor.value as AnyObject?) else {
                throw SBError.invalidDescriptorValue(descriptor: descriptor)
            }
            self = .characteristicAggregateFormatString(value: value)
            
        default:
            self = .customValue(value: value as AnyObject)
        }
    }
}
