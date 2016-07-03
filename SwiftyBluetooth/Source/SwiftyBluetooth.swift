//
//  SwiftyBluetooth.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/26/16.
//
//

import Foundation

public func scanWithTimeout(timeout: NSTimeInterval,
                            serviceUUIDs: [CBUUIDConvertible]?,
                            completion: PeripheralScanCallback)
{
    // Passing in an empty array will act the same as if you passed nil and discover all peripherals but
    // it is recommended to pass in nil for those cases similarly to how the CoreBluetooth scan method works
    assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
    
    centralDelegate.scanWithTimeout(timeout, serviceUUIDs: ExtractCBUUIDs(serviceUUIDs), completion)
}

public func stopScan() {
    centralDelegate.stopScan()
}
