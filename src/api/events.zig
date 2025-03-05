const std = @import("std");
const kwatcher = @import("kwatcher");
const tk = @import("tokamak");
const zmpl = @import("zmpl");

const Cursor = @import("kwatcher-daemon").query.Cursor;

const EventService = @import("../service/events.zig");
const model = @import("../model.zig");
const template = @import("../template.zig");

pub fn @"GET /get?"(arena: *std.heap.ArenaAllocator, data: *zmpl.Data, event_service: *EventService, cursor: Cursor) !template.Template {
    const alloc = arena.allocator();
    const rows = try event_service.get(alloc, cursor);
    const root = try data.object();
    const events = try data.array();
    try root.put("events", events);
    for (rows.items) |event| {
        const obj = try data.object();
        try obj.put("event_type", event.event_type);
        try obj.put("from", event.start_time);
        try obj.put("to", event.end_time);
        try events.append(obj);
    }
    try root.put("index", cursor.drop + cursor.take);
    return template.Template.init("list_events");
}

pub fn @"GET /"(data: *zmpl.Data) !template.Template {
    _ = try data.object();
    return template.Template.init("event");
}
