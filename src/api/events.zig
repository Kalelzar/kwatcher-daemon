const std = @import("std");
const kwatcher = @import("kwatcher");
const tk = @import("tokamak");
const zmpl = @import("zmpl");

const Cursor = @import("kwatcher-daemon").query.Cursor;

const EventService = @import("../service/events.zig");
const model = @import("../model.zig");
const template = @import("../template.zig");

pub fn @"GET /get?"(req: tk.Request, data: *zmpl.Data, event_service: *EventService, cursor: Cursor) !template.Template {
    const alloc = req.arena;
    const rows = try event_service.get(alloc, cursor);
    const root = try data.object();
    const events = try data.array();
    try root.put("events", events);
    for (rows.items) |event| {
        const obj = try data.object();
        try obj.put("event_type", event.event_type);
        try obj.put("from", event.start_time);
        try obj.put("to", event.end_time);
        try obj.put("duration", event.end_time - event.start_time);
        try obj.put("user_id", event.user_id);
        try obj.put("data", event.properties);
        try events.append(obj);
    }
    try root.put("index", cursor.drop + @min(rows.items.len, cursor.take));
    try root.put("is_at_end", rows.items.len < cursor.take);
    return template.Template.init("list_events");
}

pub fn @"GET /"(data: *zmpl.Data) !template.Template {
    _ = try data.object();
    return template.Template.init("event");
}
