# SwiftyBluetooth
Swift 3, fully featured closures based library for CoreBluetooth on iOS 9+ devices. 

For Swift 2 use v0.1.1

## Background 
CoreBluetooth and its delegate based API can be difficult to use at time. Often times you already know the specifications of the peripheral you're about to use and simply want to read or write to predetermined characteristics.  

SwiftyBluetooth tries to address these concerns by providing a clear, closure based, API for every `CBCentralManager` and `CBPeripheral` calls. Furthermore, all your calls are guaranteed to timeout in case of untraceable errors. If required, SwiftyBluetooth will also take care of connecting to peripherals and discovering the required attributes when executing read or write operations lowering the amount of work you need to do. 

## Features
- Supports Swift 3 ~> v0.2.0 and Swift 2 = v0.1.1
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
SwiftyBluetooth.scanForPeripherals(withServiceUUIDs: nil, timeoutAfter: 15) { scanResult in
    switch scanResult {
        case .scanStarted:
            // The scan started meaning CBCentralManager scanForPeripherals(...) was called 
        case .scanResult(let peripheral, let advertisementData, let RSSI):
            // A peripheral was found, your closure may be called multiple time with a .ScanResult enum case.
            // You can save that peripheral for future use, or call some of its functions directly in this closure.
        case .scanStopped(let error):
            // The scan stopped, an error is passed if the scan stopped unexpectedly
    }
}
        
```
Note that the callback closure can be called multiple times, but always start and finish with a callback containing a `.scanStarted` and `.scanStopped` result respectively. Your callback will be called with a `.scanResult` for every unique peripheral found during the scan.  

### Connecting to a peripheral
```swift
peripheral.connect { result in 
    switch result {
    case .success:
        break // You are now connected to the peripheral
    case .failure(let error):
        break // An error happened while connecting
    }
}
```
### Disconnecting from a peripheral
```swift
peripheral.disconnect { result in 
    switch result {
    case .success:
        break // You are now disconnected from the peripheral
    case .failure(let error):
        break // An error happened during the disconnection
    }
}
```
### Reading from a peripheral's service's characteristic
If you already know the characteristic and service UUIDs you want to read from, once you've found a peripheral you can read from it right away like this: 

```swift
peripheral.readValue(ofCharacWithUUID: "2A29", fromServiceWithUUID: "180A") { result in
    switch result {
    case .success(let data):
        break // The data was read and is returned as an NSData instance
    case .failure(let error):
        break // An error happened while attempting to read the data
    }
}
```
This will connect to the peripheral if necessary and ensure the characteristic and service needed are discovered before reading from the characteristic matching `characteristicUUID`. If the charac/service cannot be retrieved you will receive an error specifying which charac/service could not be found.

If you have a reference to a `CBCharacteristic`, you can read using the characteristic directly:
```swift
peripheral.readValue(ofCharac: charac) { result in
    switch result {
    case .success(let data):
        break // The data was read and is returned as an NSData instance
    case .failure(let error):
        break // An error happened while attempting to read the data
    }
}
```
### Writing to a Peripheral's service's characteristic
If you already know the characteristic and service UUID you want to write to, once you've found a peripheral, you can write to that characteristic right away like this: 
```swift
let exampleBinaryData = String(0b1010).dataUsingEncoding(NSUTF8StringEncoding)!
peripheral.writeValue(ofCharacWithUUID: "1d5bc11d-e28c-4157-a7be-d8b742a013d8", 
                      fromServiceWithUUID: "4011e369-5981-4dae-b686-619dc656c7ba", 
                      value: exampleBinaryData) { result in
    switch result {
    case .success:
        break // The write was successful.
    case .failure(let error):
        break // An error happened while writting the data.
    }
}
```
### Listening to and receiving Characteristic update notifications
Receiving characteristic value updates is done through notifications on the default `NotificationCenter`. All supported `Peripheral` notifications are part of the `PeripheralEvent` enum. Use this enum's raw values as the notification string when registering for notifications:
```swift
// First we prepare ourselves to receive update notifications 
let peripheral = somePeripheral

NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: PeripheralEvent.characteristicValueUpdate.rawValue), 
                                                                    object: peripheral, 
                                                                    queue: nil) { notification in
    let updatedCharacteristic = notification.userInfo?["characteristic"] as! CBCharacteristic
    var newValue = updatedCharacteristic.value
}

// We can then set a characteristic's notification value to true and start receiving updates to that characteristic
peripheral.setNotifyValue(toEnabled: true, forCharacWithUUID: "2A29", ofServiceWithUUID: "180A") { result in
    switch result {
    case .success(let isNotifying):
        break // You will now receive NSNotifications when that characteristic value gets updated.
    case .failure(let error):
        break // An error happened setting the characteristic to notify.
    }
}
```
### Discovering services 
Discover services using the `discoverServices(...)` function:
```swift
peripheral.discoverServices(withUUIDs: nil) { result in
    switch result {
    case .success(let services):
        break // An array containing all the services requested
    case .failure(let error):
        break // A connection error or an array containing the UUIDs of the services that we're not found
    }
}
```
Like the CBPeripheral discoverServices(...) function, passing nil instead of an array of service UUIDs will discover all of this Peripheral's services.
### Discovering characteristics
Discover characteristics using the `discoverCharacteristics(...)` function. If the service on which you are attempting to discover characteristics from has not been discovered, an attempt will first be made to discover that service for you:
```swift
peripheral.discoverCharacteristics(withUUIDs: nil, ofServiceWithUUID: "180A") { result in
    // The characteristics discovered or an error if something went wrong.
    switch result {
    case .success(let services):
        break // An array containing all the characs requested.
    case .failure(let error):
        break // A connection error or an array containing the UUIDs of the charac/services that we're not found.
    }
}
```
Like the CBPeripheral discoverCharacteristics(...) function, passing nil instead of an array of service UUIDs will discover all of this service's characteristics.  
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
github "tehjord/SwiftyBluetooth"
```

## Requirements
SwiftyBluetooth requires iOS 9.0+

## License
SwiftyBluetooth is released under the MIT License.
