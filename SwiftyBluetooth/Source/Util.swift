//
//  Util.swift
//  AcanvasBle
//
//  Created by tehjord on 4/16/16.
//  Copyright © 2016 acanvas. All rights reserved.
//

import Foundation

final class Box<T> {
    let value: T
    
    init(value: T) {
        self.value = value
    }
}

final class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}

//
//private final class QueueItem<T> {
//    let value: T
//    var next: QueueItem?
//    
//    init(value: T) {
//        self.value = value
//    }
//}
//
//final class Queue<T> {
//    private var front: QueueItem<T>?
//    private var back: QueueItem<T>?
//    
//    var isEmpty: Bool {
//        get {
//            return front == nil
//        }
//    }
//    
//    func enqueue(value: T) {
//        if let currentBack = back {
//            currentBack.next = QueueItem(value: value)
//            back =
//        } else if let front = front {
//            front.next = QueueItem(value: value)
//        } else {
//            front = QueueItem(value: value)
//        }
//    }
//    
//    func dequeue() -> T? {
//        guard let currentFront = front else {
//            return nil
//        }
//        
//        if let nextFront = currentFront.next {
//            
//        } else {
//            
//        }
//        
//        if let newFront = front?.next {
//            front = newFront
//        }
//    }
//    
//}
