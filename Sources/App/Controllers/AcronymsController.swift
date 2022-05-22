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

import Vapor
import Fluent

struct AcronymsController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let acronymsRoutes = routes.grouped("api", "acronyms")
    acronymsRoutes.get(use: getAllHandler)
    acronymsRoutes.get(":acronymID", use: getHandler)
    acronymsRoutes.get("search", use: searchHandler)
    acronymsRoutes.get("first", use: getFirstHandler)
    acronymsRoutes.get("sorted", use: sortedHandler)
    acronymsRoutes.get(":acronymID", "user", use: getUserHandler)
    acronymsRoutes.get(":acronymID", "categories", use: getCategoriesHandler)

    let tokenAuthMiddleware = Token.authenticator()
    let guardAuthMiddleware = User.guardMiddleware()
    let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(use: createHandler)
    tokenAuthGroup.delete(":acronymID", use: deleteHandler)
    tokenAuthGroup.put(":acronymID", use: updateHandler)
    tokenAuthGroup.post(":acronymID", "categories", ":categoryID", use: addCategoriesHandler)
    tokenAuthGroup.delete(":acronymID", "categories", ":categoryID", use: removeCategoriesHandler)
  }

  func getAllHandler(_ req: Request) async throws -> [Acronym] {
    try await Acronym.query(on: req.db).all()
  }

  func createHandler(_ req: Request) async throws -> Acronym {
    let data = try req.content.decode(CreateAcronymData.self)
    let user = try req.auth.require(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    try await acronym.save(on: req.db)
    return acronym
  }

  func getHandler(_ req: Request) async throws -> Acronym {
      guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
      return acronym
  }

  func updateHandler(_ req: Request) async throws -> Acronym {
    let updateData = try req.content.decode(CreateAcronymData.self)
    let user = try req.auth.require(User.self)
    let userID = try user.requireID()
    guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
    acronym.short = updateData.short
    acronym.long = updateData.long
    acronym.$user.id = userID
    try await acronym.save(on: req.db)
    return acronym
  }

  func deleteHandler(_ req: Request) async throws -> HTTPStatus {
    guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
    try await acronym.delete(on: req.db)
    return .noContent
  }

  func searchHandler(_ req: Request) async throws -> [Acronym] {
    guard let searchTerm = req.query[String.self, at: "term"] else { throw Abort(.badRequest) }
    return try await Acronym.query(on: req.db).group(.or) { or in
      or.filter(\.$short == searchTerm)
      or.filter(\.$long == searchTerm)
    }.all()
  }

  func getFirstHandler(_ req: Request) async throws -> Acronym {
      guard let acronym = try await Acronym.query(on: req.db).first() else { throw Abort(.notFound) }
      return acronym
  }

  func sortedHandler(_ req: Request) async throws -> [Acronym] {
    return try await Acronym.query(on: req.db).sort(\.$short, .ascending).all()
  }

  func getUserHandler(_ req: Request) async throws -> User.Public {
      guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
      return try await acronym.$user.get(on: req.db).convertToPublic()
  }

  func addCategoriesHandler(_ req: Request) async throws -> HTTPStatus {
    guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
    guard let category = try await Category.find(req.parameters.get("categoryID"), on: req.db) else { throw Abort(.notFound) }
    try await acronym.$categories.attach(category, on: req.db)
    return .created
  }

  func getCategoriesHandler(_ req: Request) async throws -> [Category] {
      guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
      return try await acronym.$categories.query(on: req.db).all()
  }

  func removeCategoriesHandler(_ req: Request) async throws -> HTTPStatus {
    guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else { throw Abort(.notFound) }
    guard let category = try await Category.find(req.parameters.get("categoryID"), on: req.db) else { throw Abort(.notFound) }
    try await acronym.$categories.detach(category, on: req.db)
    return .noContent
  }
}

struct CreateAcronymData: Content {
  let short: String
  let long: String
}
