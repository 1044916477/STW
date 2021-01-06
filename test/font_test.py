from pymeow import *

overlay = overlay_init()

font1 = font_init(10, "Unispace")
font2 = font_init(30, "Fixedsys")
font3 = font_init(15, "Tahoma")

while overlay_loop(overlay):
    font_print(
        font1, overlay["midX"], 500, "Unispace", rgb("white")
    )
    font_print(
        font2, overlay["midX"], 700, "Fixedsys", rgb("white")
    )
    font_print(
        font3, overlay["midX"], 900, "Tahoma", rgb("white")
    )

    overlay_update(overlay)
