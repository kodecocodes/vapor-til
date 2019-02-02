/// Copyright (c) 2019 Razeware LLC
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

import Vapor
@testable import App
import Authentication
import FluentPostgreSQL

extension Application {
  static func testable(envArgs: [String]? = nil) throws -> Application {
    var config = Config.default()
    var services = Services.default()
    var env = Environment.testing

    if let environmentArgs = envArgs {
      env.arguments = environmentArgs
    }

    try App.configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)

    try App.boot(app)
    return app
  }

  static func reset() throws {
    let revertEnvironment = ["vapor", "revert", "--all", "-y"]
    try Application.testable(envArgs: revertEnvironment).asyncRun().wait()
    let migrateEnvironment = ["vapor", "migrate", "-y"]
    try Application.testable(envArgs: migrateEnvironment).asyncRun().wait()
  }

  func sendRequest<T>(to path: String,
                      method: HTTPMethod,
                      headers: HTTPHeaders = .init(),
                      body: T? = nil,
                      loggedInRequest: Bool = false,
                      loggedInUser: User? = nil) throws -> Response where T: Content {
    var headers = headers
    if (loggedInRequest || loggedInUser != nil) {
      let username: String
      if let user = loggedInUser {
        username = user.username
      } else {
        username = "admin"
      }
      let credentials = BasicAuthorization(username: username, password: "password")

      var tokenHeaders = HTTPHeaders()
      tokenHeaders.basicAuthorization = credentials

      let tokenResponse = try self.sendRequest(to: "/api/users/login", method: .POST, headers: tokenHeaders)
      let token = try tokenResponse.content.syncDecode(Token.self)
      headers.add(name: .authorization, value: "Bearer \(token.token)")
    }

    let responder = try self.make(Responder.self)
    let request = HTTPRequest(method: method, url: URL(string: path)!, headers: headers)
    let wrappedRequest = Request(http: request, using: self)
    if let body = body {
      try wrappedRequest.content.encode(body)
    }
    return try responder.respond(to: wrappedRequest).wait()
  }

  func sendRequest(to path: String,
                   method: HTTPMethod,
                   headers: HTTPHeaders = .init(),
                   loggedInRequest: Bool = false,
                   loggedInUser: User? = nil) throws -> Response {
    let emptyContent: EmptyContent? = nil
    return try sendRequest(to: path, method: method, headers: headers,
                           body: emptyContent, loggedInRequest: loggedInRequest,
                           loggedInUser: loggedInUser)
  }

  func sendRequest<T>(to path: String,
                      method: HTTPMethod,
                      headers: HTTPHeaders, data: T,
                      loggedInRequest: Bool = false,
                      loggedInUser: User? = nil) throws where T: Content {
    _ = try self.sendRequest(to: path, method: method, headers: headers, body: data,
                             loggedInRequest: loggedInRequest, loggedInUser: loggedInUser)
  }

  func getResponse<C, T>(to path: String,
                         method: HTTPMethod = .GET,
                         headers: HTTPHeaders = .init(),
                         data: C? = nil,
                         decodeTo type: T.Type,
                         loggedInRequest: Bool = false,
                         loggedInUser: User? = nil) throws -> T where C: Content, T: Decodable {
    let response = try self.sendRequest(to: path, method: method,
                                        headers: headers, body: data,
                                        loggedInRequest: loggedInRequest,
                                        loggedInUser: loggedInUser)
    return try response.content.decode(type).wait()
  }

  func getResponse<T>(to path: String,
                      method: HTTPMethod = .GET,
                      headers: HTTPHeaders = .init(),
                      decodeTo type: T.Type,
                      loggedInRequest: Bool = false,
                      loggedInUser: User? = nil) throws -> T where T: Decodable {
    let emptyContent: EmptyContent? = nil
    return try self.getResponse(to: path, method: method, headers: headers,
                                data: emptyContent, decodeTo: type,
                                loggedInRequest: loggedInRequest,
                                loggedInUser: loggedInUser)
  }
}

struct EmptyContent: Content {}
