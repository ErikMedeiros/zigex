const std = @import("std");
const re = @cImport(@cInclude("regex.h"));

const Self = @This();
const SIZEOF = 64;

ptr: *re.regex_t,
allocator: std.mem.Allocator,

pub const InitFlags = packed struct(i32) {
    extendend: bool = true,
    insensitive: bool = false,
    nosub: bool = false,
    newline: bool = false,

    _: i28 = 0,
};

pub const Error = std.mem.Allocator.Error || error{
    /// REG_BADPAT
    /// Invalid regular expression.
    BadPattern,
    ///REG_ECOLLATE,
    /// Invalid collating element referenced.
    CollatingElementRef,
    /// REG_ECTYPE,
    /// Invalid character class type referenced.
    CharClassTypeRef,
    /// REG_EESCAPE,
    /// Trailing \ in pattern.
    TrailingBackslash,
    /// REG_ESUBREG,
    /// Number in \digit invalid or in error.
    BadDigit,
    /// REG_EBRACK,
    /// [ ] imbalance.
    UnmatchedBracket,
    /// REG_EPAREN,
    /// \( \) or ( ) imbalance.
    UnmatchedParentesis,
    /// REG_EBRACE,
    /// \{ \} imbalance.
    UnmatchedBrace,
    /// REG_BADBR,
    /// Content of \{ \} invalid: not a number, number too large, more than two numbers, first larger than second.
    BadBrace,
    // REG_ERANGE,
    /// Invalid endpoint in range expression.
    BadRange,
    // REG_BADRPT,
    /// ?, * or + not preceded by valid regular expression.
    BadRepetition,
    /// REG_ENOSYS,
    /// The implementation does not support the function.
    NotSupported,
};

pub fn init(allocator: std.mem.Allocator, pattern: []const u8, flags: InitFlags) Error!Self {
    const bytes = try allocator.alloc(u8, SIZEOF);
    errdefer allocator.free(bytes);
    const ptr: *re.regex_t = @alignCast(@ptrCast(bytes));

    const status = re.regcomp(ptr, @ptrCast(pattern), @bitCast(flags));
    if (errorFromStatus(status)) |err| return err;

    return .{ .ptr = ptr, .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    re.regfree(self.ptr);

    const bytes: [*]u8 = @ptrCast(self.ptr);
    self.allocator.free(bytes[0..SIZEOF]);
}

pub fn match(self: *Self, buffer: []const u8) !bool {
    const status = re.regexec(self.ptr, @ptrCast(buffer), 0, null, 0);
    if (errorFromStatus(status)) |err| return err;

    return status != re.REG_NOMATCH;
}

pub fn captures(self: *Self, comptime num: usize, buffer: []const u8) Error!?[num][]const u8 {
    if (num == 0) @compileError("you must capture at least one group.");

    var matches: [num]re.regmatch_t = undefined;

    var status = re.regexec(self.ptr, @ptrCast(buffer), num, &matches, 0);
    if (status == re.REG_NOMATCH) return null;
    if (errorFromStatus(status)) |err| return err;

    var index: usize = 0;
    while (status == 0) : (index += 1) {
        const end: usize = @intCast(matches[index].rm_eo);
        status = re.regexec(self.ptr, @ptrCast(buffer[end..]), num, &matches, re.REG_NOTBOL);
    }

    if (errorFromStatus(status)) |err| return err;

    var output: [num][]const u8 = undefined;
    for (matches, 0..) |matched, i| {
        const start: usize = @intCast(matched.rm_so);
        const end: usize = @intCast(matched.rm_eo);
        output[i] = buffer[start..end];
    }

    return output;
}

pub fn errorMessage(err: Error, buffer: []u8) []const u8 {
    const status: c_int = switch (err) {
        Error.BadPattern => re.REG_BADPAT,
        Error.CollatingElementRef => re.REG_ECOLLATE,
        Error.CharClassTypeRef => re.REG_ECTYPE,
        Error.TrailingBackslash => re.REG_EESCAPE,
        Error.BadDigit => re.REG_ESUBREG,
        Error.UnmatchedBracket => re.REG_EBRACK,
        Error.UnmatchedParentesis => re.REG_EPAREN,
        Error.UnmatchedBrace => re.REG_EBRACE,
        Error.BadBrace => re.REG_BADBR,
        Error.BadRange => re.REG_ERANGE,
        Error.OutOfMemory => re.REG_ESPACE,
        Error.BadRepetition => re.REG_BADRPT,
        Error.NotSupported => re.REG_ENOSYS,
    };

    const written = re.regerror(status, null, @ptrCast(buffer), buffer.len);
    return buffer[0..written];
}

fn errorFromStatus(status: c_int) ?Error {
    return switch (status) {
        0, re.REG_NOMATCH => null,
        re.REG_BADPAT => Error.BadPattern,
        re.REG_ECOLLATE => Error.CollatingElementRef,
        re.REG_ECTYPE => Error.CharClassTypeRef,
        re.REG_EESCAPE => Error.TrailingBackslash,
        re.REG_ESUBREG => Error.BadDigit,
        re.REG_EBRACK => Error.UnmatchedBracket,
        re.REG_EPAREN => Error.UnmatchedParentesis,
        re.REG_EBRACE => Error.UnmatchedBrace,
        re.REG_BADBR => Error.BadBrace,
        re.REG_ERANGE => Error.BadRange,
        re.REG_ESPACE => Error.OutOfMemory,
        re.REG_BADRPT => Error.BadRepetition,
        re.REG_ENOSYS => Error.NotSupported,
        else => unreachable,
    };
}
