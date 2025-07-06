const std = @import("std");
const basics = @import("category/basics.zig");

// Category Theory Basics - Compile-time API
pub const Object = basics.Object;
pub const Morphism = basics.Morphism;
pub const Identity = basics.Identity;
pub const Compose = basics.Compose;

// Runtime Composition API - Fat Pointer Pattern
pub const RuntimeMorphism = basics.RuntimeMorphism;
pub const RuntimeIdentity = basics.RuntimeIdentity;
pub const RuntimePipeline = basics.RuntimePipeline;
pub const toRuntimeMorphism = basics.toRuntimeMorphism;
