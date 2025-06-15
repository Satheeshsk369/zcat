const std = @import("std");
const C = @import("zcat");

pub fn main() !void {
    std.debug.print("Category Theory in Zig\n", .{});
    std.debug.print("====================\n\n", .{});

    // Demonstrate Objects
    std.debug.print("Objects:\n", .{});
    std.debug.print("--------\n", .{});
    const IntObject = C.object.CategoricalObject(i32);
    const obj = IntObject.new(42);
    const identity_obj = obj.identity();
    std.debug.print("Object value: {}\n", .{obj.value});
    std.debug.print("Identity morphism: {}\n\n", .{identity_obj.value});

    // Demonstrate Morphisms
    std.debug.print("Morphisms:\n", .{});
    std.debug.print("----------\n", .{});
    const add_one = C.morphism.Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const double = C.morphism.Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const composed = add_one.compose(double);
    std.debug.print("f(x) = x + 1\n", .{});
    std.debug.print("g(x) = x * 2\n", .{});
    std.debug.print("(g ∘ f)(2) = {}\n\n", .{composed.apply(2)});

    // Demonstrate Functors
    std.debug.print("Functors:\n", .{});
    std.debug.print("---------\n", .{});
    const maybe = C.functor.Maybe(i32).some(42);
    const mapped = maybe.map(add_one);
    std.debug.print("Maybe(42) -> Maybe(43)\n", .{});
    std.debug.print("fmap(add_one)(Some(42)) = Some({})\n\n", .{mapped.value.Some});

    // Demonstrate Products
    std.debug.print("Products:\n", .{});
    std.debug.print("---------\n", .{});
    const Point = C.products.Product(struct {
        x: f32,
        y: f32,
    });

    const point = Point.new(.{ .x = 1.0, .y = 2.0 });
    const proj_x = Point.project(0);
    const proj_y = Point.project(1);
    std.debug.print("Point(1.0, 2.0)\n", .{});
    std.debug.print("π₁(point) = {}\n", .{proj_x.apply(point)});
    std.debug.print("π₂(point) = {}\n\n", .{proj_y.apply(point)});

    // Demonstrate Coproducts
    std.debug.print("Coproducts:\n", .{});
    std.debug.print("------------\n", .{});
    const Result = C.products.Coproduct(struct {
        Ok: i32,
        Err: []const u8,
    });

    const ok = Result.inject(i32, "Ok").apply(42);
    const err = Result.inject([]const u8, "Err").apply("error");
    std.debug.print("in₁(42) = {}\n", .{ok.value.Ok});
    std.debug.print("in₂(\"error\") = {s}\n", .{err.value.Err});
}

test "main" {
    try main();
}
