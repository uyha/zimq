const std = @import("std");
const log = std.log.warn;
const zmq = @import("libzmq");
const errno = @import("errno.zig").errno;
const strerror = @import("errno.zig").strerror;

pub const Timers = opaque {
    const Self = @This();
    pub fn init() *Self {
        // The doc says it will always return a valid pointer
        return @ptrCast(zmq.zmq_timers_new().?);
    }

    pub fn deinit(self: *Self) void {
        var temp: ?*Self = self;
        _ = zmq.zmq_timers_destroy(&temp);
    }

    test init {
        var timer: *Timers = Timers.init();
        timer.deinit();
    }

    pub const TimerFn = fn (id: c_int, arg: ?*anyopaque) callconv(.c) void;

    pub const Error = error{ TimersInvalid, Unexpected };

    pub const AddError = Error;
    pub fn add(
        self: *Self,
        /// milliseconds
        interval: usize,
        handler: *const TimerFn,
        arg: *anyopaque,
    ) AddError!c_int {
        return switch (zmq.zmq_timers_add(self, interval, handler, arg)) {
            -1 => switch (errno()) {
                zmq.EFAULT => AddError.TimersInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return AddError.Unexpected;
                },
            },
            else => |id| id,
        };
    }

    pub const CancelError = Error || error{TimerNotExist};
    pub fn cancel(self: *Self, id: c_int) CancelError!void {
        if (zmq.zmq_timers_cancel(self, id) == -1) {
            return switch (errno()) {
                zmq.EFAULT => CancelError.TimersInvalid,
                zmq.EINVAL => CancelError.TimerNotExist,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return CancelError.Unexpected;
                },
            };
        }
    }

    pub const SetIntervalError = Error || error{TimerNotExist};
    pub fn setInterval(
        self: *Self,
        id: c_int,
        /// milliseconds
        interval: usize,
    ) SetIntervalError!void {
        if (zmq.zmq_timers_set_interval(self, id, interval) == -1) {
            return switch (errno()) {
                zmq.EFAULT => SetIntervalError.TimersInvalid,
                zmq.EINVAL => SetIntervalError.TimerNotExist,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return SetIntervalError.Unexpected;
                },
            };
        }
    }

    pub const ResetError = Error || error{TimerNotExist};
    pub fn reset(self: *Self, id: c_int) ResetError!void {
        if (zmq.zmq_timers_reset(self, id) == -1) {
            return switch (errno()) {
                zmq.EFAULT => ResetError.TimersInvalid,
                zmq.EINVAL => ResetError.TimerNotExist,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ResetError.Unexpected;
                },
            };
        }
    }

    pub const TimeoutError = error{ TimersInvalid, NoActiveTimer };
    pub fn timeout(self: *Self) TimeoutError!c_long {
        return switch (zmq.zmq_timers_timeout(self)) {
            -1 => switch (errno()) {
                zmq.EFAULT => TimeoutError.TimersInvalid,
                else => TimeoutError.NoActiveTimer,
            },
            else => |time| time,
        };
    }

    pub const ExecuteError = Error;
    pub fn execute(self: *Self) ExecuteError!void {
        if (zmq.zmq_timers_execute(self) == -1) {
            return switch (errno()) {
                zmq.EFAULT => ExecuteError.TimersInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ExecuteError.Unexpected;
                },
            };
        }
    }

    test "timers functions" {
        const t = std.testing;

        const interval = 100;

        var timers: *Timers = Timers.init();
        defer timers.deinit();

        const Arg = struct {
            invoked: bool = false,
            handle: ?c_int = null,
            same: bool = false,
        };

        var in: Arg = .{};

        const callback = struct {
            fn callback(id: c_int, arg: ?*anyopaque) callconv(.c) void {
                const actual_arg: *Arg = @ptrCast(@alignCast(arg.?));

                actual_arg.invoked = true;
                actual_arg.same = actual_arg.handle.? == id;
            }
        }.callback;

        const handle = try timers.add(interval, &callback, &in);
        in.handle = handle;

        try t.expect(try timers.timeout() <= interval);

        std.Thread.sleep((interval + 1) * 1_000_000);
        try timers.reset(handle);
        try timers.execute();
        try t.expect(!in.invoked);
        try t.expect(!in.same);

        try timers.setInterval(handle, interval);
        std.Thread.sleep((interval + 1) * 1_000_000);
        try timers.execute();
        try t.expect(in.invoked);
        try t.expect(in.same);

        in.invoked = false;
        in.same = false;
        try timers.setInterval(handle, interval);
        try timers.cancel(handle);
        std.Thread.sleep((interval + 1) * 1_000_000);
        try timers.execute();
        try t.expect(!in.invoked);
        try t.expect(!in.same);
    }
};
