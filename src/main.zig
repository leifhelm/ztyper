const std = @import("std");

const exit = @import("error.zig").exit;
const exitError = @import("error.zig").exitError;
const ScreenApp = @import("app.zig").Application.ScreenApp;

pub fn main() !void {
    var stderr = std.io.getStdErr();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            _ = stderr.write("\nLEAKED MEMORY\n") catch {};
            exit(.LeakedMemory);
        }
    }
    const allocator = gpa.allocator();
    var app = ScreenApp.init(allocator) catch |err| {
        _ = stderr.write("Cannot initialze application\n") catch {};
        exitError(err);
    };
    defer app.deinit();
    app.registerSigwinchHandler() catch |err| exitError(err);
    app.run() catch |err| exitError(err);
}

const expect = std.testing.expect;
const builtin = @import("builtin");

test {
    std.testing.refAllDecls(@This());
}
