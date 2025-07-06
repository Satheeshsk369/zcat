# Category Theory Basics

This document explains the design choices for the foundational category theory implementation in `src/category/basics.zig`.

## Design Philosophy

### Type-Based Objects
We use Zig's `type` directly as our Object representation:
```zig
pub const Object = type;
```
Re-export core category theory concepts with PascalCase naming
**Why this approach?**
- Leverages Zig's compile-time type system naturally
- Avoids concrete limitations (like u32 IDs)
- Makes the implementation truly abstract
- Enables direct use of any Zig type as a category object

### Generic Morphisms
Morphisms are implemented as generic functions that take source and target Object types:
```zig
pub fn Morphism(comptime source: Object, comptime target: Object) type
```

**Why this approach?**
- Type-safe: prevents composition of incompatible morphisms
- Compile-time checked: morphism validity verified at compile time
- Flexible: works with any function signature matching source → target
- Mathematical: directly represents the mathematical concept

### Identity and Composition
Core category laws are implemented as standalone functions:
- `Identity(T)` - creates identity morphism for type T using inline struct pattern
- `Compose(A, B, C, f, g)` - composes morphisms f: A→B and g: B→C using inline struct pattern

**Why standalone functions?**
- Clear mathematical semantics
- Easy to understand and use
- Follows functional programming principles
- Enables method chaining and composition patterns

**Important: Comptime-Only Composition**
The `Compose` function requires all morphism parameters to be `comptime` due to Zig's closure limitations:
- Inner functions cannot capture variables from outer scopes at runtime
- By making parameters `comptime`, they become available at compile-time
- This provides zero runtime overhead as composition is resolved at compile-time
- Morphisms being composed must be known at compile-time

## Category Laws Satisfied

1. **Identity Law**: `id_B ∘ f = f` and `f ∘ id_A = f`
2. **Associativity**: `(h ∘ g) ∘ f = h ∘ (g ∘ f)`

These laws are enforced by the type system and implementation structure.

## Usage Pattern

```zig
const zcat = @import("zcat");

// Objects are just types
const A = i32;
const B = []const u8;

// Create morphisms
const f = zcat.Morphism(A, B){ .f = myFunction };
const id_A = zcat.Identity(A);

// Compose morphisms
const composed = zcat.Compose(A, B, C, f, g);
```
