//
//  PeripheralExtensions.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/28/16.
//
//

import CoreBluetooth

public typealias ReadRequestAsJSONCallback = (json: [String: AnyObject]?, error: Error?) -> Void
public typealias ReadRequestAsStringCallback = (string: String?, error: Error?) -> Void

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
