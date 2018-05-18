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
import Fluent
import Authentication

struct WebsiteController: RouteCollection {
  func boot(router: Router) throws {
    let authSessionRoutes = router.grouped(User.authSessionsMiddleware())

    authSessionRoutes.get(use: indexHandler)
    authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
    authSessionRoutes.get("users", User.parameter, use: userHandler)
    authSessionRoutes.get("users", use: allUsersHandler)
    authSessionRoutes.get("categories", use: allCategoriesHandler)
    authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
    authSessionRoutes.get("login", use: loginHandler)
    authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)
    authSessionRoutes.post("logout", use: logoutHandler)
    authSessionRoutes.get("register", use: registerHandler)
    authSessionRoutes.post(RegisterData.self, at: "register", use: registerPostHandler)

    let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
    protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
    protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
    protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
    protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
    protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
  }

  func indexHandler(_ req: Request) throws -> Future<View> {
    return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
      let acronymsData = acronyms.isEmpty ? nil : acronyms
      let userLoggedIn = try req.isAuthenticated(User.self)
      let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
      let context = IndexContext(title: "Homepage", acronyms: acronymsData, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
      return try req.view().render("index", context)
    }
  }

  func acronymHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
      return try acronym.user.get(on: req).flatMap(to: View.self) { user in
        let context = try AcronymContext(title: acronym.short, acronym: acronym, user: user, categories: acronym.categories.query(on: req).all())
        return try req.view().render("acronym", context)
      }
    }
  }

  func userHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(User.self).flatMap(to: View.self) { user in
      return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
        let context = UserContext(title: user.name, user: user, acronyms: acronyms)
        return try req.view().render("user", context)
      }
    }
  }

  func allUsersHandler(_ req: Request) throws -> Future<View> {
    return User.query(on: req).all().flatMap(to: View.self) { users in
      let context = AllUsersContext(title: "All Users", users: users)
      return try req.view().render("allUsers", context)
    }
  }

  func allCategoriesHandler(_ req: Request) throws -> Future<View> {
    let context = AllCategoriesContext(categories: Category.query(on: req).all())
    return try req.view().render("allCategories", context)
  }

  func categoryHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Category.self).flatMap(to: View.self) { category in
      let context = try CategoryContext(title: category.name, category: category, acronyms: category.acronyms.query(on: req).all())
      return try req.view().render("category", context)
    }
  }

  func createAcronymHandler(_ req: Request) throws -> Future<View> {
    let token = try CryptoRandom().generateData(count: 16).base64EncodedString()
    let context = CreateAcronymContext(csrfToken: token)
    try req.session()["CSRF_TOKEN"] = token
    return try req.view().render("createAcronym", context)
  }

  func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
    let expectedToken = try req.session()["CSRF_TOKEN"]
    try req.session()["CSRF_TOKEN"] = nil
    guard expectedToken == data.csrfToken else {
      throw Abort(.badRequest)
    }
    let user = try req.requireAuthenticated(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req).flatMap(to: Response.self) { acronym in
      guard let id = acronym.id else {
        throw Abort(.internalServerError)
      }

      var categorySaves: [Future<Void>] = []
      for category in data.categories ?? [] {
        try categorySaves.append(Category.addCategory(category, to: acronym, on: req))
      }
      return categorySaves.flatten(on: req).transform(to: req.redirect(to: "/acronyms/\(id)"))
    }
  }

  func editAcronymHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
      let context = try EditAcronymContext(acronym: acronym, categories: acronym.categories.query(on: req).all())
      return try req.view().render("createAcronym", context)
    }
  }

  func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
    return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(CreateAcronymData.self)) { acronym, data in
      let user = try req.requireAuthenticated(User.self)
      acronym.short = data.short
      acronym.long = data.long
      acronym.userID = try user.requireID()

      return acronym.save(on: req).flatMap(to: Response.self) { savedAcronym in
        guard let id = savedAcronym.id else {
          throw Abort(.internalServerError)
        }

        return try acronym.categories.query(on: req).all().flatMap(to: Response.self) { existingCategories in
          let existingStringArray = existingCategories.map { $0.name }
          let existingSet = Set<String>(existingStringArray)
          let newSet = Set<String>(data.categories ?? [])

          let categoriesToAdd = newSet.subtracting(existingSet)
          let categoriesToRemove = existingSet.subtracting(newSet)

          var categoryResults: [Future<Void>] = []
          for newCategory in categoriesToAdd {
            categoryResults.append(try Category.addCategory(newCategory, to: acronym, on: req))
          }

          for categoryNameToRemove in categoriesToRemove {
            let categoryToRemove = existingCategories.first { $0.name == categoryNameToRemove }
            if let category = categoryToRemove {
              categoryResults.append(try AcronymCategoryPivot.query(on: req).filter(\.acronymID == acronym.requireID()).filter(\.categoryID == category.requireID()).delete())
            }
          }
          return categoryResults.flatten(on: req).transform(to: req.redirect(to: "/acronyms/\(id)"))
        }
      }
    }
  }

  func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
    return try req.parameters.next(Acronym.self).delete(on: req).transform(to: req.redirect(to: "/"))
  }

  func loginHandler(_ req: Request) throws -> Future<View> {
    return try req.view().render("login", LoginContext())
  }

  func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
    return User.authenticate(username: userData.username, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
      guard let user = user else {
        return req.redirect(to: "/login")
      }
      try req.authenticateSession(user)
      return req.redirect(to: "/")
    }
  }

  func logoutHandler(_ req: Request) throws -> Response {
    try req.unauthenticateSession(User.self)
    return req.redirect(to: "/")
  }

  func registerHandler(_ req: Request) throws -> Future<View> {
    var context = RegisterContext()
    if req.query[Bool.self, at: "error"] != nil {
      context.registrationError = true
    }
    return try req.view().render("register", context)
  }

  func registerPostHandler(_ req: Request, data: RegisterData) throws -> Future<Response> {
    do {
      try data.validate()
    } catch {
      return Future.map(on: req) {
        req.redirect(to: "/register?error=true")
      }
    }
    let password = try BCrypt.hash(data.password)
    let user = User(name: data.name, username: data.username, password: password)
    return user.save(on: req).map(to: Response.self) { user in
      try req.authenticateSession(user)
      return req.redirect(to: "/")
    }
  }

}

struct IndexContext: Encodable {
  let title: String
  let acronyms: [Acronym]?
  let userLoggedIn: Bool
  let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
  let title: String
  let acronym: Acronym
  let user: User
  let categories: Future<[Category]>
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let acronyms: [Acronym]?
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]
}

struct AllCategoriesContext: Encodable {
  let title = "All Categories"
  let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
  let title: String
  let category: Category
  let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
  let title = "Create An Acronym"
  let csrfToken: String
}

struct EditAcronymContext: Encodable {
  let title = "Edit Acronym"
  let acronym: Acronym
  let editing = true
  let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
  let short: String
  let long: String
  let categories: [String]?
  let csrfToken: String
}

struct LoginContext: Encodable {
  let title = "Log In"
}

struct LoginPostData: Content {
  let username: String
  let password: String
}

struct RegisterContext: Encodable {
  let title = "Register"
  var registrationError = false
}

struct RegisterData: Content {
  let name: String
  let username: String
  let password: String
  let confirmPassword: String
}

extension RegisterData: Validatable, Reflectable {
  static func validations() throws -> Validations<RegisterData> {
    var validations = Validations(RegisterData.self)
    try validations.add(\.name, .ascii)
    try validations.add(\.username, .alphanumeric && .count(3...))
    try validations.add(\.password, .count(8...))
    validations.add("passwords match") { model in
      guard model.password == model.confirmPassword else {
        throw BasicValidationError("passwords don't match")
      }
    }
    return validations
  }
}
