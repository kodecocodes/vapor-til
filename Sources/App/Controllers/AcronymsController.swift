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
import Fluent

struct AcronymsController: RouteCollection {
  func boot(router: Router) throws {
    let acronymsRoutes = router.grouped("api", "acronyms")
    acronymsRoutes.get(use: getAllHandler)
    acronymsRoutes.post(Acronym.self, use: createHandler)
    acronymsRoutes.get(Acronym.parameter, use: getHandler)
    acronymsRoutes.put(Acronym.parameter, use: updateHandler)
    acronymsRoutes.delete(Acronym.parameter, use: deleteHandler)
    acronymsRoutes.get("search", use: searchHandler)
    acronymsRoutes.get("first", use: getFirstHandler)
    acronymsRoutes.get("sorted", use: sortedHandler)
    acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
    acronymsRoutes.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
    acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)
  }

  func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
    return Acronym.query(on: req).all()
  }

  func createHandler(_ req: Request, acronym: Acronym) throws -> Future<Acronym> {
    return acronym.save(on: req)
  }

  func getHandler(_ req: Request) throws -> Future<Acronym> {
    return try req.parameters.next(Acronym.self)
  }

  func updateHandler(_ req: Request) throws -> Future<Acronym> {
    return try flatMap(to: Acronym.self,
                       req.parameters.next(Acronym.self),
                       req.content.decode(Acronym.self)) { acronym, updatedAcronym in
                        acronym.short = updatedAcronym.short
                        acronym.long = updatedAcronym.long
                        acronym.userID = updatedAcronym.userID
                        return acronym.save(on: req)
    }
  }

  func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try req.parameters.next(Acronym.self).delete(on: req).transform(to: HTTPStatus.noContent)
  }

  func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
    guard let searchTerm = req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return try Acronym.query(on: req).group(.or) { or in
      try or.filter(\.short == searchTerm)
      try or.filter(\.long == searchTerm)
    }.all()
  }

  func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
    return Acronym.query(on: req).first().map(to: Acronym.self) { acronym in
      guard let acronym = acronym else {
        throw Abort(.notFound)
      }
      return acronym
    }
  }

  func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
    return try Acronym.query(on: req).sort(\.short, .ascending).all()
  }

  func getUserHandler(_ req: Request) throws -> Future<User> {
    return try req.parameters.next(Acronym.self).flatMap(to: User.self) { acronym in
      try acronym.user.get(on: req)
    }
  }

  func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self)) { acronym, category in
      let pivot = try AcronymCategoryPivot(acronym.requireID(), category.requireID())
      return pivot.save(on: req).transform(to: .created)
    }
  }

  func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
    return try req.parameters.next(Acronym.self).flatMap(to: [Category].self) { acronym in
      try acronym.categories.query(on: req).all()
    }
  }
}
