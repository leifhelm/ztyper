const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Random = std.rand.Random;

fn readLen(reader: anytype) !u32 {
    const len = try reader.readIntBig(u8);
    if (len == 255) {
        return reader.readIntBig(u32);
    } else {
        return len;
    }
}

pub fn main() !void {
    var stderr = std.io.getStdErr();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            _ = stderr.write("\nLEAKED MEMORY\n") catch {};
            std.process.exit(199);
        }
    }
    const allocator = gpa.allocator();

    var input_file = try std.fs.cwd().openFile("en.pred", .{});
    defer input_file.close();
    var br = std.io.bufferedReader(input_file.reader());

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var word_generator = try WordGenerator.deserialize(allocator, br.reader());
    defer word_generator.deinit();

    const random = word_generator.random;

    // var iter = word_generator.hash_map.iterator();
    // while (iter.next()) |entry| {
    //     try stdout.print("{s}\n", .{entry.key_ptr.*});
    // }
    var word = ArrayList(u8).init(allocator);
    defer word.deinit();
    var i: usize = 0;
    while (i < 10000000) : (i += 1) {
        word.clearRetainingCapacity();
        const word_length = random.intRangeAtMostBiased(usize, 3, 8);
        const starting_char = random.intRangeAtMostBiased(u21, 'a', 'z');
        try word_generator.generateWord(starting_char, word_length, &word);
        try stdout.print("{s}\n", .{word.items});
    }
    try bw.flush();
}

pub const WordGenerator = struct {
    const Self = @This();

    random: Random,
    arena: ArenaAllocator,
    hash_map: StringHashMap(Predictor),

    pub fn deserialize(allocator: Allocator, reader: anytype) !Self {
        var arena = ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();
        var hash_map = StringHashMap(Predictor).init(allocator);
        errdefer hash_map.deinit();

        const size = try reader.readIntBig(u32);
        try hash_map.ensureTotalCapacity(size);
        var i: usize = 0;
        while (i < size) : (i += 1) {
            const n_gram_length = try reader.readIntBig(u8);
            const n_gram = try arena_allocator.alloc(u8, n_gram_length);
            _ = try reader.readAll(n_gram);
            const entry_size = try reader.readIntBig(u32);
            const entries = try arena_allocator.alloc(Predictor.Entry, entry_size);
            var sum: u64 = 0;
            var j: usize = 0;
            while (j < entry_size) : (j += 1) {
                const char = try reader.readIntBig(u24);
                const count = try reader.readIntBig(u64);
                entries[j] = .{
                    .char = @intCast(u21, char),
                    .count = count,
                };
                sum += count;
            }
            hash_map.putAssumeCapacityNoClobber(n_gram, Predictor{ .list = entries, .sum = sum });
        }
        return Self{
            .random = std.crypto.random,
            .arena = arena,
            .hash_map = hash_map,
        };
    }

    pub fn deinit(self: *Self) void {
        self.hash_map.deinit();
        self.arena.deinit();
    }

    pub fn generateWord(self: Self, start: u21, length: usize, str: *ArrayList(u8)) !void {
        if (length == 0) {
            return;
        }
        var prev_start = str.items.len;
        const writer = str.writer();
        try writer.print("{u}", .{start});

        var i: usize = 1;
        while (i < length) : (i += 1) {
            const prev = str.items[prev_start..];
            const char = if (self.hash_map.get(prev)) |predictor|
                predictor.nextRandomChar(self.random)
            else
                self.random.intRangeAtMostBiased(u21, 'a', 'z');
            try writer.print("{u}", .{char});
            if (i > 2) {
                prev_start += try std.unicode.utf8ByteSequenceLength(str.items[prev_start]);
            }
        }
    }
};

pub const Predictor = struct {
    const Self = @This();
    const Entry = struct {
        char: u21,
        count: u64,
    };

    list: []const Entry,
    sum: u64,

    pub fn nextRandomChar(self: Self, random: Random) u21 {
        const rand = random.uintLessThan(u64, self.sum);
        var i: usize = 0;
        for (self.list) |entry| {
            i += entry.count;
            if (rand < i) {
                return entry.char;
            }
        }
        // std.debug.print("rand: {d}, i: {d}, sum: {d}\n", .{rand, i, self.sum});
        unreachable;
    }
};
