--Requires LuaJit
--Hashing function and PRNG

--[[*<= Version '20180820a' =>*]]

local _M={}

local bit = require("bit")

local tobit, bxor, band, rol, rshift, lshift = bit.tobit, bit.bxor, bit.band, bit.rol, bit.rshift, bit.lshift

local seeds = {}

_M.hash = function(str0,dwords0) --dwords x 32bit hash
	str0 = tostring(str0)
	dwords0 = dwords0 or 1
	assert(dwords0 >= 1 and dwords0 <= 16)
	local str = str0 .. #str0
	local acc = {}
	local dwords = dwords0
	if dwords == 1 then --Generate 2 #s for dwords==1
		dwords = 2
	end
	for sumn = 1,dwords do
		acc[sumn] = seeds[-sumn] + dwords0
	end
    for charn = 1,#str do
		local byte = string.byte(str, charn)
		for sumn = 1, dwords do
			local sum = acc[sumn] + byte
			acc[sumn] = bxor(rol(sum, 11), seeds[band(0x1ff, sum)])
		end
	end
	if dwords == dwords0 then
		acc[dwords0 + 1] = acc[1]
	end
	for n = 1, dwords0 do
		--print(n, bit.tohex(acc[n]), bit.tohex(acc[n+1]))
		acc[n] = tobit(bxor(acc[n + 1] + seeds[-16-n], rol(acc[n], n)))
	end
	acc[dwords0 + 1] = nil
    return acc
end

_M.hashstring_hex = function(str,dwords)
	dwords = dwords or 2
	local res = _M.hash(str, dwords)
	for i,item in ipairs(res) do
		res[i] = bit.tohex(item)
	end
	return table.concat(res,"_")
end

local counter = os.time()

_M.new_random = function(seed)
	if not seed then
		counter = bit.band(counter+1,0xfffffff)
		seed = counter..tostring({})..os.time()
	end
	local hash
	if type(seed) == "table" then
		assert(#seed == 4)
		hash = seed
	else
		seed = tostring(seed)
		assert(#seed > 0, "Seed string is empty")
		hash = _M.hash(seed,4)
	end
	local w,x,y,z = hash[1],hash[2],hash[3],hash[4]

	if bit.bor(w,x,y,z) == 0 then --Cannot be all zeroes!
		w,x,y,z = 1,0,0,0
	end
	local fun = function(arg) --Xorshift algorithm
		if arg == "dump" then
			return w, x, y, z
		end
		--print(bit.tohex(w), bit.tohex(x),bit.tohex(y),bit.tohex(z))
		local t = bxor(x, lshift(x,11))
		x,y,z = y,z,w
		w = bxor(w, rshift(w,19), t, rshift(t,8))

		if arg == "bin" then
			return w
		end

		local float = bit.rshift(w,1) / 0x80000000 --31bit float
		if not arg then
			return float
		end
		return math.floor(float * arg) + 1
	end
	return fun
end

_M.random_string = function(rnd, nchars, alphabetstr)
	assert(type(rnd) == "function", "rnd is not a function")
	if not alphabetstr then
		alphabetstr = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	end
	if not nchars then
		nchars = 40
	end
	local alphabet = {}
	for char in alphabetstr:gmatch(".") do
		table.insert(alphabet, char)
	end
	local res = {}
	for i = 1, nchars do
		res[i] = alphabet[rnd(#alphabetstr)]
	end
	return table.concat(res)
end

_M.shuffle = function(tbl, rnd) --Shuffle array elements in place
	if #tbl <= 1 then
		return(tbl)
	end
	for i = #tbl, 2, -1 do
		local ind = rnd(i)
		if i~=ind then
			tbl[i], tbl[ind] = tbl[ind],tbl[i]
		end
	end
	return tbl
end

local function init(arg)
	local seed = {}
	for i = 1, 4 do
		seed[i] = bit.ror(seed[i - 1] or 0xf0f04321, 9 + i) + 0x1fedcba9
	end
	local rnd = _M.new_random(seed)
	local w,x,y,z = rnd("dump")
	if arg == "test" then
		print("init rnd seeds",bit.tohex(w),bit.tohex(x),bit.tohex(y),bit.tohex(z))
	end

	local all = {}
	for i = -32, 511 do
		local num = 0
		local ones = 13 + rnd(5)
		for bitn = 32, 1, -1 do
			if rnd(bitn) <= ones then
				num = bit.bor(num, bit.ror(1, bitn))
				ones = ones - 1
			end
		end
		seeds[i] = num
	end
end

local function test()
	local all = {}
	for i = -32, 511 do
		io.write(i.."\t")
		local num = seeds[i]
		io.write(bit.tohex(num).."\t")
		local ones = 0
		for j = 1, 32 do
			num = bit.rol(num,1)
			if bit.band(num,1) == 1 then
				io.write("X")
				ones = ones + 1
			else
				io.write(".")
			end
			if all[num] then
				print(" CONFLICT!")
				os.exit()
			end
		end
		print("\t"..ones)
		all[num] = true
	end

	local rnd = _M.new_random {0x0, 0x0, 0x0, 0x0}
	for i = 1,99 do
		local a,b,c,d = rnd("bin")
		--print(string.format("{0x%s, 0x%s, 0x%s, 0x%s}",bit.tohex(a), bit.tohex(b), bit.tohex(c), bit.tohex(d)))
	end

	for i, b in ipairs{-32, -2, 250, 511 - 5} do
		for i = b, b+5 do
			print(i, bit.tohex(seeds[i]))
		end
	end

	local tests = {[{"", 4}] = "c2d16300_b944e294_bf7bac58_f84abb97", [{"", 1}] = "0d16d220", [{"", 2}] = "82880fe3_0f7db2ef", [{string.rep("X", 100), 4}] = "47673211_8303bceb_900275f4_a891159f"}
	for inp, outp in pairs(tests) do
		local res = _M.hashstring_hex(inp[1], inp[2])
		if res ~= outp then
			print(string.format("Hash of '%s' (%s) is wrong.\nIs: %s\nShould be: %s", inp[1], inp[2], res, outp))
		end
	end
	for i = 0, 9 do
		local hash = _M.hashstring_hex(string.rep(string.char(0),100) ..i, 8)
		print(i, hash)
	end

	for i = 1,16 do
		print(_M.hashstring_hex("", i))
	end
	local sums = {}

	local range = 0xffffffff
	local count = 0
	local sum, rounds,tries = 0,0,0
	local prefix = os.time()
	local t0 = os.time()
	while true do
		local bf = {}
		local try = 0
		while true do
			try = try + 1
			count = count + 1
			local n = _M.hash(tostring(count)..prefix, 1)[1]
			local num = bit.band(n, range)
			local bt = bit.lshift(1, band(num, 0x1f))
			local ind = bit.rshift(num, 5)
			local db = bf[ind] or 0
			--print(bit.tohex(db))
			if band (db, bt) ~= 0 then
				tries = tries + try
				if try > 77000 then
					sum = sum + 100
				end
				rounds = rounds + 1
				print(string.format("Collision after %s, avg %f %%, %fh, %s/s", try, sum / rounds, (os.time()-t0) / 3600, math.floor(tries / (os.time()-t0))))
				print("count", (count/1000000) .. "M", "hash", bit.tohex(num))
				if try <= 100 then
					print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
					print(count .. prefix)
					for c = count - 1, 0, -1 do
						if _M.hash(tostring(c)..prefix, 1)[1] == num then
							print(c..prefix)
							os.exit()
						end
					end
					print("WTF?")
					os.exit()
				end
				break
			end
			bf[ind] = bit.bor(db, bt)
		end
	end
end

--[[while _M.hash("",1)[1] ~= 0 do
	--print(_M.hash("",1)[1])
	if band(START,0xfffff) == 0 then
		print(bit.tohex(START))
	end
	init()
end

print(bit.tohex(START))
os.exit()]]
if arg[1]=="test" then
	init("test")
	test()
else
	init()
end

return _M

--[[
1 -> 2 (1 x 2)
01
10

2 -> 6 (2 x 3)
0011
0101
0110
1001
1010
1100

3 -> 20 (4 x 5)

000111	000111
001011	000100
001101	000010
001110	000001
010011	000101
010101	000010
010110	000001
011001	000011
011010	000001
011100	000010
100011
100101
100110
101001
101010
101100
110001
110010
110100
111000
2^(n-1) * (2^(n-1)+1)

00011
00101
00110
01001
01010
01100
10001
10010
10100
11000

00011
00101
01001
10001
00110
01010
10010
01100
10100
11000

000111
001011
010011
100011
001101
010101
100101
011001
101001
110001
-----
001110
010110
100110
011010
101010
110010
011100
101100
110100
111000

]]