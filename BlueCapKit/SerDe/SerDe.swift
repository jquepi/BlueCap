//
//  ByteSwap.swift
//  BlueCap
//
//  Created by Troy Stribling on 7/8/14.
//  Copyright (c) 2014 gnos.us. All rights reserved.
//

import Foundation
import CoreBluetooth

func toHostByteOrder<T>(value:T) -> T {
    return value;
}

func fromHostByteOrder<T>(value:T) -> T {
    return value;
}

func byteArrayValue<T>(value:T) -> [Byte] {
    let values = [value]
    let data = NSData(bytes:values, length:sizeof(T))
    var byteArray = [Byte](count:sizeof(T), repeatedValue:0)
    data.getBytes(&byteArray, length:sizeof(T))
    return byteArray
}

func reverseBytes<T>(value:T) -> T {
    var result = value
    var swappedBytes = NSData(bytes:byteArrayValue(value).reverse(), length:sizeof(T))
    swappedBytes.getBytes(&result, length:sizeof(T))
    return result
}

public protocol Deserializable {
    class var size : Int {get}
    class func fromString(data:String) -> Self?
    class func deserialize(data:NSData) -> Self
    class func deserialize(data:NSData, start:Int) -> Self
    class func deserialize(data:NSData) -> [Self]
}

public protocol Serializable {
    class func serialize<T>(value:T) -> NSData
    class func serialize<T>(values:[T]) -> NSData
    class func serialize<T1, T2>(values:(T1, T2)) -> NSData
    class func serialize<T1, T2>(values:([T1], [T2])) -> NSData
}

public protocol BLEConfigurable {
    class var name          : String {get}
    class var tag           : String {get}
    class var permissions   : CBAttributePermissions {get}
    class var properties    : CBCharacteristicProperties {get}
    class var initialValue  : NSData {get}
}

public protocol StringDeserializable {
    class var stringValues  : [String] {get}
    var stringValue         : [String:String] {get}
    init?(stringValue:[String:String])
}

public protocol RawDeserializable {
    typealias RawType   : Deserializable
    class var uuid      : String {get}
    var rawValue        : RawType {get}
    init?(rawValue:RawType)
}

public protocol RawArrayDeserializable {
    typealias RawType   : Deserializable
    class var uuid      : String {get}
    var rawValue        : [RawType] {get}
    init?(rawValue:[RawType])
}

public protocol RawPairDeserializable {
    typealias RawType1   : Deserializable
    typealias RawType2   : Deserializable
    class var uuid      : String {get}
    var rawValue        : (RawType1, RawType2) {get}
    init?(rawValue:(RawType1, RawType2))
}

public protocol RawArrayPairDeserializable {
    typealias RawType1  : Deserializable
    typealias RawType2  : Deserializable
    class var uuid      : String {get}
    class var size      : (Int, Int) {get}
    var rawValue        : ([RawType1], [RawType2]) {get}
    init?(rawValue:([RawType1], [RawType2]))
}

public func deserialize<T:Deserializable>(data:NSData) -> T {
    return T.deserialize(data)
}

public func serialize<T:Deserializable>(value:T) -> NSData {
    return NSData.serialize(value)
}

public func deserialize<T:RawDeserializable>(data:NSData) -> T.RawType {
    return T.RawType.deserialize(data)
}

public func serialize<T:RawDeserializable>(value:T) -> NSData {
    return NSData.serialize(value.rawValue)
}

public func deserialize<T:RawArrayDeserializable>(data:NSData) -> [T.RawType] {
    return T.RawType.deserialize(data)
}

public func serialize<T:RawArrayDeserializable>(value:T) -> NSData {
    return NSData.serialize(value.rawValue)
}

public func deserialize<T:RawPairDeserializable>(data:NSData) -> (T.RawType1, T.RawType2) {
    let rawData1 = data.subdataWithRange(NSMakeRange(0, T.RawType1.size))
    let rawData2 = data.subdataWithRange(NSMakeRange(T.RawType1.size, T.RawType2.size))
    return (T.RawType1.deserialize(rawData1), T.RawType2.deserialize(rawData2))
}

public func serialize<T:RawPairDeserializable>(value:T) -> NSData {
    return NSData.serialize(value.rawValue)
}

public func deserialize<T:RawArrayPairDeserializable>(data:NSData) -> ([T.RawType1], [T.RawType2]) {
        let (rawSize1, rawSize2) = T.size
        let rawData1 = data.subdataWithRange(NSMakeRange(0, rawSize1))
        let rawData2 = data.subdataWithRange(NSMakeRange(rawSize1, rawSize2))
        return (T.RawType1.deserialize(rawData1), T.RawType2.deserialize(rawData2))
}

public func serialize<T:RawArrayPairDeserializable>(value:T) -> NSData {
    return NSData.serialize(value.rawValue)
}





