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

@testable import App
import Fluent
import Vapor

extension User {
  // 1
  static func create(
    name: String = "Luke",
    username: String? = nil,
    on database: Database
  ) throws -> User {
    let createUsername: String
    // 2
    if let suppliedUsername = username {
      createUsername = suppliedUsername
    // 3
    } else {
      createUsername = UUID().uuidString
    }

    // 4
    let password = try Bcrypt.hash("password")
    let user = User(
      name: name,
      username: createUsername,
      password: password)
    try user.save(on: database).wait()
    return user
  }
}

extension Acronym {
  static func create(
    short: String = "TIL",
    long: String = "Today I Learned",
    user: User? = nil,
    on database: Database
  ) throws -> Acronym {
    var acronymsUser = user
    
    if acronymsUser == nil {
      acronymsUser = try User.create(on: database)
    }
    
    let acronym = Acronym(
      short: short,
      long: long,
      userID: acronymsUser!.id!)
    try acronym.save(on: database).wait()
    return acronym
  }
}

extension App.Category {
  static func create(
    name: String = "Random",
    on database: Database
  ) throws -> App.Category {
    let category = Category(name: name)
    try category.save(on: database).wait()
    return category
  }
}
