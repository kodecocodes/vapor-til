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

struct WebsiteController: RouteCollection {
  func boot(router: Router) throws {
    router.get(use: indexHandler)
    router.get("acronyms", Acronym.parameter, use: acronymHandler)
    router.get("users", User.parameter, use: userHandler)
    router.get("users", use: allUsersHandler)
    router.get("categories", use: allCategoriesHandler)
    router.get("categories", Category.parameter, use: categoryHandler)
    router.get("acronyms", "create", use: createAcronymHandler)
    router.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
    router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
    router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
    router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
  }

  func indexHandler(_ req: Request) throws -> Future<View> {
    return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
      let acronymsData = acronyms.isEmpty ? nil : acronyms
      let context = IndexContext(title: "Homepage", acronyms: acronymsData)
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
    let context = CreateAcronymContext(users: User.query(on: req).all())
    return try req.view().render("createAcronym", context)
  }

  func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
    let acronym = Acronym(short: data.short, long: data.long, userID: data.userID)
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
      let context = try EditAcronymContext(acronym: acronym, users: User.query(on: req).all(), categories: acronym.categories.query(on: req).all())
      return try req.view().render("createAcronym", context)
    }
  }

  func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
    return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(CreateAcronymData.self)) { acronym, data in
      acronym.short = data.short
      acronym.long = data.long
      acronym.userID = data.userID

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
}

struct IndexContext: Encodable {
  let title: String
  let acronyms: [Acronym]?
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
  let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
  let title = "Edit Acronym"
  let acronym: Acronym
  let users: Future<[User]>
  let editing = true
  let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
  let userID: User.ID
  let short: String
  let long: String
  let categories: [String]?
}
