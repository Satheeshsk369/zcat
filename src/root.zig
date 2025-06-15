const std = @import("std");

pub fn Compose(comptime funcs: anytype) type {
    const funcs_info = @typeInfo(@TypeOf(funcs));
    if (funcs_info != .@"struct") {
        @compileError("Expected tuple of functions");
    }

    const fields = funcs_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Need at least one function");
    }

    // Validate all items are functions
    inline for (fields) |field| {
        const field_type = @typeInfo(field.type);
        if (field_type != .@"fn") {
            @compileError("All items must be functions");
        }
    }

    // Get first function's parameter type and last function's return type
    const first_func_info = @typeInfo(@TypeOf(@field(funcs, fields[0].name))).@"fn";
    const last_func_info = @typeInfo(@TypeOf(@field(funcs, fields[fields.len - 1].name))).@"fn";

    const InputType = first_func_info.params[0].type.?;
    const OutputType = last_func_info.return_type.?;

    return fn (InputType) OutputType;
}

pub fn compose(comptime funcs: anytype) Compose(funcs) {
    const fields = @typeInfo(@TypeOf(funcs)).@"struct".fields;

    if (fields.len == 1) {
        return @field(funcs, fields[0].name);
    }

    return composeImpl(funcs);
}

fn composeImpl(comptime funcs: anytype) Compose(funcs) {
    const fields = @typeInfo(@TypeOf(funcs)).@"struct".fields;
    const first_func_info = @typeInfo(@TypeOf(@field(funcs, fields[0].name))).@"fn";
    const InputType = first_func_info.params[0].type.?;

    return struct {
        fn call(input: InputType) callReturnType() {
            return composeChain(funcs, input, 0);
        }

        fn callReturnType() type {
            const last_func_info = @typeInfo(@TypeOf(@field(funcs, fields[fields.len - 1].name))).@"fn";
            return last_func_info.return_type.?;
        }

        fn composeChain(comptime fs: @TypeOf(funcs), value: anytype, comptime index: usize) callReturnType() {
            const current_func = @field(fs, fields[index].name);
            const result = current_func(value);

            if (index == fields.len - 1) {
                return result;
            } else {
                return composeChain(fs, result, index + 1);
            }
        }
    }.call;
}

// Example usage:
test "function composition" {
    const add_one = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const composed = compose(.{ add_one, double });
    const result = composed(2); // (2 + 1) * 2 = 6

    try std.testing.expectEqual(@as(i32, 6), result);
}
