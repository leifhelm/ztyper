const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Rect = geometry.Rect;

pub const Error = error{
    OutOfBounds,
};

pub const Buffer = struct {
    const Self = @This();

    buffer: ArrayList(Char),
    bounds: Point,

    pub fn init(allocator: Allocator, bounds: Point) !Self {
        var buffer = ArrayList(Char).init(allocator);
        try buffer.appendNTimes(Char.empty, bounds.x * bounds.y);
        return Self{
            .buffer = buffer,
            .bounds = bounds,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    fn put(self: *Self, other: Self) Error!void {
        if (!other.bounding_box.inBounds(self.bounding_box)) {
            return Error.OutOfBounds;
        }
        var y: usize = other.bounding_box.getTop();
        const x_offset = other.bounding_box.getLeft() - self.bounding_box.getLeft();
        while (y <= other.bounding_box.getBottom()) : (y += 1) {
            std.mem.copy(
                Char,
                self.buffer.items[x_offset + y * self.bounding_box.getWidth() ..],
                other.buffer.items[y * other.bounding_box.getWidth() .. other.bounding_box.getWidth()],
            );
        }
    }
    pub fn resize(self: *Self, bounds: Point) error{OutOfMemory}!void {
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendNTimes(Char.empty, bounds.x * bounds.y);
        self.bounds = bounds;
    }
    pub fn slice(self: *Self, bounding_box: Rect) Error!BufferSlice {
        return BufferSlice.init(self, bounding_box);
    }
    pub fn getSlice(self: *Self) BufferSlice {
        return .{
            .ptr = self,
            .bounding_box = .{
                .top_left = .{ .x = 0, .y = 0 },
                .bottom_right = self.bounds,
            },
        };
    }
    fn getChar(self: Self, x: usize, y: usize) Char {
        return self.buffer.items[y * self.bounds.x + x];
    }
};

pub const BufferSlice = struct {
    const Self = @This();

    bounding_box: Rect,
    ptr: *Buffer,

    fn init(buffer: *Buffer, bounding_box: Rect) Error!BufferSlice {
        if (!bounding_box.inBounds(buffer.bounds)) {
            return Error.OutOfBounds;
        }
        return BufferSlice{
            .ptr = buffer,
            .bounding_box = bounding_box,
        };
    }
    pub fn getBoundingBox(self: Self) Rect {
        return .{
            .top_left = .{ .x = 0, .y = 0 },
            .bottom_right = .{ .x = self.bounding_box.getWidth(), .y = self.bounding_box.getHeight() },
        };
    }
    pub fn draw(self: Self, char: Char, p: Point) !void {
        if (!p.inBoundingBox(self.bounding_box)) {
            return error.InvalidArgument;
        }
        self.setChar(char, p);
    }
    pub fn drawBorder(self: Self, border_style: BorderStyle, rect: Rect) Error!void {
        if (!rect.valid() or !rect.inBoundingBox(self.bounding_box) or rect.getWidth() < 2 or rect.getHeight() < 2) {
            return Error.OutOfBounds;
        }
        // Corners
        self.setChar(border_style.top_left, rect.getTopLeftCorner());
        self.setChar(border_style.top_right, rect.getTopRightCorner());
        self.setChar(border_style.bottom_left, rect.getBottomLeftCorner());
        self.setChar(border_style.bottom_right, rect.getBottomRightCorner());

        var x: usize = rect.getLeft() + 1;
        while (x < rect.getRightEdge()) : (x += 1) {
            self.setChar(border_style.horizontal, .{ .x = x, .y = rect.getTopEdge() });
            self.setChar(border_style.horizontal, .{ .x = x, .y = rect.getBottomEdge() });
        }

        var y: usize = rect.getTop() + 1;
        while (y < rect.getBottomEdge()) : (y += 1) {
            self.setChar(border_style.vertical, .{ .x = rect.getLeftEdge(), .y = y });
            self.setChar(border_style.vertical, .{ .x = rect.getRightEdge(), .y = y });
        }
    }
    pub fn drawText(self: Self, text: []const u8, style: Style, point: Point) Error!void {
        if (!point.inBoundingBox(self.bounding_box) or !point.add(text.len, 0).inBoundingBox(self.bounding_box)) {
            return Error.OutOfBounds;
        }
        for (text) |char, index| {
            self.setChar(.{ .char = char, .style = style }, point.add(index, 0));
        }
    }
    fn setChar(self: Self, char: Char, point: Point) void {
        const p = self.bounding_box.globalPosition(point);
        self.ptr.buffer.items[p.y * self.ptr.bounds.x + p.x] = char;
    }
};

const CsiWriter = struct {
    const Self = @This();

    written_start: bool = false,

    fn close(self: Self, writer: anytype) !void {
        if (self.written_start) {
            try writer.writeAll("m");
        }
    }
    fn writeCode(self: *Self, writer: anytype, code: u8) !void {
        if (!self.written_start) {
            try writer.print("\x1b[{d}", .{code});
            self.written_start = true;
        } else {
            try writer.print(";{d}", .{code});
        }
    }
    fn writeCodes(self: *Self, writer: anytype, codes: anytype) !void {
        // const codes_info = @TypeOf(codes);
        const tuple = @typeInfo(@TypeOf(codes));
        // assert(std.meta.trait.isTuple(@TypeOf(codes)));
        assert(tuple == .Struct and tuple.Struct.is_tuple);
        const fields = tuple.Struct.fields;
        inline for (fields) |field| {
            assert(field.field_type == u8 or field.field_type == comptime_int);
        }
        inline for (codes) |code| {
            try self.writeCode(writer, code);
        }
    }
};

pub const Style = struct {
    const Self = @This();

    fg: Color = .Default,
    bg: Color = .Default,
    strike_through: bool = false,
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,

    pub const default = Self{};

    pub fn change(self: Self, prev: Style, writer: anytype) !void {
        var csi_writer = CsiWriter{};

        try boolean(&csi_writer, writer, self.strike_through, prev.strike_through, 9, 29);
        try boolean(&csi_writer, writer, self.bold, prev.bold, 1, 22);
        try boolean(&csi_writer, writer, self.italic, prev.italic, 3, 23);
        try boolean(&csi_writer, writer, self.underline, prev.underline, 4, 24);
        if (!std.meta.eql(self.fg, prev.fg)) {
            try self.fg.writeCsiFg(&csi_writer, writer);
        }
        if (!std.meta.eql(self.bg, prev.bg)) {
            try self.bg.writeCsiBg(&csi_writer, writer);
        }
        try csi_writer.close(writer);
    }
    fn boolean(csi_writer: *CsiWriter, writer: anytype, b: bool, b_old: bool, on: u8, off: u8) !void {
        if (b != b_old) {
            if (b) {
                try csi_writer.writeCode(writer, on);
            } else {
                try csi_writer.writeCode(writer, off);
            }
        }
    }
};

pub const Rgb = struct {
    /// red
    r: u8,
    /// green
    g: u8,
    /// blue
    b: u8,
};

pub const Color = union(enum(u8)) {
    const Self = @This();

    Color256: u8,
    TrueColor: Rgb,

    Black = 30,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    Default = 39,

    BrightBlack = 90,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite,

    fn writeCsiFg(self: Self, csi_writer: *CsiWriter, writer: anytype) !void {
        switch (self) {
            .Color256 => |color| try csi_writer.writeCodes(writer, .{ 38, 5, color }),
            .TrueColor => |color| try csi_writer.writeCodes(writer, .{ 38, 2, color.r, color.g, color.b }),
            else => try csi_writer.writeCode(writer, @enumToInt(self)),
        }
    }
    fn writeCsiBg(self: Self, csi_writer: *CsiWriter, writer: anytype) !void {
        switch (self) {
            .Color256 => |color| try csi_writer.writeCodes(writer, .{ 48, 5, color }),
            .TrueColor => |color| try csi_writer.writeCodes(writer, .{ 48, 2, color.r, color.g, color.b }),
            else => try csi_writer.writeCode(writer, @enumToInt(self) + 10),
        }
    }
};

pub const Char = struct {
    const Self = @This();
    pub const empty = Self{
        .char = ' ',
        .style = Style.default,
    };
    char: u21,
    style: Style,

    pub fn default(char: u21) Self {
        return Self{
            .char = char,
            .style = Style.default,
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{u}", .{self.char});
    }
};

pub const BorderStyle = struct {
    const Self = @This();
    pub const default = Self{
        .top_left = Char.default('╭'),
        .top_right = Char.default('╮'),
        .bottom_left = Char.default('╰'),
        .bottom_right = Char.default('╯'),
        .horizontal = Char.default('─'),
        .vertical = Char.default('│'),
    };

    top_left: Char,
    top_right: Char,
    bottom_left: Char,
    bottom_right: Char,
    horizontal: Char,
    vertical: Char,
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "buffer getSlice" {
    var buffer = try Buffer.init(std.testing.allocator, .{ .x = 10, .y = 12 });
    defer buffer.deinit();
    var buffer_slice = buffer.getSlice();
    try expectEqual(Rect.coords(0, 10, 0, 12), buffer_slice.bounding_box);
    try buffer_slice.draw(Char.default('a'), .{ .x = 3, .y = 5 });
    for (buffer.buffer.items) |char, index| {
        if (index == 53) {
            continue;
        }
        try expectEqual(Char.empty, char);
    }
    try expectEqual(Char.default('a'), buffer.buffer.items[53]);
}

test "bufferSlice drawBorder" {
    var buffer = try Buffer.init(std.testing.allocator, .{ .x = 3, .y = 3 });
    defer buffer.deinit();
    var buffer_slice = buffer.getSlice();
    const border_style = BorderStyle.default;
    try buffer_slice.drawBorder(border_style, buffer_slice.getBoundingBox());
    const expected = [_]Char{
        border_style.top_left,
        border_style.horizontal,
        border_style.top_right,
        border_style.vertical,
        Char.empty,
        border_style.vertical,
        border_style.bottom_left,
        border_style.horizontal,
        border_style.bottom_right,
    };
    try expectEqualSlices(Char, &expected, buffer.buffer.items);
}
test "bufferSlice drawText" {
    var buffer = try Buffer.init(std.testing.allocator, .{ .x = 4, .y = 2 });
    defer buffer.deinit();
    var buffer_slice = buffer.getSlice();
    try buffer_slice.drawText("hi", Style.default, .{ .x = 1, .y = 1 });
    const expected = [_]Char{
        Char.empty,
        Char.empty,
        Char.empty,
        Char.empty,
        Char.empty,
        Char.default('h'),
        Char.default('i'),
        Char.empty,
    };
    try expectEqualSlices(Char, &expected, buffer.buffer.items);
}
