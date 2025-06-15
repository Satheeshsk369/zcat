const std = @import("std");
const C = @import("zcat");

fn add_ten(x: i32) i32 {
    return x + 10;
}

fn multiply_by_three(x: i32) i32 {
    return x * 3;
}

fn to_f32(x: i32) f32 {
    return @floatFromInt(x);
}

fn square_root(x: f32) f32 {
    return @sqrt(x);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // Test 1: Simple composition
    const comp1 = C.compose(.{ add_ten, multiply_by_three });
    const result1 = comp1(5); // (5 + 10) * 3 = 45
    try stdout.print("Test 1: compose(add_ten, multiply_by_three)(5) = {}\n", .{result1});

    // Test 2: Single function
    const comp2 = C.compose(.{add_ten});
    const result2 = comp2(7); // 7 + 10 = 17
    try stdout.print("Test 2: compose(add_ten)(7) = {}\n", .{result2});

    // Test 3: Type changing composition
    const comp3 = C.compose(.{ add_ten, multiply_by_three, to_f32, square_root });
    const result3 = comp3(2); // (2 + 10) * 3 = 36 -> 36.0 -> 6.0
    try stdout.print("Test 3: complex composition(2) = {d:.1}\n", .{result3});

    // Test 4: Lambda-style functions
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const add_one = struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f;

    const comp4 = C.compose(.{ double, add_one });
    const result4 = comp4(10); // 10 * 2 + 1 = 21
    try stdout.print("Test 4: compose(double, add_one)(10) = {}\n", .{result4});
}
