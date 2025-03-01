const std = @import("std");
const tk = @import("tokamak");
const api = @import("api.zig");
const model = @import("model.zig");

const App = struct {
    system_service: model.SystemService,
    server: *tk.Server,
    routes: []const tk.Route = &.{
        tk.logger(.{}, &.{
            tk.static.dir("public", .{}),
            .group("/api/system", &.{.router(api.system)}),
            .get("/openapi.json", tk.swagger.json(.{ .info = .{ .title = "KWatcher Daemon" } })),
            .get("/swagger-ui", tk.swagger.ui(.{ .url = "openapi.json" })),
        }),
    },
};

pub fn main() !void {
    try tk.app.run(App);
}
