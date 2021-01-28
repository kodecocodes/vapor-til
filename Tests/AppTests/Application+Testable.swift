/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

@testable import XCTVapor
@testable import App

extension Application {
  static func testable() throws -> Application {
    let app = Application(.testing)
    try configure(app)
    
    try app.autoRevert().wait()
    try app.autoMigrate().wait()
    
    return app
  }
}

extension XCTApplicationTester {
  public func login(
    user: User
  ) throws -> Token {
    var request = XCTHTTPRequest(
      method: .POST,
      url: .init(path: "/api/users/login"),
      headers: [:],
      body: ByteBufferAllocator().buffer(capacity: 0)
    )
    request.headers.basicAuthorization = .init(username: user.username, password: "password")
    let response = try performTest(request: request)
    return try response.content.decode(Token.self)
  }

  @discardableResult
  public func test(
    _ method: HTTPMethod,
    _ path: String,
    headers: HTTPHeaders = [:],
    body: ByteBuffer? = nil,
    loggedInRequest: Bool = false,
    loggedInUser: User? = nil,
    file: StaticString = #file,
    line: UInt = #line,
    beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
    afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
  ) throws -> XCTApplicationTester {
    var request = XCTHTTPRequest(
      method: method,
      url: .init(path: path),
      headers: headers,
      body: body ?? ByteBufferAllocator().buffer(capacity: 0)
    )

    if (loggedInRequest || loggedInUser != nil) {
      let userToLogin: User
      // 2
      if let user = loggedInUser {
        userToLogin = user
      } else {
        userToLogin = User(name: "Admin", username: "admin", password: "password")
      }

      let token = try login(user: userToLogin)
      request.headers.bearerAuthorization = .init(token: token.value)
    }

    try beforeRequest(&request)

    do {
      let response = try performTest(request: request)
      try afterResponse(response)
    } catch {
      XCTFail("\(error)", file: (file), line: line)
      throw error
    }
    return self
  }
}
