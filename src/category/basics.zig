const std = @import("std");
const testing = std.testing;

/// Represents an object in a category.
pub const Object = type;

/// Represents a morphism in a category.
pub fn Morphism(comptime source: Object, comptime target: Object) type {
    return struct {
        f: *const fn (source) target,

        pub fn apply(self: @This(), x: source) target {
            return self.f(x);
        }
    };
}

/// Creates an identity morphism for the given object type.
pub fn Identity(comptime T: Object) Morphism(T, T) {
    return Morphism(T, T){
        .f = struct {
            fn call(x: T) T {
                return x;
            }
        }.call,
    };
}

/// Composes two morphisms: g ∘ f
pub fn Compose(
    comptime A: Object,
    comptime B: Object,
    comptime C: Object,
    comptime f: Morphism(A, B),
    comptime g: Morphism(B, C),
) Morphism(A, C) {
    return Morphism(A, C){
        .f = struct {
            fn call(x: A) C {
                return g.f(f.f(x));
            }
        }.call,
    };
}

/// Runtime morphism using fat pointer pattern with vtable for dynamic composition
pub fn RuntimeMorphism(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,
        
        const Self = @This();
        
        const VTable = struct {
            apply: *const fn (ptr: *anyopaque, input: T) T,
            compose: *const fn (allocator: std.mem.Allocator, first_ptr: *anyopaque, first_vtable: *const VTable, second_ptr: *anyopaque, second_vtable: *const VTable) std.mem.Allocator.Error!Self,
            deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        };
        
        pub fn apply(self: Self, input: T) T {
            return self.vtable.apply(self.ptr, input);
        }
        
        pub fn compose(self: Self, allocator: std.mem.Allocator, other: Self) !Self {
            return self.vtable.compose(allocator, self.ptr, self.vtable, other.ptr, other.vtable);
        }
        
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            self.vtable.deinit(self.ptr, allocator);
        }
    };
}

/// Creates a runtime morphism from a compile-time morphism
pub fn toRuntimeMorphism(comptime T: type, comptime morphism: anytype, allocator: std.mem.Allocator) !RuntimeMorphism(T) {
    const MorphismImpl = struct {
        morphism: @TypeOf(morphism),
        
        fn apply(ptr: *anyopaque, input: T) T {
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            return self.morphism.apply(input);
        }
        
        fn compose(alloc: std.mem.Allocator, first_ptr: *anyopaque, first_vtable: *const RuntimeMorphism(T).VTable, second_ptr: *anyopaque, second_vtable: *const RuntimeMorphism(T).VTable) std.mem.Allocator.Error!RuntimeMorphism(T) {
            const CompositionImpl = struct {
                first: RuntimeMorphism(T),
                second: RuntimeMorphism(T),
                
                fn apply_composed(ptr: *anyopaque, input: T) T {
                    const self: *const @This() = @ptrCast(@alignCast(ptr));
                    const intermediate = self.first.vtable.apply(self.first.ptr, input);
                    return self.second.vtable.apply(self.second.ptr, intermediate);
                }
                
                fn deinit_composed(ptr: *anyopaque, allocator_param: std.mem.Allocator) void {
                    const self: *const @This() = @ptrCast(@alignCast(ptr));
                    self.first.deinit(allocator_param);
                    self.second.deinit(allocator_param);
                    allocator_param.destroy(@as(*@This(), @ptrCast(@alignCast(ptr))));
                }
                
                const composed_vtable = RuntimeMorphism(T).VTable{
                    .apply = apply_composed,
                    .compose = compose,
                    .deinit = deinit_composed,
                };
            };
            
            const composition = try alloc.create(CompositionImpl);
            composition.* = CompositionImpl{
                .first = RuntimeMorphism(T){ .ptr = first_ptr, .vtable = first_vtable },
                .second = RuntimeMorphism(T){ .ptr = second_ptr, .vtable = second_vtable },
            };
            
            return RuntimeMorphism(T){
                .ptr = @ptrCast(composition),
                .vtable = &CompositionImpl.composed_vtable,
            };
        }
        
        fn deinit(ptr: *anyopaque, alloc: std.mem.Allocator) void {
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            alloc.destroy(self);
        }
        
        const vtable = RuntimeMorphism(T).VTable{
            .apply = apply,
            .compose = compose,
            .deinit = deinit,
        };
    };
    
    const impl = try allocator.create(MorphismImpl);
    impl.* = MorphismImpl{ .morphism = morphism };
    
    return RuntimeMorphism(T){
        .ptr = @ptrCast(impl),
        .vtable = &MorphismImpl.vtable,
    };
}

/// Creates a runtime identity morphism
pub fn RuntimeIdentity(comptime T: type, allocator: std.mem.Allocator) !RuntimeMorphism(T) {
    const identity = Identity(T);
    return toRuntimeMorphism(T, identity, allocator);
}

/// Pipeline for chaining multiple runtime morphisms
pub fn RuntimePipeline(comptime T: type) type {
    return struct {
        steps: std.ArrayList(RuntimeMorphism(T)),
        allocator: std.mem.Allocator,
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .steps = std.ArrayList(RuntimeMorphism(T)).init(allocator),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            for (self.steps.items) |step| {
                step.deinit(self.allocator);
            }
            self.steps.deinit();
        }
        
        pub fn addStep(self: *Self, step: RuntimeMorphism(T)) !void {
            try self.steps.append(step);
        }
        
        pub fn execute(self: Self, input: T) T {
            var result = input;
            for (self.steps.items) |step| {
                result = step.apply(result);
            }
            return result;
        }
        
        pub fn toMorphism(self: Self) !RuntimeMorphism(T) {
            if (self.steps.items.len == 0) {
                return error.EmptyPipeline;
            }
            
            var result = self.steps.items[0];
            for (self.steps.items[1..]) |step| {
                result = try result.compose(self.allocator, step);
            }
            return result;
        }
    };
}

// Tests
test "Object type alias" {
    const IntObj = i32;
    const StringObj = []const u8;
    
    try testing.expect(IntObj == i32);
    try testing.expect(StringObj == []const u8);
}

test "Morphism creation and application" {
    const IntObj = i32;
    const StringObj = []const u8;
    
    const intToString = Morphism(IntObj, StringObj){
        .f = struct {
            fn convert(x: i32) []const u8 {
                return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
            }
        }.convert,
    };
    
    try testing.expectEqualStrings("positive", intToString.apply(42));
    try testing.expectEqualStrings("negative", intToString.apply(-5));
    try testing.expectEqualStrings("zero", intToString.apply(0));
}

test "Identity morphism" {
    const IntObj = i32;
    const StringObj = []const u8;
    
    const id_int = Identity(IntObj);
    const id_string = Identity(StringObj);
    
    try testing.expect(id_int.apply(42) == 42);
    try testing.expect(id_int.apply(-10) == -10);
    
    const test_string = "hello";
    try testing.expectEqualStrings(test_string, id_string.apply(test_string));
}

test "Morphism composition" {
    const A = i32;
    const B = i32;
    const C = []const u8;
    
    const double = Morphism(A, B){
        .f = struct {
            fn f(x: i32) i32 {
                return x * 2;
            }
        }.f,
    };
    
    const toString = Morphism(B, C){
        .f = struct {
            fn f(x: i32) []const u8 {
                return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
            }
        }.f,
    };
    
    const composed = Compose(A, B, C, double, toString);
    
    try testing.expectEqualStrings("positive", composed.apply(21)); // 21 * 2 = 42 -> "positive"
    try testing.expectEqualStrings("negative", composed.apply(-3)); // -3 * 2 = -6 -> "negative"
    try testing.expectEqualStrings("zero", composed.apply(0)); // 0 * 2 = 0 -> "zero"
}

test "Identity laws" {
    const A = i32;
    const B = []const u8;
    
    const f = comptime Morphism(A, B){
        .f = struct {
            fn convert(x: i32) []const u8 {
                return if (x > 0) "positive" else "negative";
            }
        }.convert,
    };
    
    const id_A = comptime Identity(A);
    const id_B = comptime Identity(B);
    
    // Test left identity: id_B ∘ f = f
    const left_composed = comptime Compose(A, B, B, f, id_B);
    try testing.expectEqualStrings("positive", left_composed.apply(5));
    try testing.expectEqualStrings("negative", left_composed.apply(-3));
    
    // Test right identity: f ∘ id_A = f  
    const right_composed = comptime Compose(A, A, B, id_A, f);
    try testing.expectEqualStrings("positive", right_composed.apply(5));
    try testing.expectEqualStrings("negative", right_composed.apply(-3));
}

test "Composition associativity" {
    const A = i32;
    const B = i32;
    const C = i32;
    const D = []const u8;
    
    const f = comptime Morphism(A, B){
        .f = struct {
            fn call(x: i32) i32 {
                return x + 1;
            }
        }.call,
    };
    
    const g = comptime Morphism(B, C){
        .f = struct {
            fn call(x: i32) i32 {
                return x * 2;
            }
        }.call,
    };
    
    const h = comptime Morphism(C, D){
        .f = struct {
            fn call(x: i32) []const u8 {
                return if (x > 10) "big" else "small";
            }
        }.call,
    };
    
    // Test associativity: (h ∘ g) ∘ f = h ∘ (g ∘ f)
    const hg = comptime Compose(B, C, D, g, h);
    const left_assoc = comptime Compose(A, B, D, f, hg);
    
    const gf = comptime Compose(A, B, C, f, g);
    const right_assoc = comptime Compose(A, C, D, gf, h);
    
    try testing.expectEqualStrings("big", left_assoc.apply(5)); // (5+1)*2 = 12 -> "big"
    try testing.expectEqualStrings("big", right_assoc.apply(5)); // same result
    try testing.expectEqualStrings("small", left_assoc.apply(1)); // (1+1)*2 = 4 -> "small"
    try testing.expectEqualStrings("small", right_assoc.apply(1)); // same result
}

test "Runtime morphism creation and application" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const double = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x * 2;
            }
        }.call,
    };
    
    const runtime_double = try toRuntimeMorphism(i32, double, allocator);
    defer runtime_double.deinit(allocator);
    
    const result = runtime_double.apply(@as(i32, 21));
    try testing.expect(result == 42);
}

test "Runtime morphism composition" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const double = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x * 2;
            }
        }.call,
    };
    
    const add_one = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x + 1;
            }
        }.call,
    };
    
    const runtime_double = try toRuntimeMorphism(i32, i32, double, allocator);
    defer runtime_double.deinit(allocator);
    
    const runtime_add_one = try toRuntimeMorphism(i32, i32, add_one, allocator);
    defer runtime_add_one.deinit(allocator);
    
    const composed = try runtime_double.compose(allocator, runtime_add_one);
    defer composed.deinit(allocator);
    
    const result = composed.apply(@as(i32, 5));
    try testing.expect(result == 11); // (5 * 2) + 1 = 11
}

test "Runtime identity morphism" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const runtime_id = try RuntimeIdentity(i32, allocator);
    defer runtime_id.deinit(allocator);
    
    const result = runtime_id.apply(@as(i32, 42));
    try testing.expect(result == 42);
}

test "Runtime pipeline execution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var pipeline = RuntimePipeline.init(allocator);
    defer pipeline.deinit();
    
    const double = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x * 2;
            }
        }.call,
    };
    
    const add_one = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x + 1;
            }
        }.call,
    };
    
    const subtract_three = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x - 3;
            }
        }.call,
    };
    
    try pipeline.addStep(try toRuntimeMorphism(i32, i32, double, allocator));
    try pipeline.addStep(try toRuntimeMorphism(i32, i32, add_one, allocator));
    try pipeline.addStep(try toRuntimeMorphism(i32, i32, subtract_three, allocator));
    
    const result = pipeline.execute(@as(i32, 5));
    try testing.expect(result == 8); // ((5 * 2) + 1) - 3 = 8
}

test "Dynamic morphism configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const Config = struct {
        should_double: bool,
        should_add_one: bool,
    };
    
    const config = Config{
        .should_double = true,
        .should_add_one = false,
    };
    
    var pipeline = RuntimePipeline.init(allocator);
    defer pipeline.deinit();
    
    const double = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x * 2;
            }
        }.call,
    };
    
    const add_one = Morphism(i32, i32){
        .f = struct {
            fn call(x: i32) i32 {
                return x + 1;
            }
        }.call,
    };
    
    if (config.should_double) {
        try pipeline.addStep(try toRuntimeMorphism(i32, i32, double, allocator));
    }
    
    if (config.should_add_one) {
        try pipeline.addStep(try toRuntimeMorphism(i32, i32, add_one, allocator));
    }
    
    const result = pipeline.execute(@as(i32, 5));
    try testing.expect(result == 10); // Only doubling: 5 * 2 = 10
}
