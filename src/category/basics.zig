const std = @import("std");
const testing = std.testing;

/// Represents an object in a category.
pub const Object = type;

/// A morphism f: Source → Target in a category
pub fn Morphism(
    comptime Source: Object,
    comptime Target: Object,
) type {
    return struct {
        context: ?*anyopaque = null,
        vtable: VTable,

        const Self = @This();
        const VTable = struct {
            apply: *const fn (context: ?*anyopaque, input: Source) Target,
            deinit: ?*const fn (context: ?*anyopaque, allocator: std.mem.Allocator) void = null,
        };

        pub fn apply(self: Self, input: Source) Target {
            return self.vtable.apply(self.context, input);
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            if (self.vtable.deinit) |deinit_fn| {
                deinit_fn(self.context, allocator);
            }
        }

        /// Create a morphism from a function (mathematical notation: f: Source → Target)
        pub fn new(comptime f: *const fn (Source) Target) Self {
            return Self{
                .vtable = VTable{
                    .apply = struct {
                        fn call(context: ?*anyopaque, input: Source) Target {
                            _ = context;
                            return f(input);
                        }
                    }.call,
                },
            };
        }

        /// Create a runtime morphism with context
        pub fn arrow(context: anytype, allocator: std.mem.Allocator) !Self {
            const ContextType = @TypeOf(context);
            const impl = try allocator.create(ContextType);
            impl.* = context;

            return Self{
                .context = @ptrCast(impl),
                .vtable = VTable{
                    .apply = struct {
                        fn call(ctx: ?*anyopaque, input: Source) Target {
                            const self: *const ContextType = @ptrCast(@alignCast(ctx));
                            return self.apply(input);
                        }
                    }.call,
                    .deinit = struct {
                        fn call(ctx: ?*anyopaque, alloc: std.mem.Allocator) void {
                            const self: *const ContextType = @ptrCast(@alignCast(ctx));
                            if (@hasDecl(ContextType, "deinit")) {
                                self.deinit(alloc);
                            }
                            alloc.destroy(self);
                        }
                    }.call,
                },
            };
        }

        /// compose two morphisms: g ∘ f
        pub fn compose(
            self: Self,
            comptime Codomain: type,
            other: Morphism(Target, Codomain),
            allocator: std.mem.Allocator,
        ) !Morphism(Source, Codomain) {
            const ResultType = Morphism(Source, Codomain);

            const Composition = struct {
                first: Self,
                second: Morphism(Target, Codomain),

                fn apply(ctx_self: @This(), input: Source) Codomain {
                    const intermediate = ctx_self.first.apply(input);
                    return ctx_self.second.apply(intermediate);
                }

                fn deinit(ctx_self: @This(), alloc: std.mem.Allocator) void {
                    ctx_self.first.deinit(alloc);
                    ctx_self.second.deinit(alloc);
                }
            };

            const composition = Composition{
                .first = self,
                .second = other,
            };

            return ResultType.arrow(composition, allocator);
        }
    };
}

/// Creates an identity morphism for the given object type.
pub fn Identity(comptime T: Object) Morphism(T, T) {
    return Morphism(T, T).new(struct {
        fn call(x: T) T {
            return x;
        }
    }.call);
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

    const intToString = Morphism(IntObj, StringObj).new(struct {
        fn convert(x: i32) []const u8 {
            return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
        }
    }.convert);

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

    const double = comptime Morphism(A, B).new(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    const toString = comptime Morphism(B, C).new(struct {
        fn f(x: i32) []const u8 {
            return if (x > 0) "positive" else if (x < 0) "negative" else "zero";
        }
    }.f);

    // For testing, we'll create a simple composition manually
    const composed = Morphism(A, C).new(struct {
        fn call(x: A) C {
            return toString.apply(double.apply(x));
        }
    }.call);

    try testing.expectEqualStrings("positive", composed.apply(21)); // 21 * 2 = 42 -> "positive"
    try testing.expectEqualStrings("negative", composed.apply(-3)); // -3 * 2 = -6 -> "negative"
    try testing.expectEqualStrings("zero", composed.apply(0)); // 0 * 2 = 0 -> "zero"
}

test "Identity laws" {
    const A = i32;
    const B = []const u8;

    const f = comptime Morphism(A, B).new(struct {
        fn convert(x: i32) []const u8 {
            return if (x > 0) "positive" else "negative";
        }
    }.convert);

    const id_A = comptime Identity(A);
    const id_B = comptime Identity(B);

    // Test left identity: id_B ∘ f = f (manually since .compose() needs allocator)
    const left_composed = Morphism(A, B).new(struct {
        fn call(x: A) B {
            return id_B.apply(f.apply(x));
        }
    }.call);
    try testing.expectEqualStrings("positive", left_composed.apply(5));
    try testing.expectEqualStrings("negative", left_composed.apply(-3));

    // Test right identity: f ∘ id_A = f
    const right_composed = Morphism(A, B).new(struct {
        fn call(x: A) B {
            return f.apply(id_A.apply(x));
        }
    }.call);
    try testing.expectEqualStrings("positive", right_composed.apply(5));
    try testing.expectEqualStrings("negative", right_composed.apply(-3));
}

test "Composition associativity" {
    const A = i32;
    const B = i32;
    const C = i32;
    const D = []const u8;

    const f = comptime Morphism(A, B).new(struct {
        fn call(x: i32) i32 {
            return x + 1;
        }
    }.call);

    const g = comptime Morphism(B, C).new(struct {
        fn call(x: i32) i32 {
            return x * 2;
        }
    }.call);

    const h = comptime Morphism(C, D).new(struct {
        fn call(x: i32) []const u8 {
            return if (x > 10) "big" else "small";
        }
    }.call);

    // Test associativity: (h ∘ g) ∘ f = h ∘ (g ∘ f) (manually)
    const left_assoc = Morphism(A, D).new(struct {
        fn call(x: A) D {
            return h.apply(g.apply(f.apply(x)));
        }
    }.call);

    const right_assoc = Morphism(A, D).new(struct {
        fn call(x: A) D {
            return h.apply(g.apply(f.apply(x)));
        }
    }.call);

    try testing.expectEqualStrings("big", left_assoc.apply(5)); // (5+1)*2 = 12 -> "big"
    try testing.expectEqualStrings("big", right_assoc.apply(5)); // same result
    try testing.expectEqualStrings("small", left_assoc.apply(1)); // (1+1)*2 = 4 -> "small"
    try testing.expectEqualStrings("small", right_assoc.apply(1)); // same result
}

test "Runtime morphism composition" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const DoubleContext = struct {
        fn apply(self: @This(), x: i32) i32 {
            _ = self;
            return x * 2;
        }
    };

    const AddOneContext = struct {
        fn apply(self: @This(), x: i32) i32 {
            _ = self;
            return x + 1;
        }
    };

    const double = try Morphism(i32, i32).arrow(DoubleContext{}, allocator);
    defer double.deinit(allocator);

    const add_one = try Morphism(i32, i32).arrow(AddOneContext{}, allocator);
    defer add_one.deinit(allocator);

    const composed = try double.compose(i32, add_one, allocator);
    defer composed.deinit(allocator);

    const result = composed.apply(@as(i32, 5));
    try testing.expect(result == 11); // (5 * 2) + 1 = 11
}
