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
const builtin = @import("builtin");

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    {
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

        const root = tk.Injector.init(&.{
            &alloc,
            &tk.ServerOptions{
                .listen = .{
                    .hostname = "0.0.0.0",
                    .port = 8080,
                },
            },
            ptr,
        }, null);

        var app: App = undefined;
        const injector = try tk.Module(App).init(&app, &root);
        defer tk.Module(App).deinit(injector);

        if (comptime builtin.os.tag == .linux) {
            // call our shutdown function (below) when
            // SIGINT or SIGTERM are received
            std.posix.sigaction(std.posix.SIG.INT, &.{
                .handler = .{ .handler = shutdown },
                .mask = std.posix.empty_sigset,
                .flags = 0,
            }, null);
            std.posix.sigaction(std.posix.SIG.TERM, &.{
                .handler = .{ .handler = shutdown },
                .mask = std.posix.empty_sigset,
                .flags = 0,
            }, null);
        }

        if (injector.find(*tk.Server)) |server| {
            server.injector = injector;
            server_instance = server;
            const tkthread = try std.Thread.spawn(
                .{ .allocator = alloc },
                tk.Server.start,
                .{server},
            );
            kwatcher_instance = &kwatcher_client;
            try kwatcher_client.start();
            tkthread.join();
        }
    }
    _ = gpa.detectLeaks();
}

var server_instance: ?*tk.Server = null;
var kwatcher_instance: ?*KWatcherClient = null;

fn shutdown(_: c_int) callconv(.C) void {
    if (server_instance) |server| {
        server_instance = null;
        server.stop();
    }
    if (kwatcher_instance) |kwatch| {
        kwatcher_instance = null;
        kwatch.stop();
    }
}
