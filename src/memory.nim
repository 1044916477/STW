import 
  os, tables, strutils,
  winim, nimpy, regex,
  vector
from strformat import fmt

pyExportModule("pymeow")

type
  Mod = object
    baseaddr: ByteAddress
    basesize: DWORD

  Process = object
    name: string
    handle: HANDLE
    pid: DWORD
    baseaddr: ByteAddress
    basesize: DWORD
    modules: Table[string, Mod]

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
    if p.pid != 0 and name == p.name:
      p.handle = OpenProcess(PROCESS_ALL_ACCESS, 0, p.pid).DWORD
      if p.handle != 0:
        return p
      raise newException(Exception, fmt"Unable to open Process [Pid: {p.pid}] [Error code: {GetLastError()}]")
      
  raise newException(Exception, fmt"Process '{name}' not found")

iterator enumerate_processes: Process {.exportpy.} =
  var 
    pidArray = newSeq[int32](1024)
    read: DWORD

  assert EnumProcesses(pidArray[0].addr, 1024, read.addr) != FALSE

  for i in 0..<read div 4:
    var p = pidInfo(pidArray[i])
    if p.pid != 0: 
      yield p

proc wait_for_process(name: string, interval: int = 1500): Process {.exportpy.} =
  while true:
    try:
      return processByName(name)
    except:
      sleep(interval)

proc close(self: Process): bool {.discardable, exportpy.} = 
  CloseHandle(self.handle) == 1

proc memoryErr(m: string, a: ByteAddress) {.inline.} =
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
  result = self.read(baseAddr, int32)
  for o in offsets:
    result = self.read(result + o, int32)

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
      pattern.toUpper().multiReplace((" ", ""), ("??", "?"), ("?", ".."), ("*", ".."))
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

    let r = byteString.findAllBounds(rePattern)
    if r.len != 0:
      return r[0].a div 2 + curAddr

proc nop_code(self: Process, address: ByteAddress, length: int = 1) {.exportpy.} =
  var oldProt: int32
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), length, 0x40, oldProt.addr)
  for i in 0..length-1:
    self.write(address + i, 0x90.byte)
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), length, oldProt, nil)

proc patch_bytes(self: Process, address: ByteAddress, data: openArray[byte]) {.exportpy.} =
  var oldProt: int32
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), data.len, 0x40, oldProt.addr)
  for i, b in data:
    self.write(address + i, b)
  discard VirtualProtectEx(self.handle, cast[LPCVOID](address), data.len, oldProt, nil)

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
  $cast[cstring](r[0].unsafeAddr)
proc read_int(self: Process, address: ByteAddress): int32 {.exportpy.} = self.read(address, int32)
proc read_ints(self: Process, address: ByteAddress, size: int32): seq[int32] {.exportpy.} = self.readSeq(address, size, int32)
proc read_int64(self: Process, address: ByteAddress): int64 {.exportpy.} = self.read(address, int64)
proc read_ints64(self: Process, address: ByteAddress, size: int32): seq[int64] {.exportpy.} = self.readSeq(address, size, int64)
proc read_uint(self: Process, address: ByteAddress): uint32 {.exportpy.} = self.read(address, uint32)
proc read_uints(self: Process, address: ByteAddress, size: int32): seq[uint32] {.exportpy.} = self.readSeq(address, size, uint32)
proc read_float(self: Process, address: ByteAddress): float32 {.exportpy.} = self.read(address, float32)
proc read_floats(self: Process, address: ByteAddress, size: int32): seq[float32] {.exportpy.} = self.readSeq(address, size, float32)
proc read_float64(self: Process, address: ByteAddress): float64 {.exportpy.} = self.read(address, float64)
proc read_floats64(self: Process, address: ByteAddress, size: int32): seq[float64] {.exportpy.} = self.readSeq(address, size, float64)
proc read_byte(self: Process, address: ByteAddress): byte {.exportpy.} = self.read(address, byte)
proc read_bytes(self: Process, address: ByteAddress, size: int32): seq[byte] {.exportpy.} = self.readSeq(address, size, byte)
proc read_vec2(self: Process, address: ByteAddress): Vec2 {.exportpy.} = self.read(address, Vec2)
proc read_vec3(self: Process, address: ByteAddress): Vec3 {.exportpy.} = self.read(address, Vec3)
proc read_bool(self: Process, address: ByteAddress): bool {.exportpy.} = self.read(address, byte).bool

template write_data = self.write(address, data)
template write_datas = self.writeArray(address, data)
proc write_int(self: Process, address: ByteAddress, data: cint) {.exportpy.} = write_data
proc write_ints(self: Process, address: ByteAddress, data: openArray[cint]) {.exportpy.} = write_datas
proc write_float(self: Process, address: ByteAddress, data: cfloat) {.exportpy.} = write_data
proc write_floats(self: Process, address: ByteAddress, data: openArray[cfloat]) {.exportpy.} = write_datas
proc write_byte(self: Process, address: ByteAddress, data: byte) {.exportpy.} = write_data
proc write_bytes(self: Process, address: ByteAddress, data: openArray[byte]) {.exportpy.} = write_datas
proc write_vec2(self: Process, address: ByteAddress, data: Vec2) {.exportpy.} = write_data
proc write_vec3(self: Process, address: ByteAddress, data: Vec3) {.exportpy.} = write_data
proc write_bool(self: Process, address: ByteAddress, data: bool) {.exportpy.} = self.write(address, data.byte)
