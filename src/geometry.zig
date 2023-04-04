const std = @import("std");

pub const Point = struct {
    const Self = @This();

    x: usize,
    y: usize,

    pub fn inBounds(self: Self, bounds: Point) bool {
        return self.x < bounds.x and self.y < bounds.y;
    }
    pub fn inBoundingBox(self: Self, bounding_box: Rect) bool {
        return (self.x >= bounding_box.getLeft() and self.x < bounding_box.getRight()) and
            (self.y >= bounding_box.getTop() and self.y < bounding_box.getBottom());
    }
    pub fn add(self: Self, x: usize, y: usize) Self {
        return .{
            .x = self.x + x,
            .y = self.y + y,
        };
    }
    pub fn sub(self: Self, x: usize, y: usize) Self {
        return .{
            .x = self.x - x,
            .y = self.y - y,
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
        try writer.print("({d}, {d})", .{self.x, self.y});
    }
};

pub const Rect = struct {
    const Self = @This();

    top_left: Point,
    bottom_right: Point,

    pub fn coords(x1: usize, x2: usize, y1: usize, y2: usize) Self {
        return .{
            .top_left = .{ .x = x1, .y = y1 },
            .bottom_right = .{ .x = x2, .y = y2 },
        };
    }

    pub fn valid(self: Self) bool {
        return self.top_left.inBounds(self.bottom_right);
    }

    pub fn inBounds(self: Self, bounds: Point) bool {
        return self.bottom_right.x <= bounds.x and
            self.bottom_right.y <= bounds.y;
    }

    pub fn inBoundingBox(self: Self, bounding_box: Rect) bool {
        return (self.top_left.x >= bounding_box.top_left.x and self.bottom_right.x <= bounding_box.bottom_right.x) and
            (self.top_left.y >= bounding_box.top_left.y and self.bottom_right.y <= bounding_box.bottom_right.y);
    }

    pub fn getTopLeftCorner(self: Self) Point {
        return self.top_left;
    }
    pub fn getTopRightCorner(self: Self) Point {
        return .{ .x = self.bottom_right.x - 1, .y = self.top_left.y };
    }
    pub fn getBottomLeftCorner(self: Self) Point {
        return .{ .x = self.top_left.x, .y = self.bottom_right.y - 1 };
    }
    pub fn getBottomRightCorner(self: Self) Point {
        return self.bottom_right.sub(1, 1);
    }
    pub fn getWidth(self: Self) usize {
        return self.bottom_right.x - self.top_left.x;
    }
    pub fn getHeight(self: Self) usize {
        return self.bottom_right.y - self.top_left.y;
    }
    pub fn getTopEdge(self: Self) usize {
        return self.top_left.y;
    }
    pub fn getTop(self: Self) usize {
        return self.top_left.y;
    }
    pub fn getBottomEdge(self: Self) usize {
        return self.bottom_right.y-1;
    }
    pub fn getBottom(self: Self) usize {
        return self.bottom_right.y;
    }
    pub fn getLeftEdge(self: Self) usize {
        return self.top_left.x;
    }
    pub fn getLeft(self: Self) usize {
        return self.top_left.x;
    }
    pub fn getRightEdge(self: Self) usize {
        return self.bottom_right.x-1;
    }
    pub fn getRight(self: Self) usize {
        return self.bottom_right.x;
    }
    /// Translates a point relative to this `Rect` to the global position
    /// Does not perform bounds checks.
    pub fn globalPosition(self: Self, point: Point) Point {
        return Point{
            .x = self.top_left.x + point.x,
            .y = self.top_left.y + point.y,
        };
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "point in bounds" {
    const point = Point{ .x = 10, .y = 10 };
    try expect(point.inBounds(point) == false);
    try expect(point.inBounds(.{ .x = 10, .y = 11 }) == false);
    try expect(point.inBounds(.{ .x = 11, .y = 10 }) == false);
    try expect(point.inBounds(.{ .x = 0, .y = 0 }) == false);

    try expect(point.inBounds(.{ .x = 11, .y = 11 }) == true);
}

test "point in bounding box" {
    const bounding_box = Rect.coords(2, 5, 12, 20);
    try expect((Point{ .x = 0, .y = 0 }).inBoundingBox(bounding_box) == false);
    try expect((Point{ .x = 2, .y = 0 }).inBoundingBox(bounding_box) == false);
    try expect((Point{ .x = 5, .y = 12 }).inBoundingBox(bounding_box) == false);
    try expect((Point{ .x = 5, .y = 12 }).inBoundingBox(bounding_box) == false);
    try expect((Point{ .x = 4, .y = 20 }).inBoundingBox(bounding_box) == false);
    try expect((Point{ .x = 4, .y = 11 }).inBoundingBox(bounding_box) == false);

    try expect((Point{ .x = 2, .y = 12 }).inBoundingBox(bounding_box) == true);
    try expect((Point{ .x = 4, .y = 12 }).inBoundingBox(bounding_box) == true);
    try expect((Point{ .x = 4, .y = 19 }).inBoundingBox(bounding_box) == true);
    try expect((Point{ .x = 2, .y = 19 }).inBoundingBox(bounding_box) == true);
}

test "rect in bounds" {
    const rect = Rect.coords(2, 5, 12, 20);
    try expect(rect.inBounds(.{ .x = 4, .y = 19 }) == false);
    try expect(rect.inBounds(.{ .x = 5, .y = 19 }) == false);
    try expect(rect.inBounds(.{ .x = 4, .y = 20 }) == false);

    try expect(rect.inBounds(.{ .x = 5, .y = 20 }) == true);
}

test "rect in bounding box" {
    const bounding_box = Rect.coords(2, 5, 12, 20);
    try expect(Rect.coords(1, 5, 12, 20).inBoundingBox(bounding_box) == false);
    try expect(Rect.coords(2, 6, 12, 20).inBoundingBox(bounding_box) == false);
    try expect(Rect.coords(2, 5, 11, 20).inBoundingBox(bounding_box) == false);
    try expect(Rect.coords(2, 5, 12, 21).inBoundingBox(bounding_box) == false);

    try expect(bounding_box.inBoundingBox(bounding_box) == true);
}

test "rect is valid" {
    try expect(Rect.coords(3, 3, 4, 5).valid() == false);
    try expect(Rect.coords(2, 3, 5, 5).valid() == false);

    try expect(Rect.coords(2, 3, 4, 5).valid() == true);
}

test "rect width" {
    try expectEqual(@as(usize, 0), Rect.coords(2, 2, 0, 0).getWidth());
    try expectEqual(@as(usize, 1), Rect.coords(2, 3, 0, 0).getWidth());
}

test "rect height" {
    try expectEqual(@as(usize, 0), Rect.coords(0, 0, 2, 2).getHeight());
    try expectEqual(@as(usize, 1), Rect.coords(0, 0, 2, 3).getHeight());
}
