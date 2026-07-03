# Master HUD plate v2 — craftsmanship pass.
# Layers: vertical obsidian gradient, outer near-black bevel, inner
# highlight/shadow pair (carved depth), teal hairline, finer engraved greca,
# gold corner ticks, a few weathering nicks in the border band.
from PIL import Image, ImageDraw
import random
S=64; M=12
img=Image.new("RGBA",(S,S),(0,0,0,0))
d=ImageDraw.Draw(img)
# fill: vertical gradient, slightly lighter top (light from above)
for y in range(S):
    t=y/(S-1)
    r=int(11-3*t); g=int(14-3*t); b=int(19-4*t)
    d.line([(0,y),(S-1,y)],fill=(r,g,b,248))
# outer near-black bevel (2px)
d.rectangle([0,0,S-1,S-1],outline=(1,2,4,255),width=2)
# carved depth: inner top highlight + inner bottom shadow
d.line([(3,3),(S-4,3)],fill=(120,200,190,18))
d.line([(3,S-4),(S-4,S-4)],fill=(0,0,0,90))
# teal hairline
d.rectangle([2,2,S-3,S-3],outline=(0,217,199,40),width=1)
# finer engraved greca in the border band
g=(0,217,199,16); g2=(0,0,0,60)
for x in range(7, S-9, 6):
    d.line([(x,5),(x+2,5)],fill=g); d.point((x+2,6),fill=g)
    d.point((x,4),fill=g2)
    d.line([(x,S-6),(x+2,S-6)],fill=g); d.point((x,S-7),fill=g)
# gold corner ticks
gold=(200,169,74,170); goldd=(140,115,50,120)
L=7
for (cx,cy,dx,dy) in [(1,1,1,1),(S-2,1,-1,1),(1,S-2,1,-1),(S-2,S-2,-1,-1)]:
    d.line([(cx,cy),(cx+dx*L,cy)],fill=gold,width=1)
    d.line([(cx,cy),(cx,cy+dy*L)],fill=gold,width=1)
    d.point((cx+dx*(L+1),cy),fill=goldd); d.point((cx,cy+dy*(L+1)),fill=goldd)
# subtle weathering nicks in the band
random.seed(7)
for _ in range(10):
    x=random.randint(4,S-5); y=random.choice([4,5,S-6,S-5])
    d.point((x,y),fill=(0,0,0,50))
img.save("assets/ui/plate_frame.png")
print("plate v2 ok")

# v3: bake the engraved-obsidian material into the plate fill (8% overlay)
base=Image.open("assets/ui/plate_frame.png").convert("RGBA")
tex=Image.open("assets/ui/minimap_bg.png").convert("RGBA").resize((S,S))
tex.putalpha(tex.split()[0].point(lambda v: 22))  # ~8% opacity, luminance-keyed
mat=Image.alpha_composite(base, tex)
# re-stamp the border details on top so they stay crisp
mat=Image.alpha_composite(mat, Image.new("RGBA",(S,S),(0,0,0,0)))
d2=ImageDraw.Draw(mat)
d2.rectangle([0,0,S-1,S-1],outline=(1,2,4,255),width=2)
d2.rectangle([2,2,S-3,S-3],outline=(0,217,199,40),width=1)
for (cx,cy,dx,dy) in [(1,1,1,1),(S-2,1,-1,1),(1,S-2,1,-1),(S-2,S-2,-1,-1)]:
    d2.line([(cx,cy),(cx+dx*L,cy)],fill=gold,width=1)
    d2.line([(cx,cy),(cx,cy+dy*L)],fill=gold,width=1)
mat.save("assets/ui/plate_frame.png")
print("plate v3 ok")
