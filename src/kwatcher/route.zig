const std = @import("std");
const schema = @import("kwatcher").schema;

const metric = @import("../metrics.zig");

pub fn @"consume amq.direct/metrics"(
    metrics: schema.Metrics.V1(),
) !void {
    try metric.collected.put(metrics.client.name, metrics.metrics);

    try metric.update(.{
        .job = metrics.client.name,
    });
}
