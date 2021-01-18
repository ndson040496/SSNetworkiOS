//
//  SSNetworkError.swift
//  Okee
//
//  Created by Son Nguyen on 11/25/20.
//

import Foundation

public protocol SSNetworkError {
    init(data: Data, response: URLResponse)
}

public extension Error {
    var isNoInternetError: Bool {
        _code == NSURLErrorNotConnectedToInternet
    }
}
