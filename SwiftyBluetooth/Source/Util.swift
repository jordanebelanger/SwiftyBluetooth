//
//  Util.swift
//  AcanvasBle
//
//  Created by tehjord on 4/16/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import Foundation

final class Weak<T: AnyObject> {
    weak var value : T?
    
    init (value: T) {
        self.value = value
    }
}
