const std = @import("std");
const tk = @import("tokamak");
const httpz = @import("httpz");
const pg = @import("pg");
const m = @import("metrics");

var metrics = m.initializeNoop(Metrics);

const Metrics = struct {
    statuses: Status,

    const StatusL = struct { status: u16 };
    const Status = m.CounterVec(u32, StatusL);
};

pub fn status(labels: Metrics.StatusL) !void {
    return metrics.statuses.incr(labels);
}

pub fn initialize(allocator: std.mem.Allocator, comptime opts: m.RegistryOpts) !void {
    metrics = .{
        .statuses = try Metrics.Status.init(allocator, "kwatcher_https_statuses", .{}, opts),
    };
}

pub fn write(writer: anytype) !void {
    return m.write(&metrics, writer);
}

fn sendMetrics(context: *tk.Context) !void {
    context.res.header("content-type", "text/plain; version=0.0.4");
    const writer = context.res.writer();
    try httpz.writeMetrics(writer);
    try pg.writeMetrics(writer);
    try write(writer);
    context.responded = true;
}

pub fn route() tk.Route {
    const H = struct {
        fn handleMetrics(context: *tk.Context) anyerror!void {
            return sendMetrics(context);
        }
    };
    return .{ .handler = &H.handleMetrics };
}

pub fn track(children: []const tk.Route) tk.Route {
    const H = struct {
        fn handleMetrics(context: *tk.Context) anyerror!void {
            try context.next();
            try status(.{ .status = context.res.status });
        }
    };
    return .{ .handler = &H.handleMetrics, .children = children };
}
