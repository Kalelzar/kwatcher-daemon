const std = @import("std");
const kwatcher = @import("kwatcher");

const KEventRepo = @import("kwatcher-daemon").repo.KEvent;
const Cursor = @import("kwatcher-daemon").query.Cursor;

const EventService = @This();

repo_factory: *KEventRepo.FromPool,

pub fn init(repo: *KEventRepo.FromPool) EventService {
    return .{
        .repo_factory = repo,
    };
}

pub fn get(self: *const EventService, allocator: std.mem.Allocator, cursor: Cursor) !std.ArrayListUnmanaged(KEventRepo.KEventRow) {
    var repo = try self.repo_factory.yield();
    defer repo.deinit();
    return repo.get(allocator, cursor);
}
