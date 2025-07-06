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
    const intToString = zcat.Morphism(IntObj, StringObj){
        .f = struct {
            fn convert(x: i32) []const u8 {
                return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
            }
        }.convert,
    };
    
    // Create identity morphism for i32
    const id_int = zcat.Identity(IntObj);
    
    // Demonstrate morphism application
    const test_value: i32 = 42;
    const result = intToString.apply(test_value);
    const identity_result = id_int.apply(test_value);
    
    std.debug.print("Morphism f(42) = {s}\n", .{result});
    std.debug.print("Identity id(42) = {d}\n", .{identity_result});
    
    // Demonstrate composition with another morphism
    const doubleInt = zcat.Morphism(IntObj, IntObj){
        .f = struct {
            fn double(x: i32) i32 {
                return x * 2;
            }
        }.double,
    };
    
    const composed = zcat.Compose(IntObj, IntObj, StringObj, doubleInt, intToString);
    const composed_result = composed.apply(21);
    
    std.debug.print("Composition (double then toString)(21) = {s}\n", .{composed_result});
    
    // === RUNTIME COMPOSITION DEMO ===
    std.debug.print("\n--- Runtime Composition ---\n", .{});
    
    // Convert compile-time morphisms to runtime morphisms
    const runtime_double = try zcat.toRuntimeMorphism(i32, i32, doubleInt, allocator);
    defer runtime_double.deinit(allocator);
    
    const add_ten = zcat.Morphism(i32, i32){
        .f = struct {
            fn add(x: i32) i32 {
                return x + 10;
            }
        }.add,
    };
    
    const runtime_add_ten = try zcat.toRuntimeMorphism(i32, i32, add_ten, allocator);
    defer runtime_add_ten.deinit(allocator);
    
    // Runtime composition
    const runtime_composed = try runtime_double.compose(allocator, runtime_add_ten);
    defer runtime_composed.deinit(allocator);
    
    const runtime_result = runtime_composed.apply(@as(i32, 5));
    std.debug.print("Runtime composition (double then add10)(5) = {d}\n", .{runtime_result});
    
    // === DYNAMIC PIPELINE DEMO ===
    std.debug.print("\n--- Dynamic Pipeline ---\n", .{});
    
    // Simulate dynamic configuration
    const Config = struct {
        should_double: bool,
        should_add_ten: bool,
        should_subtract_five: bool,
    };
    
    const configs = [_]Config{
        Config{ .should_double = true, .should_add_ten = false, .should_subtract_five = true },
        Config{ .should_double = false, .should_add_ten = true, .should_subtract_five = false },
        Config{ .should_double = true, .should_add_ten = true, .should_subtract_five = true },
    };
    
    const subtract_five = zcat.Morphism(i32, i32){
        .f = struct {
            fn subtract(x: i32) i32 {
                return x - 5;
            }
        }.subtract,
    };
    
    for (configs, 0..) |config, i| {
        std.debug.print("Configuration {d}: ", .{i + 1});
        
        var pipeline = zcat.RuntimePipeline.init(allocator);
        defer pipeline.deinit();
        
        if (config.should_double) {
            try pipeline.addStep(try zcat.toRuntimeMorphism(i32, i32, doubleInt, allocator));
            std.debug.print("double ");
        }
        
        if (config.should_add_ten) {
            try pipeline.addStep(try zcat.toRuntimeMorphism(i32, i32, add_ten, allocator));
            std.debug.print("add10 ");
        }
        
        if (config.should_subtract_five) {
            try pipeline.addStep(try zcat.toRuntimeMorphism(i32, i32, subtract_five, allocator));
            std.debug.print("subtract5 ");
        }
        
        const pipeline_result = pipeline.execute(@as(i32, 8));
        std.debug.print("-> f(8) = {d}\n", .{pipeline_result});
    }
    
    std.debug.print("\n=== Demo Complete ===\n", .{});
}