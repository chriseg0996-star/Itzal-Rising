# Map the sliced line-art sheet tiles (in _tiles/, indexed) onto the game's
# icon filenames. Tiles keep their own obsidian plate + gold corners.
from PIL import Image
MAP={
 'res_food':(0,64),'res_wood':(1,64),'res_gold':(12,64),'res_energy':(29,64),'res_pop':(2,64),
 'unit_villager':(2,96),'unit_soldier':(3,96),'unit_archer':(4,96),
 'unit_raider':(5,96),'unit_guard':(6,96),'unit_siege':(31,96),
 'bld_tc':(7,96),'bld_house':(8,96),'bld_farm':(11,96),'bld_storehouse':(13,96),
 'bld_barracks':(23,96),'bld_tower':(21,96),'bld_monument':(39,96),
 'bld_pylon':(40,96),'bld_beacon':(19,96),
 'cmd_stop':(17,96),
}
for name,(idx,size) in MAP.items():
    im=Image.open('_tiles/t%02d.png'%idx).convert('RGBA')
    s=min(im.size)
    x=(im.width-s)//2; y=(im.height-s)//2
    im.crop((x,y,x+s,y+s)).resize((size,size),Image.LANCZOS).save('assets/ui/icons/%s.png'%name)
    print(name,'<- t%02d'%idx)
