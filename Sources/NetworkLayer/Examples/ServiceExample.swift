//
//  ServiceExample.swift
//  NetworkLayer
//
//  Created by Philippe Blanchette on 2025-08-11.
//

import Foundation

struct DummyModel: Sendable & Codable {
    init(_ dto: DummyDTO) {}
}

protocol DummyService {
    func fetchDummyData() async throws -> DummyModel
}

protocol DummyRepository {
    func fetchDummyData(request: URLRequest) async throws -> DummyModel
}

struct DummyDTO: Sendable, Codable {
    var description: String
}

class DummyServiceImpl: DummyService {

    private let dummyRepo: any DummyRepository
    
    init(_ repo: any DummyRepository) {
        self.dummyRepo = repo
    }
    
    struct DummyDataSpec: RequestSpecs {
        var query: [String : String]? = nil
        
        var method: HTTPMethod {
            .get
        }
        
        var path: String {
            ""
        }
    }
    
    func fetchDummyData() async throws -> DummyModel {
        
        let request = try URLRequestBuilder(baseUrl: .init(string: ""), defaultHeader: [:]).buildRequest(DummyDataSpec())
        
        return try await self.dummyRepo.fetchDummyData(request: request)

    }
}

final class DummyRepositoryImpl: DummyRepository {
    
    private let base: any Repository<URLRequest, DummyDTO>
   
    init() {
        self.base = RepositoryBuilder<DummyDTO>.fullOnBuilder()
    }
    
    func fetchDummyData(request: URLRequest) async throws -> DummyModel {
        let data = try await base.fetch(request)
        let dto = try await base.decode(data)
        
        return .init(dto)
    }
}

class DummyProvider {
    let repo: any DummyRepository
    
    init() {
        self.repo = DummyRepositoryImpl()
    }
    
    var service: DummyService {
        DummyServiceImpl(repo)
    }
}
