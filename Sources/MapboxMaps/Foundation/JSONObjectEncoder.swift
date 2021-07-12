import Foundation

final class JSONObjectEncoder {

    var userInfo = [CodingUserInfoKey: Any]()

    /// Encodes the given top-level value and returns its JSON representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded JSON data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    func encode<T>(_ value: T) throws -> Any where T : Encodable {
        let encoder = JSONObjectEncoderImpl(codingPath: [], userInfo: userInfo)
        try value.encode(to: encoder)
        return try encoder.finalValue()
    }
}

enum JSONObject {
    case dictionary(Dictionary)
    case array(Array)
    case value(Any)
    case encoder(JSONObjectEncoderImpl)

    func finalValue() throws -> Any {
        switch self {
        case let .dictionary(dictionary):
            return try dictionary.finalValue()
        case let .array(array):
            return try array.finalValue()
        case let .encoder(encoder):
            return try encoder.finalValue()
        case let .value(value):
            return value
        }
    }

    class Dictionary {
        private var dictionary = [String: JSONObject]()

        func finalValue() throws -> [String: Any] {
            try dictionary.mapValues { try $0.finalValue() }
        }

        subscript(key: String) -> JSONObject? {
            get {
                dictionary[key]
            }
            set {
                dictionary[key] = newValue
            }
        }
    }

    class Array {
        private var array = [JSONObject]()

        var count: Int {
            array.count
        }

        func finalValue() throws -> [Any] {
            try array.map { try $0.finalValue() }
        }

        func append(_ newElement: JSONObject) {
            array.append(newElement)
        }
    }
}

struct JSONObjectCodingKey: CodingKey {
    var stringValue: String

    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = intValue.description
        self.intValue = intValue
    }
}

final class JSONObjectEncoderImpl: Encoder {
    let codingPath: [CodingKey]

    let userInfo: [CodingUserInfoKey: Any]

    var result: JSONObject?

    func finalValue() throws -> Any {
        guard let result = result else {
            preconditionFailure()
        }
        return try result.finalValue()
    }

    init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let dictionary: JSONObject.Dictionary
        switch result {
        case .none:
            dictionary = JSONObject.Dictionary()
            result = .dictionary(dictionary)
        case let .dictionary(dict):
            dictionary = dict
        default:
            preconditionFailure()
        }
        return KeyedEncodingContainer<Key>(
            JSONObjectKeyedEncodingContainer(
                codingPath: codingPath,
                dictionary: dictionary,
                userInfo: userInfo))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let array: JSONObject.Array
        switch result {
        case .none:
            array = JSONObject.Array()
            result = .array(array)
        case let .array(arr):
            array = arr
        default:
            preconditionFailure()
        }
        return JSONObjectUnkeyedEncodingContainer(codingPath: codingPath, array: array, userInfo: userInfo)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        JSONObjectSingleValueEncodingContainer(codingPath: codingPath, impl: self)
    }
}

struct JSONObjectKeyedEncodingContainer<K>: KeyedEncodingContainerProtocol where K: CodingKey {
    typealias Key = K

    let codingPath: [CodingKey]

    let dictionary: JSONObject.Dictionary

    let userInfo: [CodingUserInfoKey: Any]

    mutating func encodeNil(forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNull())
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSString(string: value))
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        dictionary[key.stringValue] = .value(NSNumber(value: value))
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        let encoder = JSONObjectEncoderImpl(codingPath: codingPath + [key], userInfo: userInfo)
        try value.encode(to: encoder)
        dictionary[key.stringValue] = try .value(encoder.finalValue())
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let dictionary: JSONObject.Dictionary
        switch self.dictionary[key.stringValue] {
        case let .dictionary(dict):
            dictionary = dict
        case .array, .encoder:
            preconditionFailure()
        case .none, .value:
            dictionary = JSONObject.Dictionary()
            self.dictionary[key.stringValue] = .dictionary(dictionary)
        }
        return KeyedEncodingContainer<NestedKey>(
            JSONObjectKeyedEncodingContainer<NestedKey>(
                codingPath: codingPath + [key],
                dictionary: dictionary,
                userInfo: userInfo))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let array: JSONObject.Array
        switch self.dictionary[key.stringValue] {
        case let .array(arr):
            array = arr
        case .dictionary, .encoder:
            preconditionFailure()
        case .none, .value:
            array = JSONObject.Array()
            self.dictionary[key.stringValue] = .array(array)
        }
        return JSONObjectUnkeyedEncodingContainer(
            codingPath: codingPath + [key],
            array: array,
            userInfo: userInfo)
    }

    mutating func superEncoder() -> Encoder {
        return _superEncoder(forKey: JSONObjectCodingKey(stringValue: "super")!)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return _superEncoder(forKey: key)
    }

    private func _superEncoder<T>(forKey key: T) -> Encoder where T: CodingKey {
        switch self.dictionary[key.stringValue] {
        case .dictionary, .array, .encoder:
            preconditionFailure()
        case .none, .value:
            let encoder = JSONObjectEncoderImpl(codingPath: codingPath + [key], userInfo: userInfo)
            self.dictionary[key.stringValue] = .encoder(encoder)
            return encoder
        }
    }
}

struct JSONObjectUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let codingPath: [CodingKey]

    let array: JSONObject.Array

    let userInfo: [CodingUserInfoKey: Any]

    var count: Int {
        return array.count
    }

    mutating func encodeNil() throws {
        array.append(.value(NSNull()))
    }

    mutating func encode(_ value: Bool) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: String) throws {
        array.append(.value(NSString(string: value)))
    }

    mutating func encode(_ value: Double) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Float) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Int) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Int8) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Int16) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Int32) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: Int64) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: UInt) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: UInt8) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: UInt16) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: UInt32) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode(_ value: UInt64) throws {
        array.append(.value(NSNumber(value: value)))
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let encoder = JSONObjectEncoderImpl(codingPath: codingPath + [JSONObjectCodingKey(intValue: count)!], userInfo: userInfo)
        try value.encode(to: encoder)
        try array.append(.value(encoder.finalValue()))
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let key = JSONObjectCodingKey(intValue: count)!
        let dictionary = JSONObject.Dictionary()
        self.array.append(.dictionary(dictionary))
        return KeyedEncodingContainer<NestedKey>(
            JSONObjectKeyedEncodingContainer<NestedKey>(
                codingPath: codingPath + [key],
                dictionary: dictionary,
                userInfo: userInfo))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = JSONObjectCodingKey(intValue: count)!
        let array = JSONObject.Array()
        self.array.append(.array(array))
        return JSONObjectUnkeyedEncodingContainer(
            codingPath: codingPath + [key],
            array: array,
            userInfo: userInfo)
    }

    mutating func superEncoder() -> Encoder {
        let encoder = JSONObjectEncoderImpl(codingPath: codingPath + [JSONObjectCodingKey(intValue: count)!], userInfo: userInfo)
        array.append(.encoder(encoder))
        return encoder
    }
}

struct JSONObjectSingleValueEncodingContainer: SingleValueEncodingContainer {
    let codingPath: [CodingKey]

    let impl: JSONObjectEncoderImpl

    init(codingPath: [CodingKey], impl: JSONObjectEncoderImpl) {
        self.codingPath = codingPath
        self.impl = impl
        verifyImplResultIsNil()
    }

    func verifyImplResultIsNil() {
        precondition(self.impl.result == nil)
    }

    mutating func encodeNil() throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNull())
    }

    mutating func encode(_ value: Bool) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: String) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSString(string: value))
    }

    mutating func encode(_ value: Double) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Float) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int8) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int16) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int32) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: Int64) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt8) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt16) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt32) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode(_ value: UInt64) throws {
        verifyImplResultIsNil()
        impl.result = .value(NSNumber(value: value))
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        verifyImplResultIsNil()
        let encoder = JSONObjectEncoderImpl(codingPath: codingPath, userInfo: impl.userInfo)
        try value.encode(to: encoder)
        impl.result = try .value(encoder.finalValue())
    }
}
