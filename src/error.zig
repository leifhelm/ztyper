const std = @import("std");

pub const Error = error{
    OutOfMemory,
    IoError,
};

pub const ExitCode = enum(u8) {
    Ok = 0,
    CliUsageError = 64,
    CannotOpenInput = 66,
    OsError = 71,
    IoError = 74,
    LeakedMemory = 199,
};

pub fn exit(exit_code: ExitCode) noreturn {
    std.process.exit(@enumToInt(exit_code));
}

pub fn exitError(err: Error) noreturn {
    exit(errorToExitCode(err));
}

pub fn errorToExitCode(err: Error) ExitCode {
    return switch (err) {
        Error.OutOfMemory => .OsError,
        Error.IoError => .IoError,
    };
}
