pub const KeyPair = struct {
    public_key: [40:0]u8 = @splat(0),
    secret: [40:0]u8 = @splat(0),
};
pub fn keyPair() KeyPair {
    if (!config.curve) {
        @compileError("CURVE is not enabled");
    }

    var result: KeyPair = undefined;

    assert(zmq.zmq_curve_keypair(&result.public_key, &result.secret) == 0);
    return result;
}
pub fn publicKey(secret: *const [40:0]u8) [40:0]u8 {
    if (!config.curve) {
        @compileError("CURVE is not enabled");
    }

    var result: [40:0]u8 = @splat(0);
    assert(zmq.zmq_curve_public(&result, secret) == 0);
    return result;
}

test "keyPair and publicKey" {
    const t = std.testing;

    if (config.curve) {
        const pair = keyPair();
        try t.expectEqualStrings(&pair.public_key, &publicKey(&pair.secret));
    }
}

const zmq = @import("libzmq");
const config = @import("config");

const std = @import("std");
const assert = std.debug.assert;
