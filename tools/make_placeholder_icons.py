# Minimalist production placeholder icons: flat silhouette, obsidian bg,
# single turquoise accent, small gold tick. Drawn 4x and downscaled (AA).
# Overwrites the painted set (same filenames) until final icons exist.
from PIL import Image, ImageDraw

S=256; OUT=96
BG=(10,14,19,255); EDGE=(0,217,199,60)
TEAL=(0,230,199,255); TEAL_D=(0,150,132,255); GOLD=(200,169,74,255)
WHITE=(223,245,241,255)

def canvas():
    im=Image.new("RGBA",(S,S),(0,0,0,0))
    d=ImageDraw.Draw(im)
    d.rounded_rectangle([8,8,S-9,S-9],20,fill=BG,outline=EDGE,width=3)
    d.line([(28,S-22),(70,S-22)],fill=GOLD,width=5)  # gold base tick
    return im,d

def save(im,name,size=96):
    im.resize((size,size),Image.LANCZOS).save("assets/ui/icons/%s.png"%name)
    print(name)

def P(d,pts,c=TEAL): d.polygon(pts,fill=c)

# ---------- buildings ----------
im,d=canvas()  # tc: stepped pyramid
for i,(w,y0,y1) in enumerate([(180,150,200),(130,105,150),(80,60,105)]):
    x=(S-w)//2; P(d,[(x,y1),(x+w,y1),(x+w-14,y0),(x+14,y0)])
d.rectangle([S//2-10,34,S//2+10,60],fill=GOLD)
save(im,"bld_tc")

im,d=canvas()  # farm: field rows in a diamond
P(d,[(S//2,60),(215,150),(S//2,205),(40,150)],TEAL_D)
for t in range(3):
    y=100+t*34
    d.line([(70+t*8,y),(190-t*8,y)],fill=TEAL,width=10)
save(im,"bld_farm")

im,d=canvas()  # storehouse: dome hut
d.pieslice([50,70,205,225],180,360,fill=TEAL)
d.rectangle([50,146,205,190],fill=TEAL)
d.rectangle([112,146,143,190],fill=BG)
d.line([(50,70+78),(205,148)],fill=GOLD,width=4)
save(im,"bld_storehouse")

im,d=canvas()  # house: gabled hut
P(d,[(S//2,52),(210,130),(45,130)])
d.rectangle([70,130,185,200],fill=TEAL_D)
d.rectangle([112,152,142,200],fill=BG)
save(im,"bld_house")

im,d=canvas()  # pylon: obelisk + crystal
P(d,[(S//2,90),(165,205),(90,205)],TEAL_D)
P(d,[(S//2,30),(S//2+22,70),(S//2,105),(S//2-22,70)])
save(im,"bld_pylon")

im,d=canvas()  # barracks: fort with crenellation
d.rectangle([48,110,208,200],fill=TEAL_D)
for x in range(48,209,40): d.rectangle([x,88,x+22,110],fill=TEAL_D)
P(d,[(80,180),(128,120),(176,180),(128,150)],TEAL)
save(im,"bld_barracks")

im,d=canvas()  # tower
d.rectangle([100,70,156,205],fill=TEAL_D)
for x in (88,120,152): d.rectangle([x,48,x+18,72],fill=TEAL)
d.rectangle([88,64,174,74],fill=TEAL)
save(im,"bld_tower")

im,d=canvas()  # monument: stela
P(d,[(S//2,36),(170,80),(170,190),(86,190),(86,80)],TEAL_D)
d.rectangle([118,90,138,170],fill=TEAL)
d.ellipse([116,56,140,80],fill=GOLD)
save(im,"bld_monument")

im,d=canvas()  # beacon: spire + rays
P(d,[(S//2,40),(150,205),(106,205)],TEAL)
for a,b in [((60,90),(90,110)),((196,90),(166,110)),((52,150),(88,158)),((204,150),(168,158))]:
    d.line([a,b],fill=TEAL,width=8)
save(im,"bld_beacon")

# ---------- units ----------
im,d=canvas()  # villager: hooded head + pick
d.pieslice([70,60,186,176],180,360,fill=TEAL)
d.rectangle([70,118,186,150],fill=TEAL)
d.line([(90,200),(180,160)],fill=GOLD,width=10)
save(im,"unit_villager")

im,d=canvas()  # soldier: sword
P(d,[(S//2-14,44),(S//2+14,44),(S//2+10,150),(S//2-10,150)])
P(d,[(S//2,36),(S//2+14,44),(S//2-14,44)])
d.rectangle([S//2-40,150,S//2+40,164],fill=GOLD)
d.rectangle([S//2-10,164,S//2+10,205],fill=TEAL_D)
save(im,"unit_soldier")

im,d=canvas()  # archer: bow + arrow
d.arc([70,50,200,206],300,60,fill=TEAL,width=12)
d.line([(188,66),(188,190)],fill=TEAL_D,width=8)
d.line([(70,128),(196,128)],fill=WHITE,width=8)
P(d,[(60,128),(84,116),(84,140)],GOLD)
save(im,"unit_archer")

im,d=canvas()  # raider: double chevron (speed)
for off in (0,52):
    P(d,[(70+off,70),(130+off,128),(70+off,186),(96+off,128)])
save(im,"unit_raider")

im,d=canvas()  # guard: shield
P(d,[(S//2,44),(190,72),(190,140),(S//2,208),(66,140),(66,72)],TEAL_D)
P(d,[(S//2,70),(168,90),(168,136),(S//2,184),(88,136),(88,90)],TEAL)
d.ellipse([S//2-10,110,S//2+10,130],fill=GOLD)
save(im,"unit_guard")

im,d=canvas()  # siege: catapult arm + wheel
d.ellipse([60,150,120,210],outline=TEAL,width=12)
d.line([(90,170),(190,70)],fill=TEAL,width=14)
d.ellipse([176,52,208,84],fill=GOLD)
d.rectangle([60,196,200,210],fill=TEAL_D)
save(im,"unit_siege")

# ---------- resources (64px) ----------
im,d=canvas()  # food: maize
P(d,[(S//2,44),(170,140),(S//2,215),(86,140)],GOLD)
for y in range(88,190,26): d.line([(96,y),(160,y)],fill=BG,width=8)
P(d,[(S//2,44),(200,88),(170,140)],TEAL_D)
save(im,"res_food",64)

im,d=canvas()  # wood: two logs
for y in (92,150):
    d.rectangle([56,y,200,y+44],fill=TEAL_D)
    d.ellipse([180,y,224,y+44],fill=TEAL)
    d.ellipse([194,y+14,210,y+30],fill=BG)
save(im,"res_wood",64)

im,d=canvas()  # gold: ingots
P(d,[(80,120),(176,120),(196,160),(60,160)],GOLD)
P(d,[(110,80),(206,80),(226,120),(90,120)],(230,200,110,255))
save(im,"res_gold",64)

im,d=canvas()  # energy: bolt
P(d,[(150,40),(96,132),(130,132),(102,212),(180,110),(140,110)])
save(im,"res_energy",64)

im,d=canvas()  # pop: person glyph
d.ellipse([100,52,156,108],fill=TEAL)
d.pieslice([76,116,180,230],180,360,fill=TEAL)
save(im,"res_pop",64)
