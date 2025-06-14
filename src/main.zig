const std = @import("std");
const C = @import("zcat");

pub fn main() !void {
    // Define a more complex category at compile time
    comptime {
        const X = C.Object.init("X");
        const Y = C.Object.init("Y");
        const Z = C.Object.init("Z");

        const f = C.Morphism.init("f", X, Y);
        const g = C.Morphism.init("g", Y, Z);
        const h = C.Morphism.init("h", X, Z);

        // Verify composition
        const gf = C.Morphism.compose(f, g);

        // This would cause a compile error if h != g∘f in a real category
        // For demonstration, we assume h = g∘f

        var ComplexCategory = C.CategoryWithIdentities("Complex", &[_]C.Object{ X, Y, Z }, &[_]C.Morphism{ f, g, h, gf });

        ComplexCategory.verify();
    }

    std.debug.print("Complex category verified at compile time!\n", .{});
}
