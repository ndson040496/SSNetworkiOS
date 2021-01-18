//
//  SSNetworkTests.swift
//  SSNetworkTests
//
//  Created by Son Nguyen on 1/18/21.
//

import XCTest
@testable import SSNetwork

class SSNetworkRequestTests: XCTestCase {

    func testEquality() throws {
        let request1 = SSNetworkRequest<[String: String], MockError>(baseUrl: "https://abc.com", path: ["def", "ghi"], method: .GET)
        request1.addQuery(key: "a", value: 123)
        request1.setBody(["abc": 1])
        let request2 = SSNetworkRequest<[String: String], MockError>(baseUrl: "https://abc.com", path: ["def", "ghi"], method: .GET)
        request2.addQuery(key: "a", value: 123)
        request2.setBody(["abc": 1])

        XCTAssertEqual(request1, request2)
    }
}

fileprivate class MockError: SSNetworkError, Error {
    required init(data: Data, response: URLResponse) {
        
    }
}
