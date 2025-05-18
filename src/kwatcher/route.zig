const std = @import("std");
const schema = @import("kwatcher").schema;

const metric = @import("../metrics.zig");

pub fn @"consume amq.direct/metrics/metrics"(
    metrics: schema.Metrics.V1(),
) !void {
    metric.collected_mutex.lock();
    defer metric.collected_mutex.unlock();
    try metric.collected.put(metrics.client.name, metrics.metrics);

    try metric.update(.{
        .job = metrics.client.name,
    });
}
