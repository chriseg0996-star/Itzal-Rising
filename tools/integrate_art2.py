# Slice the second AI art pack: resource icons (white bg), unit portraits
# (transparent 3x2), minimap backdrop.
import os
from PIL import Image
d=os.path.expanduser('~/Downloads')

# ---- 1. resources: key out the white background, split into 5 columns ----
im=Image.open(d+'/ChatGPT Image Jul 3, 2026, 01_32_49 AM.png').convert('RGBA')
px=im.load()
W,H=im.size
for y in range(H):
    for x in range(W):
        r,g,b,a=px[x,y]
        lum=(r+g+b)/3
        if lum>235 and abs(r-g)<18 and abs(g-b)<18:
            px[x,y]=(r,g,b,0)
        elif lum>190 and abs(r-g)<18 and abs(g-b)<18:
            px[x,y]=(r,g,b,int((235-lum)/45*255))
# column occupancy
alpha=im.split()[3]
cols=[0]*W
ap=alpha.load()
for x in range(W):
    s=0
    for y in range(0,H,4):
        s+= 1 if ap[x,y]>40 else 0
    cols[x]=s
# find 5 runs
runs=[];inr=False
for x in range(W):
    if cols[x]>1 and not inr: start=x; inr=True
    elif cols[x]<=1 and inr:
        if x-start>40: runs.append((start,x))
        inr=False
if inr: runs.append((start,W))
print("runs:",runs)
names=['res_food','res_wood','res_gold','res_energy','res_pop']
assert len(runs)==5, runs
for (name,(x0,x1)) in zip(names,runs):
    box=im.crop((x0,0,x1,H)).getbbox()
    ic=im.crop((x0+box[0],box[1],x0+box[2],box[3]))
    s=max(ic.size)
    sq=Image.new('RGBA',(s,s),(0,0,0,0))
    sq.paste(ic,((s-ic.width)//2,(s-ic.height)//2))
    sq.resize((64,64),Image.LANCZOS).save('assets/ui/icons/%s.png'%name)
    print(name,'ok')

# ---- 2. units: 3x2 grid, alpha-crop each cell ----
im=Image.open(d+'/ChatGPT Image Jul 3, 2026, 01_37_02 AM.png').convert('RGBA')
W,H=im.size
cw,ch=W//3,H//2
units=['unit_villager','unit_soldier','unit_archer','unit_raider','unit_guard','unit_siege']
for i,name in enumerate(units):
    cx,cy=(i%3)*cw,(i//3)*ch
    cell=im.crop((cx,cy,cx+cw,cy+ch))
    b=cell.getbbox()
    ic=cell.crop(b)
    s=max(ic.size)
    sq=Image.new('RGBA',(s,s),(0,0,0,0))
    sq.paste(ic,((s-ic.width)//2,(s-ic.height)//2))
    sq.resize((96,96),Image.LANCZOS).save('assets/ui/icons/%s.png'%name)
    print(name,'ok')

# ---- 3. minimap backdrop ----
Image.open(d+'/ChatGPT Image Jul 3, 2026, 01_38_22 AM.png').convert('RGB')\
    .resize((512,512),Image.LANCZOS).save('assets/ui/minimap_bg.png')
print('minimap ok')
