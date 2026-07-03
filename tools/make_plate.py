# Master HUD plate: layered obsidian ninepatch shared by every HUD panel.
# 64x64, ninepatch margin 12. Layers: outer dark bevel, teal hairline,
# gold corner ticks, faint Mayan step-fret engraving along the border band.
from PIL import Image, ImageDraw
S=64; M=12
img=Image.new("RGBA",(S,S),(0,0,0,0))
d=ImageDraw.Draw(img)
# fill: deep obsidian
d.rectangle([0,0,S-1,S-1],fill=(9,12,16,247))
# outer near-black bevel (2px) for depth
d.rectangle([0,0,S-1,S-1],outline=(2,3,5,255),width=2)
# teal hairline just inside
d.rectangle([2,2,S-3,S-3],outline=(0,217,199,45),width=1)
# faint engraved step-fret in the border band (greca)
g=(0,217,199,22)
for x in range(6, S-6, 8):
    d.line([(x,4),(x+3,4)],fill=g); d.line([(x+3,4),(x+3,6)],fill=g)
    d.line([(x,S-5),(x+3,S-5)],fill=g); d.line([(x,S-7),(x,S-5)],fill=g)
# gold corner ticks (L shapes)
gold=(200,169,74,160)
L=7
for (cx,cy,dx,dy) in [(1,1,1,1),(S-2,1,-1,1),(1,S-2,1,-1),(S-2,S-2,-1,-1)]:
    d.line([(cx,cy),(cx+dx*L,cy)],fill=gold,width=1)
    d.line([(cx,cy),(cx,cy+dy*L)],fill=gold,width=1)
img.save("assets/ui/plate_frame.png")
print("plate ok")
