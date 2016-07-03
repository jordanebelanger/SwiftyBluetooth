//
//  Central.swift
//  AcanvasBle
//
//  Created by tehjord on 4/15/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import Foundation
import CoreBluetooth

public let PeripheralsInvalidatedEvent = "PeripheralsInvalidatedEvent"

public enum PeripheralScanResult {
    case ScanStarted
    case ScanResult(peripheral: Peripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    case ScanStopped(error: BleError?)
}

public typealias InitializeBluetoothCallback = (error: BleError?) -> Void
public typealias BluetoothStateCallback = (state: CBCentralManagerState) -> Void
public typealias PeripheralScanCallback = (result: PeripheralScanResult) -> Void
public typealias PeripheralConnectCallback = (error: BleError?) -> Void
public typealias PeripheralDisconnectCallback = (error: BleError?) -> Void

public final class Central {
    public static let sharedInstance = Central()
    
    private let centralProxy: CentralProxy = CentralProxy()
    
    private init() {}
    
    func initializeBluetooth(completion: InitializeBluetoothCallback) {
        centralProxy.initializeBluetooth(completion)
    }
}

extension Central {
    public var bluetoothState: CBCentralManagerState {
        get {
            return self.centralProxy.bluetoothState
        }
    }
    
    public var isScanning: Bool {
        get {
            return self.centralProxy.isScanning
        }
    }
    
    public func scanWithTimeout(timeout: NSTimeInterval,
                                serviceUUIDs: [CBUUIDConvertible]?,
                                completion: PeripheralScanCallback) {
        // Passing in an empty array will act the same as if you passed nil and discover all peripherals but
        // it is recommended to pass in nil for those cases similarly to how the CoreBluetooth scan method works
        assert(serviceUUIDs == nil || serviceUUIDs?.count > 0)
        
        centralProxy.scanWithTimeout(timeout, serviceUUIDs: ExtractCBUUIDs(serviceUUIDs), completion)
    }
    
    public func stopScan() {
        centralProxy.stopScan()
    }
    
    func connectPeripheral(peripheral: Peripheral,
                           timeout: NSTimeInterval = 10,
                           completion: PeripheralConnectCallback)
    {
        centralProxy.connectPeripheral(peripheral, timeout: timeout, completion)
    }
    
    func disconnectPeripheral(peripheral: Peripheral,
                              timeout: NSTimeInterval = 10,
                              completion: PeripheralDisconnectCallback)
    {
        centralProxy.disconnectPeripheral(peripheral, timeout: timeout, completion)
    }
}
