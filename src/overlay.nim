import
  strutils, math, 
  nimpy, winim, nimgl/[glfw, glfw/native, opengl]
from strformat import fmt

pyExportModule("pymeow")

type
  Overlay* = object
    width*, height*, midX*, midY*: float
    hwnd: int

  Font = object
    font: uint32
    fontHDC: HDC

var OverlayWindow: GLFWWindow

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
  glfwWindowHint(GLFWSamples, 30)

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
  glDisable(GL_TEXTURE_2D)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  result.hwnd = cast[int](getWin32Window(OverlayWindow))
  # Note: GLFW_MOUSE_PASSTHROUGH window hint will be supported in GLFW 3.4
  SetWindowLong(result.hwnd, GWL_EXSTYLE, GetWindowLongW(result.hwnd, GWL_EXSTYLE) or WS_EX_TRANSPARENT)
  if target != "Fullscreen":
    SetWindowPos(result.hwnd, -1, rect.left, rect.top + borderOffset, 0, 0, 0x0001)

proc overlay_update(self: Overlay) {.exportpy.} =
  OverlayWindow.swapBuffers()
  glClear(GL_COLOR_BUFFER_BIT)
  glfwPollEvents()

proc overlay_deinit(self: Overlay) {.exportpy.} =
  OverlayWindow.destroyWindow()
  glfwTerminate()

proc overlay_close(self: Overlay) {.exportpy.} = 
  OverlayWindow.setWindowShouldClose(true)

proc overlay_loop(self: Overlay): bool {.exportpy.} = 
  not OverlayWindow.windowShouldClose()

proc overlay_set_pos(self: Overlay, x, y: int32) {.exportpy.} =
  SetWindowPos(self.hwnd, -1, x, y, 0, 0, 0x0001)

#[
  bitmap font rendering
]#

proc font_init(height: int32, fontName: string): Font {.exportpy.} =
  result.fontHDC = wglGetCurrentDC()

  let
    hFont = CreateFont(-(height), 0, 0, 0, FW_DONTCARE, 0, 0, 0, ANSI_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE or
        DEFAULT_PITCH, cast[cstring](fontName[0].unsafeAddr))
    hOldFont = SelectObject(result.fontHDC, hFont)

  result.font = glGenLists(96)
  wglUseFontBitmaps(result.fontHDC, 32, 96, result.font.int32)
  SelectObject(result.fontHDC, hOldFont)
  discard DeleteObject(hFont)

proc font_deinit(self: Font) {.exportpy.} = 
  glDeleteLists(self.font, 96)

proc font_print(self: Font, x, y: float, text: string, color: array[0..2, float32]) {.exportpy.} =
  glColor3f(color[0], color[1], color[2])
  glWindowPos2f(x, y)
  glPushAttrib(GL_LIST_BIT)
  glListBase(self.font - 32)
  glCallLists(cast[int32](text.len), GL_UNSIGNED_BYTE, cast[pointer](text[0].unsafeAddr))
  glPopAttrib()

#[
  2d shapes
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
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x, y)
  glVertex2f(x + width, y)
  glVertex2f(x + width, y + height)
  glVertex2f(x, y + height)
  glEnd()

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
  glBegin(GL_POLYGON)
  glColor4f(color[0], color[1], color[2], alpha)
  glVertex2f(x1, y1)
  glVertex2f(x2, y2)
  glVertex2f(x3, y3)
  glEnd()