const std = @import("std");
const schema = @import("kwatcher").schema;

pub fn @"consume amq.direct/metrics"(
    metrics: schema.Metrics.V1(),
) void {
    std.log.info("Got metrics from: [{s}]{s}@{s} - {s}:{s}", .{
        metrics.user.id,
        metrics.user.username,
        metrics.user.hostname,
        metrics.client.name,
        metrics.client.version,
    });
}
