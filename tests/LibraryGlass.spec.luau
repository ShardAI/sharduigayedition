local function libraryFixture()
    if Library.LiquidGlassManager then Library.LiquidGlassManager:Destroy() end
    Library.LiquidGlassManager = nil
    Library._WindowCreated = false
    Library._LiquidGlassEnabled = nil
    Library.liquidGlass = false
    Library.LiquidGlassOptions = {TileSize = 16, MaxSurfaces = 4}
end
test('factory opt-out survives reapplying native properties', function()
    libraryFixture()
    Library:SetLiquidGlass(true)
    local object = Library:Create('Frame', {Parent = ScreenGui, LiquidGlass = false})
    Library:Create(object, {Name = 'Updated'})
    assert(Library.LiquidGlassManager == nil)
    assert(Library._CreatedGuiObjects[object] == false)
end)
test('explicit glass factory returns a native Frame and content excludes internals', function()
    libraryFixture()
    local object = Library:Create('LiquidGlassFrame', {Parent = ScreenGui})
    local text = Library:Create('TextLabel', {Parent = object, BackgroundTransparency = 1})
    Library.LiquidGlassManager:Step()
    assert(object:IsA('Frame'))
    assert(#Library:GetContentChildren(object) == 1)
    assert(Library:GetContentChildren(object)[1] == text)
end)
test('plain factory does not create a manager with the global toggle off', function()
    libraryFixture()
    local object = Library:Create('Frame', {Parent = ScreenGui})
    assert(object.BackgroundTransparency == 0 and Library.LiquidGlassManager == nil)
end)
test('creation uses the frozen window mode, not later writes to liquidGlass', function()
    libraryFixture()
    Library._WindowCreated, Library._LiquidGlassEnabled = true, true
    Library.liquidGlass = false
    local object = Library:Create('Frame', {Parent = ScreenGui})
    assert(Library.LiquidGlassManager.ByObject[object])
    assert(not pcall(function() Library:SetLiquidGlass(false) end))
end)
test('turning off a single attached material restores native values', function()
    libraryFixture()
    Library:SetLiquidGlass(true)
    local object = Library:Create('Frame', {Parent = ScreenGui})
    Library.LiquidGlassManager:Step()
    Library:Create(object, {LiquidGlass = false})
    assert(Library.LiquidGlassManager.ByObject[object] == nil)
    assert(object.BackgroundTransparency == 0)
end)
libraryFixture()
print(string.format('%d total tests passed, including library factory integration.', passed))
