const std = @import("std");

/// A morphism in a category, representing a function from type A to type B
pub fn Morphism(comptime A: type, comptime B: type) type {
    return struct {
        const Self = @This();

        /// The function implementing the morphism
        func: fn (A) B,

        /// Creates a new morphism from a function
        pub fn new(func: fn (A) B) Self {
            return Self{ .func = func };
        }

        /// Applies the morphism to a value
        pub fn apply(self: Self, value: A) B {
            return self.func(value);
        }

        /// Composes this morphism with another morphism
        pub fn compose(comptime self: Self, comptime other: anytype) Morphism(@TypeOf(other).Source, B) {
            const OtherType = @TypeOf(other);
            if (OtherType != Morphism(OtherType.Source, A)) {
                @compileError("Cannot compose morphisms: target type of second morphism must match source type of first");
            }

            return Morphism(OtherType.Source, B).new(struct {
                fn composed(x: OtherType.Source) B {
                    return self.func(other.func(x));
                }
            }.composed);
        }

        /// Returns the identity morphism for type A
        pub fn identity() Morphism(A, A) {
            return Morphism(A, A).new(struct {
                fn id(x: A) A {
                    return x;
                }
            }.id);
        }

        // Type metadata
        pub const Source = A;
        pub const Target = B;

        // Run validation at comptime
        comptime {
            validateTypes();
        }

        fn validateTypes() void {
            if (A == void or B == void) {
                @compileError("Source and target types cannot be void");
            }
        }
    };
}

// Example usage
test "morphism composition" {
    const add_one = Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const double = Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);

    // Test composition
    const composed = add_one.compose(double);
    const result = composed.apply(2);
    try std.testing.expectEqual(@as(i32, 5), result); // (2 * 2) + 1 = 5
}

test "morphism identity" {
    const id = Morphism(i32, i32).identity();
    const result = id.apply(42);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "morphism type checking" {
    const string_to_int = Morphism([]const u8, i32).new(struct {
        fn f(s: []const u8) i32 {
            return std.fmt.parseInt(i32, s, 10) catch 0;
        }
    }.f);

    const int_to_float = Morphism(i32, f32).new(struct {
        fn f(x: i32) f32 {
            return @floatFromInt(x);
        }
    }.f);

    // Test composition of different types
    const composed = int_to_float.compose(string_to_int);
    const result = composed.apply("42");
    try std.testing.expectEqual(@as(f32, 42.0), result);
}
