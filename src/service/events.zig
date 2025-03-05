const std = @import("std");
const kwatcher = @import("kwatcher");

const KEventRepo = @import("kwatcher-daemon").repo.KEvent;
const Cursor = @import("kwatcher-daemon").query.Cursor;

const EventService = @This();

repo: *KEventRepo,

pub fn init(repo: *KEventRepo.FromPool) EventService {
    return .{
        .repo = repo.yield(),
    };
}

pub fn get(self: *const EventService, allocator: std.mem.Allocator, cursor: Cursor) !std.ArrayListUnmanaged(KEventRepo.KEventRow) {
    return self.repo.get(allocator, cursor);
}
