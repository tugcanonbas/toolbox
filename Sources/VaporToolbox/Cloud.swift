import Vapor

/**

 // MARK: User APIs

 vapor cloud login
 - email:
 - pwd:

 vapor cloud signup
 - firstName:
 - lastName:
 - email:
 - pwd:
 - organizationName:

 vapor cloud me

 // MARK: SSH Key APIs

 vapor cloud ssh create (-n name-of-key -p path-to-key)
 // if one key, push

 vapor cloud ssh list
 // list all

 vapor cloud ssh delete name-of-key
 // if multiple names exist, ask which one

 **/

public func testCloud() throws {
    try signup()
}

let cloudBaseUrl = "https://api.v2.vapor.cloud/v2/"
let gitUrl = cloudBaseUrl + "git"
let gitSSHKeysUrl = gitUrl.finished(with: "/") + "keys"
let authUrl = cloudBaseUrl + "auth/"
let userUrl = authUrl + "users"
let loginUrl = userUrl.finished(with: "/") + "login"
let meUrl = userUrl.finished(with: "/") + "me"

struct CloudUser: Content {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
}

struct UserApi {
    static func signup(
        email: String,
        firstName: String,
        lastName: String,
        organizationName: String,
        password: String
    ) throws -> CloudUser {
        struct NewUser: Content {
            let email: String
            let firstName: String
            let lastName: String
            let organizationName: String
            let password: String
        }

        let content = NewUser(
            email: email,
            firstName: firstName,
            lastName: lastName,
            organizationName: organizationName,
            password: password
        )

        let client = try makeClient()
        let response = client.send(.POST, to: userUrl) { try $0.content.encode(content) }
        return try response.wait().content.decode(CloudUser.self).wait()
    }

    static func login(
        email: String,
        password: String
    ) throws -> Token {
        let combination = email + ":" + password
        let data = combination.data(using: .utf8)!
        let encoded = data.base64EncodedString()

        let headers: HTTPHeaders = [
            "Authorization": "Basic \(encoded)"
        ]
        let client = try makeClient()
        let response = client.send(.POST, headers: headers, to: loginUrl)
        return try response.wait().content.decode(Token.self).wait()
    }

    static func me(token: Token) throws -> CloudUser {
        let client = try makeClient()
        let headers = token.headers
        let response = client.send(.GET, headers: headers, to: meUrl)
        let resp = try response.wait()
        return try resp.content.decode(CloudUser.self).wait()
    }
}

protocol API {
    var token: Token { get }
}

struct SSHKey: Content {
    let key: String
    let name: String
    let userID: UUID

    let id: UUID
    let createdAt: Date
    let updatedAt: Date
}

extension API {
    var contentHeaders: HTTPHeaders {
        var head = token.headers
        head.add(name: "Content-Type", value: "application/json")
        return head
    }
}

struct SSHKeyApi: API {
    let token: Token

    func push(name: String, path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { throw "no rsa key found at \(path)" }
        guard let file = FileManager.default.contents(atPath: path) else { throw "unable to load rsa key" }
        guard let key = String(data: file, encoding: .utf8) else { throw "no string found in data" }
        try push(name: name, key: key)
    }

    func push(name: String, key: String) throws {
        struct Package: Content {
            let name: String
            let key: String
        }
        let package = Package(name: name, key: key)
        let client = try makeClient()
        let response = client.send(.POST, headers: contentHeaders, to: gitSSHKeysUrl) { try $0.content.encode(package) }
        let resp = try response.wait()
        print(resp)
        print("")
//        return try resp.content.decode(CloudUser.self).wait()
    }

    static func list() throws {

    }
}

struct Token: Content {
    let expiresAt: Date
    let id: UUID
    let userID: UUID
    let token: String
}

extension Token {
    var headers: HTTPHeaders {
        return [
            "Authorization": "Bearer \(token)"
        ]
    }
}


func signup() throws {
    let email = "logan+\(Date().timeIntervalSince1970)@gmail.com"
    let pwd = "12Three!"
    let new = try UserApi.signup(
        email: email,
        firstName: "Test",
        lastName: "Tester",
        organizationName: "TestOrg",
        password: pwd
    )
    print("new: \(new)")
    let token = try UserApi.login(email: email, password: pwd)
    print(token)
    let me = try UserApi.me(token: token)
    print(me)
    print("")

    let sshApi = SSHKeyApi(token: token)
    try sshApi.push(name: "my-key", key: "this is not a real key, it's pretend")
    print("")
//    let response = try client.post(signUpUrl, headers: HTTPHeaders(), content: new).wait()
//    print(response)
//    print("")
}

func makeClient() throws -> Client {
    return try Request(using: app).make()
}

let app: Application = {
    var config = Config.default()
    var env = try! Environment.detect()
    var services = Services.default()

    let app = try! Application(
        config: config,
        environment: env,
        services: services
    )

    return app
}()
