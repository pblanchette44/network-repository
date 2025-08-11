import XCTest
@testable import NetworkLayer

final class URLRequestBuilderTests: XCTestCase {
    
    private let baseURL = URL(string: "https://api.example.com")!
    private let defaultHeaders = ["Authorization": "Bearer token", "Content-Type": "application/json"]
    
    func testInitWithValidURL() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        XCTAssertEqual(builder.baseUrl, baseURL)
        XCTAssertEqual(builder.defaultHeader, defaultHeaders)
    }
    
    func testInitWithNilURL() {
        XCTAssertThrowsError(try URLRequestBuilder(baseUrl: nil, defaultHeader: defaultHeaders)) { error in
            XCTAssertEqual(error as? URLRequestError, URLRequestError.invalidURL)
        }
    }
    
    func testBuildRequestWithBasicSpecs() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(method: .get, path: "/users")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.allHTTPHeaderFields, defaultHeaders)
    }
    
    func testBuildRequestWithPathPrefix() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(method: .post, path: "/api/users")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/users")
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func testBuildRequestWithPathWithoutPrefix() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(method: .put, path: "users/123")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users/123")
        XCTAssertEqual(request.httpMethod, "PUT")
    }
    
    func testBuildRequestWithQuery() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(
            method: .get,
            path: "/search",
            query: ["q": "swift", "limit": "10"]
        )
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("q=swift") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("limit=10") == true)
        XCTAssertTrue(request.url?.absoluteString.hasPrefix("https://api.example.com/search?") == true)
    }
    
    func testBuildRequestWithCustomHeaders() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let customHeaders = ["X-Custom": "value", "User-Agent": "MyApp"]
        let specs = TestRequestSpecs(method: .delete, path: "/users/123", headers: customHeaders)
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.httpMethod, "DELETE")
        
        let expectedHeaders = defaultHeaders.merging(customHeaders) { _, new in new }
        XCTAssertEqual(request.allHTTPHeaderFields, expectedHeaders)
    }
    
    func testBuildRequestWithHeaderMerging() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let customHeaders = ["Authorization": "Bearer newtoken", "X-Custom": "value"]
        let specs = TestRequestSpecs(method: .post, path: "/login", headers: customHeaders)
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer newtoken")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["X-Custom"], "value")
    }
    
    func testBuildRequestWithNoCustomHeaders() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(method: .get, path: "/status")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.allHTTPHeaderFields, defaultHeaders)
    }
    
    func testBuildRequestWithComplexQuery() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(
            method: .get,
            path: "/users",
            query: [
                "name": "John Doe",
                "age": "30",
                "city": "New York"
            ]
        )
        
        let request = try builder.buildRequest(specs)
        
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("name=John%20Doe"))
        XCTAssertTrue(urlString.contains("age=30"))
        XCTAssertTrue(urlString.contains("city=New%20York"))
    }
    
    func testBuildRequestWithBaseURLPath() throws {
        let baseURLWithPath = URL(string: "https://api.example.com/v1")!
        let builder = try URLRequestBuilder(baseUrl: baseURLWithPath, defaultHeader: defaultHeaders)
        let specs = TestRequestSpecs(method: .get, path: "/users")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
    }
    
    func testAllHTTPMethods() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: defaultHeaders)
        
        let methods: [HTTPMethod] = [.get, .post, .put, .delete]
        
        for method in methods {
            let specs = TestRequestSpecs(method: method, path: "/test")
            let request = try builder.buildRequest(specs)
            
            XCTAssertEqual(request.httpMethod, method.rawValue)
        }
    }
    
    func testEmptyDefaultHeaders() throws {
        let builder = try URLRequestBuilder(baseUrl: baseURL, defaultHeader: [:])
        let specs = TestRequestSpecs(method: .get, path: "/test")
        
        let request = try builder.buildRequest(specs)
        
        XCTAssertEqual(request.allHTTPHeaderFields, [:])
    }
    
}

private struct TestRequestSpecs: RequestSpecs {
    let method: HTTPMethod
    let path: String
    let query: [String: String]?
    let headers: [String: String]?
    
    init(method: HTTPMethod, path: String, query: [String: String]? = nil, headers: [String: String]? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
    }
}
