import sys
from pymeow import *


class Offsets:
    EntityList = 0x346C90
    PlayerCount = 0x346C9C
    ViewMatrix = 0x32D040
    GameMode = 0x26f6c0

    Health = 0x178
    Armor = 0x180
    State = 0x77
    Name = 0x274
    Team = 0x378


try:
    mem = process_by_name("sauerbraten.exe")
    base = mem["baseaddr"]
    overlay = overlay_init("Cube 2: Sauerbraten")
except Exception as e:
    sys.exit(e)


def is_team_game():
    return read_byte(mem, base + Offsets.GameMode) in \
        [2, 4, 6, 8, 10, 11, 12, 17, 13, 14, 18, 15, 16, 19, 20, 21, 22]


class Entity:
    def __init__(self, addr):
        self.addr = addr

        self.hpos3d = read_vec3(mem, addr)
        self.fpos3d = vec3(
            self.hpos3d["x"], self.hpos3d["y"], self.hpos3d["z"] - 15
        )
        self.health = read_int(mem, addr + Offsets.Health)
        self.armor = read_int(mem, addr + Offsets.Armor)
        self.team = read_string(mem, addr + Offsets.Team)
        self.alive = read_byte(mem, addr + Offsets.State) == 0
        self.name = read_string(mem, addr + Offsets.Name)
        self.distance = 0.0
        self.hpos2d = vec2()
        self.fpos2d = vec2()


def get_ents():
    player_count = read_int(mem, base + Offsets.PlayerCount)
    if player_count > 1:
        ent_buffer = read_ints64(mem, read_int64(mem, base + Offsets.EntityList), player_count)

        try:
            local = Entity(ent_buffer[0])
        except:
            return

        vm = read_floats(mem, base + Offsets.ViewMatrix, 16)

        for e in ent_buffer[1:]:
            try:
                ent = Entity(e)
                if ent.alive:
                    if is_team_game and ent.team == local.team:
                        continue

                    ent.hpos2d = wts_ogl(overlay, vm, ent.hpos3d)
                    ent.fpos2d = wts_ogl(overlay, vm, ent.fpos3d)
                    ent.distance = int(vec3_distance(local.hpos3d, ent.hpos3d) / 3)
                    yield ent
            except:
                continue


def main():
    set_foreground("Cube 2: Sauerbraten")
    font = font_init(10, "Tahoma")

    while overlay_loop(overlay):
        overlay_update(overlay)
        if key_pressed(35):
            overlay_close(overlay)


        for e in get_ents():
            head = e.fpos2d["y"] - e.hpos2d["y"]
            width = head / 2
            center = width / -2
            font_x = e.hpos2d["x"] - len(e.name)

            alpha_box(
                e.hpos2d["x"] + center,
                e.hpos2d["y"],
                width,
                head + 5,
                rgb("red"),
                rgb("black"),
                0.15,
            )

            font_print(
                font,
                font_x,
                e.hpos2d["y"] + 10,
                e.name,
                rgb("white")
            )

            font_print(
                font,
                font_x,
                e.fpos2d["y"] - 10,
                f"{e.health} ({e.armor})",
                rgb("green") if e.health > 50 else rgb("red")
            )
            font_print(
                font,
                font_x,
                e.fpos2d["y"] - 23,
                str(e.distance),
                rgb("white")
            )

    overlay_deinit(overlay)


if __name__ == "__main__":
    main()