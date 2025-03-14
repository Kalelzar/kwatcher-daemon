const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const pg = @import("pg");
const kwatcher = @import("kwatcher");
const KWatcherClient = @import("alias.zig").KWatcherClient;
const KWatcherSingleton = @import("alias.zig").Singleton;
const api = @import("api.zig");
const model = @import("model.zig");
const template = @import("template.zig");
const metrics = @import("metrics.zig");
const EventService = @import("service/events.zig");
const KEventRepo = @import("kwatcher-daemon").repo.KEvent;
const Config = @import("config.zig").Config;

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
    kwatcher_client: *KWatcherClient,
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var instr_allocator = metrics.instrumentAllocator(allocator);
    const alloc = instr_allocator.allocator();
    try metrics.initialize(alloc, .{});
    defer metrics.deinitialize();

    var instr_page_allocator = metrics.instrumentAllocator(std.heap.page_allocator);
    const page_allocator = instr_page_allocator.allocator();
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    const merged_config = try kwatcher.config.findConfigFileWithDefaults(
        Config,
        "server",
        &arena,
    );
    const config = merged_config.value;

    const ptr = try pg.Pool.init(alloc, .{
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

    var singleton = KWatcherSingleton{};
    var kwatcher_client = try KWatcherClient.init(alloc, &singleton);
    defer kwatcher_client.deinit();
    try kwatcher_client.configure();

    const root = tk.Injector.init(&.{
        &alloc,
        &tk.ServerOptions{
            .listen = .{
                .hostname = "0.0.0.0",
                .port = 8080,
            },
        },
        &kwatcher_client,
        ptr,
    }, null);

    var app: App = undefined;
    const injector = try tk.Module(App).init(&app, &root);
    defer tk.Module(App).deinit(injector);

    if (injector.find(*tk.Server)) |server| {
        server.injector = injector;
        try server.start();
    }
}
