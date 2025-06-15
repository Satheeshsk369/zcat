const std = @import("std");
const morphism = @import("morphism.zig");

/// A product type representing a tuple of types
pub fn Product(comptime types: type) type {
    const type_info = @typeInfo(types);
    if (type_info != .@"struct") {
        @compileError("Product requires a struct type");
    }
    const fields = type_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Product requires at least one field");
    }

    return struct {
        values: types,

        const Self = @This();

        /// Creates a new product
        pub fn new(values: types) Self {
            return Self{ .values = values };
        }

        /// Projection morphism to get the i-th component
        pub fn project(comptime i: comptime_int) morphism.Morphism(Self, @TypeOf(@field(@as(types, undefined), fields[i].name))) {
            if (i >= fields.len) {
                @compileError("Projection index out of bounds");
            }

            return morphism.Morphism(Self, @TypeOf(@field(@as(types, undefined), fields[i].name))).new(struct {
                fn proj(p: Self) @TypeOf(@field(@as(types, undefined), fields[i].name)) {
                    return @field(p.values, fields[i].name);
                }
            }.proj);
        }

        /// Universal property: given morphisms to each component, construct a unique morphism to the product
        pub fn universal(comptime morphisms: anytype) morphism.Morphism(@TypeOf(@field(morphisms, @typeInfo(@TypeOf(morphisms)).@"struct".fields[0].name)).Source, Self) {
            const SourceType = @TypeOf(@field(morphisms, @typeInfo(@TypeOf(morphisms)).@"struct".fields[0].name)).Source;
            const morphism_fields = @typeInfo(@TypeOf(morphisms)).@"struct".fields;

            if (morphism_fields.len != fields.len) {
                @compileError("Number of morphisms must match number of product components");
            }

            return morphism.Morphism(SourceType, Self).new(struct {
                fn univ(x: SourceType) Self {
                    var result: types = undefined;
                    inline for (fields, 0..) |field, i| {
                        const morph = @field(morphisms, morphism_fields[i].name);
                        @field(result, field.name) = morph.apply(x);
                    }
                    return Self{ .values = result };
                }
            }.univ);
        }
    };
}

/// A coproduct type representing a union of types
pub fn Coproduct(comptime types: type) type {
    const type_info = @typeInfo(types);
    if (type_info != .@"struct") {
        @compileError("Coproduct requires a struct type");
    }
    const fields = type_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Coproduct requires at least one field");
    }

    // Create the union type with all variants
    var union_fields: [fields.len]std.builtin.Type.UnionField = undefined;
    var enum_fields: [fields.len]std.builtin.Type.EnumField = undefined;
    inline for (fields, 0..) |field, i| {
        union_fields[i] = .{
            .name = field.name,
            .type = @TypeOf(@field(@as(types, undefined), field.name)),
            .alignment = @alignOf(@TypeOf(@field(@as(types, undefined), field.name))),
        };
        enum_fields[i] = .{
            .name = field.name,
            .value = i,
        };
    }

    const UnionType = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = @Type(.{
                .@"enum" = .{
                    .tag_type = u8,
                    .fields = &enum_fields,
                    .decls = &.{},
                    .is_exhaustive = true,
                },
            }),
            .fields = &union_fields,
            .decls = &.{},
        },
    });

    return struct {
        value: UnionType,

        const Self = @This();

        /// Injection morphism to inject a value of type T into the coproduct
        pub fn inject(comptime ValueType: type, comptime tag: []const u8) morphism.Morphism(ValueType, Self) {
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, tag)) {
                    if (ValueType != @TypeOf(@field(@as(types, undefined), field.name))) {
                        @compileError("Injection type must match coproduct component type");
                    }
                    return morphism.Morphism(ValueType, Self).new(struct {
                        fn inj(x: ValueType) Self {
                            return Self{
                                .value = @unionInit(UnionType, tag, x),
                            };
                        }
                    }.inj);
                }
            }
            @compileError("Invalid injection tag");
        }

        /// Universal property: given morphisms from each component, construct a unique morphism from the coproduct
        pub fn universal(comptime morphisms: anytype) morphism.Morphism(Self, @TypeOf(@field(morphisms, @typeInfo(@TypeOf(morphisms)).@"struct".fields[0].name)).Target) {
            const TargetType = @TypeOf(@field(morphisms, @typeInfo(@TypeOf(morphisms)).@"struct".fields[0].name)).Target;
            const morphism_fields = @typeInfo(@TypeOf(morphisms)).@"struct".fields;

            if (morphism_fields.len != fields.len) {
                @compileError("Number of morphisms must match number of coproduct components");
            }

            return morphism.Morphism(Self, TargetType).new(struct {
                fn univ(x: Self) TargetType {
                    inline for (fields) |field| {
                        if (std.mem.eql(u8, @tagName(x.value), field.name)) {
                            const morph = @field(morphisms, field.name);
                            return morph.apply(@field(x.value, field.name));
                        }
                    }
                    unreachable;
                }
            }.univ);
        }
    };
}

// Example usage
test "product" {
    const Point = Product(struct {
        x: f32,
        y: f32,
    });

    const point = Point.new(.{ .x = 1.0, .y = 2.0 });

    // Test projections
    const proj_x = Point.project(0);
    const proj_y = Point.project(1);

    try std.testing.expectEqual(@as(f32, 1.0), proj_x.apply(point));
    try std.testing.expectEqual(@as(f32, 2.0), proj_y.apply(point));

    // Test universal property
    const to_float = morphism.Morphism(i32, f32).new(struct {
        fn to_float(x: i32) f32 {
            return @floatFromInt(x);
        }
    }.to_float);

    const to_double = morphism.Morphism(i32, f32).new(struct {
        fn to_double(x: i32) f32 {
            return @floatFromInt(x * 2);
        }
    }.to_double);

    const univ = Point.universal(.{ .x = to_float, .y = to_double });
    const result = univ.apply(1);
    try std.testing.expectEqual(@as(f32, 1.0), result.values.x);
    try std.testing.expectEqual(@as(f32, 2.0), result.values.y);

    // Test that the universal property commutes with projections
    try std.testing.expectEqual(to_float.apply(1), proj_x.apply(result));
    try std.testing.expectEqual(to_double.apply(1), proj_y.apply(result));
}

test "coproduct" {
    const Result = Coproduct(struct {
        Ok: i32,
        Err: []const u8,
    });

    // Test injections
    const inj_ok = Result.inject(i32, "Ok");
    const inj_err = Result.inject([]const u8, "Err");

    const ok = inj_ok.apply(42);
    const err = inj_err.apply("error");

    try std.testing.expectEqual(@as(i32, 42), ok.value.Ok);
    try std.testing.expectEqualStrings("error", err.value.Err);

    // Test universal property
    const to_ok = morphism.Morphism(i32, []const u8).new(struct {
        fn to_ok(_: i32) []const u8 {
            return "ok";
        }
    }.to_ok);

    const to_err = morphism.Morphism([]const u8, []const u8).new(struct {
        fn to_err(s: []const u8) []const u8 {
            return s;
        }
    }.to_err);

    const univ = Result.universal(.{ .Ok = to_ok, .Err = to_err });
    try std.testing.expectEqualStrings("ok", univ.apply(ok));
    try std.testing.expectEqualStrings("error", univ.apply(err));
}
