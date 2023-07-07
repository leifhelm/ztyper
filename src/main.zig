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
    ScreenApp.init(allocator) catch |err| {
        _ = stderr.write("Cannot initialze application\n") catch {};
        exitError(err);
    };
    defer ScreenApp.deinit();
    ScreenApp.registerSigwinchHandler() catch |err| exitError(err);
    ScreenApp.run() catch |err| exitError(err);
}

const expect = std.testing.expect;
const builtin = @import("builtin");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    ScreenApp.resetTerm();
    std.debug.panicImpl( stack_trace, ret_addr, message);
}

test {
    std.testing.refAllDecls(@This());
}
