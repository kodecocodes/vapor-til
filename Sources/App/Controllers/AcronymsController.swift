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
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
  func boot(router: Router) throws {
    let acronymsRoutes = router.grouped("api", "acronyms")
    acronymsRoutes.get(use: getAllHandler)
    acronymsRoutes.get(Acronym.parameter, use: getHandler)
    acronymsRoutes.get("search", use: searchHandler)
    acronymsRoutes.get("first", use: getFirstHandler)
    acronymsRoutes.get("sorted", use: sortedHandler)
    acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
    acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)

    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)
    tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
    tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
    tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
    tokenAuthGroup.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
  }

  func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
    return Acronym.query(on: req).all()
  }

  func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
    let user = try req.requireAuthenticated(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req)
  }

  func getHandler(_ req: Request) throws -> Future<Acronym> {
    return try req.parameters.next(Acronym.self)
  }

  func updateHandler(_ req: Request) throws -> Future<Acronym> {
    return try flatMap(to: Acronym.self,
                       req.parameters.next(Acronym.self),
                       req.content.decode(AcronymCreateData.self)) { acronym, updateData in
      acronym.short = updateData.short
      acronym.long = updateData.long
      let user = try req.requireAuthenticated(User.self)
      acronym.userID = try user.requireID()
      return acronym.save(on: req)
    }
  }

  func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try req.parameters.next(Acronym.self).delete(on: req).transform(to: .noContent)
  }

  func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
    guard let searchTerm = req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return Acronym.query(on: req).group(.or) { or in
      or.filter(\.short, .ilike, searchTerm)
      or.filter(\.long == searchTerm)
      }.all()
  }

  func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
    return Acronym.query(on: req).first().unwrap(or: Abort(.notFound))
  }

  func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
    return Acronym.query(on: req).sort(\.short, .ascending).all()
  }

  func getUserHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(Acronym.self).flatMap(to: User.Public.self) { acronym in
      acronym.user.get(on: req).convertToPublic()
    }
  }

  func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self),
                       req.parameters.next(Category.self)) { acronym, category in
      return acronym.categories.attach(category, on: req).transform(to: .created)
    }
  }

  func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
    return try req.parameters.next(Acronym.self).flatMap(to: [Category].self) { acronym in
      try acronym.categories.query(on: req).all()
    }
  }

  func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self),
                       req.parameters.next(Category.self)) { acronym, category in
      return acronym.categories.detach(category, on: req).transform(to: .noContent)
    }
  }
}

struct AcronymCreateData: Content {
  let short: String
  let long: String
}
