const zmq = @import("libzmq");

pub const EncodeError = error{
    BufferTooSmall,
    /// The string's length is not divisible by 4
    StringInvalid,
};
pub fn encode(dest: [:0]u8, data: []const u8) EncodeError!usize {
    // This is safe to do since the length of `data` must to be divisible by 4, so the
    // result of `data.len * 5 / 4` will always be a whole number. If it is not, then
    // `zmq_z85_encode` will error out anyway.
    const len = data.len * 5 / 4;
    if (dest.len < len) {
        return EncodeError.BufferTooSmall;
    }

    if (zmq.zmq_z85_encode(dest.ptr, data.ptr, data.len)) |_| {
        return len;
    } else {
        return EncodeError.StringInvalid;
    }
}

pub const DecodeError = error{
    BufferTooSmall,
    /// The string has fewer than 5 characters or its length is not divisible by 5
    StringInvalid,
};
pub fn decode(dest: []u8, string: [:0]const u8) DecodeError!usize {
    // This is safe to do since the length of `string` must to be divisible by 5, so the
    // result of `string.len * 4 / 5` will always be a whole number. If it is not, then
    // `zmq_z85_decode` will error out anyway.
    const len = string.len * 4 / 5;
    if (dest.len < len) {
        return DecodeError.BufferTooSmall;
    }

    if (zmq.zmq_z85_decode(dest.ptr, string.ptr)) |_| {
        return len;
    } else {
        return DecodeError.StringInvalid;
    }
}

test encode {
    const std = @import("std");
    const t = std.testing;

    var small_buffer: [4:0]u8 = .{ 0, 0, 0, 0 };
    var buffer: [256:0]u8 = undefined;
    buffer[256] = 0;

    try t.expectEqual(EncodeError.StringInvalid, encode(buffer[0..], "1234a"));
    try t.expectEqual(EncodeError.BufferTooSmall, encode(small_buffer[0..], "1234"));

    try t.expectEqual(DecodeError.StringInvalid, decode(buffer[0..], "1345"));
    try t.expectEqual(DecodeError.BufferTooSmall, decode(buffer[0..1], "12345"));

    const content = "1234";
    const encode_len = try encode(buffer[0..], content);
    try t.expectEqual(5, encode_len);

    var decode_buffer: [4]u8 = undefined;
    try t.expectEqual(4, decode(&decode_buffer, buffer[0..encode_len :0]));
    try t.expect(std.mem.eql(u8, &decode_buffer, content));
}
test decode {
    const std = @import("std");
    const t = std.testing;

    var small_buffer: [4:0]u8 = .{ 0, 0, 0, 0 };
    var buffer: [256:0]u8 = undefined;
    buffer[256] = 0;

    try t.expectEqual(EncodeError.StringInvalid, encode(buffer[0..], "1234a"));
    try t.expectEqual(EncodeError.BufferTooSmall, encode(small_buffer[0..], "1234"));

    try t.expectEqual(DecodeError.StringInvalid, decode(buffer[0..], "1345"));
    try t.expectEqual(DecodeError.BufferTooSmall, decode(buffer[0..1], "12345"));

    const content = "1234";
    const encode_len = try encode(buffer[0..], content);
    try t.expectEqual(5, encode_len);

    var decode_buffer: [4]u8 = undefined;
    try t.expectEqual(4, decode(&decode_buffer, buffer[0..encode_len :0]));
    try t.expect(std.mem.eql(u8, &decode_buffer, content));
}
