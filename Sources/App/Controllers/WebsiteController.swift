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
import Leaf

struct WebsiteController: RouteCollection {
  func boot(router: Router) throws {
    router.get(use: indexHandler)
    router.get("acronyms", Acronym.parameter, use: acronymHandler)
    router.get("users", User.parameter, use: userHandler)
    router.get("users", use: allUsersHandler)
  }

  func indexHandler(_ req: Request) throws -> Future<View> {
    return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
      let acronymsData = acronyms.isEmpty ? nil : acronyms
      let context = IndexContext(title: "Homepage", acronyms: acronymsData)
      return try req.make(LeafRenderer.self).render("index", context)
    }
  }

  func acronymHandler(_ req: Request) throws -> Future<View> {
    return try req.parameter(Acronym.self).flatMap(to: View.self) { acronym in
      return try acronym.user.get(on: req).flatMap(to: View.self) { user in
        let context = AcronymContext(title: acronym.short, acronym: acronym, user: user)
        return try req.make(LeafRenderer.self).render("acronym", context)
      }
    }
  }

  func userHandler(_ req: Request) throws -> Future<View> {
    return try req.parameter(User.self).flatMap(to: View.self) { user in
      return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
        let usersAcronyms = acronyms.isEmpty ? nil : acronyms
        let context = UserContext(title: user.name, user: user, acronyms: usersAcronyms)
        return try req.make(LeafRenderer.self).render("user", context)
      }
    }
  }

  func allUsersHandler(_ req: Request) throws -> Future<View> {
    return User.query(on: req).all().flatMap(to: View.self) { users in
      let usersData = users.isEmpty ? nil : users
      let context = AllUsersContext(title: "All Users", users: usersData)
      return try req.make(LeafRenderer.self).render("allUsers", context)
    }
  }
}

struct IndexContext: Encodable {
  let title: String
  let acronyms: [Acronym]?
}

struct AcronymContext: Encodable {
  let title: String
  let acronym: Acronym
  let user: User
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let acronyms: [Acronym]?
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]?
}
