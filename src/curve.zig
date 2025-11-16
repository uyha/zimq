pub const Error = error{NotSupported};
pub const KeyPair = struct {
    public_key: [40:0]u8 = @splat(0),
    secret: [40:0]u8 = @splat(0),
};
pub fn keyPair() if (config.curve) KeyPair else Error!void {
    var result: KeyPair = undefined;

    if (config.curve) {
        assert(zmq.zmq_curve_keypair(&result.public_key, &result.secret) == 0);
        return result;
    } else {
        return Error.NotSupported;
    }
}
pub fn publicKey(secret: *const [40:0]u8) if (config.curve) [40:0]u8 else Error!void {
    var result: [40:0]u8 = @splat(0);

    if (config.curve) {
        assert(zmq.zmq_curve_public(&result, secret) == 0);
        return result;
    } else {
        return Error.NotSupported;
    }
}

test "keyPair and publicKey" {
    const t = std.testing;

    if (config.curve) {
        const pair = keyPair();
        try t.expectEqualStrings(&pair.public_key, &publicKey(&pair.secret));
    } else {
        var dummy: [40:0]u8 = undefined;

        try t.expectEqual(Error.NotSupported, keyPair());
        try t.expectEqual(Error.NotSupported, publicKey(&dummy));
    }
}

const zmq = @import("libzmq");
const config = @import("config");

const std = @import("std");
const assert = std.debug.assert;
