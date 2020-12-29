from pymeow import *


class Colors:
    red = (255, 0, 0)
    yellow = (255, 255, 100)
    blue = (0, 0, 255)
    green = (0, 255, 0)
    white = (255, 255, 255)
    black = (0, 0, 0)
    silver = (192, 192, 192)


class Pointer:
    player_count = 0x0050F500
    entity_list = 0x0050F4F8
    local_player = 0x00509B74
    view_matrix = 0x00501AE8
    console = 0x4090F0
    game_mode = 0x50F49C


class Offsets:
    name = 0x225
    health = 0xF8
    armor = 0xFC
    team = 0x32C
    pos = 0x4
    viewX = 0x40
    viewY = 0x44
    rifle_ammo = 0x148
    pistol_ammo = 0x13C
    nades = 0x158
    force_attack = 0x224
    viewable = 0x408
    recoil = 0xEE444


class Entity:
    def __init__(self, addr, mem):
        self.mem = mem
        self.addr = addr

        self.info = dict()
        self.update()

    def update(self):
        self.info = {
            "name": read_string(self.mem, self.addr + Offsets.name),
            "hp": read_int(self.mem, self.addr + Offsets.health),
            "team": read_int(self.mem, self.addr + Offsets.team),
            "armor": read_int(self.mem, self.addr + Offsets.armor),
            "pos3d": read_floats(self.mem, self.addr + Offsets.pos, 3),
            "pos2d": list(),
        }

    def calc_wts(self, overlay, v_matrix):
        clip_x = self.info["pos3d"][0] * v_matrix[0] + self.info["pos3d"][1] * v_matrix[4] + \
                 self.info["pos3d"][2] * v_matrix[8] + v_matrix[12]
        clip_y = self.info["pos3d"][0] * v_matrix[1] + self.info["pos3d"][1] * v_matrix[5] + \
                 self.info["pos3d"][2] * v_matrix[9] + v_matrix[13]
        clip_w = self.info["pos3d"][0] * v_matrix[3] + self.info["pos3d"][1] * v_matrix[7] + \
                 self.info["pos3d"][2] * v_matrix[11] + v_matrix[15]

        if clip_w < 0.1:
            raise Exception("WTS")

        nds_x = clip_x / clip_w
        nds_y = clip_y / clip_w

        self.info["pos2d"].append(((nds_x / 2) + 0.5) * overlay["width"])
        self.info["pos2d"].append(((nds_y / 2) + 0.5) * overlay["height"])


def main():
    mem = process_by_name("ac_client.exe")
    overlay = overlay_init("AssaultCube")
    font = font_init(10, "Tahoma")
    set_foreground("AssaultCube")

    while overlay_loop(overlay):
        player_count = read_int(mem, Pointer.player_count)

        if player_count > 1:
            ent_buffer = read_ints(mem, read_int(mem, Pointer.entity_list), player_count)[1:]
            v_matrix = read_floats(mem, Pointer.view_matrix, 16)
            for addr in ent_buffer:
                try:
                    ent_obj = Entity(addr, mem)
                    ent_obj.calc_wts(overlay, v_matrix)
                except:
                    continue

                if ent_obj.info["pos2d"] and ent_obj.info["hp"] > 0:
                    ent_color = Colors.blue if ent_obj.info['team'] == 1 else Colors.red

                    circle(ent_obj.info["pos2d"][0] - 10, ent_obj.info["pos2d"][1], 3, ent_color)
                    font_print(
                        font, ent_obj.info["pos2d"][0], ent_obj.info["pos2d"][1],
                        ent_obj.info["name"],
                        Colors.white
                    )
                    font_print(
                        font, ent_obj.info["pos2d"][0], ent_obj.info["pos2d"][1] - 13,
                        f"Team: {ent_obj.info['team']}",
                        ent_color
                    )
                    font_print(
                        font, ent_obj.info["pos2d"][0], ent_obj.info["pos2d"][1] - 26,
                        f"Health: {ent_obj.info['hp']}",
                        Colors.white
                    )
                    font_print(
                        font, ent_obj.info["pos2d"][0], ent_obj.info["pos2d"][1] - 39,
                        f"Armor:  {ent_obj.info['armor']}",
                        Colors.white
                    )

        overlay_update(overlay)


if __name__ == "__main__":
    main()
