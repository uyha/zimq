const zmq = @import("zmq");
const std = @import("std");
const log = std.log.warn;
const c = @import("std").c;

const opt = @import("context/option.zig");
const SetOption = opt.SetOption;
const SetOptionType = opt.SetOptionType;
const GetOption = opt.GetOption;
const GetOptionType = opt.GetOptionType;

const errno = @import("errno.zig").errno;
const strerror = @import("errno.zig").strerror;

pub const Context = opaque {
    const Self = @This();

    pub const InitError = error{ TooManyOpenFiles, Unexpected };
    pub inline fn init() InitError!*Self {
        if (zmq.zmq_ctx_new()) |handle| {
            return @ptrCast(handle);
        } else {
            switch (errno()) {
                zmq.EMFILE => return InitError.TooManyOpenFiles,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return InitError.Unexpected;
                },
            }
        }
    }

    pub fn deinit(self: *Self) void {
        _ = zmq.zmq_ctx_term(self);
    }

    pub const ShutdownError = error{ ContextInvalid, Unexpected };
    pub fn shutdown(self: *Self) ShutdownError!void {
        if (zmq.zmq_ctx_shutdown(self) == -1) {
            switch (errno()) {
                zmq.EFAULT => return ShutdownError.ContextInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ShutdownError.Unexpected;
                },
            }
        }
    }

    test init {
        var context: *Self = try .init();
        defer context.deinit();
    }
    test deinit {
        var context: *Self = try .init();
        defer context.deinit();
    }
    test shutdown {
        var context: *Self = try .init();
        defer context.deinit();

        try context.shutdown();
    }

    pub const SetError = error{ ThreadNamePrefixTooLong, Unexpected };
    pub fn set(self: *Self, comptime option: SetOption, value: SetOptionType(option)) SetError!void {
        const Value = @TypeOf(value);

        const error_message = std.fmt.comptimePrint(
            "Implementation error: {} is not expected",
            .{Value},
        );
        const raw_value = switch (Value) {
            bool => @as(c_int, @intFromBool(value)),
            c_int, [:0]const u8 => value,
            else => @compileError(error_message),
        };
        const RawValue = @TypeOf(raw_value);

        const ptr, const size = switch (RawValue) {
            c_int => .{ &raw_value, @sizeOf(RawValue) },
            [:0]const u8 => .{ raw_value.ptr, raw_value.len + 1 },
            else => @compileError(error_message),
        };

        if (option == .thread_name_prefix and size >= 16) {
            return SetError.ThreadNamePrefixTooLong;
        }

        if (zmq.zmq_ctx_set_ext(self, @backingInt(option), ptr, size) == -1) {
            switch (errno()) {
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return SetError.Unexpected;
                },
            }
        }
    }

    pub const GetError = error{Unexpected};
    pub fn get(self: *Self, comptime option: GetOption) GetError!GetOptionType(option) {
        const Output = GetOptionType(option);
        const error_message = std.fmt.comptimePrint(
            "Implementation error: {} is not expected",
            .{Output},
        );

        switch (Output) {
            bool, c_int => {},
            [:0]u8 => @compileError(std.fmt.comptimePrint(
                "{} returns a slice, use `getSlice` to get its value",
                .{option},
            )),
            else => @compileError(error_message),
        }

        const Value = if (Output == bool) c_int else Output;

        var output: Value = undefined;
        var size: usize = @sizeOf(Value);

        if (zmq.zmq_ctx_get_ext(self, @backingInt(option), &output, &size) == -1) {
            switch (errno()) {
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return GetError.Unexpected;
                },
            }
        }

        return if (Output == bool) output != 0 else output;
    }
    pub fn getSlice(
        self: *Self,
        comptime option: GetOption,
        buffer: [:0]u8,
    ) GetError![:0]u8 {
        const Output = GetOptionType(option);
        const error_message = std.fmt.comptimePrint(
            "Implementation error: {} is not expected",
            .{Output},
        );

        switch (Output) {
            bool, c_int => @compileError(std.fmt.comptimePrint(
                "{} returns a scalar, use `get` to get its value",
                .{option},
            )),
            [:0]u8 => {},
            else => @compileError(error_message),
        }

        var dummy_len = buffer.len;
        if (zmq.zmq_ctx_get_ext(self, @backingInt(option), buffer.ptr, &dummy_len) == -1) {
            switch (errno()) {
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return GetError.Unexpected;
                },
            }
        }

        // There is a bug in libzmq's implementation that does not
        // actually set the length of the output so it has to be done
        // manually
        const len = std.mem.findSentinel(u8, 0, buffer.ptr);

        return buffer[0..len :0];
    }

    test set {
        var context: *Self = try .init();
        defer context.deinit();

        try context.set(.blocky, true);
        try context.set(.thread_name_prefix, "somename");
    }
    test get {
        var context: *Self = try .init();
        defer context.deinit();

        try context.set(.blocky, true);

        const blocky: bool = try context.get(.blocky);
        try std.testing.expect(blocky);

        const thread_name_prefix = "0123456789ABCD";
        try context.set(.thread_name_prefix, thread_name_prefix);
        var buffer: [15:0]u8 = undefined;
        try std.testing.expectEqualStrings(
            thread_name_prefix,
            try context.getSlice(.thread_name_prefix, &buffer),
        );
    }
};
