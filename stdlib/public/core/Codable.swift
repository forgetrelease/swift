//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Codable
//===----------------------------------------------------------------------===//

/// A type that can encode itself to an external representation.
public protocol Encodable {
    /// Encodes this value into the given encoder.
    ///
    /// If the value fails to encode anything, `encoder` will encode an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: Encoder) throws
}

/// A type that can decode itself from an external representation.
public protocol Decodable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    init(from decoder: Decoder) throws
}

/// A type that can convert itself into and out of an external representation.
public typealias Codable = Encodable & Decodable

//===----------------------------------------------------------------------===//
// CodingKey
//===----------------------------------------------------------------------===//

/// A type that can be used as a key for encoding and decoding.
public protocol CodingKey: CustomStringConvertible, CustomDebugStringConvertible {
    /// The string to use in a named collection (e.g. a string-keyed dictionary).
    var stringValue: String { get }

    /// Creates a new instance from the given string.
    ///
    /// If the string passed as `stringValue` does not correspond to any instance of this type, the result is `nil`.
    ///
    /// - parameter stringValue: The string value of the desired key.
    init?(stringValue: String)

    /// The value to use in an integer-indexed collection (e.g. an int-keyed dictionary).
    var intValue: Int? { get }

    /// Creates a new instance from the specified integer.
    ///
    /// If the value passed as `intValue` does not correspond to any instance of this type, the result is `nil`.
    ///
    /// - parameter intValue: The integer value of the desired key.
    init?(intValue: Int)
}

extension CodingKey {
    /// A textual representation of this key.
    @_inlineable // FIXME(sil-serialize-all)
    public var description: String {
        let intValue = self.intValue?.description ?? "nil"
        return "\(type(of: self))(stringValue: \"\(stringValue)\", intValue: \(intValue))"
    }

    /// A textual representation of this key, suitable for debugging.
    @_inlineable // FIXME(sil-serialize-all)
    public var debugDescription: String {
        return description
    }
}

//===----------------------------------------------------------------------===//
// Encoder & Decoder
//===----------------------------------------------------------------------===//

/// A type that can encode values into a native format for external representation.
public protocol Encoder {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    /// Returns an encoding container appropriate for holding multiple values keyed by the given key type.
    ///
    /// You must use only one kind of top-level encoding container. This method must not be called after a call to `unkeyedContainer()` or after encoding a value through a call to `singleValueContainer()`
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>

    /// Returns an encoding container appropriate for holding multiple unkeyed values.
    ///
    /// You must use only one kind of top-level encoding container. This method must not be called after a call to `container(keyedBy:)` or after encoding a value through a call to `singleValueContainer()`
    ///
    /// - returns: A new empty unkeyed container.
    func unkeyedContainer() -> UnkeyedEncodingContainer

    /// Returns an encoding container appropriate for holding a single primitive value.
    ///
    /// You must use only one kind of top-level encoding container. This method must not be called after a call to `unkeyedContainer()` or `container(keyedBy:)`, or after encoding a value through a call to `singleValueContainer()`
    ///
    /// - returns: A new empty single value container.
    func singleValueContainer() -> SingleValueEncodingContainer
}

/// A type that can decode values from a native format into in-memory representations.
public protocol Decoder {
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }

    /// Any contextual information set by the user for decoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    /// Returns the data stored in this decoder as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>

    /// Returns the data stored in this decoder as represented in a container appropriate for holding values with no keys.
    ///
    /// - returns: An unkeyed container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not an unkeyed container.
    func unkeyedContainer() throws -> UnkeyedDecodingContainer

    /// Returns the data stored in this decoder as represented in a container appropriate for holding a single primitive value.
    ///
    /// - returns: A single value container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a single value container.
    func singleValueContainer() throws -> SingleValueDecodingContainer
}

//===----------------------------------------------------------------------===//
// Keyed Encoding Containers
//===----------------------------------------------------------------------===//

/// A type that provides a view into an encoder's storage and is used to hold
/// the encoded properties of an encodable type in a keyed manner.
///
/// Encoders should provide types conforming to
/// `KeyedEncodingContainerProtocol` for their format.
public protocol KeyedEncodingContainerProtocol {
    associatedtype Key : CodingKey

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// Encodes a null value for the given key.
    ///
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    mutating func encodeNil(forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Bool, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int8, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int16, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int32, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int64, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt8, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt16, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt32, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt64, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Float, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Double, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: String, forKey key: Key) throws

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws

    /// Encodes a reference to the given object only if it is encoded unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For encoders which don't support this feature, the default implementation encodes the given object unconditionally.
    ///
    /// - parameter object: The object to encode.
    /// - parameter key: The key to associate the object with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeConditional<T : AnyObject & Encodable>(_ object: T, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent<T : Encodable>(_ value: T?, forKey key: Key) throws

    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to encode the container for.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>

    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to encode the container for.
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer

    /// Stores a new nested container for the default `super` key and returns A new encoder instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superEncoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder() -> Encoder

    /// Stores a new nested container for the given key and returns A new encoder instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to encode `super` for.
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder(forKey key: Key) -> Encoder
}

// An implementation of _KeyedEncodingContainerBase and _KeyedEncodingContainerBox are given at the bottom of this file.

/// A concrete container that provides a view into an encoder's storage, making
/// the encoded properties of an encodable type accessible by keys.
@_fixed_layout // FIXME(sil-serialize-all)
public struct KeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
    public typealias Key = K

    /// The container for the concrete encoder. The type is _*Base so that it's generic on the key type.
    @_versioned
    internal var _box: _KeyedEncodingContainerBase<Key>

    /// Creates a new instance with the given container.
    ///
    /// - parameter container: The container to hold.
    @_inlineable // FIXME(sil-serialize-all)
    public init<Container : KeyedEncodingContainerProtocol>(_ container: Container) where Container.Key == Key {
        _box = _KeyedEncodingContainerBox(container)
    }

    /// The path of coding keys taken to get to this point in encoding.
    @_inlineable // FIXME(sil-serialize-all)
    public var codingPath: [CodingKey] {
        return _box.codingPath
    }

    /// Encodes a null value for the given key.
    ///
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeNil(forKey key: Key) throws {
        try _box.encodeNil(forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Int, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Float, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: Double, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode(_ value: String, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }

    /// Encodes a reference to the given object only if it is encoded unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For encoders which don't support this feature, the default implementation encodes the given object unconditionally.
    ///
    /// - parameter object: The object to encode.
    /// - parameter key: The key to associate the object with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeConditional<T : AnyObject & Encodable>(_ object: T, forKey key: Key) throws {
        try _box.encodeConditional(object, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent<T : Encodable>(_ value: T?, forKey key: Key) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }

    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to encode the container for.
    /// - returns: A new keyed encoding container.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        return _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to encode the container for.
    /// - returns: A new unkeyed encoding container.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return _box.nestedUnkeyedContainer(forKey: key)
    }

    /// Stores a new nested container for the default `super` key and returns A new encoder instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superEncoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func superEncoder() -> Encoder {
        return _box.superEncoder()
    }

    /// Stores a new nested container for the given key and returns A new encoder instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to encode `super` for.
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _box.superEncoder(forKey: key)
    }
}

/// A type that provides a view into a decoder's storage and is used to hold
/// the encoded properties of a decodable type in a keyed manner.
///
/// Decoders should provide types conforming to `UnkeyedDecodingContainer` for
/// their format.
public protocol KeyedDecodingContainerProtocol {
    associatedtype Key : CodingKey

    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }

    /// All the keys the `Decoder` has for this container.
    ///
    /// Different keyed containers from the same `Decoder` may return different keys here; it is possible to encode with multiple key types which are not convertible to one another. This should report all keys present which are convertible to the requested type.
    var allKeys: [Key] { get }

    /// Returns a Boolean value indicating whether the decoder contains a value associated with the given key.
    ///
    /// The value associated with `key` may be a null value as appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Decoder` has an entry for the given key.
    func contains(_ key: Key) -> Bool

    /// Decodes a null value for the given key.
    ///
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    func decodeNil(forKey key: Key) throws -> Bool

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: String.Type, forKey key: Key) throws -> String

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String?

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T?

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey>

    /// Returns the data stored for the given key as represented in an unkeyed container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not an unkeyed container.
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer

    /// Returns a `Decoder` instance for decoding `super` from the container associated with the default `super` key.
    ///
    /// Equivalent to calling `superDecoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the default `super` key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the default `super` key.
    func superDecoder() throws -> Decoder

    /// Returns a `Decoder` instance for decoding `super` from the container associated with the given key.
    ///
    /// - parameter key: The key to decode `super` for.
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func superDecoder(forKey key: Key) throws -> Decoder
}

// An implementation of _KeyedDecodingContainerBase and _KeyedDecodingContainerBox are given at the bottom of this file.

/// A concrete container that provides a view into an decoder's storage, making
/// the encoded properties of an decodable type accessible by keys.
@_fixed_layout // FIXME(sil-serialize-all)
public struct KeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    public typealias Key = K

    /// The container for the concrete decoder. The type is _*Base so that it's generic on the key type.
    @_versioned
    internal var _box: _KeyedDecodingContainerBase<Key>

    /// Creates a new instance with the given container.
    ///
    /// - parameter container: The container to hold.
    @_inlineable // FIXME(sil-serialize-all)
    public init<Container : KeyedDecodingContainerProtocol>(_ container: Container) where Container.Key == Key {
        _box = _KeyedDecodingContainerBox(container)
    }

    /// The path of coding keys taken to get to this point in decoding.
    @_inlineable // FIXME(sil-serialize-all)
    public var codingPath: [CodingKey] {
        return _box.codingPath
    }

    /// All the keys the decoder has for this container.
    ///
    /// Different keyed containers from the same decoder may return different keys here, because it is possible to encode with multiple key types which are not convertible to one another. This should report all keys present which are convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public var allKeys: [Key] {
        return _box.allKeys
    }

    /// Returns a Boolean value indicating whether the decoder contains a value associated with the given key.
    ///
    /// The value associated with the given key may be a null value as appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Decoder` has an entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func contains(_ key: Key) -> Bool {
        return _box.contains(key)
    }

    /// Decodes a null value for the given key.
    ///
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeNil(forKey key: Key) throws -> Bool {
        return try _box.decodeNil(forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try _box.decode(Bool.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try _box.decode(Int.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try _box.decode(Int8.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try _box.decode(Int16.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try _box.decode(Int32.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try _box.decode(Int64.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try _box.decode(UInt.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try _box.decode(UInt8.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try _box.decode(UInt16.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try _box.decode(UInt32.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try _box.decode(UInt64.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try _box.decode(Float.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try _box.decode(Double.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try _box.decode(String.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try _box.decode(T.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try _box.decodeIfPresent(Bool.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try _box.decodeIfPresent(Int.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try _box.decodeIfPresent(Int8.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try _box.decodeIfPresent(Int16.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try _box.decodeIfPresent(Int32.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try _box.decodeIfPresent(Int64.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try _box.decodeIfPresent(UInt.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try _box.decodeIfPresent(UInt8.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try _box.decodeIfPresent(UInt16.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try _box.decodeIfPresent(UInt32.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try _box.decodeIfPresent(UInt64.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try _box.decodeIfPresent(Float.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try _box.decodeIfPresent(Double.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        return try _box.decodeIfPresent(String.self, forKey: key)
    }

    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try _box.decodeIfPresent(T.self, forKey: key)
    }

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    @_inlineable // FIXME(sil-serialize-all)
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    /// Returns the data stored for the given key as represented in an unkeyed container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not an unkeyed container.
    @_inlineable // FIXME(sil-serialize-all)
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try _box.nestedUnkeyedContainer(forKey: key)
    }

    /// Returns a `Decoder` instance for decoding `super` from the container associated with the default `super` key.
    ///
    /// Equivalent to calling `superDecoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the default `super` key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the default `super` key.
    @_inlineable // FIXME(sil-serialize-all)
    public func superDecoder() throws -> Decoder {
        return try _box.superDecoder()
    }

    /// Returns a `Decoder` instance for decoding `super` from the container associated with the given key.
    ///
    /// - parameter key: The key to decode `super` for.
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    @_inlineable // FIXME(sil-serialize-all)
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _box.superDecoder(forKey: key)
    }
}

//===----------------------------------------------------------------------===//
// Unkeyed Encoding Containers
//===----------------------------------------------------------------------===//

/// A type that provides a view into an encoder's storage and is used to hold
/// the encoded properties of an encodable type sequentially, without keys.
///
/// Encoders should provide types conforming to `UnkeyedEncodingContainer` for
/// their format.
public protocol UnkeyedEncodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// The number of elements encoded into the container.
    var count: Int { get }

    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    mutating func encodeNil() throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Bool) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int8) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int16) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int32) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Int64) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt8) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt16) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt32) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: UInt64) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Float) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Double) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: String) throws

    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode<T : Encodable>(_ value: T) throws

    /// Encodes a reference to the given object only if it is encoded unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For encoders which don't support this feature, the default implementation encodes the given object unconditionally.
    ///
    /// For formats which don't support this feature, the default implementation encodes the given object unconditionally.
    ///
    /// - parameter object: The object to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeConditional<T : AnyObject & Encodable>(_ object: T) throws

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Bool

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int8

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int16

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int32

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int64

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt8

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt16

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt32

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt64

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Float

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Double

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == String

    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element : Encodable

    /// Encodes a nested container keyed by the given type and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>

    /// Encodes an unkeyed encoding container and returns it.
    ///
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer

    /// Encodes a nested container and returns an `Encoder` instance for encoding `super` into that container.
    ///
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder() -> Encoder
}

/// A type that provides a view into a decoder's storage and is used to hold
/// the encoded properties of a decodable type sequentially, without keys.
///
/// Decoders should provide types conforming to `UnkeyedDecodingContainer` for
/// their format.
public protocol UnkeyedDecodingContainer {
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }

    /// The number of elements contained within this container.
    ///
    /// If the number of elements is unknown, the value is `nil`.
    var count: Int? { get }

    /// A Boolean value indicating whether there are no more elements left to be decoded in the container.
    var isAtEnd: Bool { get }

    /// The current decoding index of the container (i.e. the index of the next element to be decoded.)
    /// Incremented after every successful decode call.
    var currentIndex: Int { get }

    /// Decodes a null value.
    ///
    /// If the value is not null, does not increment currentIndex.
    ///
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.valueNotFound` if there are no more values to decode.
    mutating func decodeNil() throws -> Bool

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Bool.Type) throws -> Bool

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Int.Type) throws -> Int

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Int8.Type) throws -> Int8

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Int16.Type) throws -> Int16

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Int32.Type) throws -> Int32

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Int64.Type) throws -> Int64

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt.Type) throws -> UInt

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt8.Type) throws -> UInt8

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt16.Type) throws -> UInt16

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt32.Type) throws -> UInt32

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt64.Type) throws -> UInt64

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Float.Type) throws -> Float

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: Double.Type) throws -> Double

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode(_ type: String.Type) throws -> String

    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func decode<T : Decodable>(_ type: T.Type) throws -> T

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int.Type) throws -> Int?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int8.Type) throws -> Int8?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int16.Type) throws -> Int16?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int32.Type) throws -> Int32?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int64.Type) throws -> Int64?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt.Type) throws -> UInt?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt8.Type) throws -> UInt8?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt16.Type) throws -> UInt16?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt32.Type) throws -> UInt32?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt64.Type) throws -> UInt64?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Float.Type) throws -> Float?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Double.Type) throws -> Double?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: String.Type) throws -> String?

    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to decode, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    mutating func decodeIfPresent<T : Decodable>(_ type: T.Type) throws -> T?

    /// Decodes a nested container keyed by the given type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>

    /// Decodes an unkeyed nested container.
    ///
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not an unkeyed container.
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer

    /// Decodes a nested container and returns a `Decoder` instance for decoding `super` from that container.
    ///
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null, or of there are no more values to decode.
    mutating func superDecoder() throws -> Decoder
}

//===----------------------------------------------------------------------===//
// Single Value Encoding Containers
//===----------------------------------------------------------------------===//

/// A container that can support the storage and direct encoding of a single
/// non-keyed value.
public protocol SingleValueEncodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encodeNil() throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Bool) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Int) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Int8) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Int16) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Int32) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Int64) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: UInt) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: UInt8) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: UInt16) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: UInt32) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: UInt64) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Float) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Double) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: String) throws

    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode<T : Encodable>(_ value: T) throws
}

/// A `SingleValueDecodingContainer` is a container which can support the storage and direct decoding of a single non-keyed value.
public protocol SingleValueDecodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Bool.Type) throws -> Bool

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Int.Type) throws -> Int

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Int8.Type) throws -> Int8

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Int16.Type) throws -> Int16

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Int32.Type) throws -> Int32

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Int64.Type) throws -> Int64

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: UInt.Type) throws -> UInt

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: UInt8.Type) throws -> UInt8

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: UInt16.Type) throws -> UInt16

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: UInt32.Type) throws -> UInt32

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: UInt64.Type) throws -> UInt64

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Float.Type) throws -> Float

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Double.Type) throws -> Double

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: String.Type) throws -> String

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode<T : Decodable>(_ type: T.Type) throws -> T
}

//===----------------------------------------------------------------------===//
// User Info
//===----------------------------------------------------------------------===//

/// A user-defined key for providing context during encoding and decoding.
@_fixed_layout // FIXME(sil-serialize-all)
public struct CodingUserInfoKey : RawRepresentable, Equatable, Hashable {
    public typealias RawValue = String

    /// The key's string value.
    public let rawValue: String

    /// Creates a new instance with the given raw value.
    ///
    /// - parameter rawValue: The value of the key.
    @_inlineable // FIXME(sil-serialize-all)
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Returns a Boolean value indicating whether the given keys are equal.
    ///
    /// - parameter lhs: The key to compare against.
    /// - parameter rhs: The key to compare with.
    @_inlineable // FIXME(sil-serialize-all)
    public static func ==(_ lhs: CodingUserInfoKey, _ rhs: CodingUserInfoKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    /// The key's hash value.
    @_inlineable // FIXME(sil-serialize-all)
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}

//===----------------------------------------------------------------------===//
// Errors
//===----------------------------------------------------------------------===//

/// An error that occurs during the encoding of a value.
public enum EncodingError : Error {
    /// The context in which the error occurred.
    @_fixed_layout // FIXME(sil-serialize-all)
    public struct Context {
        /// The path of coding keys taken to get to the point of the failing encode call.
        public let codingPath: [CodingKey]

        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String

        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?

        /// Creates a new context with the given path of coding keys and a description of what went wrong.
        ///
        /// - parameter codingPath: The path of coding keys taken to get to the point of the failing encode call.
        /// - parameter debugDescription: A description of what went wrong, for debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this error, if any.
        @_inlineable // FIXME(sil-serialize-all)
        public init(codingPath: [CodingKey], debugDescription: String, underlyingError: Error? = nil) {
            self.codingPath = codingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }

    /// An indication that an encoder or its containers could not encode the given value.
    ///
    /// As associated values, this case contains the attempted value and context for debugging.
    case invalidValue(Any, Context)

    // MARK: - NSError Bridging

    // CustomNSError bridging applies only when the CustomNSError conformance is applied in the same module as the declared error type.
    // Since we cannot access CustomNSError (which is defined in Foundation) from here, we can use the "hidden" entry points.

    @_inlineable // FIXME(sil-serialize-all)
    public var _domain: String {
        return "NSCocoaErrorDomain"
    }

    @_inlineable // FIXME(sil-serialize-all)
    public var _code: Int {
        switch self {
        case .invalidValue(_, _): return 4866
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this only on platforms with bridging, unfortunately.
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            let context: Context
            switch self {
            case .invalidValue(_, let c): context = c
            }

            var userInfo: [String : Any] = [
                "NSCodingPath": context.codingPath,
                "NSDebugDescription": context.debugDescription
            ]

            if let underlyingError = context.underlyingError {
                userInfo["NSUnderlyingError"] = underlyingError
            }

            return userInfo as AnyObject
        #else
            return nil
        #endif
    }
}

/// An error that occurs during the decoding of a value.
public enum DecodingError : Error {
    /// The context in which the error occurred.
    @_fixed_layout // FIXME(sil-serialize-all)
    public struct Context {
        /// The path of coding keys taken to get to the point of the failing decode call.
        public let codingPath: [CodingKey]

        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String

        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?

        /// Creates a new context with the given path of coding keys and a description of what went wrong.
        ///
        /// - parameter codingPath: The path of coding keys taken to get to the point of the failing decode call.
        /// - parameter debugDescription: A description of what went wrong, for debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this error, if any.
        @_inlineable // FIXME(sil-serialize-all)
        public init(codingPath: [CodingKey], debugDescription: String, underlyingError: Error? = nil) {
            self.codingPath = codingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }

    /// An indication that a value of the given type could not be decoded because it did not match the type of what was found in the encoded payload.
    ///
    /// As associated values, this case contains the attempted type and context for debugging.
    case typeMismatch(Any.Type, Context)

    /// An indication that a non-optional value of the given type was expected, but a null value was found.
    ///
    /// As associated values, this case contains the attempted type and context for debugging.
    case valueNotFound(Any.Type, Context)

    ///  An indication that a keyed decoding container was asked for an entry for the given key, but did not contain one.
    ///
    /// As associated values, this case contains the attempted key and context for debugging.
    case keyNotFound(CodingKey, Context)

    /// An indication that the data is corrupted or otherwise invalid.
    ///
    /// As an associated value, this case contains the context for debugging.
    case dataCorrupted(Context)

    // MARK: - NSError Bridging

    // CustomNSError bridging applies only when the CustomNSError conformance is applied in the same module as the declared error type.
    // Since we cannot access CustomNSError (which is defined in Foundation) from here, we can use the "hidden" entry points.

    @_inlineable // FIXME(sil-serialize-all)
    public var _domain: String {
        return "NSCocoaErrorDomain"
    }

    @_inlineable // FIXME(sil-serialize-all)
    public var _code: Int {
        switch self {
        case .keyNotFound(_, _):   fallthrough
        case .valueNotFound(_, _): return 4865
        case .typeMismatch(_, _):  fallthrough
        case .dataCorrupted(_):    return 4864
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this only on platforms with bridging, unfortunately.
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            let context: Context
            switch self {
            case .keyNotFound(_,   let c): context = c
            case .valueNotFound(_, let c): context = c
            case .typeMismatch(_,  let c): context = c
            case .dataCorrupted(   let c): context = c
            }

            var userInfo: [String : Any] = [
                "NSCodingPath": context.codingPath,
                "NSDebugDescription": context.debugDescription
            ]

            if let underlyingError = context.underlyingError {
                userInfo["NSUnderlyingError"] = underlyingError
            }

            return userInfo as AnyObject
        #else
            return nil
        #endif
    }
}

// The following extensions allow for easier error construction.

@_versioned // FIXME(sil-serialize-all)
@_fixed_layout // FIXME(sil-serialize-all)
internal struct _GenericIndexKey : CodingKey {
    @_versioned // FIXME(sil-serialize-all)
    internal var stringValue: String
    @_versioned // FIXME(sil-serialize-all)
    internal var intValue: Int?

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init?(stringValue: String) {
        return nil
    }

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init?(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
}

public extension DecodingError {
    /// Returns a new `.dataCorrupted` error using a constructed coding path and the given debug description.
    ///
    /// The coding path for the returned error is constructed by appending the given key to the given container's coding path.
    ///
    /// - param key: The key which caused the failure.
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    /// - Returns: A new `.dataCorrupted` error with the given information.
    @_inlineable // FIXME(sil-serialize-all)
    public static func dataCorruptedError<C : KeyedDecodingContainerProtocol>(forKey key: C.Key, in container: C, debugDescription: String) -> DecodingError {
        let context = DecodingError.Context(codingPath: container.codingPath + [key],
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }

    /// Returns a new `.dataCorrupted` error using a constructed coding path and the given debug description.
    ///
    /// The coding path for the returned error is constructed by appending the given container's current index to its coding path.
    ///
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    /// - Returns: A new `.dataCorrupted` error with the given information.
    @_inlineable // FIXME(sil-serialize-all)
    public static func dataCorruptedError(in container: UnkeyedDecodingContainer, debugDescription: String) -> DecodingError {
        let context = DecodingError.Context(codingPath: container.codingPath + [_GenericIndexKey(intValue: container.currentIndex)!],
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }

    /// Returns a new `.dataCorrupted` error using a constructed coding path and the given debug description.
    ///
    /// The coding path for the returned error is the given container's coding path.
    ///
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    /// - Returns: A new `.dataCorrupted` error with the given information.
    @_inlineable // FIXME(sil-serialize-all)
    public static func dataCorruptedError(in container: SingleValueDecodingContainer, debugDescription: String) -> DecodingError {
        let context = DecodingError.Context(codingPath: container.codingPath,
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }
}

//===----------------------------------------------------------------------===//
// Keyed Encoding Container Implementations
//===----------------------------------------------------------------------===//

@_fixed_layout
@_versioned
internal class _KeyedEncodingContainerBase<Key : CodingKey> {
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init(){}

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    deinit {}

    // These must all be given a concrete implementation in _*Box.
    @_inlineable
    @_versioned
    internal var codingPath: [CodingKey] {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeNil(forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Bool, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Int, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Int8, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Int16, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Int32, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Int64, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: UInt, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: UInt8, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: UInt16, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: UInt32, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: UInt64, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Float, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: Double, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode(_ value: String, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeConditional<T : AnyObject & Encodable>(_ object: T, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func encodeIfPresent<T : Encodable>(_ value: T?, forKey key: Key) throws {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func superEncoder() -> Encoder {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func superEncoder(forKey key: Key) -> Encoder {
        fatalError("_KeyedEncodingContainerBase cannot be used directly.")
    }
}

@_fixed_layout
@_versioned
internal final class _KeyedEncodingContainerBox<Concrete : KeyedEncodingContainerProtocol> : _KeyedEncodingContainerBase<Concrete.Key> {
    typealias Key = Concrete.Key

    @_versioned
    internal var concrete: Concrete

    @_inlineable
    @_versioned
    internal init(_ container: Concrete) {
        concrete = container
    }

    @_inlineable
    @_versioned
    override internal var codingPath: [CodingKey] {
        return concrete.codingPath
    }

    @_inlineable
    @_versioned
    override internal func encodeNil(forKey key: Key) throws {
        try concrete.encodeNil(forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Bool, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Int, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Int8, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Int16, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Int32, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Int64, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: UInt, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: UInt8, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: UInt16, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: UInt32, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: UInt64, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Float, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: Double, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode(_ value: String, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        try concrete.encode(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeConditional<T : AnyObject & Encodable>(_ object: T, forKey key: Key) throws {
        try concrete.encodeConditional(object, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func encodeIfPresent<T : Encodable>(_ value: T?, forKey key: Key) throws {
        try concrete.encodeIfPresent(value, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        return concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return concrete.nestedUnkeyedContainer(forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func superEncoder() -> Encoder {
        return concrete.superEncoder()
    }

    @_inlineable
    @_versioned
    override internal func superEncoder(forKey key: Key) -> Encoder {
        return concrete.superEncoder(forKey: key)
    }
}

@_fixed_layout
@_versioned
internal class _KeyedDecodingContainerBase<Key : CodingKey> {
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init(){}

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    deinit {}

    @_inlineable
    @_versioned
    internal var codingPath: [CodingKey] {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal var allKeys: [Key] {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func contains(_ key: Key) -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeNil(forKey key: Key) throws -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func superDecoder() throws -> Decoder {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }

    @_inlineable
    @_versioned
    internal func superDecoder(forKey key: Key) throws -> Decoder {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
}

@_fixed_layout
@_versioned
internal final class _KeyedDecodingContainerBox<Concrete : KeyedDecodingContainerProtocol> : _KeyedDecodingContainerBase<Concrete.Key> {
    typealias Key = Concrete.Key

    @_versioned
    internal var concrete: Concrete

    @_inlineable
    @_versioned
    internal init(_ container: Concrete) {
        concrete = container
    }

    @_inlineable
    @_versioned
    override var codingPath: [CodingKey] {
        return concrete.codingPath
    }

    @_inlineable
    @_versioned
    override var allKeys: [Key] {
        return concrete.allKeys
    }

    @_inlineable
    @_versioned
    override internal func contains(_ key: Key) -> Bool {
        return concrete.contains(key)
    }

    @_inlineable
    @_versioned
    override internal func decodeNil(forKey key: Key) throws -> Bool {
        return try concrete.decodeNil(forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try concrete.decode(Bool.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try concrete.decode(Int.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try concrete.decode(Int8.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try concrete.decode(Int16.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try concrete.decode(Int32.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try concrete.decode(Int64.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try concrete.decode(UInt.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try concrete.decode(UInt8.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try concrete.decode(UInt16.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try concrete.decode(UInt32.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try concrete.decode(UInt64.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try concrete.decode(Float.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try concrete.decode(Double.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try concrete.decode(String.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try concrete.decode(T.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try concrete.decodeIfPresent(Bool.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try concrete.decodeIfPresent(Int.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try concrete.decodeIfPresent(Int8.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try concrete.decodeIfPresent(Int16.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try concrete.decodeIfPresent(Int32.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try concrete.decodeIfPresent(Int64.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try concrete.decodeIfPresent(UInt.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try concrete.decodeIfPresent(UInt8.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try concrete.decodeIfPresent(UInt16.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try concrete.decodeIfPresent(UInt32.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try concrete.decodeIfPresent(UInt64.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try concrete.decodeIfPresent(Float.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try concrete.decodeIfPresent(Double.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        return try concrete.decodeIfPresent(String.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try concrete.decodeIfPresent(T.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try concrete.nestedUnkeyedContainer(forKey: key)
    }

    @_inlineable
    @_versioned
    override internal func superDecoder() throws -> Decoder {
        return try concrete.superDecoder()
    }

    @_inlineable
    @_versioned
    override internal func superDecoder(forKey key: Key) throws -> Decoder {
        return try concrete.superDecoder(forKey: key)
    }
}

//===----------------------------------------------------------------------===//
// Primitive and RawRepresentable Extensions
//===----------------------------------------------------------------------===//

extension Bool : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Bool.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Int : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Int8 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int8.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Int16 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int16.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Int32 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int32.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Int64 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int64.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension UInt : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension UInt8 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt8.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension UInt16 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt16.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension UInt32 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt32.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension UInt64 : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt64.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Float : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Float.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension Double : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Double.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension String : Codable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(String.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

public extension RawRepresentable where RawValue == Bool, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Bool, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Int, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Int8, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int8, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Int16, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int16, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Int32, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int32, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Int64, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int64, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == UInt, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == UInt8, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt8, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == UInt16, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt16, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == UInt32, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt32, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == UInt64, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt64, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Float, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Float, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == Double, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Double, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

public extension RawRepresentable where RawValue == String, Self : Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == String, Self : Decodable {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
      let decoded = try decoder.singleValueContainer().decode(RawValue.self)
      guard let value = Self(rawValue: decoded) else {
          throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"))
      }

      self = value
    }
}

//===----------------------------------------------------------------------===//
// Optional/Collection Type Conformances
//===----------------------------------------------------------------------===//

@_inlineable // FIXME(sil-serialize-all)
@_versioned // FIXME(sil-serialize-all)
internal func assertTypeIsEncodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
    guard T.self is Encodable.Type else {
        if T.self == Encodable.self || T.self == Codable.self {
            preconditionFailure("\(wrappingType) does not conform to Encodable because Encodable does not conform to itself. You must use a concrete type to encode or decode.")
        } else {
            preconditionFailure("\(wrappingType) does not conform to Encodable because \(T.self) does not conform to Encodable.")
        }
    }
}

@_inlineable // FIXME(sil-serialize-all)
@_versioned // FIXME(sil-serialize-all)
internal func assertTypeIsDecodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
    guard T.self is Decodable.Type else {
        if T.self == Decodable.self || T.self == Codable.self {
            preconditionFailure("\(wrappingType) does not conform to Decodable because Decodable does not conform to itself. You must use a concrete type to encode or decode.")
        } else {
            preconditionFailure("\(wrappingType) does not conform to Decodable because \(T.self) does not conform to Decodable.")
        }
    }
}

// Temporary resolution for SR-5206.
// 
// The following two extension on Encodable and Decodable are used below to provide static type information where we don't have any yet.
// The wrapped contents of the below generic types have to expose their Encodable/Decodable conformance via an existential cast/their metatype.
// Since those are dynamic types without static type guarantees, we cannot call generic methods taking those arguments, e.g.
// 
//   try container.encode((someElement as! Encodable))
// 
// One way around this is to get elements to encode into `superEncoder`s and decode from `superDecoder`s because those interfaces are available via the existentials/metatypes.
// However, this direct encoding/decoding never gives containers a chance to intercept and do something custom on types.
// 
// If we instead expose this custom private functionality of writing to/reading from containers directly, the containers do get this chance.

// FIXME: Remove when conditional conformance is available.
extension Encodable {
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal func __encode(to container: inout SingleValueEncodingContainer) throws { try container.encode(self) }
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal func __encode(to container: inout UnkeyedEncodingContainer)     throws { try container.encode(self) }
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal func __encode<Key>(to container: inout KeyedEncodingContainer<Key>, forKey key: Key) throws { try container.encode(self, forKey: key) }
}

// FIXME: Remove when conditional conformance is available.
extension Decodable {
    // Since we cannot call these __init, we'll give the parameter a '__'.
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init(__from container: SingleValueDecodingContainer)   throws { self = try container.decode(Self.self) }
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init(__from container: inout UnkeyedDecodingContainer) throws { self = try container.decode(Self.self) }
    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init<Key>(__from container: KeyedDecodingContainer<Key>, forKey key: Key) throws { self = try container.decode(Self.self, forKey: key) }
}

// FIXME: Uncomment when conditional conformance is available.
extension Optional : Encodable /* where Wrapped : Encodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        assertTypeIsEncodable(Wrapped.self, in: type(of: self))

        var container = encoder.singleValueContainer()
        switch self {
        case .none: try container.encodeNil()
        case .some(let wrapped): try (wrapped as! Encodable).__encode(to: &container)
        }
    }
}

extension Optional : Decodable /* where Wrapped : Decodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        // Initialize self here so we can get type(of: self).
        self = .none
        assertTypeIsDecodable(Wrapped.self, in: type(of: self))

        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            let metaType = (Wrapped.self as! Decodable.Type)
            let element = try metaType.init(__from: container)
            self = .some(element as! Wrapped)
        }
    }
}

// FIXME: Uncomment when conditional conformance is available.
extension Array : Encodable /* where Element : Encodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        assertTypeIsEncodable(Element.self, in: type(of: self))

        var container = encoder.unkeyedContainer()
        for element in self {
            try (element as! Encodable).__encode(to: &container)
        }
    }
}

extension Array : Decodable /* where Element : Decodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        // Initialize self here so we can get type(of: self).
        self.init()
        assertTypeIsDecodable(Element.self, in: type(of: self))

        let metaType = (Element.self as! Decodable.Type)
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try metaType.init(__from: &container)
            self.append(element as! Element)
        }
    }
}

extension Set : Encodable /* where Element : Encodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        assertTypeIsEncodable(Element.self, in: type(of: self))

        var container = encoder.unkeyedContainer()
        for element in self {
            try (element as! Encodable).__encode(to: &container)
        }
    }
}

extension Set : Decodable /* where Element : Decodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        // Initialize self here so we can get type(of: self).
        self.init()
        assertTypeIsDecodable(Element.self, in: type(of: self))

        let metaType = (Element.self as! Decodable.Type)
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try metaType.init(__from: &container)
            self.insert(element as! Element)
        }
    }
}

/// A wrapper for dictionary keys which are Strings or Ints.
@_versioned // FIXME(sil-serialize-all)
@_fixed_layout // FIXME(sil-serialize-all)
internal struct _DictionaryCodingKey : CodingKey {
    @_versioned // FIXME(sil-serialize-all)
    internal let stringValue: String
    @_versioned // FIXME(sil-serialize-all)
    internal let intValue: Int?

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    @_inlineable // FIXME(sil-serialize-all)
    @_versioned // FIXME(sil-serialize-all)
    internal init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension Dictionary : Encodable /* where Key : Encodable, Value : Encodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public func encode(to encoder: Encoder) throws {
        assertTypeIsEncodable(Key.self, in: type(of: self))
        assertTypeIsEncodable(Value.self, in: type(of: self))

        if Key.self == String.self {
            // Since the keys are already Strings, we can use them as keys directly.
            var container = encoder.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(stringValue: key as! String)!
                try (value as! Encodable).__encode(to: &container, forKey: codingKey)
            }
        } else if Key.self == Int.self {
            // Since the keys are already Ints, we can use them as keys directly.
            var container = encoder.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(intValue: key as! Int)!
                try (value as! Encodable).__encode(to: &container, forKey: codingKey)
            }
        } else {
            // Keys are Encodable but not Strings or Ints, so we cannot arbitrarily convert to keys.
            // We can encode as an array of alternating key-value pairs, though.
            var container = encoder.unkeyedContainer()
            for (key, value) in self {
                try (key as! Encodable).__encode(to: &container)
                try (value as! Encodable).__encode(to: &container)
            }
        }
    }
}

extension Dictionary : Decodable /* where Key : Decodable, Value : Decodable */ {
    @_inlineable // FIXME(sil-serialize-all)
    public init(from decoder: Decoder) throws {
        // Initialize self here so we can print type(of: self).
        self.init()
        assertTypeIsDecodable(Key.self, in: type(of: self))
        assertTypeIsDecodable(Value.self, in: type(of: self))

        if Key.self == String.self {
            // The keys are Strings, so we should be able to expect a keyed container.
            let container = try decoder.container(keyedBy: _DictionaryCodingKey.self)
            let valueMetaType = Value.self as! Decodable.Type
            for key in container.allKeys {
                let value = try valueMetaType.init(__from: container, forKey: key)
                self[key.stringValue as! Key] = (value as! Value)
            }
        } else if Key.self == Int.self {
            // The keys are Ints, so we should be able to expect a keyed container.
            let valueMetaType = Value.self as! Decodable.Type
            let container = try decoder.container(keyedBy: _DictionaryCodingKey.self)
            for key in container.allKeys {
                guard key.intValue != nil else {
                    // We provide stringValues for Int keys; if an encoder chooses not to use the actual intValues, we've encoded string keys.
                    // So on init, _DictionaryCodingKey tries to parse string keys as Ints. If that succeeds, then we would have had an intValue here.
                    // We don't, so this isn't a valid Int key.
                    var codingPath = decoder.codingPath
                    codingPath.append(key)
                    throw DecodingError.typeMismatch(Int.self,
                                                     DecodingError.Context(codingPath: codingPath,
                                                                           debugDescription: "Expected Int key but found String key instead."))
                }

                let value = try valueMetaType.init(__from: container, forKey: key)
                self[key.intValue! as! Key] = (value as! Value)
            }
        } else {
            // We should have encoded as an array of alternating key-value pairs.
            var container = try decoder.unkeyedContainer()

            // We're expecting to get pairs. If the container has a known count, it had better be even; no point in doing work if not.
            if let count = container.count {
                guard count % 2 == 0 else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                            debugDescription: "Expected collection of key-value pairs; encountered odd-length array instead."))
                }
            }

            let keyMetaType = (Key.self as! Decodable.Type)
            let valueMetaType = (Value.self as! Decodable.Type)
            while !container.isAtEnd {
                let key = try keyMetaType.init(__from: &container)

                guard !container.isAtEnd else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                                 debugDescription: "Unkeyed container reached end before value in key-value pair."))
                }

                let value = try valueMetaType.init(__from: &container)
                self[key as! Key] = (value as! Value)
            }
        }
    }
}

//===----------------------------------------------------------------------===//
// Convenience Default Implementations
//===----------------------------------------------------------------------===//

// Default implementation of encodeConditional(_:forKey:) in terms of encode(_:forKey:)
public extension KeyedEncodingContainerProtocol {
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeConditional<T : AnyObject & Encodable>(_ object: T, forKey key: Key) throws {
        try encode(object, forKey: key)
    }
}

// Default implementation of encodeIfPresent(_:forKey:) in terms of encode(_:forKey:)
public extension KeyedEncodingContainerProtocol {
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeIfPresent<T : Encodable>(_ value: T?, forKey key: Key) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
}

// Default implementation of decodeIfPresent(_:forKey:) in terms of decode(_:forKey:) and decodeNil(forKey:)
public extension KeyedDecodingContainerProtocol {
    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Bool.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Int.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Int8.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Int16.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Int32.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Int64.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(UInt.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(UInt8.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(UInt16.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(UInt32.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(UInt64.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Float.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(Double.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(String.self, forKey: key)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard try self.contains(key) && !self.decodeNil(forKey: key) else { return nil }
        return try self.decode(T.self, forKey: key)
    }
}

// Default implementation of encodeConditional(_:) in terms of encode(_:), and encode(contentsOf:) in terms of encode(_:) loop.
public extension UnkeyedEncodingContainer {
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encodeConditional<T : AnyObject & Encodable>(_ object: T) throws {
        try self.encode(object)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Bool {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int8 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int16 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int32 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int64 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt8 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt16 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt32 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt64 {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Float {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Double {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == String {
        for element in sequence {
            try self.encode(element)
        }
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func encode<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element : Encodable {
        for element in sequence {
            try self.encode(element)
        }
    }
}

// Default implementation of decodeIfPresent(_:) in terms of decode(_:) and decodeNil()
public extension UnkeyedDecodingContainer {
    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Bool.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Int.Type) throws -> Int? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Int8.Type) throws -> Int8? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int8.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Int16.Type) throws -> Int16? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int16.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Int32.Type) throws -> Int32? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int32.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Int64.Type) throws -> Int64? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int64.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: UInt.Type) throws -> UInt? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: UInt8.Type) throws -> UInt8? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt8.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: UInt16.Type) throws -> UInt16? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt16.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: UInt32.Type) throws -> UInt32? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt32.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: UInt64.Type) throws -> UInt64? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt64.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Float.Type) throws -> Float? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Float.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: Double.Type) throws -> Double? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Double.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(String.self)
    }

    @_inlineable // FIXME(sil-serialize-all)
    public mutating func decodeIfPresent<T : Decodable>(_ type: T.Type) throws -> T? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(T.self)
    }
}
