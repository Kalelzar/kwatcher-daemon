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

    pub fn pgConnFactory(pool: *pg.Pool) !*pg.Conn {
        return pool.acquire();
    }

    pub fn clientRepoFactory(
        self: *ScopedDependencies,
        arena: *kwatcher.mem.InternalArena,
        pool: *pg.Pool,
    ) !*repo.KClient {
        if (self.clientRepo) |r| {
            return r;
        } else {
            // We need to acquire a connection manually. Had we injected it, we would have to release it here instead.
            // No need for the extra churn.
            // Maybe we could add lazy evaluation in the future ;)
            const conn = try pgConnFactory(pool);
            errdefer conn.release();
            const alloc = arena.allocator();
            self.clientRepo = try alloc.create(repo.KClient);
            self.clientRepo.?.* = repo.KClient.init(conn);
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
            // We need to acquire a connection manually. Had we injected it, we would have to release it here instead.
            // No need for the extra churn.
            // Maybe we could add lazy evaluation in the future ;)
            const conn = try pgConnFactory(pool);
            errdefer conn.release();
            const alloc = arena.allocator();
            self.eventRepo = try alloc.create(repo.KEvent);
            self.eventRepo.?.* = repo.KEvent.init(conn);
            return self.eventRepo.?;
        }
    }

    pub fn deconstruct(self: *ScopedDependencies) void {
        if (self.clientRepo) |_| {
            self.clientRepo.?.deinit();
        }
        if (self.eventRepo) |_| {
            self.eventRepo.?.deinit();
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
    defer singleton.deinit();

    var server = try kwatcher.server.Server(
        "daemon",
        "0.1.0",
        SingletonDependencies,
        ScopedDependencies,
        Config,
        routes,
        EventProvider,
    ).init(allocator, singleton);
    defer server.deinit();

    try server.run();
}
