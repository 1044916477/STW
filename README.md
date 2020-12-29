# PyMeow
##### Python Library for external Game Hacking created with [Nim](https://nim-lang.org)

## [CSGo ESP](https://github.com/Sann0/PyMeow/blob/master/examples/csgo_esp.py):
![Alt text](https://i.ibb.co/WtcRsWv/csgo-py.png)

## [Assault Cube ESP](https://github.com/Sann0/PyMeow/blob/master/examples/ac_esp.py)
![Alt text](https://i.ibb.co/gzQgQyQ/ac2-py.png)

## [Assault Cube Mem Hacks](https://github.com/Sann0/PyMeow/blob/master/examples/ac_hacks.py):
![Alt text](https://i.ibb.co/ZfdgcMS/ac-py.png)

## API:
```
-- Memory:
  process_by_name(name: string) -> Process
  wait_for_process(name: string) -> Process
  close(Process) -> bool

  read_string(Process, address: int) -> string
  read_int(Process, address: int) -> int
  read_ints(Process, address: int, size: int) -> int array
  read_float(Process, address: int) -> float
  read_floats(Process, address: int, size: int) -> float array
  read_byte(Process, address: int) -> byte
  read_bytes(Process, address: int, size: int) -> byte array

  write_int(Process, address: int, data: int)
  write_ints(Process, address: int, data: int array)
  write_float(Process, address: int, data: float)
  write_floats(Process, address: int, data: float array)
  write_byte(Process, address: int, data: byte)
  write_bytes(Process, address: int, data: byte array)

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
  dashed_line(x1, y1, x2, y2, lineWidth: float, color: rgb array, factor = 2: int, pattern = "11111110000": string, alpha = 0.5: float)
  circle(x, y, radius: float, color: rgb array, filled = true: bool)
  rad_circle(x, y, radius: float, value: int, color: rgb array)
  triangle(x1, y1, x2, y2, x3, y3: float, color: rgb array, alpha: float)
  
-- Misc
  set_foreground(title: string)
  mouse_click()
  mouse_move(overlay: Overlay, x, y: float)
```

###### credits to: [nimpy](https://github.com/yglukhov/nimpy), [winim](https://github.com/khchen/winim), [nimgl](https://github.com/nimgl/nimgl), [GuidedHacking](https://guidedhacking.com)