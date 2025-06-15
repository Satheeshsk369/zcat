const std = @import("std");

/// A categorical object that wraps any type T with identity morphism
pub fn CategoricalObject(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// Creates a new categorical object
        pub fn new(value: T) Self {
            return Self{ .value = value };
        }

        /// Returns the identity morphism (self-morphism)
        pub fn identity(self: Self) Self {
            return self;
        }

        /// Validates that T is a valid type for categorical operations
        fn validateType() void {
            // Basic type validation - ensure T is not void
            if (T == void) {
                @compileError("Type T cannot be void");
            }
        }

        // Run validation at comptime
        comptime {
            validateType();
        }
    };
}

// Example usage
test "categorical object" {
    const IntObject = CategoricalObject(i32);
    const obj = IntObject.new(42);

    // Test identity morphism
    const identity_obj = obj.identity();
    try std.testing.expectEqual(@as(i32, 42), identity_obj.value);
    try std.testing.expectEqual(obj.value, identity_obj.value);
}

test "categorical object with custom type" {
    const Point = struct {
        x: f32,
        y: f32,
    };

    const PointObject = CategoricalObject(Point);
    const point = Point{ .x = 1.0, .y = 2.0 };
    const obj = PointObject.new(point);

    // Test identity morphism
    const identity_obj = obj.identity();
    try std.testing.expectEqual(@as(f32, 1.0), identity_obj.value.x);
    try std.testing.expectEqual(@as(f32, 2.0), identity_obj.value.y);
}
