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
import Imperial
import Authentication

struct ImperialController: RouteCollection {
  func boot(router: Router) throws {
    guard let googleCallbackURL = Environment.get("GOOGLE_CALLBACK_URL") else {
      fatalError("Google callback URL not set")
    }
    try router.oAuth(from: Google.self, authenticate: "login-google", callback: googleCallbackURL,
                     scope: ["profile", "email"], completion: processGoogleLogin)

    guard let githubCallbackURL = Environment.get("GITHUB_CALLBACK_URL") else {
      fatalError("GitHub callback URL not set")
    }
    try router.oAuth(from: GitHub.self, authenticate: "login-github", callback: githubCallbackURL,
                     scope: ["user:email"], completion: processGitHubLogin)
  }

  func processGoogleLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
    return try Google.getUser(on: request).flatMap(to: ResponseEncodable.self) { userInfo in
      return User.query(on: request).filter(\.username == userInfo.email)
                 .first().flatMap(to: ResponseEncodable.self) { foundUser in
        guard let existingUser = foundUser else {
          let user = User(name: userInfo.name, username: userInfo.email, password: UUID().uuidString,
                          email: userInfo.email)
          return user.save(on: request).map(to: ResponseEncodable.self) { user in
            try request.authenticateSession(user)
            return request.redirect(to: "/")
          }
        }
        try request.authenticateSession(existingUser)
        return request.future(request.redirect(to: "/"))
      }
    }
  }

  func processGitHubLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
    return try flatMap(to: ResponseEncodable.self, GitHub.getUser(on: request),
                       GitHub.getEmails(on: request)) { userInfo, emailInfo in
      return User.query(on: request).filter(\.username == userInfo.login).first()
                 .flatMap(to: ResponseEncodable.self) { foundUser in
        guard let existingUser = foundUser else {
          let user = User(name: userInfo.name, username: userInfo.login,
                          password: UUID().uuidString, email: emailInfo[0].email)
          return user.save(on: request).map(to: ResponseEncodable.self) { user in
            try request.authenticateSession(user)
            return request.redirect(to: "/")
          }
        }
        try request.authenticateSession(existingUser)
        return request.future(request.redirect(to: "/"))
      }
    }
  }
}

struct GoogleUserInfo: Content {
  let email: String
  let name: String
}

extension Google {
  static func getUser(on request: Request) throws -> Future<GoogleUserInfo> {
    var headers = HTTPHeaders()
    headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())

    let googleAPIURL = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
    return try request.client().get(googleAPIURL, headers: headers).map(to: GoogleUserInfo.self) { response in
      guard response.http.status == .ok else {
        if response.http.status == .unauthorized {
          throw Abort.redirect(to: "/login-google")
        } else {
          throw Abort(.internalServerError)
        }
      }
      return try response.content.syncDecode(GoogleUserInfo.self)
    }
  }
}

struct GitHubUserInfo: Content {
  let name: String
  let login: String
}

struct GitHubEmailInfo: Content {
  let email: String
}

extension GitHub {
  static func getUser(on request: Request) throws -> Future<GitHubUserInfo> {
    var headers = HTTPHeaders()
    headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())

    let githubUserAPIURL = "https://api.github.com/user"
    return try request.client().get(githubUserAPIURL, headers: headers).map(to: GitHubUserInfo.self) { response in
      guard response.http.status == .ok else {
        if response.http.status == .unauthorized {
          throw Abort.redirect(to: "/login-github")
        } else {
          throw Abort(.internalServerError)
        }
      }
      return try response.content.syncDecode(GitHubUserInfo.self)
    }
  }

  static func getEmails(on request: Request) throws -> Future<[GitHubEmailInfo]> {
    var headers = HTTPHeaders()
    headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())

    let githubUserAPIURL = "https://api.github.com/user/emails"
    return try request.client().get(githubUserAPIURL, headers: headers).map(to: [GitHubEmailInfo].self) { response in
      guard response.http.status == .ok else {
        if response.http.status == .unauthorized {
          throw Abort.redirect(to: "/login-github")
        } else {
          throw Abort(.internalServerError)
        }
      }
      return try response.content.syncDecode([GitHubEmailInfo].self)
    }
  }
}
