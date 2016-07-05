//
//  CBUUIDConvertible.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 4/20/16.
//
//

import CoreBluetooth

public protocol CBUUIDConvertible {
    var CBUUIDRepresentation: CBUUID { get }
}

extension String: CBUUIDConvertible {
    public var CBUUIDRepresentation: CBUUID {
        get {
            return CBUUID(string: self)
        }
    }
}

extension NSUUID: CBUUIDConvertible {
    public var CBUUIDRepresentation: CBUUID {
        get {
            return CBUUID(NSUUID: self)
        }
    }
}

extension CBUUID: CBUUIDConvertible {
    public var CBUUIDRepresentation: CBUUID {
        get {
            return self
        }
    }
}

extension CBAttribute: CBUUIDConvertible {
    public var CBUUIDRepresentation: CBUUID {
        get {
            return self.UUID
        }
    }
}

func ExtractCBUUIDs(CBUUIDConvertibles: [CBUUIDConvertible]?) -> [CBUUID]? {
    if let CBUUIDConvertibles = CBUUIDConvertibles where CBUUIDConvertibles.count > 0 {
        
        return CBUUIDConvertibles.map { (CBUUIDConvertible) -> CBUUID in
            return CBUUIDConvertible.CBUUIDRepresentation
        }
        
    } else {
        return nil
    }
}
