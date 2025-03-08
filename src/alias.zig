const kwatcher = @import("kwatcher");
const Config = struct {};
const Routes = @import("kwatcher/route.zig");

pub const KWatcherClient = kwatcher.server.Server(
    "http",
    "0.1.0",
    struct {},
    struct {},
    Config,
    Routes,
    struct {},
);
