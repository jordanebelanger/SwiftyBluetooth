# SwiftyBluetooth

Fully featured Swift closure based library for CoreBluetooth Central operations on iOS devices.  

## Background 

CoreBluetooth and its delegate based API can be difficult to use at time. Often times you already know the specifications of the peripheral you're about to use and simply want to read or write predetermined Characteristics. 

Corebluetooth read or write operations on a peripheral first require you to connect to a peripheral and discover the required services/characteristics/descriptors. This can get cubbersome at time because the delegate based API of CoreBluetooth makes it difficult to follow the flow of operations and delegate callbacks, especially when accounting for all the different errors that might arise in the process.  

SwiftyBluetooth addresses these concerns by providing a clear, closure based, API for every CBCentralManager and CBPeripheral calls. If required, SwiftyBluetooth will also take care of connecting to peripherals and discovering the required attributes when executing read or write operations saving you from potential headaches and lowering the amount of work you need to do. 

All done in modern Swift. 

## Features

- Synthaxic sugar and helper functions for common CoreBluetooth tasks 
- Closure based CBCentralManager peripheral scanning with a timeout
- NSNotification based event for CBCentralManager state changes and state restoration  
- Closure based calls for every CBPeripheral operations
- NSNotification based event for CBPeripheral name updates, characteristic value updates and services updates
- Precise errors and guaranteed timeout for every Bluetooth operation
 
## Usage

The Library has 2 important class: 

- The Central class, a Singleton wrapper around CBCentralManager mostly used to scan for peripherals with a closure callback. 
- The Peripheral class, a wrapper around CBPeripheral used to call CBPeripheral functions with closure callbacks. 

Below are a couple examples of operations that might be of interest to you.

### Scanning for Peripherals

You can scan for Peripherals by calling scanWithTimeout(...) while passing a timeout in seconds and a callback closure to receive Peripheral result callbacks as well as update on the status of your scan.

```swift
SwiftyBluetooth.scanWithTimeout(15, serviceUUIDs: ["0011"]) { (scanResult) in
    switch scanResult {
        case .ScanStarted:
            // The scan started meaning CBCentralManager scanForPeripherals(...) was called 
        case .ScanResult(let peripheral, let advertisementData, let RSSI):
            // A peripheral was found, your closure may be called multiple time with a .ScanResult enum case.
            // You can save that peripheral for future use, or call some of its functions directly in this closure.
        case .ScanStopped(let error):
            // The scan stopped, an error is passed if the scan stopped unexpectedly
    }
}
        
```

Note that the callback closure can be called multiple times, but always start and finish with a callback containing a .ScanStarted and .ScanStopped result respectively. Your callback will be called with a .ScanResult for every unique peripheral found during the scan.  

### Reading from a Peripheral's service's characteristic

If you already know the characteristic and service UUIDs you want to read from, once you've found a Peripheral you can read from it right away like this: 

```swift
peripheral.readCharacteristicValue(characteristicUUID: "2A29", serviceUUID: "180A") { (data, error) in

}
```

This will connect to the Peripheral if necessary and ensure the characteristic and service needed are discovered before reading from the characteristic matching characteristicUUID.

If instead you have a reference to a CBCharacteristic, instead you can read using the characteristic directly:

```swift
peripheral.readCharacteristicValue(characteristic) { (data, error) in
    // The read data is returned or an error if something went wrong
}
```

### Writing to a Peripheral's service's characteristic

If you already know the characteristic and service UUIDs you want to write to, once you've found a Peripheral, you can write to its characteristics right away like this: 

```swift
let exampleBinaryData = String(0b1010).dataUsingEncoding(NSUTF8StringEncoding)!

peripheral.writeCharacteristicValue(characteristicUUID: "1d5bc11d-e28c-4157-a7be-d8b742a013d8",
                                    serviceUUID: "4011e369-5981-4dae-b686-619dc656c7ba",
                                    value: exampleBinaryData) { (error) in
    // An error is returned if something went wrong
}
```

### Listening to and receiving Characteristic update notifications

Receiving Characteristic value updates is done through notifications on the default NSNotificationCenter. All supported Peripherals notifications are part of the PeripheralEvent enum. Use this enum's raw value as the notification string. 

```swift
// First we prepare ourselves to receive update notifications 
let peripheral = somePeripheral

NSNotificationCenter.defaultCenter().addObserverForName(PeripheralEvent.CharacteristicValueUpdate.rawValue, 
                                                        object: peripheral, 
                                                        queue: nil) { (notification) in
    let updatedCharacteristic: CBCharacteristic = notification.userInfo["characteristic"]!
    var newValue = updatedCharacteristic.value 
}

// We can then set a characteristic notification value to true and start receiving updates to that characteristic
peripheral.setNotifyValueForCharacteristic(true, characteristicUUID: "2A29", serviceUUID: "180A") { (isNotifying, error) in
    // If there were no errors, you will now receive update notification to that characteristic
}

```

### Discovering services 

Discovering services is again very simple: 

```swift
peripheral.discoverServices(serviceUUIDs: nil) { (services, error) in
    // Like the CBPeripheral discoverServices(...) functions, passing nil instead of an array
    // of service UUIDs will discover all of this Peripheral's services.
}
```

### Discovering characteristics

You can discover characteristics of a services like using the discoverCharacteristics(...) function. If the service on which you are attempting to discover characteristics has not been discoverd, an attempt will first be made to discover that service. 

peripheral.discoverCharacteristics(characteristicUUIDs: nil, forService: "180A") { (characteristics, error) in
    // my characs or an error if something went wrong
}

### Connecting / Disconnecting from a peripheral

Connecting to a peripheral is very simple, just call:

peripheral.connect { (error) in 
    if let error = error {
        // an error happened during the connection or the connect call timed out
    }
}

Disconnecting from a peripheral is also very simple, simply call:

peripheral.disconnect { (error) in 
    if let error = error {
        // an error happened during the disconnection, but your peripheral is guaranteed to be disconnected 
    }
}

## Installation

### CocoaPods

Add this to your Podfile:

```ruby
platform :ios, '9.0'
use_frameworks!

pod 'SwiftyBluetooth'
```

Then run:

```bash
$ pod install
```
### Carthage

Add this to your Cartfile 

```ogdl
github "tehjord/SwiftyBluetooth" "head"
```

##License
SwiftyBluetooth is released under the MIT License.