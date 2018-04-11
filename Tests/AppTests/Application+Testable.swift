/// Copyright (c) 2018 Razeware LLC
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
import App
import FluentPostgreSQL

extension Application {
  static func testable() throws -> Application {
    var config = Config.default()
    var env = Environment.testing
    var services = Services.default()

    try App.configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)

    try App.boot(app)
    return app
  }

  func teardown(connection: PostgreSQLConnection) throws {
    let console = try! self.make(Console.self)
    var commandInput = CommandInput(arguments: ["revert", "--all", "-y"])
    try console.run(RevertCommand(), input: &commandInput, on: self).wait()
    self.releaseConnection(connection, to: .psql)
  }

  func getResponse<T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), body: HTTPBody = .init(), decodeTo type: T.Type) throws -> T where T: Decodable {
    let responder = try self.make(Responder.self)
    let request = HTTPRequest(method: method, url: URL(string: path)!, headers:headers, body: body)
    let wrappedRequest = Request(http: request, using: self)
    let response = try responder.respond(to: wrappedRequest).wait()
    let data = response.http.body.data
    return try JSONDecoder().decode(type, from: data!)
  }

  func getResponse<T, U>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), data: U, decodeTo type: T.Type) throws -> T where T: Decodable, U: Encodable {
    let body = try JSONEncoder().encodeBody(from: data)
    return try self.getResponse(to: path, method: method, headers: headers, body: body, decodeTo: type)
  }

  func sendRequest(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init(), body: HTTPBody = .init()) throws {
    let responder = try self.make(Responder.self)
    let request = HTTPRequest(method: method, url: URL(string: path)!, headers: headers, body: body)
    let wrappedRequest = Request(http: request, using: self)
    _ = try responder.respond(to: wrappedRequest).wait()
  }

  func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders, data: T) throws where T: Encodable {
    let body = try JSONEncoder().encodeBody(from: data)
    try self.sendRequest(to: path, method: method, headers: headers, body: body)
  }
}
