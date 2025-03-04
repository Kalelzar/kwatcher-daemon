const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const api = @import("api.zig");
const model = @import("model.zig");
const template = @import("template.zig");
const metrics = @import("metrics.zig");

fn notFound(context: *tk.Context, data: *zmpl.Data) !template.Template {
    _ = try data.object();
    context.res.status = 404;
    return template.Template.init("not_found");
}

const App = struct {
    system_service: model.SystemService,
    rabbitmq_service: model.RabbitMqService,
    server: *tk.Server,
    routes: []const tk.Route = &.{
        tk.logger(.{}, &.{
            metrics.track(&.{
                .get("/", tk.static.file("static/index.html")),
                .get("/metrics", metrics.route()),
                template.templates(&.{
                    .group("/api/system", &.{.router(api.system)}),
                    .group("/api/rabbitmq", &.{.router(api.rabbitmq)}),
                    .get("/openapi.json", tk.swagger.json(.{ .info = .{ .title = "KWatcher Daemon" } })),
                    .get("/swagger-ui", tk.swagger.ui(.{ .url = "openapi.json" })),
                    .get("/*", notFound),
                }),
            }),
        }),
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const root = tk.Injector.init(&.{
        &gpa.allocator(),
        &tk.ServerOptions{ .listen = .{
            .hostname = "0.0.0.0",
            .port = 8080,
        } },
    }, null);

    try metrics.initialize(allocator, .{});

    var app: App = undefined;
    const injector = try tk.Module(App).init(&app, &root);
    defer tk.Module(App).deinit(injector);

    if (injector.find(*tk.Server)) |server| {
        server.injector = injector;
        try server.start();
    }
}
