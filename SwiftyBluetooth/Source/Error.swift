//
//  Error.swift
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
    case ScanTerminatedUnexpectedly(invalidState: CBCentralManagerState)
    case InvalidDescriptorValue(descriptor: CBDescriptor)
    
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
            case .ScanTerminatedUnexpectedly:
                return 110
            case .InvalidDescriptorValue:
                return 111
            }
        }
    }
    
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
            
        case .ScanTerminatedUnexpectedly:
            return self.errorWithDescription("Scan terminated unexpectedly", failureReason: "You're iOS device bluetooth was desactivated", recoverySuggestion: "Restart bluetooth and try scanning again")
            
        case .InvalidDescriptorValue(let descriptor):
            return self.errorWithDescription("Invalid descriptor value", failureReason: "Unparsable value for descriptor: \(descriptor.description)")
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
}
