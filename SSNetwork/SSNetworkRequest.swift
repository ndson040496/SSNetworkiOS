//
//  SSNetworkRequest.swift
//  Okee Dev
//
//  Created by Son Nguyen on 11/21/20.
//

import Foundation

public class SSNetworkRequest<D, E>: Equatable where D:Decodable, E: SSNetworkError & Error {
    
    public enum HttpMethod: String {
        case GET
        case PUT
        case POST
        case DELETE
    }
    
    private var url: String
    private let method: HttpMethod
    private var headers: [String: Any]?
    private var params: [String: Any]?
    private var query: [String: Any]?
    private var body: Data?
    
    let uuid: String
    private(set) var ignoreCache: Bool = false
    
    internal private(set) var cacheExpirationTime: Date = Date()
    
    public init(baseUrl: String, path: [String], method: SSNetworkRequest.HttpMethod) {
        let path = path.joined(separator: "/")
        self.url = "\(baseUrl)/\(SSNetworkRequest.safeString(path))"
        self.method = method
        
        uuid = UUID().uuidString
    }
    
    public static func == (lhs: SSNetworkRequest<D, E>, rhs: SSNetworkRequest<D, E>) -> Bool {
        if lhs.uuid == rhs.uuid {
            return true
        }
        
        if lhs.method != rhs.method {
            return false
        }
        
        if lhs.urlRequest?.url?.absoluteString != rhs.urlRequest?.url?.absoluteString {
            return false
        }
        
        if lhs.body != rhs.body {
            return false
        }
        
        if lhs.headers?.count != rhs.headers?.count {
            return false
        }
        
        var result = true
        lhs.headers?.forEach({ (key, value) in
            if String(describing: rhs.headers?[key]) != String(describing: lhs.headers?[key]) {
                result = false
                return
            }
        })
        
        return result
    }
    
    var shouldCacheNow: Bool {
        return Date().compare(cacheExpirationTime) == .orderedAscending && method == .GET
    }
    
    public func setCacheDuration(_ duration: TimeInterval) {
        self.cacheExpirationTime = Date().addingTimeInterval(duration)
    }
    
    public func setIgnoreCache(_ value: Bool) {
        self.ignoreCache = value
    }
    
    public func setHeaders(_ headers: [String: Any]) {
        self.headers = headers
    }
    
    public func addHeader(key: String, value: Any) {
        if self.headers?.isEmpty ?? true {
            self.headers = [:]
        }
        self.headers?[key] = value
    }
    
    public func setParams(_ params: [String: Any]) {
        self.params = params
    }
    
    public func addParam(name: String, value: Any) {
        if self.params?.isEmpty ?? true {
            self.params = [:]
        }
        self.params?[name] = value
    }
    
    public func setQuery(_ query: [String: Any]) {
        self.query = query
    }
    
    public func setQuery<E: Encodable>(_ query: E) {
        do {
            let data = try JSONEncoder().encode(query)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
            setQuery(dictionary)
        } catch {}
        
    }
    
    public func addQuery(key: String, value: Any) {
        if self.query?.isEmpty ?? true {
            self.query = [:]
        }
        self.query?[key] = value
    }
    
    public func setBody(_ body: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            self.body = data
        } catch {
            // nothing to do
        }
    }
    
    public func setBody<E: Encodable>(_ body: E) {
        do {
            let data = try JSONEncoder().encode(body)
            self.body = data
        } catch {
            // nothing to do
        }
    }
    
    public func setApiKey(_ key: String, name: String = "x-api-key") {
        self.addHeader(key: name, value: key)
    }
    
    public func setContentType(_ contentType: String = "application/json") {
        self.addHeader(key: "Content-Type", value: contentType)
    }
    
    public func setAuthToken(_ token: String, prefix: String = "Bearer") {
        self.addHeader(key: "Authorization", value: "\(prefix) \(token)")
    }
    
    private var pUrlRequest: URLRequest?
    internal var urlRequest: URLRequest? {
        if let request = pUrlRequest {
            return request
        }
        
        var urlString = url
        
        if let params = self.params, !params.isEmpty {
            params.keys.sorted().forEach { (key) in
                urlString += "/"
                urlString += "\(SSNetworkRequest.safeString(key))/\(SSNetworkRequest.safeString("\(params[key] ?? "")"))"
            }
        }
        
        if let query = self.query, !query.isEmpty {
            urlString += "?"
            query.keys.sorted().forEach({ (key) in
                urlString += "\(SSNetworkRequest.safeString(key))=\(SSNetworkRequest.safeString("\(query[key] ?? "")"))&"
            })
        }
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var urlRequest = URLRequest(url: url)
        
        self.headers?.forEach({ (key, value) in
            urlRequest.addValue("\(value)", forHTTPHeaderField: key)
        })
        
        urlRequest.httpBody = self.body
        urlRequest.httpMethod = self.method.rawValue
        
        pUrlRequest = urlRequest
        return urlRequest
    }
    
    private static func safeString(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? string
    }
}
