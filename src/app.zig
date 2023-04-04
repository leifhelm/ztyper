const std = @import("std");
const Allocator = std.mem.Allocator;

const events = @import("mibu").events;

const Screen = @import("screen.zig").Screen;
const Widget = @import("screen.zig").Widget;
const BorderStyle = @import("buffer.zig").BorderStyle;
const BufferSlice = @import("buffer.zig").BufferSlice;
const Char = @import("buffer.zig").Char;
const Error = @import("error.zig").Error;

const widgets = @import("widgets.zig");
const TypingWidget = widgets.TypingWidget;

const tea = @import("tea.zig");
const Program = tea.Program;
const Cmd = tea.Cmd;

pub const Application = struct {
    const Model = struct {
        typing: TypingWidget.Model,
    };
    const Msg = union(enum) {
        event: events.Event,
    };

    fn init(allocator: Allocator) Model {
        return Model{
            .typing = TypingWidget.init(allocator),
        };
    }
    fn deinit(model: *Model) void {
        TypingWidget.deinit(&model.typing);
    }
    fn view(model: Model, buffer: BufferSlice) void {
        buffer.drawBorder(BorderStyle.default, buffer.getBoundingBox()) catch unreachable;
        TypingWidget.view(model.typing, buffer);
        // var buf = [1]u8{undefined} ** 32;
        // const text = std.fmt.bufPrint(&buf, "{d}", .{model.counter}) catch &[_]u8{};
        // buffer.draw(Char.default(self.last_typed_char), .{ .x = 2, .y = 1 }) catch unreachable;
        // buffer.drawText(text, .{}, .{ .x = 3, .y = 2 }) catch unreachable;
    }
    fn update(msg: Msg, model: *Model) Cmd {
        return switch (msg) {
            .event => |e| handleEvent(e, model),
        };
    }
    fn handleEvent(event: events.Event, model: *Model) Cmd {
        switch (event) {
            .key => |k| switch (k) {
                // char can have more than 1 u8, because of unicode
                .char => |c| return TypingWidget.update(.{ .key_pressed = c }, &model.typing),
                .ctrl => |c| switch (c) {
                    'c' => return .exit,
                    else => {},
                },
                .delete => return TypingWidget.update(.delete_pressed, &model.typing),
                else => {},
            },
            // ex. mouse events not supported yet
            else => {},
        }
        return .none;
    }
    fn onTerminalEvent(event: events.Event) Msg {
        return .{ .event = event };
    }
    pub const Prog = Program(Model, Msg){
        .init = init,
        .deinit = deinit,
        .view = view,
        .update = update,
        .onTerminalEvent = onTerminalEvent,
    };
    pub const ScreenApp = Screen(Model, Msg, Prog);
};
