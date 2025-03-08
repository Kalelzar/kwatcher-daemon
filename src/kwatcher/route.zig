const std = @import("std");
const schema = @import("kwatcher").schema;

const metric = @import("../metrics.zig");

pub fn @"consume amq.direct/metrics"(
    metrics: schema.Metrics.V1(),
) !void {
    try metric.up(.{
        .job = metrics.client.name,
    });
    std.log.info("Got metrics from: [{s}]{s}@{s} - {s}:{s}", .{
        metrics.user.id,
        metrics.user.username,
        metrics.user.hostname,
        metrics.client.name,
        metrics.client.version,
    });
}
