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

import Routing
import Vapor
import Fluent

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
  // Basic "Hello, world!" example
  router.get("hello") { req in
    return "Hello, world!"
  }

  // Example of creating a Service and using it.
  router.get("hash", String.parameter) { req -> String in
    // Create a BCryptHasher using the Request's Container
    let hasher = try req.make(BCryptHasher.self)

    // Fetch the String parameter (as described in the route)
    let string = try req.parameter(String.self)

    // Return the hashed string!
    return try hasher.make(string)
  }

  router.post("api", "acronyms") { req -> Future<Acronym> in
    return try req.content.decode(Acronym.self).flatMap(to: Acronym.self) { acronym in
      return acronym.save(on: req)
    }
  }

  router.get("api", "acronyms") { req -> Future<[Acronym]> in
    return Acronym.query(on: req).all()
  }

  router.get("api", "acronyms", Acronym.parameter) { req -> Future<Acronym> in
    return try req.parameter(Acronym.self)
  }

  router.put("api", "acronyms", Acronym.parameter) { req -> Future<Acronym> in
    return try flatMap(to: Acronym.self,
                       req.parameter(Acronym.self),
                       req.content.decode(Acronym.self)) { acronym, updatedAcronym in
      acronym.short = updatedAcronym.short
      acronym.long = updatedAcronym.long
      return acronym.save(on: req)
    }
  }

  router.delete("api", "acronyms", Acronym.parameter) { req -> Future<HTTPStatus> in
    return try req.parameter(Acronym.self).flatMap(to: HTTPStatus.self) { acronym in
      return acronym.delete(on: req).transform(to: HTTPStatus.noContent)
    }
  }

  router.get("api", "acronyms", "search") { req -> Future<[Acronym]> in
    guard let searchTerm = req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return try Acronym.query(on: req).group(.or) { or in
      try or.filter(\.short == searchTerm)
      try or.filter(\.long == searchTerm)
    }.all()
  }

  router.get("api", "acronyms", "first") { req -> Future<Acronym> in
    return Acronym.query(on: req).first().map(to: Acronym.self) { acronym in
      guard let acronym = acronym else {
        throw Abort(.notFound)
      }
      return acronym
    }
  }

  router.get("api", "acronyms", "sorted") { req -> Future<[Acronym]> in
    return try Acronym.query(on: req).sort(\.short, .ascending).all()
  }

}
