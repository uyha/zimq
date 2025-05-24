const zmq = @import("libzmq");

pub const AtomicCounter = opaque {
    const Self = @This();
    pub fn init() ?*Self {
        return @ptrCast(zmq.zmq_atomic_counter_new());
    }

    pub fn deinit(self: **Self) void {
        zmq.zmq_atomic_counter_destroy(@ptrCast(self));
    }

    test init {
        var aCounter: *Self = init().?;
        defer deinit(&aCounter);
    }

    test deinit {
        var aCounter: *Self = init().?;
        defer deinit(&aCounter);
    }

    pub fn set(self: *Self, new_value: c_int) void {
        return zmq.zmq_atomic_counter_set(self, new_value);
    }
    pub fn value(self: *Self) c_int {
        return zmq.zmq_atomic_counter_value(self);
    }
    pub fn inc(self: *Self) c_int {
        return zmq.zmq_atomic_counter_inc(self);
    }

    /// Return if the counter is greater than 1 after decrement
    pub fn dec(self: *Self) bool {
        return zmq.zmq_atomic_counter_dec(self) != 0;
    }

    test value {
        const t = @import("std").testing;
        var counter: *Self = init().?;
        defer deinit(&counter);

        try t.expectEqual(0, counter.value());
    }
    test set {
        const t = @import("std").testing;
        var counter: *Self = init().?;
        defer deinit(&counter);

        counter.set(1);
        try t.expectEqual(1, counter.value());
    }
    test inc {
        const t = @import("std").testing;
        var counter: *Self = init().?;
        defer deinit(&counter);

        try t.expectEqual(0, counter.inc());
        try t.expectEqual(1, counter.value());
    }
    test dec {
        const t = @import("std").testing;
        var counter: *Self = init().?;
        defer deinit(&counter);

        counter.set(1);
        try t.expect(!counter.dec());
        try t.expectEqual(0, counter.value());
        try t.expect(counter.dec());
        try t.expectEqual(-1, counter.value());
    }
};
