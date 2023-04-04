const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const mibu = @import("mibu");
const term = mibu.term;
const events = mibu.events;
const RawTerm = term.RawTerm;
const TermSize = term.TermSize;

const Buffer = @import("buffer.zig").Buffer;
const BufferSlice = @import("buffer.zig").BufferSlice;
const Char = @import("buffer.zig").Char;
const Style = @import("buffer.zig").Style;
const Error = @import("error.zig").Error;

const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Rect = geometry.Rect;

const tea = @import("tea.zig");
const Program = tea.Program;
const Cmd = tea.Cmd;

pub fn Screen(comptime Model: type, comptime Msg: type, comptime program: Program(Model, Msg)) type {
    return struct {
        const Self = @This();

        model: Model,
        term: TerminalBuffer,

        pub fn init(allocator: Allocator) Error!Self {
            return .{
                .term = try TerminalBuffer.init(allocator),
                .model = program.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.term.deinit();
            program.deinit(&self.model);
        }

        pub fn registerSigwinchHandler(self: *Self) Error!void {
            const handlers = struct {
                var global_self: *Self = undefined;
                fn handleSigwinch(_: c_int) callconv(.C) void {
                    global_self.term.resize() catch return;
                    global_self.render() catch return;
                }
            };
            handlers.global_self = self;
            const act =
                .{
                .handler = .{ .handler = handlers.handleSigwinch },
                .mask = std.os.system.empty_sigset,
                .flags = 0,
            };
            if (std.os.system.sigaction(std.os.system.SIG.WINCH, &act, null) != 0) {
                return Error.IoError;
            }
        }

        fn render(self: *Self) Error!void {
            // self.root.window = self.term.buffer.getSlice().getBoundingBox();
            for(self.term.buffer.buffer.items) |*char|{
                char.* = Char.empty;
            }
            program.view(self.model, self.term.buffer.getSlice());
            self.term.swapBuffers() catch return Error.IoError;
        }
        pub fn run(self: *Self) Error!void {
            try self.render();
            var stdin = std.io.getStdIn();

            while (true) {
                const event = events.next(stdin) catch return Error.IoError;
                const msg = program.onTerminalEvent(event);
                switch (program.update(msg, &self.model)) {
                    .none => {},
                    .exit => break,
                }
                try self.render();
            }
        }
    };
}

// pub const SubScreen = struct {
//     const Self = @This();

//     visible: bool = true,
//     parent: ?*Self,
//     sub_screen: []Self = &[_]Self{},
//     widget: Widget = undefined,
//     window: Rect = undefined,

//     fn render(self: *Self, buffer: *Buffer) void {
//         if (self.visible) {
//             self.widget.render(buffer.slice(self.window) catch unreachable);
//             for (self.sub_screen) |*sub_screen| {
//                 sub_screen.render(buffer);
//             }
//         }
//     }
// };

pub fn Widget(comptime T: type, comptime Model: type) type {
    return struct {
        const Self = @This();

        value: T,
        renderImpl: std.meta.FnPtr(fn (value: T, model: Model, buffer: BufferSlice) void),
        vtable: VTable,

        const VTable = struct {
            // deinit: std.meta.FnPtr(fn (ptr: *anyopaque) void),
            render: std.meta.FnPtr(fn (value: T, model: Model, buffer: BufferSlice) void),
        };

        pub fn init(
            value: T,
            // comptime deinitFn: fn (ptr: @TypeOf(pointer)) void,
            comptime renderFn: fn (value: T, model: Model, buffer: BufferSlice) void,
        ) Self {
            // const Ptr = @TypeOf(pointer);
            // const ptr_info = @typeInfo(Ptr);

            // assert(ptr_info == .Pointer); // Must be a pointer
            // assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

            // const alignment = ptr_info.Pointer.alignment;
            // const gen = struct {
            //     // fn deinitImpl(ptr: *anyopaque) void {
            //     //     const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
            //     //     @call(.{ .modifier = .always_inline }, deinitFn, .{self});
            //     // }
            //     fn renderImpl(ptr: *anyopaque, buffer: BufferSlice) void {
            //         const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
            //         @call(.{ .modifier = .always_inline }, renderFn, .{ self, buffer });
            //     }
            //     const vtable = VTable{
            //         // .deinit = deinitImpl,
            //         .render = renderImpl,
            //     };
            // };

            return .{
                .value = value,
                .vtable = .{ .render = renderFn },
                // .vtable = &gen.vtable,
            };
        }
        fn render(self: Self, model: Model, buffer: BufferSlice) void {
            self.vtable.render(self.ptr, model, buffer);
        }
    };
}

const expectEqual = std.testing.expectEqual;

// test "Widget" {
//     const CharWidget = struct {
//         const Self = @This();
//         char: u21,
//         fn init(self: *Self, sub_screen: *SubScreen) void {
//             sub_screen.widget = self.widget();
//         }
//         fn render(self: *Self, buffer: BufferSlice) void {
//             buffer.draw(Char.default(self.char), .{ .x = 2, .y = 1 }) catch unreachable;
//         }
//         fn widget(self: *Self) Widget {
//             return Widget.init(self, render);
//         }
//     };
//     var buffer = try Buffer.init(std.testing.allocator, .{ .x = 10, .y = 12 });
//     defer buffer.deinit();
//     var root = SubScreen{
//         .parent = null,
//         .window = Rect.coords(0, 10, 0, 12),
//     };
//     var char_widget = CharWidget{ .char = 'b' };
//     char_widget.init(&root);
//     root.render(&buffer);
//     for (buffer.buffer.items) |char, index| {
//         if (index == 12) {
//             continue;
//         }
//         try expectEqual(Char.empty, char);
//     }
//     try expectEqual(Char.default('b'), buffer.buffer.items[12]);
// }

const TerminalBuffer = struct {
    const Self = @This();

    term: RawTerm,
    buffer: Buffer,
    bw: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(allocator: Allocator) Error!Self {
        const fd = std.io.getStdIn().handle;
        var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
        var raw_term = term.enableRawMode(fd, .blocking) catch return Error.IoError;
        const writer = bw.writer();
        mibu.private.enableAlternativeScreenBuffer(writer) catch return Error.IoError;
        mibu.cursor.hide(writer) catch return Error.IoError;

        const size = term.getSize(fd) catch return Error.IoError;

        bw.flush() catch return Error.IoError;
        return Self{
            .term = raw_term,
            .buffer = try Buffer.init(allocator, .{ .x = size.width, .y = size.height }),
            .bw = bw,
        };
    }

    fn deinit(self: *Self) void {
        self.buffer.deinit();
        mibu.private.disableAlternativeScreenBuffer(self.bw.writer()) catch {};
        mibu.cursor.show(self.bw.writer()) catch {};
        self.bw.flush() catch {};
        self.term.disableRawMode() catch {};
    }

    fn swapBuffers(self: *Self) !void {
        const fd = std.io.getStdIn().handle;
        const size = term.getSize(fd) catch return Error.IoError;
        assert(size.width == self.buffer.bounds.x);
        assert(size.height == self.buffer.bounds.y);
        const writer = self.bw.writer();
        // try mibu.clear.all(writer);
        var style = Style.default;
        var y: usize = 0;
        try writer.writeAll("\x1b[H\x1b[0m");
        while (y < self.buffer.bounds.y) : (y += 1) {
            var x: usize = 0;
            while (x < self.buffer.bounds.x) : (x += 1) {
                const char = self.getChar(x, y);
                try char.style.change(style, writer);
                try writer.print("{u}", .{char.char});
                style = char.style;
            }
        }
        try self.bw.flush();
    }
    fn resize(self: *Self) Error!void {
        const size = term.getSize(self.term.handle) catch return Error.IoError;
        try self.buffer.resize(.{ .x = size.width, .y = size.height });
    }
    fn getChar(self: Self, x: usize, y: usize) Char {
        return self.buffer.buffer.items[y * self.buffer.bounds.x + x];
    }
};
