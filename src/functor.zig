const std = @import("std");
const object = @import("object.zig");
const morphism = @import("morphism.zig");

/// A functor maps between categories, preserving structure
pub fn Functor(comptime F: type) type {
    return struct {
        const Self = @This();

        /// Maps a morphism over the functor's objects
        pub fn fmap(comptime f: anytype) F(@TypeOf(f).Target) {
            const A = @TypeOf(f).Source;
            const B = @TypeOf(f).Target;

            // Verify f is a valid morphism
            if (@TypeOf(f) != morphism.Morphism(A, B)) {
                @compileError("fmap requires a valid morphism");
            }

            return mapImpl(f);
        }

        /// Verifies that the functor preserves identity
        pub fn verifyIdentity(comptime fa: anytype) bool {
            const A = @TypeOf(fa).T;
            const id = morphism.Morphism(A, A).identity();
            const mapped_id = fmap(id);
            return std.meta.eql(mapped_id, fa);
        }

        /// Verifies that the functor preserves composition
        pub fn verifyComposition(comptime f: anytype, comptime g: anytype) bool {
            const A = @TypeOf(f).Source;
            const B = @TypeOf(f).Target;
            const C = @TypeOf(g).Target;

            if (@TypeOf(f) != morphism.Morphism(A, B) or
                @TypeOf(g) != morphism.Morphism(B, C))
            {
                @compileError("Invalid morphism types for composition");
            }

            const composed = g.compose(f);
            const mapped_composed = fmap(composed);
            const mapped_f = fmap(f);
            const mapped_g = fmap(g);
            const composed_mapped = mapped_g.compose(mapped_f);

            return std.meta.eql(mapped_composed, composed_mapped);
        }

        // Implementation details
        fn mapImpl(comptime f: anytype) F(@TypeOf(f).Target) {
            // This is a placeholder - concrete functors must implement their own mapping
            @compileError("Concrete functors must implement mapImpl");
        }
    };
}

/// Example: Maybe functor (Option type)
pub fn Maybe(comptime T: type) type {
    return struct {
        const Self = @This();
        value: union(enum) {
            Some: T,
            None,
        },

        /// Creates a new Maybe with Some value
        pub fn some(value: T) Self {
            return Self{ .value = .{ .Some = value } };
        }

        /// Creates a new Maybe with None value
        pub fn none() Self {
            return Self{ .value = .None };
        }

        /// Maps a function over the Maybe value
        pub fn map(self: Self, comptime f: anytype) Maybe(@TypeOf(f).Target) {
            return switch (self.value) {
                .Some => |x| Maybe(@TypeOf(f).Target).some(f.apply(x)),
                .None => Maybe(@TypeOf(f).Target).none(),
            };
        }
    };
}

// Example usage
test "maybe functor" {
    const add_one = morphism.Morphism(i32, i32).new(struct {
        fn f(x: i32) i32 {
            return x + 1;
        }
    }.f);

    const maybe = Maybe(i32).some(42);
    const mapped = maybe.map(add_one);
    try std.testing.expectEqual(@as(i32, 43), mapped.value.Some);

    const none = Maybe(i32).none();
    const mapped_none = none.map(add_one);
    try std.testing.expectEqual(Maybe(i32).none().value, mapped_none.value);
}

test "functor laws" {
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

    const maybe = Maybe(i32).some(42);

    // Test identity law
    const id = morphism.Morphism(i32, i32).identity();
    const mapped_id = maybe.map(id);
    try std.testing.expectEqual(maybe.value, mapped_id.value);

    // Test composition law
    const composed = double.compose(add_one);
    const mapped_composed = maybe.map(composed);
    const mapped_add = maybe.map(add_one);
    const mapped_double = mapped_add.map(double);
    try std.testing.expectEqual(mapped_composed.value, mapped_double.value);
}
