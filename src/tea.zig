/// TEA - The Elm Architecture
const std = @import("std");
const Allocator = std.mem.Allocator;

const BufferSlice = @import("buffer.zig").BufferSlice;
pub const TerminalEvent = @import("mibu").events.Event;

pub fn Program(comptime Model: type, comptime Msg: type) type {
    return struct {
        const Self = @This();

        fn noDeinit(model: *Model) void {
            _ = model;
        }

        init: std.meta.FnPtr(fn (allocator: Allocator) Model),
        deinit: std.meta.FnPtr(fn (model: *Model) void) = noDeinit,
        view: std.meta.FnPtr(fn (model: Model, buffer: BufferSlice) void),
        update: std.meta.FnPtr(fn (msg: Msg, model: *Model) Cmd),
        onTerminalEvent: std.meta.FnPtr(fn (TerminalEvent) Msg),
    };
}

pub fn Update(comptime Model: type) type {
    return struct {
        model: Model,
        cmd: Cmd,
    };
}

pub const Cmd = union(enum) { none, exit };

const expectEqual = std.testing.expectEqual;

test "Program" {
    const Model = struct { counter: isize };
    const Msg = union(enum) {
        CountUp,
        CountDown,
    };
    const Application = struct {
        fn init(allocator: Allocator) Model {
            _ = allocator;
            return .{ .counter = 0 };
        }
        fn view(model: Model, buffer: BufferSlice) void {
            _ = model;
            _ = buffer;
        }
        fn update(msg: Msg, model: *Model) Cmd {
            switch (msg) {
                .CountUp => model.counter += 1,
                .CountDown => model.counter -= 1,
            }
            return .none;
        }
        fn onTerminalEvent(event: TerminalEvent) Msg {
            _ = event;
            return .CountUp;
        }
        const program = Program(Model, Msg){
            .init = init,
            .view = view,
            .update = update,
            .onTerminalEvent = onTerminalEvent,
        };
    };
    const App = Application.program;
    var model = App.init();
    try expectEqual(Cmd.none, App.update(.CountUp, &model));
    try expectEqual(@as(isize, 1), model.counter);
}
