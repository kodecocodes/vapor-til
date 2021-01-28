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

final class CategoryTests: XCTestCase {
  let categoriesURI = "/api/categories/"
  let categoryName = "Teenager"
  var app: Application!

  override func setUp() {
    app = try! Application.testable()
  }

  override func tearDown() {
    app.shutdown()
  }

  func testCategoriesCanBeRetrievedFromAPI() throws {
    let category = try Category.create(name: categoryName, on: app.db)
    _ = try Category.create(on: app.db)
    
    try app.test(.GET, categoriesURI, afterResponse: { response in
      let categories = try response.content.decode([App.Category].self)
      XCTAssertEqual(categories.count, 2)
      XCTAssertEqual(categories[0].name, categoryName)
      XCTAssertEqual(categories[0].id, category.id)
    })
  }

  func testCategoryCanBeSavedWithAPI() throws {
    let category = Category(name: categoryName)
    
    try app.test(.POST, categoriesURI, loggedInRequest: true, beforeRequest: { request in
      try request.content.encode(category)
    }, afterResponse: { response in
      let receivedCategory = try response.content.decode(Category.self)
      XCTAssertEqual(receivedCategory.name, categoryName)
      XCTAssertNotNil(receivedCategory.id)

      try app.test(.GET, categoriesURI, afterResponse: { response in
        let categories = try response.content.decode([App.Category].self)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, categoryName)
        XCTAssertEqual(categories[0].id, receivedCategory.id)
      })
    })
  }

  func testGettingASingleCategoryFromTheAPI() throws {
    let category = try Category.create(name: categoryName, on: app.db)
    
    try app.test(.GET, "\(categoriesURI)\(category.id!)", afterResponse: { response in
      let returnedCategory = try response.content.decode(Category.self)
      XCTAssertEqual(returnedCategory.name, categoryName)
      XCTAssertEqual(returnedCategory.id, category.id)
    })
  }

  func testGettingACategoriesAcronymsFromTheAPI() throws {
    let acronymShort = "OMG"
    let acronymLong = "Oh My God"
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: app.db)
    let acronym2 = try Acronym.create(on: app.db)

    let category = try Category.create(name: categoryName, on: app.db)
    
    try app.test(.POST, "/api/acronyms/\(acronym.id!)/categories/\(category.id!)", loggedInRequest: true)
    try app.test(.POST, "/api/acronyms/\(acronym2.id!)/categories/\(category.id!)", loggedInRequest: true)

    try app.test(.GET, "\(categoriesURI)\(category.id!)/acronyms", afterResponse: { response in
      let acronyms = try response.content.decode([Acronym].self)
      XCTAssertEqual(acronyms.count, 2)
      XCTAssertEqual(acronyms[0].id, acronym.id)
      XCTAssertEqual(acronyms[0].short, acronymShort)
      XCTAssertEqual(acronyms[0].long, acronymLong)
    })
  }
}
