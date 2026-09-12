
-- Numerical compositor contracts, independent of Roblox's rasterizer.
do
local passed=0
local function test(name,fn) fn(); passed+=1; print('PASS backdrop '..name) end
local function setup(global)
    local root=Instance.new('ScreenGui')
    if global then root.ZIndexBehavior=Enum.ZIndexBehavior.Global end
    local function frame(color,z,parent)
        local f=Instance.new('Frame'); f.BackgroundColor3=color; f.BorderSizePixel=0
        f.AbsolutePosition=Vector2.new(-200,-200); f.AbsoluteSize=Vector2.new(500,500)
        f.ZIndex=z; f.Parent=parent or root; return f
    end
    local base=frame(Color3.new(1,0,0),1)
    local glass=frame(Color3.new(0,0,0),10); glass:SetAttribute('LiquidGlass',true)
    local sampler=Glass.GuiBackdrop.new(root,{BackdropRoots={root},BackdropResolution=16})
    local request={Surfaces={{Record={Object=glass},Rect={X=0,Y=0,Width=100,Height=100}}}}
    return root,base,glass,sampler,request,frame
end
local function pixel(source,x,y)
    local i=(y or 8)*source.Width+(x or 8)
    return buffer.readu8(source.Pixels,i*4),buffer.readu8(source.Pixels,i*4+1),buffer.readu8(source.Coverage,i)
end
local function get(s,r) return s:Build(r).Sources[r.Surfaces[1].Record.Object] end

test('opaque fill and transparent overlay compose in draw order',function()
    local root,base,g,s,r,frame=setup()
    local top=frame(Color3.new(0,1,0),2); top.BackgroundTransparency=.5
    local red,green,known=pixel(get(s,r))
    assert(red==128 and green==128 and known==255)
    s:Destroy(); root:Destroy()
end)
test('layers above the lens never enter its background',function()
    local root,base,g,s,r,frame=setup()
    frame(Color3.new(0,1,0),11)
    local red,green=pixel(get(s,r)); assert(red==255 and green==0)
    s:Destroy(); root:Destroy()
end)
test('text invalidates its region, later opaque paint restores it',function()
    local root,base,g,s,r,frame=setup()
    local text=Instance.new('TextLabel'); text.Text='Unknown glyphs'; text.ZIndex=2; text.Parent=root
    local _,_,known=pixel(get(s,r)); assert(known==0)
    frame(Color3.new(0,1,0),3)
    local red,green,k=pixel(get(s,r)); assert(red==0 and green==255 and k==255)
    s:Destroy(); root:Destroy()
end)
test('transparency over the unknown world never fabricates opaque pixels',function()
    local root,base,g,s,r=setup()
    base.BackgroundTransparency=.25
    local _,_,known=pixel(get(s,r)); assert(known==0)
    s:Destroy(); root:Destroy()
end)
test('property edits, new descendants and removal invalidate the cached tree',function()
    local root,base,g,s,r,frame=setup()
    get(s,r); local revision=s.Revision
    get(s,r); assert(s.Revision==revision)
    base.BackgroundColor3=Color3.new(0,1,0)
    local red,green=pixel(get(s,r)); assert(red==0 and green==255 and s.Revision>revision)
    local cover=frame(Color3.new(1,0,0),2); assert(pixel(get(s,r))==255)
    cover:Destroy(); assert(pixel(get(s,r))==0)
    s:Destroy(); root:Destroy()
end)
test('hidden ancestors suppress descendants and clipping limits their paint',function()
    local root,base,g,s,r,frame=setup()
    local parent=frame(Color3.new(0,1,0),2); parent.BackgroundTransparency=1
    local child=frame(Color3.new(0,1,0),1,parent)
    parent.Visible=false; assert(pixel(get(s,r))==255)
    parent.Visible=true; parent.ClipsDescendants=true
    parent.AbsolutePosition=Vector2.new(500,500); parent.AbsoluteSize=Vector2.new(10,10)
    assert(pixel(get(s,r))==255)
    parent.ClipsDescendants=false; assert(pixel(get(s,r))==0)
    s:Destroy(); root:Destroy()
end)
test('global Z ordering differs from sibling subtree ordering',function()
    local root,base,g,s,r,frame=setup()
    local parent=frame(Color3.new(0,0,0),2); parent.BackgroundTransparency=1
    frame(Color3.new(0,1,0),100,parent)
    assert(pixel(get(s,r))==0)
    root.ZIndexBehavior=Enum.ZIndexBehavior.Global
    assert(pixel(get(s,r))==255)
    s:Destroy(); root:Destroy()
end)
test('ScreenGui DisplayOrder controls background inclusion',function()
    local container=Instance.new('Folder')
    local root,base,g,s,r,frame=setup(); root.Parent=container
    s:Destroy(); s=Glass.GuiBackdrop.new(root,{BackdropRoots={container},BackdropResolution=16})
    local other=Instance.new('ScreenGui'); other.DisplayOrder=1; other.Parent=container
    frame(Color3.new(0,1,0),1,other)
    assert(pixel(get(s,r))==255)
    other.DisplayOrder=-1; base.BackgroundTransparency=1
    assert(pixel(get(s,r))==0)
    s:Destroy(); container:Destroy()
end)
test('gradient colors are multiplied by the native fill color',function()
    local root,base,g,s,r=setup(); base.BackgroundColor3=Color3.new(.5,1,1)
    local grad=Instance.new('UIGradient'); grad.Enabled=true; grad.Offset=Vector2.zero; grad.Rotation=0
    grad.Color={Keypoints={{Time=0,Value=Color3.new(1,0,0)},{Time=1,Value=Color3.new(1,0,0)}}}
    grad.Transparency={Keypoints={{Time=0,Value=0},{Time=1,Value=0}}}; grad.Parent=base
    local red,green,known=pixel(get(s,r)); assert(red==128 and green==0 and known==255)
    s:Destroy(); root:Destroy()
end)
test('source maps are separate for different lens draw cutoffs',function()
    local root,base,g,s,r,frame=setup()
    frame(Color3.new(0,1,0),12)
    local second=frame(Color3.new(0,0,0),20); second:SetAttribute('LiquidGlass',true)
    table.insert(r.Surfaces,{Record={Object=second},Rect=r.Surfaces[1].Rect})
    local sources=s:Build(r).Sources
    assert(pixel(sources[g])==255 and pixel(sources[second])==0)
    s:Destroy(); root:Destroy()
end)
test('layer budget fails closed and disconnects watchers on destroy',function()
    local root,base,g,s,r,frame=setup(); s.MaxLayers=1
    frame(Color3.new(0,1,0),2)
    assert(get(s,r)==nil and s:GetStatus().LayerBudgetExceeded)
    local connections=table.clone(s.Watches); s:Destroy()
    for _,c in ipairs(connections) do assert(not c.Connected) end
    root:Destroy()
end)
test('auto manager supplies a partial source without a custom provider',function()
    local root,base,g,s,r=setup(); s:Destroy()
    g.AbsolutePosition=Vector2.zero; g.AbsoluteSize=Vector2.new(100,100)
    local m=Glass.newManager(root,{AutoBackdrop=true,BackdropRoots={root},TileSize=16,MaxSurfaces=1})
    m:Attach(g); m:Step()
    assert(m:GetStatus().Mode=='GuiReconstruction' and m:GetStatus().Backdrop.KnownPixels>0)
    assert(m:GetStatus().SourceRequired==false)
    m:SetSourceProvider(nil); assert(m.Backdrop==nil)
    m:Destroy(); root:Destroy()
end)
test('unknown sample masks suppress optical writes',function()
    local root,base,g,s,r=setup()
    local source=get(s,r)
    assert(Glass.ValidateSource(source))
    buffer.fill(source.Coverage,0,0)
    local output=buffer.create(16*16*4)
    Glass.RenderTile(output,16,0,0,16,source,r.Surfaces[1].Rect,{Radius=0,Opacity=1,Bezel=16,
        Refraction=8,Blur=1,Tint=Color3.new(1,1,1),TintStrength=0})
    for i=3,buffer.len(output)-1,4 do assert(buffer.readu8(output,i)==0) end
    source.Coverage=buffer.create(1); assert(not Glass.ValidateSource(source))
    s:Destroy(); root:Destroy()
end)
test('EditableImage Content is unknown even when legacy Image is empty',function()
    local root,base,g,s,r=setup()
    local image=Instance.new('ImageLabel'); image.Image=''; image.ImageContent={SourceType={Value=2}}
    image.ZIndex=2; image.Parent=root
    local _,_,known=pixel(get(s,r)); assert(known==0)
    image.ImageTransparency=1
    local _,_,nowKnown=pixel(get(s,r)); assert(nowKnown==255)
    s:Destroy(); root:Destroy()
end)
test('CoreGui remains above PlayerGui regardless of player DisplayOrder',function()
    local player=Instance.new('PlayerGui'); local core=Instance.new('CoreGui')
    local root,base,g,s,r,frame=setup(); root.Parent=core; root.DisplayOrder=-100
    local other=Instance.new('ScreenGui'); other.DisplayOrder=10000; other.Parent=player
    frame(Color3.new(0,1,0),1,other); base.BackgroundTransparency=1
    s:Destroy(); s=Glass.GuiBackdrop.new(root,{BackdropRoots={player,core},BackdropResolution=16})
    local red,green,known=pixel(get(s,r)); assert(red==0 and green==255 and known==255)
    s:Destroy(); player:Destroy(); core:Destroy()
end)
test('invalid backdrop settings are rejected before manager connections',function()
    local root=Instance.new('ScreenGui')
    local before=#heartbeat.listeners
    assert(not pcall(Glass.newManager,root,{AutoBackdrop=true,BackdropResolution=0/0}))
    assert(not pcall(Glass.newManager,root,{AutoBackdrop=true,BackdropMaxLayers=1.5}))
    assert(#heartbeat.listeners==before)
    root:Destroy()
end)
test('rounded background corners preserve the unknown world',function()
    local root,base,g,s,r=setup()
    base.AbsolutePosition=Vector2.zero; base.AbsoluteSize=Vector2.new(100,100)
    local c=Instance.new('UICorner'); c.CornerRadius=UDim.new(0,50); c.Parent=base
    local source=get(s,r)
    local _,_,center=pixel(source,8,8); local _,_,corner=pixel(source,5,5)
    assert(center==255 and corner==0)
    s:Destroy(); root:Destroy()
end)
print(passed..' GUI backdrop tests passed (mocked API).')
end
