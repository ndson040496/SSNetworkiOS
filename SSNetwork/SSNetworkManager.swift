//
//  SSNetworkManager.swift
//  Okee
//
//  Created by Son Nguyen on 11/23/20.
//

import Foundation
import Combine

public class SSNetworkManager {
    public static let shared = SSNetworkManager()
    
    private var cache: [String: CachedData] = [:]
    private var subscribers: [String: AnyCancellable] = [:]
    
    private var pendingRequests: [Any]  = []
    private var pendingSubjects: [String: Any] = [:]
    
    public func makeServiceCall<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>,
                                                                         onMainThread: Bool = true) -> AnyPublisher<D, Error> {
        guard let urlRequest = request.urlRequest else {
            return Empty().setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        if let cachedPublisher = cachedPublisher(forRequest: request) {
            return finalizePublisher(publisher: cachedPublisher, onMainThread: onMainThread)
        }
        
        if let publisher = existingPublisher(forRequest: request) {
            return finalizePublisher(publisher: publisher, onMainThread: onMainThread)
        }
        
        let publisher = URLSession.shared.dataTaskPublisher(for: urlRequest).tryMap {[weak self] (data, response) -> Data in
            defer {
                self?.removePendingRequest(forRequest: request)
            }
            
            let subject = self?.pendingSubjects[request.uuid] as? PassthroughSubject<Data, Error>
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let error = E(data: data, response: response)
                subject?.send(completion: .failure(error))
                throw error
            }
            self?.cacheDataIfPossible(forRequest: request, data: data)
            subject?.send(data)
            subject?.send(completion: .finished)
            
            return data
        }
        .eraseToAnyPublisher()
        
        addPendingRequest(request)
        return finalizePublisher(publisher: publisher, onMainThread: onMainThread)
    }
    
    private func finalizePublisher<D: Decodable>(publisher: AnyPublisher<Data, Error>,onMainThread: Bool) -> AnyPublisher<D, Error> {
        let finalPublisher = publisher
            .decode(type: D.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
        if onMainThread {
            return finalPublisher
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
            
        } else {
            return finalPublisher
                .eraseToAnyPublisher()
        }
    }
    
    public func registerSubscriber<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>,
                                                                            subscriber: AnyCancellable) {
        self.subscribers[request.uuid] = subscriber
    }
    
    public func unregisterSubscriber<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>) {
        self.subscribers.removeValue(forKey: request.uuid)
    }
    
    private func cacheDataIfPossible<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>,
                                                                              data: Data) {
        if request.shouldCacheNow,
           let url = request.urlRequest?.url?.absoluteString {
            cache[url] = CachedData(data: data, expirationTime: request.cacheExpirationTime)
        }
    }
    
    private func cachedPublisher<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>) -> AnyPublisher<Data, Error>? {
        if request.ignoreCache {
            return nil
        }
        if let url = request.urlRequest?.url?.absoluteString,
           let cachedData = cache[url],
           cachedData.isValid {
            return Just(cachedData.data)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return nil
        }
    }
    
    private func addPendingRequest<D: Decodable, E: SSNetworkError & Error>(_ request: SSNetworkRequest<D, E>) {
        pendingRequests.append(request)
        pendingSubjects[request.uuid] = PassthroughSubject<Data, Error>()
    }
    
    private func removePendingRequest<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>) {
        pendingRequests.removeAll(where: { (pendindRequest) -> Bool in
            (pendindRequest as? SSNetworkRequest<D, E>) == request
        })
        pendingSubjects.removeValue(forKey: request.uuid)
    }
    
    private func existingPublisher<D: Decodable, E: SSNetworkError & Error>(forRequest request: SSNetworkRequest<D, E>) -> AnyPublisher<Data, Error>? {
        var pendingUuid: String = ""
        if pendingRequests.contains(where: { (pendingRequest) -> Bool in
            if let pendingRequest = pendingRequest as? SSNetworkRequest<D, E>, pendingRequest == request {
                pendingUuid = pendingRequest.uuid
                return true
            }
            return false
        }), let subject = pendingSubjects[pendingUuid] as? PassthroughSubject<Data, Error> {
            return subject
                .eraseToAnyPublisher()
        } else {
            return nil
        }
    }
}

fileprivate struct CachedData {
    let data: Data
    let expirationTime: Date
    
    var isValid: Bool {
        return Date().compare(expirationTime) != .orderedDescending
    }
}
