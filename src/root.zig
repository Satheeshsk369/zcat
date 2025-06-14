const std = @import("std");

/// Represents an object in a category
pub const Object = struct {
    name: []const u8,

    const Self = @This();

    pub fn init(comptime name: []const u8) Self {
        return Self{ .name = name };
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.name, other.name);
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Obj({s})", .{self.name});
    }
};

/// Represents a morphism between two objects in a category
pub const Morphism = struct {
    name: []const u8,
    source: Object,
    target: Object,

    const Self = @This();

    pub fn init(comptime name: []const u8, source: Object, target: Object) Self {
        return Self{
            .name = name,
            .source = source,
            .target = target,
        };
    }

    /// Check if two morphisms can be composed (g ∘ f)
    pub fn canCompose(f: Self, g: Self) bool {
        return f.target.eql(g.source);
    }

    /// Create identity morphism for an object
    pub fn identity(comptime obj: Object) Self {
        return Self.init("id_" ++ obj.name, obj, obj);
    }

    /// Compose two morphisms at compile time
    pub fn compose(comptime f: Self, comptime g: Self) Self {
        if (!comptime f.canCompose(g)) {
            @compileError("Cannot compose morphisms: target of f must equal source of g");
        }
        return Self.init(g.name ++ "∘" ++ f.name, f.source, g.target);
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}: {} → {}", .{ self.name, self.source, self.target });
    }
};

/// Compile-time category builder
pub fn Category(comptime name: []const u8, comptime objects: []const Object, comptime morphisms: []const Morphism) type {
    // Validate at compile time that all morphisms reference existing objects
    comptime {
        for (morphisms) |morph| {
            var source_found = false;
            var target_found = false;

            for (objects) |obj| {
                if (obj.eql(morph.source)) source_found = true;
                if (obj.eql(morph.target)) target_found = true;
            }

            if (!source_found) {
                @compileError("Morphism '" ++ morph.name ++ "' references non-existent source object");
            }
            if (!target_found) {
                @compileError("Morphism '" ++ morph.name ++ "' references non-existent target object");
            }
        }
    }

    return struct {
        pub const category_name = name;
        pub const category_objects = objects;
        pub const category_morphisms = morphisms;

        /// Find object by name at compile time
        pub fn findObject(comptime obj_name: []const u8) ?Object {
            comptime {
                for (objects) |obj| {
                    if (std.mem.eql(u8, obj.name, obj_name)) {
                        return obj;
                    }
                }
                return null;
            }
        }

        /// Find morphism by name at compile time
        pub fn findMorphism(comptime morph_name: []const u8) ?Morphism {
            comptime {
                for (morphisms) |morph| {
                    if (std.mem.eql(u8, morph.name, morph_name)) {
                        return morph;
                    }
                }
                return null;
            }
        }

        /// Get all morphisms from source to target
        pub fn getMorphisms(comptime source: Object, comptime target: Object) []const Morphism {
            comptime {
                var result: []const Morphism = &[_]Morphism{};
                for (morphisms) |morph| {
                    if (morph.source.eql(source) and morph.target.eql(target)) {
                        result = result ++ [_]Morphism{morph};
                    }
                }
                return result;
            }
        }

        /// Check if category laws are satisfied (compile-time verification)
        pub fn verify() void {
            comptime {
                // Check that identity morphisms exist for all objects
                for (objects) |obj| {
                    var id_found = false;
                    for (morphisms) |morph| {
                        if (morph.source.eql(obj) and morph.target.eql(obj) and
                            (std.mem.eql(u8, morph.name, "id_" ++ obj.name) or
                                std.mem.startsWith(u8, morph.name, "id")))
                        {
                            id_found = true;
                            break;
                        }
                    }
                    if (!id_found) {
                        @compileError("Missing identity morphism for object: " ++ obj.name);
                    }
                }
            }
        }

        pub fn print() void {
            std.debug.print("Category: {s}\n", .{category_name});
            std.debug.print("Objects:\n");
            inline for (category_objects) |obj| {
                std.debug.print("  {}\n", .{obj});
            }
            std.debug.print("Morphisms:\n");
            inline for (category_morphisms) |morph| {
                std.debug.print("  {}\n", .{morph});
            }
        }
    };
}

/// Helper function to create categories with automatic identity morphisms
pub fn CategoryWithIdentities(comptime name: []const u8, comptime objects: []const Object, comptime extra_morphisms: []const Morphism) type {
    comptime {
        // Generate identity morphisms for all objects
        var identities: [objects.len]Morphism = undefined;
        for (objects, 0..) |obj, i| {
            identities[i] = Morphism.identity(obj);
        }

        // Combine identities with extra morphisms
        const all_morphisms = identities ++ extra_morphisms;

        return Category(name, objects, all_morphisms);
    }
}
