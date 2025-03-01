const std = @import("std");
const kwatcher = @import("kwatcher");
const routes = @import("daemon/route.zig");

const NoConfig = struct {};

const SingletonDependencies = struct {};

const ScopedDependencies = struct {};

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

    var server = try kwatcher.server.Server(
        "daemon",
        "0.1.0",
        SingletonDependencies,
        ScopedDependencies,
        NoConfig,
        routes,
        EventProvider,
    ).init(allocator, .{});
    defer server.deinit();

    try server.run();
}
