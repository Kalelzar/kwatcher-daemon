const std = @import("std");
const tk = @import("tokamak");
const httpz = @import("httpz");
const pg = @import("pg");
const m = @import("metrics");
const kwatcher = @import("kwatcher");
const KWatcherClient = @import("alias.zig").KWatcherClient;

var metrics = m.initializeNoop(Metrics);
pub var collected = std.StringHashMapUnmanaged([]const u8){};

const Metrics = struct {
    statuses: Status,
    up: Up,
    timeOfLastUpdate: TimeOfLastUpdate,

    const StatusL = struct { status: u16 };
    const Status = m.CounterVec(u32, StatusL);
    const UpL = struct { job: []const u8 };
    const Up = m.GaugeVec(u1, UpL);
    const TimeOfLastUpdateL = struct { job: []const u8 };
    const TimeOfLastUpdate = m.GaugeVec(i64, TimeOfLastUpdateL);
};

pub fn status(labels: Metrics.StatusL) !void {
    return metrics.statuses.incr(labels);
}

pub fn update(labels: Metrics.TimeOfLastUpdateL) !void {
    return metrics.timeOfLastUpdate.set(labels, std.time.timestamp());
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
        .timeOfLastUpdate = try Metrics.TimeOfLastUpdate.init(allocator, "kwatcher_time_of_last_update", .{}, opts),
    };
}

pub fn write(writer: anytype) !void {
    return m.write(&metrics, writer);
}

fn sendMetrics(context: *tk.Context) !void {
    context.res.header("content-type", "text/plain; version=0.0.4");

    const client = try context.injector.get(*KWatcherClient);
    client.handleConsume(std.time.ns_per_s / 200) catch {
        try client.reset();
    };
    const writer = context.res.writer();

    var iter = metrics.timeOfLastUpdate.impl.values.iterator();
    const now = std.time.timestamp();
    while (iter.next()) |entry| {
        if (entry.value_ptr.*.value >= now - 15) { // TODO: This should be configurable
            try up(.{ .job = entry.key_ptr.*.job });
        } else {
            try down(.{ .job = entry.key_ptr.*.job });
        }
    }

    var collected_iter = collected.valueIterator();
    while (collected_iter.next()) |collected_metrics| {
        try writer.writeAll(collected_metrics.*);
    }
    try httpz.writeMetrics(writer);
    try pg.writeMetrics(writer);
    try write(writer);
    context.responded = true;
}

pub fn route() tk.Route {
    const H = struct {
        fn handleMetrics(context: *tk.Context) anyerror!void {
            sendMetrics(context) catch |e| {
                std.log.err("Encountered error while sending metrics: {}", .{e});
            };
            return;
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
