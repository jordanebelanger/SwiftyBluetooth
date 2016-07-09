//
//  DescriptorValue.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 7/8/16.
//
//

import CoreBluetooth

public enum DescriptorValue {
    case CharacteristicExtendedProperties(value: UInt16)
    case CharacteristicUserDescription(value: String)
    case ClientCharacteristicConfigurationString(value: UInt16)
    case ServerCharacteristicConfigurationString(value: UInt16)
    case CharacteristicFormatString(value: NSData)
    case CharacteristicAggregateFormatString(value: UInt16)
    case CustomValue(value: AnyObject)
    
    init(descriptor: CBDescriptor) throws {
        guard let value = descriptor.value else {
            throw Error.InvalidDescriptorValue(descriptor: descriptor)
        }
        
        switch descriptor.CBUUIDRepresentation.UUIDString {
        case CBUUIDCharacteristicExtendedPropertiesString:
            guard let value = UInt16(uncastedUnWrappedNSNumber: descriptor.value) else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .CharacteristicExtendedProperties(value: value)
            
        case CBUUIDCharacteristicUserDescriptionString:
            guard let value = descriptor.value as? String else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .CharacteristicUserDescription(value: value)
            
        case CBUUIDClientCharacteristicConfigurationString:
            guard let value = UInt16(uncastedUnWrappedNSNumber: descriptor.value) else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .ClientCharacteristicConfigurationString(value: value)
            
        case CBUUIDServerCharacteristicConfigurationString:
            guard let value = UInt16(uncastedUnWrappedNSNumber: descriptor.value) else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .ServerCharacteristicConfigurationString(value: value)
            
        case CBUUIDCharacteristicFormatString:
            guard let value = descriptor.value as? NSData else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .CharacteristicFormatString(value: value)
            
        case CBUUIDCharacteristicAggregateFormatString:
            guard let value = UInt16(uncastedUnWrappedNSNumber: descriptor.value) else {
                throw Error.InvalidDescriptorValue(descriptor: descriptor)
            }
            self = .CharacteristicAggregateFormatString(value: value)
            
        default:
            self = .CustomValue(value: value)
        }
    }
}
