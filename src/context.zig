const zmq = @import("libzmq");
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

    pub const SetError = error{ OptionInvalid, Unexpected };
    pub fn set(self: *Self, comptime option: SetOption, value: SetOptionType(option)) SetError!void {
        const Value = @TypeOf(value);
        const raw_value = switch (Value) {
            bool => @as(c_int, @intFromBool(value)),
            c_int, [:0]const u8 => value,
            else => @compileError("Unrecognized type: " ++ @typeName(Value)),
        };
        const RawValue = @TypeOf(raw_value);

        const ptr, const size = switch (RawValue) {
            c_int => .{ &raw_value, @sizeOf(RawValue) },
            [:0]const u8 => .{ raw_value.ptr, raw_value.len + 1 },
            else => @compileError("Unrecognized type: " ++ @typeName(RawValue)),
        };
        if (zmq.zmq_ctx_set_ext(
            self,
            @intFromEnum(option),
            ptr,
            size,
        ) == -1) {
            switch (errno()) {
                zmq.EINVAL => return SetError.OptionInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return SetError.Unexpected;
                },
            }
        }
    }

    pub const GetError = error{Unexpected};
    // The underlying function `zmq_ctx_get_ext` does not set the actual length of passed in
    // size pointer despite what the document says. Hence, the slice pointer passed in for
    // .thread_name_prefix will not have its `len` updated.
    pub fn get(self: *Self, comptime option: GetOption, out: *GetOptionType(option)) GetError!void {
        const Out = @TypeOf(out);

        const result = get: switch (Out) {
            *bool => {
                var value: c_int = undefined;
                var size: usize = @sizeOf(@TypeOf(value));

                const result = zmq.zmq_ctx_get_ext(
                    self,
                    @intFromEnum(option),
                    &value,
                    &size,
                );
                if (result != -1) {
                    out.* = value != 0;
                }

                break :get result;
            },
            *[:0]u8 => {
                const result = zmq.zmq_ctx_get_ext(
                    self,
                    @intFromEnum(option),
                    out.ptr,
                    &out.len,
                );

                // There is a bug in libzmq's implementation that does not
                // actually set the length of the output so it has to be done
                // manually
                if (result == 0) {
                    out.len = std.mem.indexOfSentinel(u8, 0, out.ptr);
                }

                break :get result;
            },
            *c_int => {
                var size: usize = @sizeOf(@TypeOf(out.*));

                const result = zmq.zmq_ctx_get_ext(
                    self,
                    @intFromEnum(option),
                    out,
                    &size,
                );

                break :get result;
            },
            else => @compileError("Unrecognized type: " ++ @typeName(Out)),
        };

        if (result == -1) {
            switch (errno()) {
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return SetError.Unexpected;
                },
            }
        }
    }

    test set {
        var context: *Self = try .init();
        defer context.deinit();

        try context.set(.blocky, true);
        try context.set(.thread_name_prefix, "somename");

        var blocky: bool = undefined;
        try context.get(.blocky, &blocky);
        try std.testing.expect(blocky);

        var buffer: [255:0]u8 = undefined;
        var thread_name: [:0]u8 = &buffer;
        try context.get(.thread_name_prefix, &thread_name);
        try std.testing.expectEqualSentinel(u8, 0, "somename", thread_name);
    }
    test get {
        var context: *Self = try .init();
        defer context.deinit();

        try context.set(.blocky, true);
        try context.set(.thread_name_prefix, "somename");

        var blocky: bool = undefined;
        try context.get(.blocky, &blocky);
        try std.testing.expect(blocky);

        var buffer: [255:0]u8 = undefined;
        var thread_name: [:0]u8 = &buffer;
        try context.get(.thread_name_prefix, &thread_name);
        try std.testing.expectEqualSentinel(u8, 0, "somename", thread_name);
    }
};
