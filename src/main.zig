const std = @import("std");
const Regex = @import("regex.zig");

pub fn main() !void {
    const allocator = std.heap.raw_c_allocator;

    const re = try Regex.init(allocator, "ab|c", .{});
    defer re.deinit();
}
