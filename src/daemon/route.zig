const std = @import("std");
const kwatcher = @import("kwatcher");
const repo = @import("kwatcher-event").repo;

pub fn @"consume amq.direct/heartbeat/heartbeat"(
    heartbeat: kwatcher.schema.Heartbeat.V1(std.json.Value),
    arena: *kwatcher.mem.InternalArena,
    kclient_repo: *repo.KClient,
    kevent_repo: *repo.KEvent,
) !void {
    const allocator = arena.allocator();

    var alloc_writer = std.Io.Writer.Allocating.init(allocator);
    var formatter = std.json.fmt(heartbeat.properties, .{ .whitespace = .indent_2 });

    try formatter.format(&alloc_writer.writer);

    const props = try alloc_writer.toOwnedSlice();

    const user_info = try kwatcher.schema.UserInfo.fromV1(allocator, &heartbeat.user);

    const client = try kclient_repo.getOrCreate(
        arena,
        kwatcher.schema.ClientInfo.fromV1(&heartbeat.client),
        user_info,
    );

    // For what it is worth -- the client we created is still perfectly valid without the event
    // There is no need to delete it here.

    _ = try kevent_repo.extendEvent(
        heartbeat.event,
        heartbeat.timestamp,
        props,
        arena,
        client,
        user_info,
    );
}
