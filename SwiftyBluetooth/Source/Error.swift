//
//  Error.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

public enum BleError: ErrorType {
    case BleUnsupported
    case BleUnauthorized
    case BlePoweredOff
    
    case BleTimeoutError
    
    case CoreBluetoothError(error: NSError)
    
    case PeripheralIsInvalid
    
    case PeripheralFailedToConnectReasonUnknown
    
    case PeripheralServiceNotFound(missingServicesUUIDs: [CBUUID])
    case PeripheralCharacteristicNotFound(missingCharacteristicsUUIDs: [CBUUID])
    case PeripheralDescriptorsNotFound(missingDescriptorsUUIDs: [CBUUID])
}
