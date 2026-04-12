local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	-- SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object)
				return { type = 'Toggle', idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if Toggles[idx] then
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(tonumber(data.value))
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), Transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.Transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and data.text then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:BuildFolderTree()
		local paths = {}

		-- Build the entire folder tree at once
		local function addPath(path)
			local parts = path:split('/')
			local current = ''
			for _, part in ipairs(parts) do
				current = current .. '/' .. part
				if not table.find(paths, current) then
					table.insert(paths, current)
				end
			end
		end

		addPath(self.Folder)
		addPath(self.Folder .. '/' .. self.Library.SubFolder)
		addPath(self.Folder .. '/themes')
		addPath(self.Folder .. '/' .. self.Library.SubFolder .. '/themes')

		-- Create all folders
		for _, path in ipairs(paths) do
			if not isfolder(path) then
				makefolder(path)
			end
		end
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		-- Save Toggles
		for idx, toggle in pairs(Toggles) do
			if self.Parser[toggle.Type] then
				table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
			end
		end

		-- Save Options
		for idx, option in pairs(Options) do
			if self.Parser[option.Type] then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				self.Parser[option.type].Load(option.idx, option)
			end
		end

		-- Restore UI scale if UIScale option exists
		if Options.UIScale and Options.UIScale.Value then
			Library.SetWindowScale(Options.UIScale.Value)
		end
		
		-- Restore HUD scale if HUDScale option exists
		if Options.HUDScale and Options.HUDScale.Value then
			Library.SetHudScale(Options.HUDScale.Value)
		end
		
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor', -- themes
			'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Existing configs', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then
				return self.Library:Notify('Failed to save config: invalid name', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err, 2)
			end

			self.Library:Notify(string.format('Created config %q', name), 2)
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err, 2)
			end

			self.Library:Notify(string.format('Loaded config %q', name), 2)
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err, 2)
			end

			self.Library:Notify(string.format('Overwrote config %q', name), 2)
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			self.Library:Notify(string.format('Set %q to auto-load', name), 2)
		end)

		section:AddButton('Reset autoload', function()
			local success = pcall(delfile, self.Folder .. '/settings/autoload.txt')
			if not success then
				return self.Library:Notify('Failed to reset autoload: delete file error', 2)
			end

			self.Library:Notify('Reset autoload', 2)
		end)
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done (ini files)
				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end

		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Ignore = {}
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err, 2)
			end

			self.Library:Notify(string.format('Loaded autoload config %q', name), 2)
		end
	end


    -- SaveManager:BuildFolderTree() -- УДАЛЕНО, так как Library еще не задан
end

return SaveManager
