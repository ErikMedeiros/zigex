const std = @import("std");
const re = @cImport(@cInclude("regex.h"));

const Self = @This();
const SIZEOF = 64;

ptr: *re.regex_t,
allocator: std.mem.Allocator,

pub const CompileFlags = packed struct(i32) {
    extendend: bool = true,
    insensitive: bool = false,
    nosub: bool = false,
    newline: bool = false,

    _: i28 = 0,
};

pub const Error = error{
    /// Invalid regular expression.
    REG_BADPAT,
    /// Invalid collating element referenced.
    REG_ECOLLATE,
    /// Invalid character class type referenced.
    REG_ECTYPE,
    /// Trailing \ in pattern.
    REG_EESCAPE,
    /// Number in \digit invalid or in error.
    REG_ESUBREG,
    /// [ ] imbalance.
    REG_EBRACK,
    /// \( \) or ( ) imbalance.
    REG_EPAREN,
    /// \{ \} imbalance.
    REG_EBRACE,
    /// Content of \{ \} invalid: not a number, number too large, more than two numbers, first larger than second.
    REG_BADBR,
    /// Invalid endpoint in range expression.
    REG_ERANGE,
    /// ?, * or + not preceded by valid regular expression.
    REG_BADRPT,
    /// The implementation does not support the function.
    REG_ENOSYS,
};

pub fn init(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    flags: CompileFlags,
) (std.mem.Allocator.Error || Error)!Self {
    const bytes = try allocator.alloc(u8, SIZEOF);
    errdefer allocator.free(bytes);
    const ptr: *re.regex_t = @alignCast(@ptrCast(bytes));

    switch (re.regcomp(ptr, @ptrCast(pattern), @bitCast(flags))) {
        0 => {},
        re.REG_BADPAT => return Error.REG_BADPAT,
        re.REG_ECOLLATE => return Error.REG_ECOLLATE,
        re.REG_ECTYPE => return Error.REG_ECTYPE,
        re.REG_EESCAPE => return Error.REG_EESCAPE,
        re.REG_ESUBREG => return Error.REG_ESUBREG,
        re.REG_EBRACK => return Error.REG_EBRACK,
        re.REG_EPAREN => return Error.REG_EPAREN,
        re.REG_EBRACE => return Error.REG_EBRACE,
        re.REG_BADBR => return Error.REG_BADBR,
        re.REG_ERANGE => return Error.REG_ERANGE,
        re.REG_ESPACE => return std.mem.Allocator.Error.OutOfMemory,
        re.REG_BADRPT => return Error.REG_BADRPT,
        re.REG_ENOSYS => return Error.REG_ENOSYS,
        else => unreachable,
    }

    return .{ .ptr = ptr, .allocator = allocator };
}

pub fn deinit(self: Self) void {
    re.regfree(self.ptr);

    const bytes: [*]u8 = @ptrCast(self.ptr);
    self.allocator.free(bytes[0..SIZEOF]);
}
