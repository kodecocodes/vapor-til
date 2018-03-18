import App
import Service
import Vapor

var config = Config.default()
var env = try Environment.detect()
var services = Services.default()

try App.configure(&config, &env, &services)

let app = try Application(
    config: config,
    environment: env,
    services: services
)

try App.boot(app)

try app.run()
