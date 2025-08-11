import Foundation

///
/// A default remote repository protocol that can be implemented to perform a basic url request
///
/// Default implementation will provide basic error handling and the usual requestBuilding -> fetchData -> decoding data
protocol RemoteRepository {
    
    func request() throws -> URLRequest
    var encodedParameters: [URLQueryItem] { get }
    var url: String { get }
    
    func fetchData() async throws -> Data
    
    associatedtype DTO: Decodable
    func decode(data: Data) throws -> DTO
}

enum RepositoryError: Error {
    case requestBuildingError
    case parsingError
    case networkError
    case decodingError
    case transformingError
}

/// The default implementation of the remoteRepository
@available(macOS 12.0, *)
extension RemoteRepository {
    
    func request() throws -> URLRequest {
        
        var urlComponents = URLComponents(string: self.url)
        urlComponents?.queryItems = encodedParameters
        
        guard let url = urlComponents?.url else {
            throw RepositoryError.requestBuildingError
        }
        
        return URLRequest(url: url)
    }
    
    func fetchData() async throws -> Data {
        do {
            let request = try self.request()
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw RepositoryError.networkError
            }
            
            return data
        } catch {
            throw RepositoryError.networkError
        }
    }
    
    func decode(data: Data) throws -> Self.DTO {
        do {
            return try JSONDecoder().decode(Self.DTO.self, from: data)
        } catch {
            throw RepositoryError.decodingError
        }
    }
}
