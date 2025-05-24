const std = @import("std");
const zmq = @import("libzmq");

pub fn errno() c_int {
    return zmq.zmq_errno();
}

pub fn strerror(err: c_int) [:0]const u8 {
    const ptr: [*:0]const u8 = zmq.zmq_strerror(err);
    var len: usize = 0;
    while (ptr[len] != 0) {
        len += 1;
    }

    return ptr[0..len :0];
}

test strerror {
    try std.testing.expect(std.mem.eql(u8, strerror(1), "Operation not permitted"));
}
