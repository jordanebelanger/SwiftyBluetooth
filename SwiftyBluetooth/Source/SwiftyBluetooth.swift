//
//  SwiftyBluetooth.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/26/16.
//
//

import CoreBluetooth

/// Mark: Shorthands for the Central singleton instance content

/// Scans for Peripherals through a CBCentralManager scanForPeripheralsWithServices(...) function call.
///
/// Parameter timeout: The scanning time in seconds before the scan is stopped and the completion closure is called with a scanStopped result.
/// Parameter serviceUUIDs: The service UUIDs to search peripherals for or nil if looking for all peripherals.
/// Parameter completion: The closures, called multiple times throughout a scan.
public func scanWithTimeout(timeout: NSTimeInterval,
                            serviceUUIDs: [CBUUIDConvertible]?,
                            completion: PeripheralScanCallback)
{
    // Passing in an empty array will act the same as if you passed nil and discover all peripherals but
    // it is recommended to pass in nil for those cases similarly to how the CoreBluetooth scan method works
    assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
    
    Central.sharedInstance.scanWithTimeout(timeout, serviceUUIDs: ExtractCBUUIDs(serviceUUIDs), completion: completion)
}

/// Will stop the current scan through a CBCentralManager stopScan() function call and invokes the completion
/// closures of the original scanWithTimeout function call with a scanStopped result containing an error if something went wrong.
public func stopScan() {
    Central.sharedInstance.stopScan()
}

/// Sometime, the bluetooth state of your iOS Device/CBCentralManagerState is in an inbetween state of either
/// ".Unknown" or ".Reseting". This function will wait until the bluetooth state is stable and return a subset
/// of the CBCentralManager state value which does not includes these values in its completion closure.
public func asyncCentralState(completion: AsyncCentralStateCallback) {
    Central.sharedInstance.asyncCentralState(completion)
}

/// The Central singleton underlying CBCentralManager state
public var state: CBCentralManagerState {
    get {
        return Central.sharedInstance.state
    }
}

/// The Central singleton CBCentralManager isScanning value
public var isScanning: Bool {
    get {
        return Central.sharedInstance.isScanning
    }
}
