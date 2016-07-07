//
//  CBUUIDConvertible.swift
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
        return CBUUIDConvertibles.map { $0.CBUUIDRepresentation }
    } else {
        return nil
    }
}
