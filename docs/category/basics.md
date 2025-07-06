# Category Theory Basics

This document explains the design choices for the foundational category theory implementation in `src/category/basics.zig`.

## Design Philosophy

### Type-Based Objects
We use Zig's `type` directly as our Object representation:
```zig
pub const Object = type;
```

**Why this approach?**
- Leverages Zig's compile-time type system naturally
- Avoids concrete limitations (like u32 IDs)
- Makes the implementation truly abstract
- Enables direct use of any Zig type as a category object

### Unified Morphism System
Morphisms are implemented as a unified type that supports both compile-time and runtime contexts:
```zig
pub fn Morphism(comptime Source: Object, comptime Target: Object) type
```

**Key features:**
- **Vtable-based dispatch**: Enables runtime polymorphism when needed
- **Zero-cost abstraction**: Compile-time morphisms have no runtime overhead
- **Type-safe composition**: Prevents composition of incompatible morphisms
- **Mathematical purity**: Directly represents the mathematical concept f: A → B

### Morphism Creation Methods
Two methods for creating morphisms:

1. **`new()`** - Creates compile-time morphisms from functions:
```zig
const f = Morphism(i32, []const u8).new(struct {
    fn convert(x: i32) []const u8 {
        return if (x > 0) "positive" else "negative";
    }
}.convert);
```

2. **`arrow()`** - Creates runtime morphisms with context:
```zig
const Context = struct {
    pub fn apply(self: @This(), x: i32) i32 {
        return x * 2;
    }
};
const f = try Morphism(i32, i32).arrow(Context{}, allocator);
```

**Why "arrow"?**
- Morphisms are arrows in category theory
- Emphasizes the mathematical nature of the operation
- Distinguishes runtime context-based creation from compile-time function creation

### Identity and Composition
Core category operations:

1. **Identity**: `Identity(T)` creates identity morphism for type T
2. **Composition**: `morphism.compose(Codomain, other, allocator)` composes morphisms

**Composition semantics:**
- Given `f: A → B` and `g: B → C`, `f.compose(C, g, allocator)` creates `g ∘ f: A → C`
- Supports both compile-time and runtime morphisms
- Uses vtable dispatch for runtime composition
- Memory management via allocator for runtime compositions

## Category Laws Satisfied

1. **Identity Law**: `id_B ∘ f = f` and `f ∘ id_A = f`
2. **Associativity**: `(h ∘ g) ∘ f = h ∘ (g ∘ f)`

These laws are enforced by the type system and implementation structure.

## Usage Patterns

### Compile-time Morphisms
```zig
const zcat = @import("zcat");

// Objects are just types
const A = i32;
const B = []const u8;

// Create compile-time morphisms
const f = zcat.Morphism(A, B).new(myFunction);
const id_A = zcat.Identity(A);

// Manual composition (zero-cost)
const composed = zcat.Morphism(A, B).new(struct {
    fn call(x: A) B {
        return g.apply(f.apply(x));
    }
}.call);
```

### Runtime Morphisms
```zig
// Create runtime morphisms with context
const Context = struct {
    multiplier: i32,
    pub fn apply(self: @This(), x: i32) i32 {
        return x * self.multiplier;
    }
};

const f = try zcat.Morphism(i32, i32).arrow(Context{ .multiplier = 2 }, allocator);
defer f.deinit(allocator);

// Runtime composition
const composed = try f.compose(i32, g, allocator);
defer composed.deinit(allocator);
```

## Architecture Benefits

1. **Unified API**: Single morphism type handles both compile-time and runtime cases
2. **Performance**: Zero overhead for compile-time morphisms, efficient vtable dispatch for runtime
3. **Mathematical**: Clean representation of category theory concepts
4. **Flexible**: Supports both pure functions and stateful contexts
5. **Type-safe**: Zig's type system prevents invalid morphism compositions
