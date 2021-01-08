import math, nimpy

pyExportModule("pymeow")

type
  Vec2* = object
    x*, y*: float32
  Vec3* = object
    x*, y*, z*: float32

proc vec2(x, y: float32 = 0): Vec2 {.exportpy.} =
  result.x = x
  result.y = y
proc vec3(x, y, z: float32 = 0): Vec3 {.exportpy.} =
  result.x = x
  result.y = y
  result.z = z

proc vec2_add(a, b: Vec2): Vec2 {.exportpy.} =
  result.x = a.x + b.x
  result.y = a.y + b.y
proc vec3_add(a, b: Vec3): Vec3 {.exportpy.} =
  result.x = a.x + b.x
  result.y = a.y + b.y
  result.z = a.z + b.z

proc vec2_sub(a, b: Vec2): Vec2 {.exportpy.} =
  result.x = a.x - b.x
  result.y = a.y - b.y
proc vec3_sub(a, b: Vec3): Vec3 {.exportpy.} =
  result.x = a.x - b.x
  result.y = a.y - b.y
  result.z = a.z - b.z

proc vec2_mult(a, b: Vec2): Vec2 {.exportpy.} =
  result.x = a.x * b.x
  result.y = a.y * b.y
proc vec3_mult(a, b: Vec3): Vec3 {.exportpy.} =
  result.x = a.x * b.x
  result.y = a.y * b.y
  result.z = a.z * b.z

proc vec2_div(a, b: Vec2): Vec2 {.exportpy.} =
  result.x = a.x / b.x
  result.y = a.y / b.y
proc vec3_div(a, b: Vec3): Vec3 {.exportpy.} =
  result.x = a.x / b.x
  result.y = a.y / b.y
  result.z = a.z / b.z

proc vec2_magSq(self: Vec2): float32 {.exportpy.} =
  (self.x * self.x) + (self.y * self.y)
proc vec3_magSq(self: Vec3): float32 {.exportpy.} =
  (self.x * self.x) + (self.y * self.y) + (self.z * self.z)

proc vec2_mag(self: Vec2): float32 {.exportpy.} =
  sqrt(self.vec2_magSq())
proc vec3_mag(self: Vec3): float32 {.exportpy.} =
  sqrt(self.vec3_magSq())

proc vec2_distance(a, b: Vec2): float32 {.exportpy.} =
  vec2_mag(vec2_sub(a, b))
proc vec3_distance(a, b: Vec3): float32 {.exportpy.} =
  vec3_mag(vec3_sub(a, b))

proc vec2_closest(a: Vec2, b: varargs[Vec2]): Vec2 {.exportpy.} =
  var closest_value = float32.high
  for v in b:
    let dist = a.vec2_distance(v)
    if dist < closest_value:
      result = v
      closest_value = dist
proc vec3_closest(a: Vec3, b: varargs[Vec3]): Vec3 {.exportpy.} =
  var closest_value = float32.high
  for v in b:
    let dist = a.vec3_distance(v) 
    if a.vec3_distance(v) < closest_value:
      result = v
      closest_value = dist