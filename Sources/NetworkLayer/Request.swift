//
//  Request.swift
//  NetworkLayer
//
//  Created by Philippe Blanchette on 2025-08-11.
//
import Foundation

public enum HTTPMethod: String, Sendable {
    case get  = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public enum URLRequestError: Error {
    case invalidURL
    case invalidURLFormatting
    case invalidBaseURLComponents
    case invalidBaseURL
}

public protocol RequestSpecs: Sendable {
    var method: HTTPMethod { get }
    var path: String { get }
    var query: [String: String]? { get }
    var headers: [String: String]? { get }
}

public extension RequestSpecs {
    
    var query: [String: String] {
        [:]
    }
    
    var headers: [String: String]? {
        nil
    }
}

public struct URLRequestBuilder: Sendable {
    public let baseUrl: URL
    public let defaultHeader: [String: String]
    
    public init(baseUrl: URL?, defaultHeader: [String : String]) throws {
        
        guard let url = baseUrl else {
            throw URLRequestError.invalidURL
        }
        
        self.baseUrl = url
        self.defaultHeader = defaultHeader
    }
    
    public func buildRequest(_ specs: some RequestSpecs) throws -> URLRequest {
        
        guard var baseComponent = URLComponents(url: self.baseUrl, resolvingAgainstBaseURL: false) else {
            throw URLRequestError.invalidBaseURLComponents
        }
        
        // components
        baseComponent.path = baseUrl.path.appending({
            specs.path.hasPrefix("/") ? specs.path: "/\(specs.path)"
        }())

        // query formating
        baseComponent.queryItems = specs.query?.map({ URLQueryItem(name: $0.key, value: $0.value) })

        guard let url = baseComponent.url else {
            throw URLRequestError.invalidURLFormatting
        }

        // request building
        var request = URLRequest(url: url)
        request.httpMethod = specs.method.rawValue
        
        // headers merging
        if let headers = specs.headers {
            request.allHTTPHeaderFields = headers.merging(defaultHeader) {
                (new, old) in
                
                return new
            }
        } else {
            request.allHTTPHeaderFields = defaultHeader
        }
        
        return request
    }
}


struct DummySpecs: RequestSpecs {

    var method: HTTPMethod = .get
    var path: String = "/dummy"
    var query: [String : String]? = nil
    
    var request: URLRequest? {
        try? URLRequestBuilder(
            baseUrl: .init(string: "https://api.example.com"),
            defaultHeader: ["randomHeader":"lol"]
        )
            .buildRequest(DummySpecs())
    }
}
