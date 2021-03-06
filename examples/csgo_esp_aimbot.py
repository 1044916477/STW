from pymeow import *

"""
CSGo ESP + AimBot written with PyMeow
X: Aim to closest Target
END: Exit
"""


class Offsets:
    dwEntityList = 0x4DA2E14
    dwLocalPlayer = 0xD8B2BC
    dwViewMatrix = 0x4D94714
    dwGlowObjectManager = 0x52EB3F8
    dwRadarBase = 0x51D7B8C

    m_bDormant = 0xED
    m_iHealth = 0x100
    m_vecOrigin = 0x138
    m_iTeamNum = 0xF4
    m_iGlowIndex = 0xA438
    m_dwBoneMatrix = 0x26A8


class Entity:
    def __init__(self, addr, mem, gmod):
        self.wts = None
        self.addr = addr
        self.mem = mem
        self.gmod = gmod

        self.id = read_int(self.mem, self.addr + 0x64)
        self.health = read_int(self.mem, self.addr + Offsets.m_iHealth)
        self.dormant = read_int(self.mem, self.addr + Offsets.m_bDormant)
        self.team = read_int(self.mem, self.addr + Offsets.m_iTeamNum)
        self.bone_base = read_int(self.mem, self.addr + Offsets.m_dwBoneMatrix)

    @property
    def pos(self):
        return read_vec3(self.mem, self.addr + Offsets.m_vecOrigin)

    @property
    def name(self):
        radar_base = read_int(self.mem, self.gmod + Offsets.dwRadarBase)
        hud_radar = read_int(self.mem, radar_base + 0x78)
        return read_string(self.mem, hud_radar + 0x300 + (0x174 * (self.id - 1)))

    def bone_pos(self, bone_id):
        return vec3(
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x0C),
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x1C),
            read_float(self.mem, self.bone_base + 0x30 * bone_id + 0x2C),
        )

    def glow(self):
        glow_addr = (
            read_int(self.mem, self.gmod + Offsets.dwGlowObjectManager)
            + read_int(self.mem, self.addr + Offsets.m_iGlowIndex) * 0x38
        )

        color = rgb("cyan") if self.team != 2 else rgb("orange")
        write_floats(self.mem, glow_addr + 4, color + [1.3])
        write_bytes(self.mem, glow_addr + 0x24, [1, 0])


def aim_bot(overlay, ent_vecs):
    crosshair = vec2(overlay["midX"], overlay["midY"])
    closest_ent = vec2_closest(crosshair, ent_vecs)
    mouse_move(overlay, closest_ent["x"], closest_ent["y"])


def main():
    csgo_proc = wait_for_process("csgo.exe")
    game_module = csgo_proc["modules"]["client.dll"]["baseaddr"]
    overlay = overlay_init()
    font = font_init(10, "Tahoma")
    set_foreground("Counter-Strike: Global Offensive")

    while overlay_loop(overlay):
        local_player_addr = read_int(csgo_proc, game_module + Offsets.dwLocalPlayer)
        local_ent = Entity(local_player_addr, csgo_proc, game_module)

        ent_vecs = list()

        if local_player_addr:
            ent_addrs = read_ints(csgo_proc, game_module + Offsets.dwEntityList, 255)[
                0::4
            ]
            view_matrix = read_floats(csgo_proc, game_module + Offsets.dwViewMatrix, 16)
            for ent_addr in ent_addrs:
                if ent_addr > 0 and ent_addr != local_player_addr:
                    ent = Entity(ent_addr, csgo_proc, game_module)
                    if not ent.dormant and ent.health > 0:
                        try:
                            ent.wts = wts_dx(overlay, view_matrix, ent.pos)
                            ent.glow()
                            font_print(
                                font,
                                ent.wts["x"] + 20,
                                ent.wts["y"] + 30,
                                ent.name,
                                rgb("white"),
                            )
                            font_print(
                                font,
                                ent.wts["x"] + 20,
                                ent.wts["y"] + 20,
                                str(ent.health),
                                rgb("white"),
                            )
                            font_print(
                                font,
                                ent.wts["x"] + 20,
                                ent.wts["y"] + 10,
                                str(int(vec3_distance(ent.pos, local_ent.pos) / 20)),
                                rgb("white"),
                            )
                            dashed_line(
                                overlay["midX"],
                                0,
                                ent.wts["x"],
                                ent.wts["y"],
                                1,
                                rgb("white"),
                            )

                            head_pos = wts_dx(overlay, view_matrix, ent.bone_pos(8))
                            head = head_pos["y"] - ent.wts["y"]
                            width = head / 2
                            center = width / -2
                            alpha_box(
                                ent.wts["x"] + center,
                                ent.wts["y"],
                                width,
                                head + 5,
                                rgb("blue") if ent.team != 2 else rgb("red"),
                                rgb("black"),
                                0.15,
                            )

                            if ent.team != local_ent.team:
                                ent_vecs.append(head_pos)
                        except Exception as e:
                            pass

            # 88: X
            if key_pressed(88) and ent_vecs:
                aim_bot(overlay, ent_vecs)

        overlay_update(overlay)

        # 35: END
        if key_pressed(35):
            overlay_close(overlay)

    overlay_deinit(overlay)


if __name__ == "__main__":
    main()
