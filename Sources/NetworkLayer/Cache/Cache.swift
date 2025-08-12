//
//  Cache.swift
//  NetworkLayer
//
//  Created by Philippe Blanchette on 2025-08-12.
//
import Foundation

public enum CacheBehavior: Sendable {
    case networkOnly
    case cacheOnly(ttl: TimeInterval)
    case cacheFirst(ttl: TimeInterval, staleWhileRevalidate: TimeInterval)
    case networkFirst(ttl: TimeInterval)
}

public struct CacheEntry: Sendable {
    public let data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    public var isFresh: Bool {
        fatalError("unimplemented")
    }
    
    public var isStaleButServable: Bool {
        fatalError("unimplemented")
    }
}

public protocol CacheStore<Key>: Sendable {
    associatedtype Key: Hashable & Sendable
    func get(_ key: Key, nameSpace: String) async -> CacheEntry?
    func set(_ entry: CacheEntry, for key: Key, nameSpace: String) async
    func remove(_ key: Key, nameSpace: String) async
    func clear(nameSpace: String) async
}

/// a very simple in memory cache with a dictionnary and not memory limit
public actor MemoryCacheStore<Key: Hashable & Sendable>: CacheStore {
    
    private struct Item {
        var entry: CacheEntry
    }
    
    private var storage: [Key: Item] = [:]
    
    public func get(_ key: Key, nameSpace: String) async -> CacheEntry? {
        
        guard var item = storage[key] else {
            return nil
        }
        
        return item.entry
    }
    
    public func set(_ entry: CacheEntry, for key: Key, nameSpace: String) async {
        self.storage[key] = Item(entry: entry)
    }
    
    public func remove(_ key: Key, nameSpace: String) async {
        self.storage[key] = nil
    }
    
    public func clear(nameSpace: String) async {
        self.storage.removeAll()
    }
}

enum CacheError: Error {
    case cacheMissError
}

actor CacheableRepository<Base: Repository>: Repository {
    typealias Request = Base.Request
    typealias Response = Base.Response
    
    private let base: Base
    private let cache: any CacheStore<Request>
    private let policy: CacheBehavior
    private let nameSpace: String
    
    init(base: Base, cache: any CacheStore<Request>, policy: CacheBehavior, nameSpace: String) {
        self.base = base
        self.cache = cache
        self.policy = policy
        self.nameSpace = nameSpace
    }
    
    func fetch(_ request: Base.Request) async throws -> Data {
        switch policy {
        case .networkOnly:
            return try await fetchAndFillCache(request: request)
        case .cacheOnly(let ttl):
            if let entity = await cache.get(request, nameSpace: self.nameSpace), entity.isFresh {
                /// cache hit
                return entity.data
            } else {
                throw CacheError.cacheMissError
            }
        case .cacheFirst(let ttl, let staleWhileRevalidate):
            if let entity = await cache.get(request, nameSpace: self.nameSpace){
                if entity.isFresh {
                    /// cache hit
                    return entity.data
                }
                
                if entity.isStaleButServable {
                    /// we refresh the data but we give the stale current version
                    /// This is kind of what we we could do with an AsyncSequence
                    Task {
                        try await self.fetchAndFillCache(request: request)
                    }
                    return entity.data
                }
            }
            
            return try await fetchAndFillCache(request: request)
        case .networkFirst(let ttl):
            do {
                return try await fetchAndFillCache(request: request)
            } catch {
                if let e = await cache.get(request, nameSpace: self.nameSpace), !e.isFresh {
                    return e.data
                } else {
                    throw error
                }
            }
        }
    }
    
    func decode(_ data: Data) async throws -> Base.Response {
        try await base.decode(data)
    }
    
    private func fetchAndFillCache(request: Request) async throws -> Data {
        let data = try await base.fetch(request)
        await cache.set(CacheEntry(data: data), for: request, nameSpace: self.nameSpace)
        return data
    }
}
