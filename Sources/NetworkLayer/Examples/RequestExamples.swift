//
//  RequestExamples.swift
//  NetworkLayer Examples
//
//  Example use cases for NetworkLayer request initialization
//

import Foundation
import NetworkLayer

// MARK: - Response Models

struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

struct SearchResult: Codable {
    let results: [User]
    let totalCount: Int
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Request Specifications

// 1. Basic GET Request
struct GetUsersRequest: RequestSpecs {
    let method: HTTPMethod = .get
    let path: String = "/users"
}

// 2. GET Request with Query Parameters
struct SearchUsersRequest: RequestSpecs {
    let method: HTTPMethod = .get
    let path: String = "/users/search"
    let query: [String: String]?
    
    init(searchTerm: String, limit: Int = 20, offset: Int = 0) {
        self.query = [
            "q": searchTerm,
            "limit": String(limit),
            "offset": String(offset)
        ]
    }
}

// 3. POST Request with Custom Headers
struct CreateUserRequest: RequestSpecs {
    let method: HTTPMethod = .post
    let path: String = "/users"
    let headers: [String: String]?
    
    init(contentType: String = "application/json") {
        self.headers = [
            "Content-Type": contentType,
            "X-Request-Source": "iOS-App"
        ]
    }
}

// 4. PUT Request for Updates
struct UpdateUserRequest: RequestSpecs {
    let method: HTTPMethod = .put
    let path: String
    let headers: [String: String]?
    
    init(userId: Int) {
        self.path = "/users/\(userId)"
        self.headers = ["Content-Type": "application/json"]
    }
}

// 5. DELETE Request
struct DeleteUserRequest: RequestSpecs {
    let method: HTTPMethod = .delete
    let path: String
    
    init(userId: Int) {
        self.path = "/users/\(userId)"
    }
}

// 6. Request with Authentication
struct AuthenticatedRequest: RequestSpecs {
    let method: HTTPMethod = .get
    let path: String = "/profile"
    let headers: [String: String]?
    
    init(authToken: String) {
        self.headers = [
            "Authorization": "Bearer \(authToken)"
        ]
    }
}

// MARK: - Usage Examples

class NetworkExamples {
    
    private let requestBuilder: URLRequestBuilder
    
    init() throws {
        // Initialize with base URL and default headers
        self.requestBuilder = try URLRequestBuilder(
            baseUrl: URL(string: "https://api.example.com/v1"),
            defaultHeader: [
                "User-Agent": "MyiOSApp/1.0",
                "Accept": "application/json"
            ]
        )
    }
    
    // MARK: - Example 1: Simple GET Request
    func getUsersList() async throws -> [User] {
        let specs = GetUsersRequest()
        let urlRequest = try requestBuilder.buildRequest(specs)
        
        let repository = RepositoryBuilder<[User]>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 2: GET with Query Parameters
    func searchUsers(term: String, limit: Int = 10) async throws -> SearchResult {
        let specs = SearchUsersRequest(searchTerm: term, limit: limit)
        let urlRequest = try requestBuilder.buildRequest(specs)
        
        let repository = RepositoryBuilder<SearchResult>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 3: POST Request (Create)
    func createUser(userData: Data) async throws -> User {
        let specs = CreateUserRequest()
        var urlRequest = try requestBuilder.buildRequest(specs)
        urlRequest.httpBody = userData
        
        let repository = RepositoryBuilder<User>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 4: PUT Request (Update)
    func updateUser(userId: Int, userData: Data) async throws -> User {
        let specs = UpdateUserRequest(userId: userId)
        var urlRequest = try requestBuilder.buildRequest(specs)
        urlRequest.httpBody = userData
        
        let repository = RepositoryBuilder<User>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 5: DELETE Request
    func deleteUser(userId: Int) async throws {
        let specs = DeleteUserRequest(userId: userId)
        let urlRequest = try requestBuilder.buildRequest(specs)
        
        let repository = RepositoryBuilder<EmptyResponse>.fullOnBuilder()
        _ = try await repository.fetch(urlRequest)
    }
    
    // MARK: - Example 6: Authenticated Request
    func getUserProfile(authToken: String) async throws -> User {
        let specs = AuthenticatedRequest(authToken: authToken)
        let urlRequest = try requestBuilder.buildRequest(specs)
        
        let repository = RepositoryBuilder<User>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 7: Complex Request with Multiple Parameters
    func advancedSearch(
        query: String,
        filters: [String: String],
        sortBy: String = "name",
        page: Int = 1
    ) async throws -> SearchResult {
        
        struct AdvancedSearchRequest: RequestSpecs {
            let method: HTTPMethod = .get
            let path: String = "/search/advanced"
            let query: [String: String]?
            
            init(searchQuery: String, filters: [String: String], sortBy: String, page: Int) {
                var queryParams = [
                    "q": searchQuery,
                    "sort": sortBy,
                    "page": String(page)
                ]
                
                // Add filters to query parameters
                for (key, value) in filters {
                    queryParams["filter_\(key)"] = value
                }
                
                self.query = queryParams
            }
        }
        
        let specs = AdvancedSearchRequest(
            searchQuery: query,
            filters: filters,
            sortBy: sortBy,
            page: page
        )
        let urlRequest = try requestBuilder.buildRequest(specs)
        
        let repository = RepositoryBuilder<SearchResult>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
    
    // MARK: - Example 8: File Upload Request
    func uploadFile(fileData: Data, fileName: String) async throws -> UploadResponse {
        
        struct FileUploadRequest: RequestSpecs {
            let method: HTTPMethod = .post
            let path: String = "/upload"
            let headers: [String: String]?
            
            init() {
                self.headers = [
                    "Content-Type": "multipart/form-data"
                ]
            }
        }
        
        let specs = FileUploadRequest()
        var urlRequest = try requestBuilder.buildRequest(specs)
        urlRequest.httpBody = fileData
        
        let repository = RepositoryBuilder<UploadResponse>.fullOnBuilder()
        let data = try await repository.fetch(urlRequest)
        return try await repository.decode(data)
    }
}

// MARK: - Supporting Models

struct EmptyResponse: Codable {}

struct UploadResponse: Codable {
    let fileId: String
    let fileName: String
    let url: String
}

// MARK: - Usage Example in SwiftUI View or ViewController

class ExampleUsage {
    private let networkExamples: NetworkExamples
    
    init() {
        do {
            self.networkExamples = try NetworkExamples()
        } catch {
            fatalError("Failed to initialize network examples: \(error)")
        }
    }
    
    func performNetworkOperations() async {
        do {
            // Get all users
            let users = try await networkExamples.getUsersList()
            print("Fetched \(users.count) users")
            
            // Search for users
            let searchResults = try await networkExamples.searchUsers(term: "john")
            print("Found \(searchResults.totalCount) users matching 'john'")
            
            // Create a new user
            let userData = """
            {
                "name": "John Doe",
                "email": "john@example.com"
            }
            """.data(using: .utf8)!
            
            let newUser = try await networkExamples.createUser(userData: userData)
            print("Created user: \(newUser.name)")
            
            // Update the user
            let updatedData = """
            {
                "name": "John Smith",
                "email": "johnsmith@example.com"
            }
            """.data(using: .utf8)!
            
            let updatedUser = try await networkExamples.updateUser(
                userId: newUser.id,
                userData: updatedData
            )
            print("Updated user: \(updatedUser.name)")
            
            // Delete the user
            try await networkExamples.deleteUser(userId: newUser.id)
            print("User deleted successfully")
            
        } catch {
            print("Network operation failed: \(error)")
        }
    }
}
