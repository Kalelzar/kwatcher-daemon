const std = @import("std");
const kwatcher = @import("kwatcher");

pub fn @"consume amq.direct/heartbeat"(
    heartbeat: kwatcher.schema.Heartbeat.V1(std.json.Value),
    arena: *std.heap.ArenaAllocator,
) !void {
    const allocator = arena.allocator();
    const props = try std.json.stringifyAlloc(
        allocator,
        heartbeat.properties,
        .{ .whitespace = .indent_2 },
    );

    std.log.info("[{}] Heartbeat/{s} from {s}.{s} by {s}@{s} ({s}):\n{s}", .{
        heartbeat.timestamp,
        heartbeat.event,
        heartbeat.client.name,
        heartbeat.client.version,
        heartbeat.user.username,
        heartbeat.user.hostname,
        heartbeat.user.id,
        props,
    });
}
