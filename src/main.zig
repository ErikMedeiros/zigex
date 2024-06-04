const std = @import("std");
const Regex = @import("regex.zig");

pub fn main() !void {
    const allocator = std.heap.raw_c_allocator;

    var re = Regex.init(allocator, "^a(b|c) (d|e)$", .{}) catch |err| {
        var buffer: [128]u8 = undefined;
        const msg = Regex.errorMessage(err, &buffer);
        std.log.err("{s}", .{msg});
        return err;
    };
    defer re.deinit();

    const matches = re.captures(3, "ac e") catch |err| {
        var buffer: [128]u8 = undefined;
        const msg = Regex.errorMessage(err, &buffer);
        std.log.err("{s}", .{msg});
        return err;
    };
    std.log.info("matches: {?s}", .{matches});
}
