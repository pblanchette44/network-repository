//
//  Repository.swift
//  NetworkLayer
//
//  Created by Philippe Blanchette on 2025-08-08.
//

import os
import Foundation

public enum RepositoryError: Error {
    case networkError(Error?)
    case decodingError(Error)
}

public protocol Repository<Request, Response>: Sendable {
    associatedtype Request: Hashable & Sendable
    associatedtype Response: Sendable & Decodable
    
    func fetch(_ request: Request) async throws -> Data
    func decode(_ data: Data) async throws -> Response
}

typealias RepositoryResponse = Sendable & Decodable

extension URLRequest: Sendable {}

/// Repository Builder is used to init Repository objects
///
/// extend it to create custom builders
public class RepositoryBuilder<DTO: Decodable & Sendable> {
    
    /// returns a Repository which provides remote data fetching, logging and cancellation logic
    public static func fullOnBuilder() -> any Repository<URLRequest, DTO> {
        let base = RequestRepository<DTO>()
        let loggable = LoggingRepo(base: base, name: "RequestRepository<\(DTO.self)>")
        let cancellable = CancellableRemoteRepository(base: loggable)
        return cancellable
    }
    
    /// returns a repository with a basic in memory cache
    public static func cacheableBuilder(nameSpace: String) -> any Repository<URLRequest, DTO> {
        let base = RequestRepository<DTO>()
        let loggable = LoggingRepo(base: base, name: "RequestRepository<\(DTO.self)>")
        let cacheable = CacheableRepository(
            base: loggable,
            cache: MemoryCacheStore(),
            policy: .cacheFirst(ttl: 60, staleWhileRevalidate: 300),
            nameSpace: nameSpace
        )
        let cancellable = CancellableRemoteRepository(base: cacheable)
        return cancellable
    }
}

private actor RequestRepository<U: RepositoryResponse>: Repository {
    typealias Request = URLRequest
    typealias Response = U
    
    func fetch(_ request: Request) async throws -> Data {
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw RepositoryError.networkError(nil)
            }
            
            return data
        } catch {
            throw RepositoryError.networkError(error)
        }

        
    }
    
    func decode(_ data: Data) async throws -> U {
        do {
            return try JSONDecoder().decode(Self.Response.self, from: data)
        } catch {
            throw RepositoryError.decodingError(error)
        }
    }
}

private actor CancellableRemoteRepository<Base: Repository>: Repository {
    
    typealias Request = Base.Request
    typealias Response = Base.Response
    
    private let base: Base
    private var inFlight: [Request: Task<Data, Error>] = [:]
    
    init(base: Base) {
        self.base = base
    }
    
    func fetch(_ request: Request) async throws -> Data {
        // cancel previous
        inFlight[request]?.cancel()

        let t = Task { [base] in try await base.fetch(request) }
        inFlight[request] = t
        defer { inFlight[request] = nil }
        return try await t.value
    }
    
    func decode(_ data: Data) async throws -> Base.Response {
        return try await base.decode(data)
    }
    
    func cancel(_ request: Request) {
        inFlight[request]?.cancel()
        inFlight[request] = nil
    }
}

private actor LoggingRepo<Base: Repository>: Repository {
    typealias Request = Base.Request
    typealias Response = Base.Response
    
    private let base: Base
    
    private let logger: Logger
    private let name: String
    
    private var prefix: String {
        "\(name)::"
    }
    
    init(base: Base, name: String) {
        self.base = base
        
        self.logger = Logger(subsystem: "NetworkLayer", category: "Repository::\(name)")
        self.name = name
    }
    
    func fetch(_ request: Base.Request) async throws -> Data {

        self.logger.info("\(self.prefix)starting the fetching of the data")
        do {
            let out = try await base.fetch(request)
            self.logger.info("\(self.prefix)done fetching the data")
            return out
        } catch {
            self.logger.error("\(self.prefix)error while fetching the data in repo: \(error)")
            throw error
        }
    }
    
    func decode(_ data: Data) async throws -> Base.Response {
        try await base.decode(data)
    }
}
