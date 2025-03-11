const std = @import("std");
const schema = @import("kwatcher").schema;

const metric = @import("../metrics.zig");

pub fn @"consume amq.direct/metrics"(
    metrics: schema.Metrics.V1(),
    persistent: *std.heap.ArenaAllocator,
) !void {
    const alloc = persistent.allocator();

    try metric.collected.put(
        alloc,
        try alloc.dupe(u8, metrics.client.name),
        try alloc.dupe(u8, metrics.metrics),
    );

    try metric.update(.{
        .job = metrics.client.name,
    });
}
