const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const pg = @import("pg");
const kwatcher = @import("kwatcher");
const api = @import("api.zig");
const model = @import("model.zig");
const template = @import("template.zig");
const metrics = @import("metrics.zig");
const EventService = @import("service/events.zig");
const KEventRepo = @import("kwatcher-daemon").repo.KEvent;

fn notFound(context: *tk.Context, data: *zmpl.Data) !template.Template {
    _ = try data.object();
    context.res.status = 404;
    return template.Template.init("not_found");
}

const App = struct {
    system_service: model.SystemService,
    event_repo: KEventRepo.FromPool,
    event_service: EventService,
    server: *tk.Server,
    routes: []const tk.Route = &.{
        tk.logger(.{}, &.{
            metrics.track(&.{
                .get("/", tk.static.file("static/index.html")),
                .get("/metrics", metrics.route()),
                template.templates(&.{
                    .group("/api/system", &.{.router(api.system)}),
                    .group("/api/events", &.{.router(api.events)}),
                    .get("/openapi.json", tk.swagger.json(.{ .info = .{ .title = "KWatcher Daemon" } })),
                    .get("/swagger-ui", tk.swagger.ui(.{ .url = "openapi.json" })),
                    .get("/*", notFound),
                }),
            }),
        }),
    },
};

const Config = struct {
    daemon: struct {
        postgre: struct {
            pool_size: u8 = 5,
            port: u16 = 5432,
            host: []const u8 = "127.0.0.1",
            auth: struct {
                username: []const u8,
                password: []const u8,
                database: []const u8 = "kwatcher",
                timeout: u16 = 10000,
            },
        },
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    const merged_config = try kwatcher.config.findConfigFileWithDefaults(
        Config,
        "server",
        &arena,
    );
    const config = merged_config.value;

    const ptr = try pg.Pool.init(allocator, .{
        .size = config.daemon.postgre.pool_size,
        .connect = .{
            .port = config.daemon.postgre.port,
            .host = config.daemon.postgre.host,
        },
        .auth = .{
            .username = config.daemon.postgre.auth.username,
            .password = config.daemon.postgre.auth.password,
            .database = config.daemon.postgre.auth.database,
            .timeout = config.daemon.postgre.auth.timeout,
        },
    });
    defer ptr.deinit();

    const root = tk.Injector.init(&.{
        &gpa.allocator(),
        &arena,
        &tk.ServerOptions{
            .listen = .{
                .hostname = "0.0.0.0",
                .port = 8080,
            },
        },
        ptr,
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
