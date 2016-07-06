//
//  Central.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import CoreBluetooth

/**
    The Central notifications sent through the default 'NSNotificationCenter' by the Central instance.
 
    Use the CentralEvent enum rawValue as the notification string when registering for notifications.
 
    - PeripheralsInvalidated: The underlying CBCentralManager went into a state invalidating all your Peripherals.
        This means they must be rediscovered through a Peripheral scanWithTimeout(...) function call.
 
 */
public enum CentralEvent: String {
    case PeripheralsInvalidated
}

/**
 The different results returned in the closure of the Central scanWithTimeout(...) function.
 
 - ScanStarted: The scan just started.
 - ScanResult: A Peripheral found result.
 - ScanStopped: The scan ended.
 
*/
public enum PeripheralScanResult {
    case ScanStarted
    case ScanResult(peripheral: Peripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    case ScanStopped(error: BleError?)
}

/**
 An enum type whoses rawValues mirror the CBCentralManagerState enum owns Integer values but without the ".Resetting" and ".Unknown" temporary values.
 
 - Unsupported: CBCentralManagerState.Unsupported
 - Unauthorized: CBCentralManagerState.Unauthorized
 - PoweredOff: CBCentralManagerState.PoweredOff
 - PoweredOn: CBCentralManagerState.PoweredOn

*/
public enum AsyncCentralState: Int {
    case Unsupported = 2 // CBCentralManagerState.Unsupported
    case Unauthorized = 3 // CBCentralManagerState.Unauthorized
    case PoweredOff = 4 // CBCentralManagerState.PoweredOff
    case PoweredOn = 5 // CBCentralManagerState.PoweredOn
}

public typealias AsyncCentralStateCallback = (state: AsyncCentralState) -> Void
public typealias BluetoothStateCallback = (state: CBCentralManagerState) -> Void
public typealias PeripheralScanCallback = (scanResult: PeripheralScanResult) -> Void
public typealias PeripheralConnectCallback = (error: BleError?) -> Void
public typealias PeripheralDisconnectCallback = (error: BleError?) -> Void

/// A singleton wrapping a CBCentralManager instance to run CBCentralManager related functions with closures based callbacks instead of the usual CBCentralManagerDelegate interface.
public final class Central {
    public static let sharedInstance = Central()
    
    private let centralProxy: CentralProxy = CentralProxy()
    
    private init() {}
}

/// Mark: Internal
typealias InitializeBluetoothCallback = (error: BleError?) -> Void

extension Central {
    func initializeBluetooth(completion: InitializeBluetoothCallback) {
        centralProxy.initializeBluetooth(completion)
    }
    
    func connectPeripheral(peripheral: CBPeripheral,
                           timeout: NSTimeInterval = 10,
                           completion: PeripheralConnectCallback)
    {
        centralProxy.connectPeripheral(peripheral, timeout: timeout, completion)
    }
    
    func disconnectPeripheral(peripheral: CBPeripheral,
                              timeout: NSTimeInterval = 10,
                              completion: PeripheralDisconnectCallback)
    {
        centralProxy.disconnectPeripheral(peripheral, timeout: timeout, completion)
    }
}

/// Mark: Public
extension Central {
    /// The underlying CBCentralManager state
    public var state: CBCentralManagerState {
        get {
            return self.centralProxy.state
        }
    }
    
    /// The underlying CBCentralManager isScanning value
    public var isScanning: Bool {
        get {
            return self.centralProxy.isScanning
        }
    }
    
    /// Scans for Peripherals through a CBCentralManager scanForPeripheralsWithServices(...) function call.
    ///
    /// - Parameter timeout: The scanning time in seconds before the scan is stopped and the completion closure is called with a scanStopped result.
    /// - Parameter serviceUUIDs: The service UUIDs to search peripherals for or nil if looking for all peripherals.
    /// - Parameter completion: The closures, called multiple times throughout a scan.
    public func scanWithTimeout(timeout: NSTimeInterval,
                                serviceUUIDs: [CBUUIDConvertible]?,
                                completion: PeripheralScanCallback) {
        // Passing in an empty array will act the same as if you passed nil and discover all peripherals but
        // it is recommended to pass in nil for those cases similarly to how the CoreBluetooth scan method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        
        centralProxy.scanWithTimeout(timeout, serviceUUIDs: ExtractCBUUIDs(serviceUUIDs), completion)
    }
    
    /// Will stop the current scan through a CBCentralManager stopScan() function call and invokes the completion
    /// closures of the original scanWithTimeout function call with a scanStopped result containing an error if something went wrong.
    public func stopScan() {
        centralProxy.stopScan()
    }
    
    /// Sometime, the bluetooth state of your iOS Device/CBCentralManagerState is in an inbetween state of either
    /// ".Unknown" or ".Reseting". This function will wait until the bluetooth state is stable and return a subset
    /// of the CBCentralManager state value which does not includes these values in its completion closure.
    public func asyncCentralState(completion: AsyncCentralStateCallback) {
        self.centralProxy.asyncCentralState(completion)
    }
}
