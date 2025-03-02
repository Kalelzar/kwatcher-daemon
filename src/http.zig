const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const api = @import("api.zig");
const model = @import("model.zig");
const template = @import("template.zig");

fn notFound(data: *zmpl.Data) !template.Template {
    _ = try data.object();
    return template.Template.init("not_found");
}

const App = struct {
    system_service: model.SystemService,
    rabbitmq_service: model.RabbitMqService,
    server: *tk.Server,
    routes: []const tk.Route = &.{
        .get("/", tk.static.file("static/index.html")),
        template.templates(
            &.{
                tk.logger(
                    .{},
                    &.{
                        .group("/api/system", &.{.router(api.system)}),
                        .group("/api/rabbitmq", &.{.router(api.rabbitmq)}),
                        .get("/openapi.json", tk.swagger.json(.{ .info = .{ .title = "KWatcher Daemon" } })),
                        .get("/swagger-ui", tk.swagger.ui(.{ .url = "openapi.json" })),
                        .get("/*", notFound),
                    },
                ),
            },
        ),
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const root = tk.Injector.init(&.{
        &gpa.allocator(),
        &tk.ServerOptions{ .listen = .{
            .hostname = "0.0.0.0",
            .port = 8080,
        } },
    }, null);

    var app: App = undefined;
    const injector = try tk.Module(App).init(&app, &root);
    defer tk.Module(App).deinit(injector);

    if (injector.find(*tk.Server)) |server| {
        server.injector = injector;
        try server.start();
    }
}
