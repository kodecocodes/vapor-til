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
import XCTVapor

final class UserTests: XCTestCase {
  let usersName = "Alice"
  let usersUsername = "alicea"
  let usersURI = "/api/users/"
  var app: Application!
  
  override func setUpWithError() throws {
    app = try Application.testable()
  }
  
  override func tearDownWithError() throws {
    app.shutdown()
  }
  
  func testUsersCanBeRetrievedFromAPI() throws {
    let user = try User.create(name: usersName, username: usersUsername, on: app.db)
    _ = try User.create(on: app.db)

    try app.test(.GET, usersURI, afterResponse: { response in
      
      XCTAssertEqual(response.status, .ok)
      let users = try response.content.decode([User.Public].self)
      
      XCTAssertEqual(users.count, 3)
      XCTAssertEqual(users[1].name, usersName)
      XCTAssertEqual(users[1].username, usersUsername)
      XCTAssertEqual(users[1].id, user.id)
    })
  }
  
  func testUserCanBeSavedWithAPI() throws {
    let user = User(name: usersName, username: usersUsername, password: "password")

    try app.test(.POST, usersURI, loggedInRequest: true, beforeRequest: { req in
      try req.content.encode(user)
    }, afterResponse: { response in
      let receivedUser = try response.content.decode(User.Public.self)
      XCTAssertEqual(receivedUser.name, usersName)
      XCTAssertEqual(receivedUser.username, usersUsername)
      XCTAssertNotNil(receivedUser.id)

      try app.test(.GET, usersURI, afterResponse: { secondResponse in
        let users = try secondResponse.content.decode([User.Public].self)
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[1].name, usersName)
        XCTAssertEqual(users[1].username, usersUsername)
        XCTAssertEqual(users[1].id, receivedUser.id)
      })
    })
  }
  
  func testGettingASingleUserFromTheAPI() throws {
    let user = try User.create(name: usersName, username: usersUsername, on: app.db)
    
    try app.test(.GET, "\(usersURI)\(user.id!)", afterResponse: { response in
      let receivedUser = try response.content.decode(User.Public.self)
      XCTAssertEqual(receivedUser.name, usersName)
      XCTAssertEqual(receivedUser.username, usersUsername)
      XCTAssertEqual(receivedUser.id, user.id)
    })
  }
  
  func testGettingAUsersAcronymsFromTheAPI() throws {
    let user = try User.create(on: app.db)

    let acronymShort = "OMG"
    let acronymLong = "Oh My God"
    
    let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, user: user, on: app.db)
    _ = try Acronym.create(short: "LOL", long: "Laugh Out Loud", user: user, on: app.db)

    try app.test(.GET, "\(usersURI)\(user.id!)/acronyms", afterResponse: { response in
      let acronyms = try response.content.decode([Acronym].self)
      XCTAssertEqual(acronyms.count, 2)
      XCTAssertEqual(acronyms[0].id, acronym1.id)
      XCTAssertEqual(acronyms[0].short, acronymShort)
      XCTAssertEqual(acronyms[0].long, acronymLong)
    })
  }
}
