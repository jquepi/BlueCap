//
//  Accelerometer.swift
//  Peripheral
//
//  Created by Troy Stribling on 4/19/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import CoreMotion
import BlueCapKit

class Accelerometer {

    var motionManager = CMMotionManager()
    let queue = OperationQueue.main
    let accelerationDataPromise = StreamPromise<CMAcceleration>(capacity: 10)
    
    var updatePeriod: TimeInterval {
        get {
            return motionManager.accelerometerUpdateInterval
        }
        set {
            motionManager.accelerometerUpdateInterval = newValue
        }
    }
    
    var accelerometerActive: Bool {
        return self.motionManager.isAccelerometerActive
    }
    
    var accelerometerAvailable: Bool {
        return self.motionManager.isAccelerometerAvailable
    }

    init() {
        self.motionManager.accelerometerUpdateInterval = 1.0
    }

    func startAcceleromterUpdates() -> FutureStream<CMAcceleration> {
        self.motionManager.startAccelerometerUpdates(to: self.queue) { (data: CMAccelerometerData?, error: Error?) in
            if let error = error {
                self.accelerationDataPromise.failure(error)
            } else {
                if let data = data {
                    self.accelerationDataPromise.success(data.acceleration)
                }
            }
        }
        return self.accelerationDataPromise.stream
    }
    
    func stopAccelerometerUpdates() {
        self.motionManager.stopAccelerometerUpdates()
    }
    
}

