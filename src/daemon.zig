const std = @import("std");
const kwatcher = @import("kwatcher");
const pg = @import("pg");
const repo = @import("kwatcher-daemon").repo;

const routes = @import("daemon/route.zig");

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

const SingletonDependencies = struct {
    pg_pool: ?*pg.Pool = null,

    pub fn pgPoolFactory(self: *SingletonDependencies, arena: *std.heap.ArenaAllocator, config: Config) !*pg.Pool {
        if (self.pg_pool) |ptr| {
            return ptr;
        } else {
            const allocator = arena.allocator();
            var ptr = try pg.Pool.init(allocator, .{
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
            var conn = try ptr.acquire();
            defer conn.release();
            try repo.initialize(conn);
            self.pg_pool = ptr;
            return ptr;
        }
    }

    pub fn deinit(self: *SingletonDependencies) void {
        if (self.pg_pool) |pool| {
            pool.deinit();
        }
    }
};

const ScopedDependencies = struct {
    clientRepo: ?*repo.KClient = null,
    eventRepo: ?*repo.KEvent = null,

    pub fn clientRepoFactory(
        self: *ScopedDependencies,
        arena: *kwatcher.mem.InternalArena,
        pool: *pg.Pool,
    ) !*repo.KClient {
        if (self.clientRepo) |r| {
            return r;
        } else {
            const alloc = arena.allocator();
            self.clientRepo = try alloc.create(repo.KClient);
            errdefer alloc.destroy(self.clientRepo);
            self.clientRepo.?.* = try repo.KClient.init(pool);
            return self.clientRepo.?;
        }
    }

    pub fn eventRepoFactory(
        self: *ScopedDependencies,
        arena: *kwatcher.mem.InternalArena,
        pool: *pg.Pool,
    ) !*repo.KEvent {
        if (self.eventRepo) |r| {
            return r;
        } else {
            const alloc = arena.allocator();
            self.eventRepo = try alloc.create(repo.KEvent);
            errdefer alloc.destroy(self.eventRepo);
            self.eventRepo.?.* = try repo.KEvent.init(pool);
            return self.eventRepo.?;
        }
    }

    pub fn deconstruct(self: *ScopedDependencies) void {
        if (self.clientRepo) |*r| {
            r.*.deinit();
        }
        if (self.eventRepo) |*r| {
            r.*.deinit();
        }
    }
};

const EventProvider = struct {
    pub fn heartbeat(timer: kwatcher.server.Timer) !bool {
        return try timer.ready("heartbeat");
    }

    pub fn disabled() bool {
        return false;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = gpa.allocator();

    var singleton = SingletonDependencies{};

    var server = try kwatcher.server.Server(
        "daemon",
        "0.1.0",
        SingletonDependencies,
        ScopedDependencies,
        Config,
        struct {},
        routes,
        EventProvider,
    ).init(allocator, &singleton);
    defer server.deinit();
    defer singleton.deinit(); // Defers are executed bottom-to-top so we schedule the singleton
    // to be before the server so the arena is still alive and we don't (occasionally) segfault
    // This is a very annoying foot-gun.

    try server.start();
}
