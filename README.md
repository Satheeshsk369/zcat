# zcat
> category theory implementation in zig

A mathematically rigorous category theory foundation built with Zig's type system. Provides zero-cost abstractions for objects, morphisms, identity elements, composition, and functors while maintaining strict adherence to categorical laws.

## Features

- **Type-Safe Objects**: Any Zig type can be a mathematical object
- **Morphisms**: Both compile-time and runtime structure-preserving mappings  
- **Functor Theory**: Identity, constant, and composition functors with law verification
- **Memory Safe**: Automatic resource management with proper cleanup
- **Zero Cost**: Compile-time optimizations with no runtime overhead
- **Comprehensive**: 13 examples demonstrating theory and practical applications

## Quick Start

```bash
zig build run    # Run comprehensive demo
zig build test   # Run mathematical law verification tests
```