const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Error = @import("error.zig").Error;

const Cmd = @import("tea.zig").Cmd;
const BufferSlice = @import("buffer.zig").BufferSlice;
const Char = @import("buffer.zig").Char;
const Style = @import("buffer.zig").Style;
const Color = @import("buffer.zig").Color;

pub const TypingWidget = struct {
    pub const Model = struct {
        const Config = struct {
            visible_spaces: bool = false,
            text_style: Style = .{},
            typed_style: Style = .{ .fg = .BrightBlack },
            cursor_style: Style = .{ .fg = .Black, .bg = .White },
            error_style: Style = .{ .fg = .White, .bg = .Red },
        };
        allocator: Allocator,
        last_key: u21,
        text: []const u8,
        cursor: usize,
        config: Config,
        errors: ArrayList(u21),
    };
    pub const Msg = union(enum) {
        key_pressed: u21,
        delete_pressed,
    };
    pub fn init(allocator: Allocator) Model {
        return .{
            .allocator = allocator,
            .last_key = ' ',
            .text = "The quick brown fox jumps over the lazy dog.",
            .cursor = 0,
            .config = .{},
            .errors = ArrayList(u21).init(allocator),
        };
    }
    pub fn deinit(model: *Model) void {
        model.errors.deinit();
    }
    pub fn view(model: Model, buffer: BufferSlice) void {
        buffer.draw(Char.default(model.last_key), .{ .x = 2, .y = 1 }) catch unreachable;
        var text = createText(model) catch unreachable;
        defer text.deinit();
        for (text.items) |char, index| {
            buffer.draw(char, .{ .x = 2 + index, .y = 2 }) catch unreachable;
        }
    }
    fn createText(model: Model) !ArrayList(Char) {
        var text = try ArrayList(Char).initCapacity(model.allocator, model.text.len + model.errors.items.len);
        for (model.text[0..model.cursor]) |char| {
            text.appendAssumeCapacity(mapChar(model, .{
                .char = char,
                .style = model.config.typed_style,
            }));
        }
        for (model.errors.items) |char| {
            text.appendAssumeCapacity(mapChar(model, .{
                .char = char,
                .style = model.config.error_style,
            }));
        }
        if (model.cursor < model.text.len) {
            text.appendAssumeCapacity(mapChar(model, .{
                .char = model.text[model.cursor],
                .style = model.config.cursor_style,
            }));
            for (model.text[model.cursor + 1 ..]) |char| {
                text.appendAssumeCapacity(mapChar(model, .{
                    .char = char,
                    .style = model.config.text_style,
                }));
            }
        }
        return text;
    }
    fn mapChar(model: Model, char: Char) Char {
        if (model.config.visible_spaces and char.char == ' ') {
            var style = char.style;
            if (style.fg == .Default) {
                style.fg = .BrightBlack;
            }
            return .{ .char = '␣', .style = style };
        }
        return char;
    }
    pub fn update(msg: Msg, model: *Model) Cmd {
        switch (msg) {
            .key_pressed => |key| {
                if (model.errors.items.len == 0 and
                    model.cursor < model.text.len and
                    model.text[model.cursor] == key)
                {
                    model.cursor += 1;
                } else {
                    model.errors.append(key) catch unreachable;
                }
                model.last_key = key;
            },
            .delete_pressed => {
                if (model.errors.items.len > 0) {
                    _ = model.errors.pop();
                }
            },
        }
        return .none;
    }
};
