const std = @import("std");
const tk = @import("tokamak");
const httpz = @import("httpz");
const pg = @import("pg");
const m = @import("metrics");
const KWatcherClient = @import("alias.zig").KWatcherClient;

var metrics = m.initializeNoop(Metrics);

const Metrics = struct {
    statuses: Status,
    up: Up,

    const StatusL = struct { status: u16 };
    const Status = m.CounterVec(u32, StatusL);
    const UpL = struct { job: []const u8 };
    const Up = m.GaugeVec(u1, UpL);
};

pub fn status(labels: Metrics.StatusL) !void {
    return metrics.statuses.incr(labels);
}

pub fn up(labels: Metrics.UpL) !void {
    return metrics.up.set(labels, 1);
}

pub fn down(labels: Metrics.UpL) !void {
    return metrics.up.set(labels, 0);
}

pub fn initialize(allocator: std.mem.Allocator, comptime opts: m.RegistryOpts) !void {
    metrics = .{
        .statuses = try Metrics.Status.init(allocator, "kwatcher_https_statuses", .{}, opts),
        .up = try Metrics.Up.init(allocator, "up", .{}, opts),
    };
}

pub fn write(writer: anytype) !void {
    return m.write(&metrics, writer);
}

fn sendMetrics(context: *tk.Context) !void {
    context.res.header("content-type", "text/plain; version=0.0.4");
    var keyIter = metrics.up.impl.values.keyIterator();
    while (keyIter.next()) |key| {
        try down(key.*);
    }
    const client = try context.injector.get(*KWatcherClient);
    try client.handleConsume(std.time.ns_per_s / 200);
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
