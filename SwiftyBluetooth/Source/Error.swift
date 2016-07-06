//
//  Error.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

public enum Error: ErrorType {
    case BluetoothUnsupported
    case BluetoothUnauthorized
    case BluetoothPoweredOff
    case OperationTimeoutError(operationName: String)
    case CoreBluetoothError(operationName: String, error: NSError)
    case InvalidPeripheral
    case PeripheralFailedToConnectReasonUnknown
    case PeripheralServiceNotFound(missingServicesUUIDs: [CBUUID])
    case PeripheralCharacteristicNotFound(missingCharacteristicsUUIDs: [CBUUID])
    case PeripheralDescriptorsNotFound(missingDescriptorsUUIDs: [CBUUID])

    public func NSErrorRepresentation() -> NSError {
        switch self {
        case .OperationTimeoutError(let operationName):
            return self.errorWithDescription("SwiftyBluetooth timeout error", failureReason: "Timed out during \"\(operationName)\" operation.")
        
        case .CoreBluetoothError(let operationName, let cbError):
            return self.errorWithDescription("CoreBluetooth Error during \(operationName).", failureReason: cbError.description)
        
        case .PeripheralServiceNotFound(let missingServices):
            let missingServicesString = missingServices.map { $0.UUIDString }.joinWithSeparator(",")
            return self.errorWithDescription("Peripheral Error", failureReason: "Failed to find the service by your operation: \(missingServicesString)")
        
        case .PeripheralCharacteristicNotFound(let missingCharacs):
            let missingCharacsString = missingCharacs.map { $0.UUIDString }.joinWithSeparator(",")
            return self.errorWithDescription("Peripheral Error", failureReason: "Failed to find the characteristics by your operation: \(missingCharacsString)")
        
        case .PeripheralDescriptorsNotFound(let missingDescriptors):
            let missingDescriptorsString = missingDescriptors.map { $0.UUIDString }.joinWithSeparator(",")
            return self.errorWithDescription("Peripheral Error", failureReason: "Failed to find the descriptor by your operation: \(missingDescriptorsString)")
        
        case .BluetoothUnsupported:
            return self.errorWithDescription("Bluetooth unsupported.", failureReason: "Your iOS Device must support Bluetooth to use SwiftyBluetooth.")
        
        case .BluetoothUnauthorized:
            return self.errorWithDescription("Bluetooth unauthorized", failureReason: "Bluetooth must be authorized for your operation to complete.")
        
        case .BluetoothPoweredOff:
            return self.errorWithDescription("Bluetooth powered off", failureReason: "Bluetooth needs to be powered on for your operation to complete.", recoverySuggestion: "Turn on bluetooth in your iOS device's settings.")
        
        case .InvalidPeripheral:
            return self.errorWithDescription("Invalid peripheral", failureReason: "Bluetooth became unreachable while using this Peripheral, the Peripheral must be discovered again to be used.", recoverySuggestion: "Rediscover the Peripheral.")
        
        case .PeripheralFailedToConnectReasonUnknown:
            return self.errorWithDescription("Failed to connect your Peripheral", failureReason: "Unknown reason")
        }
    }
    
    private func errorWithDescription(description: String, failureReason: String? = nil, recoverySuggestion: String? = nil) -> NSError {
        var userInfo: [NSObject: AnyObject] = [NSLocalizedDescriptionKey: description]
        if let failureReason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
        }
        if let recoverySuggestion = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
        }
        
        return NSError(domain: self._domain, code: self._code, userInfo: userInfo)
    }
    
    public var _domain: String {
        get {
            return "com.swiftybluetooth.error"
        }
    }
    
    public var _code: Int {
        get {
            switch self {
            case .OperationTimeoutError:
                return 100
            case .CoreBluetoothError:
                return 101
            case .PeripheralServiceNotFound:
                return 102
            case .PeripheralCharacteristicNotFound:
                return 103
            case .PeripheralDescriptorsNotFound:
                return 104
            case .BluetoothUnsupported:
                return 105
            case .BluetoothUnauthorized:
                return 106
            case .BluetoothPoweredOff:
                return 107
            case .InvalidPeripheral:
                return 108
            case .PeripheralFailedToConnectReasonUnknown:
                return 109
            }
        }
    }
}
