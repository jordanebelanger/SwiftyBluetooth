//
//  CBUUIDConvertible.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 4/20/16.
//
//

import Foundation
import CoreBluetooth

public protocol CBUUIDConvertible {
    var CBUUIDRepresentation: CBUUID { get }
}

// CBUUIDConvertible common types extensions
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

// Convenience
func ExtractCBUUIDs(CBUUIDConvertibles: [CBUUIDConvertible]?) -> [CBUUID]? {
    if let CBUUIDConvertibles = CBUUIDConvertibles where CBUUIDConvertibles.count > 0 {
        
        return CBUUIDConvertibles.map { (CBUUIDConvertible) -> CBUUID in
            return CBUUIDConvertible.CBUUIDRepresentation
        }
        
    } else {
        return nil
    }
}

final class CBUUIDPath: Hashable {
    let hash: Int
    
    init(uuids: CBUUID...) {
        var stringPath: String = String()
        
        for uuid in uuids {
            stringPath.appendContentsOf(uuid.UUIDString)
        }
        
        self.hash = stringPath.hashValue
    }
    
    var hashValue : Int {
        get {
            return self.hash
        }
    }
}
func ==(lhs: CBUUIDPath, rhs: CBUUIDPath) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

func servicePath(service service: CBUUIDConvertible) -> CBUUIDPath {
    return CBUUIDPath(uuids: service.CBUUIDRepresentation)
}
func characteristicPath(service service: CBUUIDConvertible,
                                characteristic: CBUUIDConvertible) -> CBUUIDPath {
    return CBUUIDPath(uuids: service.CBUUIDRepresentation,
                      characteristic.CBUUIDRepresentation)
}
func descriptorPath(service service: CBUUIDConvertible,
                            characteristic: CBUUIDConvertible,
                            descriptor: CBUUIDConvertible) -> CBUUIDPath {
    return CBUUIDPath(uuids: service.CBUUIDRepresentation,
                      characteristic.CBUUIDRepresentation,
                      descriptor.CBUUIDRepresentation)
}

extension CBService {
    var uuidPath: CBUUIDPath {
        get {
            return servicePath(service: self)
        }
    }
}

extension CBCharacteristic {
    var uuidPath: CBUUIDPath {
        get {
            return characteristicPath(service: self.service, characteristic: self)
        }
    }
}

extension CBDescriptor {
    var uuidPath: CBUUIDPath {
        get {
            return descriptorPath(service: self.characteristic.service, characteristic: self.characteristic, descriptor: self)
        }
    }
}
