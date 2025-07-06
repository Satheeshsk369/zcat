const std = @import("std");
const base = @import("category/base.zig");
const functors = @import("category/functors.zig");

// Category Theory Base - Pure Mathematical API
pub const Object = base.Object;
pub const Morphism = base.Morphism;
pub const Identity = base.Identity;

// Functors - Mappings between categories
pub const Functor = functors.Functor;
pub const IdentityFunctor = functors.IdentityFunctor;
pub const FunctorComposition = functors.FunctorComposition;
pub const ConstantFunctor = functors.ConstantFunctor;
