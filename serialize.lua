local _M = {}

local to_save = {}

local serfunc = {
	boolean = function (x) return tostring(x) end,
	number = function (x) return tostring(x) end,
	string = function(str) return string.format("%q",str) end,
	["function"] = function (fn) return ([["!!FUNCTION (cannot serialize)!!"]])
	end,
}

local function tabs_to_spaces(tab)
	assert (tab >= 0)
	return string.rep(" ",tab)
end

local function _serialize(neco,flags,tab)
	tab = (tab or 0)+1
	if type(neco)=="table" then
		local result = {}
		for k,v in pairs(neco) do
			--if k then --We skip "false" keys!
				local serk=nil
				serk="[".._serialize(k).."]"
				table.insert(result, "\n"..tabs_to_spaces(tab)..serk.." = ".._serialize(v,flags,tab))
			--end
		end
		table.sort(result)
		return "{"..table.concat(result,", ").." }"
	else
		local fun = serfunc[type(neco)]
		assert(fun, "I don't know how to serialize ".. tostring(neco) ..".")
--		table.insert(LOG,fun(neco))
		return fun(neco)
	end
end

_M.serialize = function(tbl)
	assert(tbl)
	return "return ".._serialize(tbl).."\n"
end

_M.load = function(fname)
	local result,errcode = loadfile(assert(fname))
	if not result then
		if string.match(errcode,"file or directory") then
			return false
		end
		--log ("cannot open "..fname..": "..errcode)
		error("Cannot execute datafile: "..(errcode or "???"))
	end
	return result()
end

_M.save = function(data, fname) --mark table for later saving
	to_save[fname] = data
end

_M.save_all = function()--actually save everything
	for fname, data in pairs(to_save) do
		local fd = assert(io.open(fname,"w"), "Cannot open file "..fname.." for writing.")
		assert(fd:write(_M.serialize(data)),"Error writing to file.")
		fd:close()
	end
	to_save={}
end

return _M
