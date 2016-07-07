//
//  PeripheralExtensions.swift
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

public typealias ReadRequestAsJSONCallback = (json: [String: AnyObject]?, error: Error?) -> Void
public typealias ReadRequestAsStringCallback = (string: String?, error: Error?) -> Void

/// Mark: Custom read functions with included serialization
public extension Peripheral {
    public func readCharacteristicValueAsJSON(characteristicUUID: CBUUIDConvertible,
                                              serviceUUID: CBUUIDConvertible,
                                              completion: ReadRequestAsJSONCallback)
    {
        self.readCharacteristicValue(characteristicUUID, serviceUUID: serviceUUID) { (data, error) in
            if let error = error {
                completion(json: nil, error: error)
                return
            }
            
            guard let data = data else {
                completion(json: nil, error: nil)
                return
            }
            
            do {
                let json: [String: AnyObject] = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as! [String : AnyObject]
                completion(json: json, error: nil)
            } catch {
                completion(json: nil, error: nil)
            }
        }
    }
    
    public func readCharacteristicValueAsUTF8String(characteristicUUID: CBUUIDConvertible,
                                                    serviceUUID: CBUUIDConvertible,
                                                    completion: ReadRequestAsStringCallback)
    {
        self.readCharacteristicValue(characteristicUUID, serviceUUID: serviceUUID) { (data, error) in
            if let error = error {
                completion(string: nil, error: error)
                return
            }
            
            guard let data = data else {
                completion(string: nil, error: nil)
                return
            }
            
            let string = String(data: data, encoding: 4)
            
            completion(string: string, error: nil)
        }
    }
}
