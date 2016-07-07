//
//  Central.swift
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

/**
    The Central notifications sent through the default 'NSNotificationCenter' by the Central instance.
 
    Use the CentralEvent enum rawValue as the notification string when registering for notifications.
 
    - PeripheralsInvalidated: The underlying CBCentralManager went into a state invalidating all your Peripherals.
        This means they must be rediscovered through a Peripheral scanWithTimeout(...) function call.
    - CentralManagerWillRestoreState: Posted when the app comes back from the background and restores the 
        underlying CBCentralManager state after the centralManager:willRestoreState: delegate method is called.
        The userInfo of this notification is the same as was passed in the delegate method, userInfo: [String : AnyObject]
 */
public enum CentralEvent: String {
    case PeripheralsInvalidated
    case CentralManagerWillRestoreState
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
    case ScanStopped(error: Error?)
}

/**
    An enum type whoses rawValues mirror the CBCentralManagerState enum owns Integer values but without the ".Resetting" and ".Unknown" temporary values.

    - Unsupported: CBCentralManagerState.Unsupported
    - Unauthorized: CBCentralManagerState.Unauthorized
    - PoweredOff: CBCentralManagerState.PoweredOff
    - PoweredOn: CBCentralManagerState.PoweredOn

*/
public enum AsyncCentralState: Int {
    case Unsupported = 2
    case Unauthorized = 3
    case PoweredOff = 4
    case PoweredOn = 5
}

public typealias AsyncCentralStateCallback = (state: AsyncCentralState) -> Void
public typealias BluetoothStateCallback = (state: CBCentralManagerState) -> Void
public typealias PeripheralScanCallback = (scanResult: PeripheralScanResult) -> Void
public typealias PeripheralConnectCallback = (error: Error?) -> Void
public typealias PeripheralDisconnectCallback = (error: Error?) -> Void

/// A singleton wrapping a CBCentralManager instance to run CBCentralManager related functions with closures based callbacks instead of the usual CBCentralManagerDelegate interface.
public final class Central {
    public static let sharedInstance = Central()
    
    private let centralProxy: CentralProxy = CentralProxy()
    
    private init() {}
}

/// Mark: Internal
typealias InitializeBluetoothCallback = (error: Error?) -> Void

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
