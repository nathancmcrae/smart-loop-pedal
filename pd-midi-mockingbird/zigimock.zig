// NathanMcRae.name
// 2021-01-06

const std = @import("std");
const mock = @cImport(@cInclude("midimock.h"));

export fn bar(b: c_int) bool {
    return b > 5;
}
