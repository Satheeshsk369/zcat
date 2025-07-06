const std = @import("std");
const zcat = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Category Theory Basics Demo ===\n", .{});

    // Define some objects (types)
    const IntObj = i32;
    const StringObj = []const u8;

    std.debug.print("Objects: {s} and {s}\n", .{ @typeName(IntObj), @typeName(StringObj) });

    // === COMPILE-TIME COMPOSITION DEMO ===
    std.debug.print("\n--- Compile-time Composition ---\n", .{});

    // Create a morphism from i32 to []const u8
    const intToString = comptime zcat.Morphism(IntObj, StringObj).new(struct {
        fn convert(x: i32) []const u8 {
            return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
        }
    }.convert);

    // Create identity morphism for i32
    const id_int = zcat.Identity(IntObj);

    // Demonstrate morphism application
    const test_value: i32 = 42;
    const result = intToString.apply(test_value);
    const identity_result = id_int.apply(test_value);

    std.debug.print("Morphism f(42) = {s}\n", .{result});
    std.debug.print("Identity id(42) = {d}\n", .{identity_result});

    // Demonstrate composition with another morphism
    const doubleInt = comptime zcat.Morphism(IntObj, IntObj).new(struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    const composed = zcat.Morphism(IntObj, StringObj).new(struct {
        fn call(x: IntObj) StringObj {
            return intToString.apply(doubleInt.apply(x));
        }
    }.call);
    const composed_result = composed.apply(21);

    std.debug.print("Composition (double then toString)(21) = {s}\n", .{composed_result});

    // === RUNTIME COMPOSITION DEMO ===
    std.debug.print("\n--- Runtime Composition ---\n", .{});

    // Create runtime morphisms with context
    const AddTenContext = struct {
        pub fn apply(self: @This(), x: i32) i32 {
            _ = self;
            return x + 10;
        }
    };

    const DoubleContext = struct {
        pub fn apply(self: @This(), x: i32) i32 {
            _ = self;
            return x * 2;
        }
    };

    const runtime_double = try zcat.Morphism(i32, i32).fromContext(DoubleContext{}, allocator);
    defer runtime_double.deinit(allocator);

    const runtime_add_ten = try zcat.Morphism(i32, i32).fromContext(AddTenContext{}, allocator);
    defer runtime_add_ten.deinit(allocator);

    // Runtime composition
    const runtime_composed = try runtime_double.compose(i32, runtime_add_ten, allocator);
    defer runtime_composed.deinit(allocator);

    const runtime_result = runtime_composed.apply(@as(i32, 5));
    std.debug.print("Runtime composition (double then add10)(5) = {d}\n", .{runtime_result});

    // === MATHEMATICAL COMPOSITION DEMO ===
    std.debug.print("\n--- Mathematical Composition ---\n", .{});

    // Demonstrate pure mathematical composition
    const subtract_five = comptime zcat.Morphism(i32, i32).new(struct {
        fn subtract(x: i32) i32 {
            return x - 5;
        }
    }.subtract);

    const add_ten = comptime zcat.Morphism(i32, i32).new(struct {
        fn add(x: i32) i32 {
            return x + 10;
        }
    }.add);

    // Mathematical composition: (subtract_five ∘ add_ten ∘ double)(8)  
    const full_composition = comptime zcat.Morphism(i32, i32).new(struct {
        fn call(x: i32) i32 {
            return subtract_five.apply(add_ten.apply(doubleInt.apply(x)));
        }
    }.call);
    
    const math_result = full_composition.apply(@as(i32, 8));
    std.debug.print("Mathematical composition (subtract5 ∘ add10 ∘ double)(8) = {d}\n", .{math_result});

    std.debug.print("\n=== Demo Complete ===\n", .{});
}
