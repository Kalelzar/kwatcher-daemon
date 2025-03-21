const std = @import("std");
const log = std.log.scoped(.kevent);
const pg = @import("pg");
const uuid = @import("uuid");
const kwatcher = @import("kwatcher");
const KClient = @import("kclient.zig");
const json = @import("../json.zig");
const Cursor = @import("../models/query.zig").Cursor;

const KEventRepo = @This();

conn: *pg.Conn,

pub const KEventRow = struct {
    id: []const u8, // UUID
    kclient: []const u8, // UUID FK(kclient)
    user_id: []const u8, // TEXT
    event_type: []const u8, // TEXT
    start_time: i64, // TimestampTZ
    end_time: i64, // TimestampTZ
    properties: []const u8, // JSONB
};

pub fn init(pool: *pg.Pool) !KEventRepo {
    return .{
        .conn = try pool.acquire(),
    };
}

pub const FromPool = struct {
    pool: *pg.Pool,
    pub fn init(pool: *pg.Pool) !FromPool {
        return .{
            .pool = pool,
        };
    }

    pub fn yield(self: *FromPool) !KEventRepo {
        return .init(self.pool);
    }
};

pub fn deinit(self: *KEventRepo) void {
    self.conn.release();
}
pub fn get(self: *KEventRepo, allocator: std.mem.Allocator, cursor: Cursor) !std.ArrayListUnmanaged(KEventRow) {
    const query =
        \\ select * from kevent
        \\    order by end_time DESC
        \\    limit $2
        \\    offset $1;
    ;

    const result = self.conn.queryOpts(
        query,
        .{ cursor.drop, cursor.take },
        .{
            .column_names = true,
            .allocator = allocator,
        },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                log.err(
                    "[{s}] Encountered an error ({s}) while retrieving a client: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while retrieving a client.\n", .{});
            }
            return e;
        },
        else => return e,
    };
    defer result.deinit();

    var arr = try std.ArrayListUnmanaged(KEventRow).initCapacity(allocator, result.number_of_columns);

    while (try result.next()) |row| {
        const data = try row.to(KEventRow, .{ .map = .name, .allocator = allocator });
        try arr.append(
            allocator,
            data,
        );
    }

    return arr;
}

pub fn bump(
    self: *KEventRepo,
    event: KEventRow,
    new_end_time: i64,
) !KEventRow {
    const query =
        \\ update kevent
        \\ set end_time = $1
        \\ where id = $2
    ;

    _ = self.conn.exec(
        query,
        .{ new_end_time, event.id },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                log.err(
                    "[{s}] Encountered an error ({s}) while updating an event: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while updating an event.\n", .{});
            }
            return e;
        },
        else => return e,
    };

    return KEventRow{
        .id = event.id,
        .kclient = event.kclient,
        .user_id = event.user_id,
        .event_type = event.event_type,
        .start_time = event.start_time,
        .end_time = new_end_time,
        .properties = event.properties,
    };
}

pub fn createEvent(
    self: *KEventRepo,
    event_type: []const u8,
    time: i64,
    body: []const u8,
    client: KClient.KClientRow,
    user: kwatcher.schema.UserInfo,
) !KEventRow {
    const query =
        \\ insert into kevent (id, kclient, user_id, event_type, start_time, end_time, properties)
        \\   values($1, $2, $3, $4, $5, $6, $7)
    ;
    const id = uuid.v7.new();
    const urn = uuid.urn.serialize(id);
    _ = self.conn.exec(
        query,
        .{
            &urn,
            client.id,
            user.id,
            event_type,
            time,
            time,
            body,
        },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                log.err(
                    "[{s}] Encountered an error ({s}) while creating an event: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while creating an event.\n", .{});
            }
            return e;
        },
        else => return e,
    };

    return .{
        .id = &urn,
        .kclient = client.id,
        .user_id = user.id,
        .event_type = event_type,
        .start_time = time,
        .end_time = time,
        .properties = body,
    };
}

pub fn extendEvent(
    self: *KEventRepo,
    event_type: []const u8,
    time: i64,
    body: []const u8,
    arena: *kwatcher.mem.InternalArena,
    client: KClient.KClientRow,
    user: kwatcher.schema.UserInfo,
) !KEventRow {
    const alloc = arena.allocator();
    //const current_time = std.time.microTimestamp();
    const row = self.conn.rowOpts(
        \\ select * from kevent
        \\    where event_type = $1 and user_id = $2 and kclient = $3
        \\    order by end_time DESC
        \\    limit 1;
    ,
        .{ event_type, user.id, client.id },
        .{
            .column_names = true,
            .allocator = alloc,
        },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                log.err(
                    "[{s}] Encountered an error ({s}) while retrieving the latest event of type {s}: \n{s}\n",
                    .{ pge.severity, pge.code, event_type, pge.message },
                );
            } else {
                log.err(
                    "Encountered an unknown error while retrieving the latest event of type {s}.\n",
                    .{event_type},
                );
            }
            return e;
        },
        else => return e,
    };
    if (row) |_found| {
        // This event exists and we should extend it.
        // This is actually fairly involved as we have to check several things.
        // 1. Is this event in the future relative to the current heartbeat?
        //    It is possible that a heartbeat is processed after another that happened in the future.
        //    In that case we have a few options:
        //    - It's the same event: We just return and do nothing since the event is already extended past us.
        //      NOTE: This is incorrect. Or rather it is incomplete. It is possible that another event happened
        //            between us and them:  A <- B <- A
        //            In that case we technically should extend the first A event, and shrink the first B
        //            but this is overly complex and we are (for now) fine with losing 5 seconds in very rare occasions.
        //    - It's a different event: Same as above. We just discard it (for now).
        //      Eventually we should just extend the previous event and shrink the current.
        // 2. Is this the same event? (Properties semantically match).
        //    - Yes: Extend the end_time of the event.
        //    - No: Create a new event.
        var found = _found;

        const data = try found.to(KEventRow, .{ .map = .name, .allocator = alloc });
        found.deinit() catch {};
        if (data.end_time > time) {
            // 1) We are in the future apparently.
            if (try extends(alloc, data.properties, body)) {
                return data;
            } else {
                // Branch duplication is deliberate to remind us that this should be handled differently
                // FIXME: Extend the previous event and shrink the current.
                return data;
            }
        } else {
            // TODO: How do we handle situations were there is a gap between events? 5-10 seconds we can just merge. Maybe even 1-5 minutes.
            // Anything more than that though? They should probably be separate. Add a configuration value for it and check.
            if (try extends(alloc, data.properties, body)) {
                return try self.bump(data, time);
            } else {
                return try self.createEvent(event_type, time, body, client, user);
            }
        }

        return data;
    } else {
        // New event. Create it.
        return try self.createEvent(event_type, time, body, client, user);
    }
}

pub fn extends(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !bool {
    const pa = try std.json.parseFromSlice(std.json.Value, allocator, a, .{});
    defer pa.deinit();
    const pb = try std.json.parseFromSlice(std.json.Value, allocator, b, .{});
    defer pb.deinit();

    return json.eql(pa.value, pb.value);
}
