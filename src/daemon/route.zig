const std = @import("std");
const kwatcher = @import("kwatcher");
const repo = @import("kwatcher-daemon").repo;

pub fn @"consume amq.direct/heartbeat"(
    heartbeat: kwatcher.schema.Heartbeat.V1(std.json.Value),
    arena: *kwatcher.mem.InternalArena,
    kclient_repo: *repo.KClient,
) !void {
    const allocator = arena.allocator();
    const props = try std.json.stringifyAlloc(
        allocator,
        heartbeat.properties,
        .{ .whitespace = .indent_2 },
    );

    const client = try kclient_repo.getOrCreate(
        arena,
        kwatcher.schema.ClientInfo.fromV1(&heartbeat.client),
        kwatcher.schema.UserInfo.fromV1(allocator, &heartbeat.user),
    );

    std.log.info("{any}", .{client});

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
