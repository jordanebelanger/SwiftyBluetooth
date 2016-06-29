//
//  CBUUIDPath.swift
//  SwiftyBluetooth
//
//  Created by tehjord on 6/22/16.
//
//

import Foundation
import CoreBluetooth

struct CBUUIDPath: Hashable {
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
