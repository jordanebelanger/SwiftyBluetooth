# SwiftyBluetooth
Fully featured Swift closure based library for CoreBluetooth Central operations on iOS devices.  

## Background 
CoreBluetooth and its delegate based API can be difficult to use at time. Often times you already know the specifications of the peripheral you're about to use and simply want to read or write to predetermined characteristics.  

SwiftyBluetooth tries to address these concerns by providing a clear, closure based, API for every `CBCentralManager` and `CBPeripheral` calls. Furthermore, all your calls are guaranteed to timeout in case of untraceable errors. If required, SwiftyBluetooth will also take care of connecting to peripherals and discovering the required attributes when executing read or write operations lowering the amount of work you need to do. 

## Features
- Synthaxic sugar and helper functions for common CoreBluetooth tasks 
- Closure based CBCentralManager peripheral scanning with a timeout
- NSNotification based event for CBCentralManager state changes and state restoration  
- Closure based calls for every CBPeripheral operations
- NSNotification based event for CBPeripheral name updates, characteristic value updates and services updates
- Precise errors and guaranteed timeout for every Bluetooth operation
- [Full documentation for all public interfaces](http://cocoadocs.org/docsets/SwiftyBluetooth/)

## Usage
The Library has 2 important class:  

- The `Central` class, a Singleton wrapper around `CBCentralManager` mostly used to scan for peripherals with a closure callback. 
- The `Peripheral` class, a wrapper around `CBPeripheral` used to call `CBPeripheral` functions with closure callbacks. 

Note: The library is currently not thread safe, make sure to run your `Central` and `Peripheral` operations on the main thread. 

Below are a couple examples of operations that might be of interest to you.

### Scanning for Peripherals
You can scan for peripherals by calling `scanWithTimeout(...)` while passing a `timeout` in seconds and a `callback` closure to receive `Peripheral` result callbacks as well as update on the status of your scan:
```swift
// You can pass in nil if you want to discover all Peripherals
SwiftyBluetooth.scanWithTimeout(15, serviceUUIDs: ["180D"]) { (scanResult) in
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
Note that the callback closure can be called multiple times, but always start and finish with a callback containing a `.ScanStarted` and `.ScanStopped` result respectively. Your callback will be called with a `.ScanResult` for every unique peripheral found during the scan.  

### Reading from a peripheral's service's characteristic
If you already know the characteristic and service UUIDs you want to read from, once you've found a peripheral you can read from it right away like this: 

```swift
peripheral.readCharacteristicValue(characteristicUUID: "2A29", serviceUUID: "180A") { (data, error) in
    // The read data is returned or an error if something went wrong
}
```
This will connect to the peripheral if necessary and ensure the characteristic and service needed are discovered before reading from the characteristic matching `characteristicUUID`.

If you have a reference to a `CBCharacteristic`, you can read using the characteristic directly:
```swift
peripheral.readCharacteristicValue(characteristic) { (data, error) in
    // The read data is returned or an error if something went wrong
}
```
### Writing to a Peripheral's service's characteristic
If you already know the characteristic and service UUID you want to write to, once you've found a peripheral, you can write to that characteristic right away like this: 
```swift
let exampleBinaryData = String(0b1010).dataUsingEncoding(NSUTF8StringEncoding)!

peripheral.writeCharacteristicValue(characteristicUUID: "1d5bc11d-e28c-4157-a7be-d8b742a013d8",
                                    serviceUUID: "4011e369-5981-4dae-b686-619dc656c7ba",
                                    value: exampleBinaryData) { (error) in
    // An error is returned if something went wrong
}
```
### Listening to and receiving Characteristic update notifications
Receiving characteristic value updates is done through notifications on the default `NSNotificationCenter`. All supported `Peripheral` notifications are part of the `PeripheralEvent` enum. Use this enum's raw values as the notification string when registering for notifications:
```swift
// First we prepare ourselves to receive update notifications 
let peripheral = somePeripheral

NSNotificationCenter.defaultCenter().addObserverForName(PeripheralEvent.CharacteristicValueUpdate.rawValue, 
                                                        object: peripheral, 
                                                        queue: nil) { (notification) in
    let updatedCharacteristic: CBCharacteristic = notification.userInfo["characteristic"]!
    var newValue = updatedCharacteristic.value 
}

// We can then set a characteristic's notification value to true and start receiving updates to that characteristic
peripheral.setNotifyValueForCharacteristic(true, characteristicUUID: "2A29", serviceUUID: "180A") { (isNotifying, error) in
    // If there were no errors, you will now receive update NSNotification to that characteristic
}
```
### Discovering services 
Discover services using the `discoverServices(...)` function:
```swift
peripheral.discoverServices(serviceUUIDs: nil) { (services, error) in
    // The services discovered or an error if something went wrong.
    // Like the CBPeripheral discoverServices(...) function, passing nil instead of an array
    // of service UUIDs will discover all of this Peripheral's services.
}
```
### Discovering characteristics
Discover characteristics using the `discoverCharacteristics(...)` function. If the service on which you are attempting to discover characteristics from has not been discovered, an attempt will first be made to discover that service for you:
```swift
peripheral.discoverCharacteristics(characteristicUUIDs: nil, forService: "180A") { (characteristics, error) in
    // The characteristics discovered or an error if something went wrong.
    // Like the CBPeripheral discoverCharacteristics(...) function, passing nil instead of an array of service 
    // UUIDs will discover all of this service's characteristics.
}
```
### Connecting to a peripheral
```swift
peripheral.connect { (error) in 
    if let error = error {
        // an error happened during the connection or the connect call timed out
    }
}
```
### Disconnecting from a peripheral
```swift
peripheral.disconnect { (error) in 
    if let error = error {
        // an error happened during the disconnection, but your peripheral is guaranteed to be disconnected 
    }
}
```
## Installation


### CocoaPods
Add this to your Podfile:

```ruby
platform :ios, '9.0'
use_frameworks!

pod 'SwiftyBluetooth', '~> 0.1.0'
```

Then run:

```bash
$ pod install
```
### Carthage

Add this to your Cartfile 

```ogdl
github "tehjord/SwiftyBluetooth" == 0.1.0
```

## Requirements
SwiftyBluetooth requires iOS 9.0+

## License
SwiftyBluetooth is released under the MIT License.
