#[
  PyMeow - Python Game Hacking Library
  v1.4
  Meow @ 2020
]#

import tables, re, os, strutils
from strformat import fmt
from strutils import fromBin
from math import degToRad, cos, sin, sqrt

import nimpy, winim
import nimgl/[glfw, opengl, glfw/native]

var OverlayWindow: GLFWWindow

type
  Mod = object
    baseaddr: ByteAddress
    basesize*: DWORD

  Process* = object
    name*: string
    handle*: HANDLE
    pid*: DWORD
    baseaddr*: ByteAddress
    basesize*: DWORD
    modules*: Table[string, Mod]

  Font* = object
    font*: uint32
    fontHDC*: HDC

  Overlay* = object
    width*, height*, midX*, midY*: float
    hwnd*: int

#[
  Memory
]#

proc pidInfo(pid: DWORD): Process =
  var 
    snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE or TH32CS_SNAPMODULE32, pid)
    me = MODULEENTRY32(dwSize: sizeof(MODULEENTRY32).cint)

  defer: CloseHandle(snap)

  if Module32First(snap, me.addr) == 1:
    result = Process(
      name: nullTerminated($$me.szModule),
      pid: me.th32ProcessID,
      baseaddr: cast[ByteAddress](me.modBaseAddr),
      basesize: me.modBaseSize,
    )

    result.modules[result.name] = Mod(
      baseaddr: result.baseaddr,
      basesize: result.basesize,
    )

    while Module32Next(snap, me.addr) != 0:
      var m = Mod(
        baseaddr: cast[ByteAddress](me.modBaseAddr),
        basesize: me.modBaseSize,
      )
      result.modules[nullTerminated($$me.szModule)] = m

proc process_by_name(name: string): Process {.exportpy.} =
  var 
    pidArray = newSeq[int32](1024)
    read: DWORD

  assert EnumProcesses(pidArray[0].addr, 1024, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0 and p.name == name:
      p.handle = OpenProcess(PROCESS_ALL_ACCESS, 0, p.pid).DWORD
      if p.handle != 0:
        return p
      raise newException(Exception, fmt"Unable to open Process [Pid: {p.pid}] [Error code: {GetLastError()}]")
      
  raise newException(Exception, fmt"Process '{name}' not found")

proc wait_for_process(name: string, interval: int = 1500): Process {.exportpy.} =
  while true:
    try:
      result = processByName(name)
      break
    except:
      sleep(interval)

proc close(self: Process): bool {.discardable, exportpy.} = 
  CloseHandle(self.handle) == 1

proc memoryErr(m: string, a: ByteAddress) =
  raise newException(
    AccessViolationDefect,
    fmt"{m} failed [Address: 0x{a.toHex()}] [Error: {GetLastError()}]"
  )

proc read(self: Process, address: ByteAddress, t: typedesc): t =
  if ReadProcessMemory(
    self.handle, cast[pointer](address), result.addr, sizeof(t), nil
  ) == 0:
    memoryErr("Read", address)

proc write(self: Process, address: ByteAddress, data: any) =
  if WriteProcessMemory(
    self.handle, cast[pointer](address), data.unsafeAddr, sizeof(data), nil
  ) == 0:
    memoryErr("Write", address)

proc writeArray[T](self: Process, address: ByteAddress, data: openArray[T]) =
  if WriteProcessMemory(
    self.handle, cast[pointer](address), data.unsafeAddr, sizeof(T) * data.len, nil
  ) == 0:
    memoryErr("Write", address)

proc dma_addr(self: Process, baseAddr: ByteAddress, offsets: openArray[int]): ByteAddress {.exportpy.} =
  result = self.read(baseAddr, ByteAddress)
  for o in offsets:
    inc result, o
    result = self.read(result, ByteAddress)

proc readSeq(self: Process, address: ByteAddress, size: SIZE_T,  t: typedesc = byte): seq[t] =
  result = newSeq[t](size)
  if ReadProcessMemory(
    self.handle, cast[pointer](address), result[0].addr, size * sizeof(t), nil
  ) == 0:
    memoryErr("readSeq", address)

proc aob_scan(self: Process, pattern: string, module: Mod = Mod()): ByteAddress {.exportpy.} =
  var 
    scanBegin, scanEnd: int
    rePattern = re(
      pattern.toUpper().multiReplace((" ", ""), ("?", ".."), ("*", "..")),
      {reIgnoreCase, reDotAll}
    )

  if module.baseaddr != 0:
    scanBegin = module.baseaddr
    scanEnd = module.baseaddr + module.basesize
  else:
    var sysInfo = SYSTEM_INFO()
    GetSystemInfo(sysInfo.addr)
    scanBegin = cast[int](sysInfo.lpMinimumApplicationAddress)
    scanEnd = cast[int](sysInfo.lpMaximumApplicationAddress)

  var mbi = MEMORY_BASIC_INFORMATION()
  VirtualQueryEx(self.handle, cast[LPCVOID](scanBegin), mbi.addr, cast[SIZE_T](sizeof(mbi)))

  var curAddr = scanBegin
  while curAddr < scanEnd:
    curAddr += mbi.RegionSize.int
    VirtualQueryEx(self.handle, cast[LPCVOID](curAddr), mbi.addr, cast[SIZE_T](sizeof(mbi)))

    if mbi.State != MEM_COMMIT or mbi.State == PAGE_NOACCESS: continue

    var oldProt: DWORD
    VirtualProtectEx(self.handle, cast[LPCVOID](curAddr), mbi.RegionSize, PAGE_EXECUTE_READWRITE, oldProt.addr)
    let byteString = cast[string](self.readSeq(cast[ByteAddress](mbi.BaseAddress), mbi.RegionSize)).toHex()
    VirtualProtectEx(self.handle, cast[LPCVOID](curAddr), mbi.RegionSize, oldProt, nil)

    let r = byteString.findBounds(rePattern)
    if r.first != -1:
      return r.first div 2 + curAddr

proc nop_code(self: Process, address: ByteAddress, length: int = 1) {.exportpy.} =
  var oldProt: int32
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), length, 0x40, oldProt.addr)
  for i in 0..length-1:
    self.write(address + i, 0x90.byte)
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), length, oldProt, nil)

proc inject_dll(self: Process, dllPath: string) {.exportpy.} =
  let vPtr = VirtualAllocEx(self.handle, nil, dllPath.len(), MEM_RESERVE or MEM_COMMIT, PAGE_EXECUTE_READWRITE)
  WriteProcessMemory(self.handle, vPtr, dllPath[0].unsafeAddr, dllPath.len, nil)
  if CreateRemoteThread(self.handle, nil, 0, cast[LPTHREAD_START_ROUTINE](LoadLibraryA), vPtr, 0, nil) == 0:
    raise newException(Exception, fmt"Injection failed [Error: {GetLastError()}]")

proc page_protection(self: Process, address: ByteAddress, newProtection: int32 = 0x40): int32 {.exportpy.} =
  var mbi = MEMORY_BASIC_INFORMATION()
  discard VirtualQueryEx(self.handle, cast[LPCVOID](address), mbi.addr, cast[SIZE_T](sizeof(mbi)))
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), mbi.RegionSize, newProtection, result.addr)

proc read_string(self: Process, address: ByteAddress): string {.exportpy.} =
  let r = self.read(address, array[0..100, char])
  result = $cast[cstring](r[0].unsafeAddr)
proc read_int(self: Process, address: ByteAddress): int32 {.exportpy.} = 
  result = self.read(address, int32)
proc read_ints(self: Process, address: ByteAddress, size: int32): seq[int32] {.exportpy.} =
  result = self.readSeq(address, size, int32)
proc read_float(self: Process, address: ByteAddress): float32 {.exportpy.} = 
  result = self.read(address, float32)
proc read_floats(self: Process, address: ByteAddress, size: int32): seq[float32] {.exportpy.} = 
  result = self.readSeq(address, size, float32)
proc read_byte(self: Process, address: ByteAddress): byte {.exportpy.} = 
  result = self.read(address, byte)
proc read_bytes(self: Process, address: ByteAddress, size: int32): seq[byte] {.exportpy.} =
  result = self.readSeq(address, size, byte)

template write_data = self.write(address, data)
template write_datas = self.writeArray(address, data)
proc write_int(self: Process, address: ByteAddress, data: cint) {.exportpy.} = write_data
proc write_ints(self: Process, address: ByteAddress, data: openArray[cint]) {.exportpy.} = write_datas
proc write_float(self: Process, address: ByteAddress, data: cfloat) {.exportpy.} = write_data
proc write_floats(self: Process, address: ByteAddress, data: openArray[cfloat]) {.exportpy.} = write_datas
proc write_byte(self: Process, address: ByteAddress, data: byte) {.exportpy.} = write_data
proc write_bytes(self: Process, address: ByteAddress, data: openArray[byte]) {.exportpy.} = write_datas

#[
  overlay
]#

proc overlay_init(target: string = "Fullscreen", borderOffset: int32 = 25): Overlay {.exportpy.} =
  var rect: RECT
  assert glfwInit()

  glfwWindowHint(GLFWFloating, GLFWTrue)
  glfwWindowHint(GLFWDecorated, GLFWFalse)
  glfwWindowHint(GLFWResizable, GLFWFalse)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFWTrue)
  glfwWindowHint(GLFWSamples, 14)

  if target == "Fullscreen":
    let videoMode = getVideoMode(glfwGetPrimaryMonitor())
    result.width = videoMode.width.float32
    result.height = videoMode.height.float32
    result.midX = videoMode.width / 2
    result.midY = videoMode.height / 2
  else:
    let hwndWin = FindWindowA(nil, target)
    if hwndWin == 0:
      raise newException(Exception, fmt"Window ({target}) not found")

    GetWindowRect(hwndWin, rect.addr)
    result.width = rect.right.float32 - rect.left.float32
    result.height = rect.bottom.float32 - rect.top.float32 - borderOffset.float32
    result.midX = result.width / 2
    result.midY = result.height / 2

  OverlayWindow = glfwCreateWindow(result.width.int32 - 1, result.height.int32 - 1, "Meow", icon=false)
  OverlayWindow.setInputMode(GLFWCursorSpecial, GLFWCursorDisabled)
  OverlayWindow.makeContextCurrent()
  glfwSwapInterval(0)

  assert glInit()
  glPushAttrib(GL_ALL_ATTRIB_BITS)
  glMatrixMode(GL_PROJECTION)
  glLoadIdentity()
  glOrtho(0, result.width.float64, 0, result.height.float64, -1, 1)
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_BLEND)
  glDisable(GL_TEXTURE_2D)

  result.hwnd = cast[int](getWin32Window(OverlayWindow))
  # Note: GLFW_MOUSE_PASSTHROUGH window hint will be supported in GLFW 3.4
  SetWindowLong(result.hwnd, GWL_EXSTYLE, GetWindowLongW(result.hwnd, GWL_EXSTYLE) or WS_EX_TRANSPARENT)
  if target != "Fullscreen":
    SetWindowPos(result.hwnd, -1, rect.left, rect.top + borderOffset, 0, 0, 0x0001)

proc overlay_update(self: Overlay) {.exportpy.} =
  OverlayWindow.swapBuffers()
  glfwPollEvents()
  glClear(GL_COLOR_BUFFER_BIT)

proc overlay_deinit(self: Overlay) {.exportpy.} =
  OverlayWindow.destroyWindow()
  glfwTerminate()

proc overlay_close(self: Overlay) {.exportpy.} = OverlayWindow.setWindowShouldClose(true) 
proc overlay_loop(self: Overlay): bool {.exportpy.} = not OverlayWindow.windowShouldClose() 

#[
  bitmap font rendering
]#

proc font_init(height: int32, fontName: string): Font {.exportpy.} =
  result.fontHDC = wglGetCurrentDC()

  let
    hFont = CreateFont(-(height), 0, 0, 0, FW_BOLD, 0, 0, 0, ANSI_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE or
        DEFAULT_PITCH, cast[LPCWSTR](fontName))
    hOldFont = SelectObject(result.fontHDC, hFont)

  result.font = glGenLists(96)
  wglUseFontBitmaps(result.fontHDC, 32, 96, result.font.int32)
  SelectObject(result.fontHDC, hOldFont)
  discard DeleteObject(hFont)

proc font_deinit(self: Font) {.exportpy.} = glDeleteLists(self.font, 96)

proc font_print(self: Font, x, y: float, text: string, color: array[0..2, float32]) {.exportpy.} =
  glColor3f(color[0], color[1], color[2])
  glWindowPos2f(x, y)
  glPushAttrib(GL_LIST_BIT)
  glListBase(self.font - 32)
  glCallLists(cast[int32](text.len), GL_UNSIGNED_BYTE, cast[pointer](text[0].unsafeAddr))
  glPopAttrib()

#[
  2d drawings
]#

proc box(x, y, width, height, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINE_LOOP)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

proc alpha_box(x, y, width, height: float, color, outlineColor: array[0..2, float32], alpha: float) {.exportpy.} =
  box(x, y, width, height, 1.0, outlineColor)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()
  glDisable(GL_BLEND)

proc line(x1, y1, x2, y2, lineWidth: float, color: array[0..2, float32]) {.exportpy.} =
  glLineWidth(lineWidth)
  glBegin(GL_LINES)
  glColor3f(color[0], color[1], color[2])
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()

proc dashed_line(x1, y1, x2, y2, lineWidth: float, color: array[0..2, float32], factor: int32 = 2, pattern: string = "11111110000", alpha: float32 = 0.5) {.exportpy.} =
  glPushAttrib(GL_ENABLE_BIT)
  glLineStipple(factor, fromBin[uint16](pattern))
  glLineWidth(lineWidth)
  glEnable(GL_LINE_STIPPLE)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  glBegin(GL_LINES)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glEnd()
  glPopAttrib()

proc circle(x, y, radius: float, color: array[0..2, float32], filled: bool = true) {.exportpy.} =
  if filled: glBegin(GL_POLYGON)
  else: glBegin(GL_LINE_LOOP)

  glColor3f(color[0], color[1], color[2])
  for i in 0..<360:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc rad_circle(x, y, radius: float, value: int, color: array[0..2, float32]) {.exportpy.} =
  glBegin(GL_POLYGON)
  glColor3f(color[0], color[1], color[2])
  for i in 0..value:
    glVertex2f(
      cos(degToRad(i.float32)) * radius + x,
      sin(degToRad(i.float32)) * radius + y
    )
  glEnd()

proc triangle(x1, y1, x2, y2, x3, y3: float, color: array[0..2, float32], alpha: float) {.exportpy.} =
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glVertex2f(x3, y3)
  glEnd()
  glDisable(GL_BLEND)

#[
  misc
]#

proc set_foreground(winTitle: string): bool {.discardable, exportpy.} = 
  SetForeGroundWindow(FindWindowA(nil, winTitle))

proc mouse_move(self: Overlay, x, y: float32) {.exportpy.} =
  var input: INPUT
  input.mi = MOUSE_INPUT(
    dwFlags: MOUSEEVENTF_MOVE, 
    dx: (x - self.midX).int32,
    dy: -(y - self.midY).int32,
  )
  SendInput(1, input.addr, sizeof(input).int32)

proc mouse_click {.exportpy.} =
  var 
    down: INPUT
    release: INPUT

  down.mi = MOUSE_INPUT(dwFlags: MOUSEEVENTF_LEFTDOWN)
  release.mi = MOUSE_INPUT(dwFlags: MOUSEEVENTF_LEFTUP)

  SendInput(1, down.addr, cast[int32](sizeof(down)))
  sleep(3)
  SendInput(1, release.addr, cast[int32](sizeof(release)))
