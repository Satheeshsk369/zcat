const std = @import("std");

// Re-export all categorical implementations
pub const object = @import("object.zig");
pub const morphism = @import("morphism.zig");
pub const functor = @import("functor.zig");
pub const products = @import("products.zig");

/// Example usage of the categorical library
pub fn example() void {
    // Object example
    const IntObject = object.CategoricalObject(i32);
    const obj = IntObject.new(42);
    const identity_obj = obj.identity();
    std.debug.print("Object identity: {}\n", .{identity_obj.value});

    // Morphism example
    const add_one = morphism.Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const double = morphism.Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const composed = add_one.compose(double);
    std.debug.print("Morphism composition: {}\n", .{composed.apply(2)});

    // Functor example
    const maybe = functor.Maybe(i32).some(42);
    const mapped = maybe.map(add_one);
    std.debug.print("Functor mapping: {}\n", .{mapped.value.Some});

    // Product example
    const Point = products.Product(struct {
        x: f32,
        y: f32,
    });

    const point = Point.new(.{ .x = 1.0, .y = 2.0 });
    const proj_x = Point.project(0);
    std.debug.print("Product projection: {}\n", .{proj_x.apply(point)});

    // Coproduct example
    const Result = products.Coproduct(struct {
        Ok: i32,
        Err: []const u8,
    });

    const ok = Result.inject(i32, "Ok").apply(42);
    std.debug.print("Coproduct injection: {}\n", .{ok.value.Ok});
}

// Example usage:
test "categorical library" {
    // Run the example
    example();
}
