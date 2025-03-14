const kwatcher = @import("kwatcher");
const Config = struct {};
const Routes = @import("kwatcher/route.zig");

pub const Singleton = struct {};

pub const KWatcherClient = kwatcher.server.Server(
    "http",
    "0.1.0",
    Singleton,
    struct {},
    Config,
    Routes,
    struct {},
);
