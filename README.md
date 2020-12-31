# PyMeow
##### Python Library for external Game Hacking created with [Nim](https://nim-lang.org)

## [CSGo ESP](https://github.com/Sann0/PyMeow/blob/master/examples/csgo_esp.py):
![Alt text](https://i.ibb.co/jr5BNYx/csgo-py.png)

## [Assault Cube ESP](https://github.com/Sann0/PyMeow/blob/master/examples/ac_esp.py)
![Alt text](https://i.ibb.co/dcZ2htV/ac2-py.png)

## [Assault Cube Mem Hacks](https://github.com/Sann0/PyMeow/blob/master/examples/ac_hacks.py):
![Alt text](https://i.ibb.co/ZfdgcMS/ac-py.png)

## [SWBF2 ESP](https://github.com/Sann0/PyMeow/blob/master/examples/swbf2_esp.py)
![Alt text](https://i.ibb.co/tq49DD1/swbf-py.png)

## API:
```
-- Memory:
  process_by_name(name: string) -> Process
  wait_for_process(name: string) -> Process
  close(Process) -> bool

  read_string(Process, address: int) -> string
  read_int(Process, address: int) -> int
  read_ints(Process, address: int, size: int) -> int array
  read_uint(Process, address: int) -> int
  read_uints(Process, address: int, size: int) -> int array
  read_float(Process, address: int) -> float
  read_floats(Process, address: int, size: int) -> float array
  read_byte(Process, address: int) -> byte
  read_bytes(Process, address: int, size: int) -> byte array
  read_vec2(Process, address: int) -> vec2
  read_vec3(Process, address: int) -> vec3

  write_int(Process, address: int, data: int)
  write_ints(Process, address: int, data: int array)
  write_float(Process, address: int, data: float)
  write_floats(Process, address: int, data: float array)
  write_byte(Process, address: int, data: byte)
  write_bytes(Process, address: int, data: byte array)
  write_vec2(Process, address: int, data: Vec2)
  write_vec3(Process, address: int, data: Vec3)

  dma_addr(Process, baseAddr: int, offsets: array) -> int
  aob_scan(Process, pattern: string, module: Process["modules"]["moduleName"]) -> int
  nop_code(Process, address: int, length: int)
  inject_dll(Process, dllPath: string)
  page_protection(Process, address: int, newProtection: int = 0x40) -> int (old protection)

-- Overlay:
  overlay_init(target: string = "Fullscreen", borderOffset: int = 25) -> Overlay
  overlay_close(Overlay)
  overlay_deinit()
  overlay_loop(Overlay) -> bool
  
-- Drawings:
  font_init(height: int, fontName: string) -> Font
  font_deinit(Font)
  font_print(Font, x, y: float, text: string, color: rgb array)

  box(x, y, width, height, lineWidth: float, color: rgb array)
  alpha_box(x, y, width, height: float, color, outlineColor: rgb array, alpha: float)
  line(x1, y1, x2, y2, lineWidth: float, color: rgb array)
  dashed_line(x1, y1, x2, y2, lineWidth: float, color: rgb array, factor: int = 2, pattern: string = "11111110000", alpha: float = 0.5)
  circle(x, y, radius: float, color: rgb array, filled: bool = true)
  rad_circle(x, y, radius: float, value: int, color: rgb array)
  triangle(x1, y1, x2, y2, x3, y3: float, color: rgb array, alpha: float)

-- Vectors:
  vec2(x, y: float = 0) -> Vec2
  vec2_add(a, b: Vec2) -> Vec2
  vec2_del(a, b: Vec2) -> Vec2
  vec2_mult(a, b: Vec2) -> Vec2
  vec2_div(a, b: Vec2) -> Vec2
  vec2_mag(a, b: Vec2) -> float
  vec2_magSq(a, b: Vec2) -> float
  vec2_distance(a, b: Vec2) -> float
  vec2_closest(a: Vec2, b: Vec2 array) -> Vec2

  vec3(x, y, z: float = 0) -> Vec3
  vec3_add(a, b: Vec3) -> Vec3
  vec3_sub(a, b: Vec3) -> Vec3
  vec3_mult(a, b: Vec3) -> Vec3
  vec3_div(a, b: Vec3) -> Vec3
  vec3_mag(a, b: Vec3) -> float
  vec3_magSq(a, b: Vec3) -> float
  vec3_distance(a, b: Vec3) -> float
  vec3_closest(a: Vec2, b: Vec3 array) -> Vec3

-- Misc
  key_pressed(vKey: int) -> bool
  rgb(color: string) -> float array
  wts_ogl(Overlay, matrix: float array (16), pos: Vec3) -> Vec2
  wts_dx(Overlay, matrix: float array (16), pos: Vec3) -> Vec2
  set_foreground(title: string)
  mouse_click()
  mouse_move(overlay: Overlay, x, y: float)
```

###### credits to: [nimpy](https://github.com/yglukhov/nimpy), [winim](https://github.com/khchen/winim), [nimgl](https://github.com/nimgl/nimgl), [GuidedHacking](https://guidedhacking.com)