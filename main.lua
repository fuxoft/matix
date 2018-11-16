--MATIX
--fuka@fuxoft.cz
_G.VERZE = ([[*<= Version '20181116a' =>*]]):match("'(.*)'")
local function mkdir(str)
	os.execute("mkdir "..str)
end

local function user_log(txt)
	local time = os.date("(b)%d. %m. %H:%M:(/b) ")
	table.insert(USER.log, time..tostring(txt))
	while #USER.log > 300 do
		table.remove(USER.log, 1)
	end
end

local function init()
	if FFTEMPL.args.debug == "gubed" then --!!!Tohle odstrante pokud vase dite rozumi zdrojovym kodum, protoze si pomoci toho muze zobrazovat spravna reseni!!!
		_G.DEBUG = true
	end
	package.path = DIR.base.."?.lua;"..package.path
	DIR.storage = "/home/fuxoft/appdata/matix/"
	--DIR.storage = "/home/fuxoft/matix_test/"
	mkdir (DIR.storage)
	DIR.users = DIR.storage.."users/"
	mkdir (DIR.users)
	DIR.cache = DIR.storage.."cache/"
	mkdir (DIR.cache)
	HASH_RANDOM = require("hash_random")
	SERIALIZE = require("serialize")
	_G.random = HASH_RANDOM.new_random()
	_G.USER = {}
	local id = (FFTEMPL.args._dash_argument or ""):match("[%d%l]+")
	if not id or #id < 4 or #id> 30 then
		_G.USER = nil
	else
		local fname=DIR.users..id..".lua"
		_G.USER = SERIALIZE.load(fname)
		if not _G.USER or FFTEMPL.args.reset == "teser" then
			_G.USER = {id = id, created = os.date(), log = {}, obtiznost = 0}
			user_log("Uživatel "..id.." založen")
		end
		SERIALIZE.save(_G.USER, fname)
		if DEBUG then
			user_log("!!!!!!!!!!! Uživatel použil funkci DEBUG. !!!!!!!!!!")
		end
		_G.HTML = {
			home = function(txt)
				local id = USER.id
				local url = "index.htm?"
				if id then
					url = "index--"..USER.id..".htm?"
				end
				if not txt then
					return url
				end
				return '(ahref "'..url..'")'..txt.."(/a)"
			end,
			priklad = function(pr)
				assert(pr)
				return HTML.home().."priklad="..pr.."&"
			end,
			---zbytecne???
			reseni00000 = function(pr)
				return string.format('(ahref ("%s")příklad %s(/a)',HTML.priklad(pr).."reseni="..HASH_RANDOM.hash("priklad"..pr.id,1), pr)
			end
		}		
	end
end

local function chyba(txt)
	return "(h3)CHYBA(/h3)(p)"..txt.."(p)"..HTML.home("Zpět na hlavní stránku")
end

local function tostringcz(num)
	assert(type(num) == "number")
	local str = tostring(num)
	return str:gsub("%.", "{,}")
end

local function nejsd(c1, c2) --nejvetsi spolecny delitel
	c1, c2 = math.abs(c1), math.abs(c2)
	if c1 * c2 == 0 then
		return 1
	end
	while c1 ~= c2 do
		if c1 < c2 then
			c1, c2 = c2, c1
		end
		if c2 == 1 then
			return 1
		end
		c1 = c1 - c2		
	end
	return c1
end

local function cislo(zak, cit, jm)
	FFTEMPL.log("rendering "..tostring(zak).." "..tostring(cit).." "..tostring(jm))
	local render
	if not cit then
		assert(not jm)
		render = tostringcz(zak)
		zak, cit, jm = nil, assert(zak), 1
	elseif not zak then
		render = string.format("\\frac{%s}{%s}", tostringcz(cit), tostringcz(jm))
	else
		render = string.format("%s\\frac{%s}{%s}", tostringcz(zak), tostringcz(cit), tostringcz(jm))
	end
	assert(jm ~= 0)
	if cit == 0 then
		jm = 1
	end
	if zak then
		assert(cit > 0)
		cit = cit + zak * jm
		zak = nil
	end

	if jm < 0 then
		cit = -cit
		jm = -jm
	end

	while tostring(math.floor(cit))~=tostring(cit) do
		cit = tonumber(tostring(cit * 10)) --Multiplication is weird...
		jm = tonumber(tostring(jm * 10))
	end

	local nsd = nejsd(cit, jm)
	if nsd > 1 then
		cit = cit / nsd
		jm = jm / nsd
	end

	local obj = {typ = "cislo", hodnota = {citatel = assert(cit), jmenovatel = assert(jm)}, render = assert(render)}
	--FFTEMPL.log("...as "..render)
	return obj
end

local function zavorka(c1)
	local render = "("..c1.render..")"
	local obj = {typ = "zavorka", render = render, obsah = c1}
	return obj
end

local function vypocti(obj)
	local typ = assert(obj.typ)
	FFTEMPL.log("pocitam: "..typ)
	if typ == "cislo" then
		return assert(obj)
	end
	if typ == "zavorka" then
		return vypocti(obj.obsah)
	end
	if typ == "mocnina" then
		local mocnitel = assert(obj.mocnitel)
		if not (mocnitel == math.floor(mocnitel) and mocnitel >= 2 and mocnitel <= 5) then
			error ("Nepripustny mocnitel: "..mocnitel)
		end
		local mocnenec = vypocti(obj.c)
		local res = {c=1, j=1}
		for i = 1, mocnitel do
			res.c = res.c * mocnenec.hodnota.citatel
			res.j = res.j * mocnenec.hodnota.jmenovatel
		end
		return cislo(nil, res.c, res.j)
	end
	if typ == "krat" then
		local c1, c2 = vypocti(obj.c1), vypocti(obj.c2)
		return cislo(nil, c1.hodnota.citatel * c2.hodnota.citatel, c1.hodnota.jmenovatel * c2.hodnota.jmenovatel)
	end
	if typ == "lomeno" then
		local c1, c2 = vypocti(obj.c1), vypocti(obj.c2)
		local res = cislo(nil, c1.hodnota.citatel * c2.hodnota.jmenovatel, c1.hodnota.jmenovatel * c2.hodnota.citatel)
		return res
	end
	if typ == "plus" or typ == "minus" then
		local c1, c2 = vypocti(obj.c1), vypocti(obj.c2)
		local cit1, jm1 = c1.hodnota.citatel, c1.hodnota.jmenovatel
		local cit2, jm2 = c2.hodnota.citatel, c2.hodnota.jmenovatel
		if typ == "minus" then
			cit2 = -cit2
		end
		local jm, cit
		FFTEMPL.log(string.format("Scitam %s/%s - %s/%s (%s)", cit1, jm1, cit2, jm2, typ))
		if jm1 == jm2 then
			jm = jm1
			cit = cit1+cit2
		else
			jm = jm1 * jm2
			cit = cit1 * jm2 + cit2 * jm1
		end
		return cislo(nil, cit, jm)
	end
end

local all_operators = {
	plus = function(c1, c2)
		local r1, r2 = c1.render, c2.render
		if r2:match("^%-") then
			r2 = "("..r2..")"
		end
		local render = r1 .. " + " .. r2
		local obj = {typ = "plus", render = render, c1=c1, c2=c2}
		return obj
	end,

	minus = function (c1, c2)
		if c2.typ == "plus" or c2.typ == "minus" then
			c2 = zavorka(c2)
		end
		local r1, r2 = c1.render, c2.render
		if r2:match("^%-") then
			r2 = "("..r2..")"
		end
		local render = r1 .. " - " .. r2
		local obj = {typ = "minus", render = render, c1=c1, c2=c2}
		return obj
	end,

	krat = function (c1, c2)
		if c1.typ == "plus" or c1.typ == "minus" then
			c1 = zavorka(c1)
		end
		if c2.typ == "plus" or c2.typ == "minus" then
			c2 = zavorka(c2)
		end
		local render = c1.render .. " \\cdot " .. c2.render
		local obj = {typ = "krat", render = render, c1 = c1, c2 = c2}
		return obj
	end,

	lomeno = function (c1, c2)
		local render = string.format("\\frac{%s}{%s}", c1.render, c2.render)
		local obj = {typ = "lomeno", render = render, c1=c1, c2=c2}
		return obj
	end,

	mocnina = function (c, mocnitel)
		local x1 = c.render
		if x1 ~= tostring(vypocti(c).hodnota.citatel) then
			x1 = "("..x1..")"
		end

		local render = string.format('%s^%s', x1, mocnitel)
		local obj = {typ = "mocnina", render = render, c = c, mocnitel = mocnitel}
		return obj
	end,
} -- konec all_operators

local function zakladni_tvar(c)
	assert(c.typ == "cislo")
	local cit, jm = c.hodnota.citatel, c.hodnota.jmenovatel
	FFTEMPL.log("zakladni tvar pro "..cit.." "..jm)
	local nsd = nejsd(cit, jm)
	local rend = {}
	if nsd > 1 then
		cit = cit / nsd
		jm = jm / nsd
	end
	if cit == 0 then
		return 0, nil, nil
	end
	if jm == 1 then
		return cit, nil, nil
	end
	local float = cit / jm
	local sign = 1
	if cit < 0 then
		cit = -cit
		sign = -1
	end
	assert(jm > 0)
	local zak
	if cit > jm then
		zak = math.floor(cit / jm)
		cit = cit - zak * jm
	end
	if zak then
		zak = zak * sign
	else
		cit = cit * sign
	end
	return zak, cit, jm, float
end

local function zakladni_tvar_tex(c)
	local zak, cit, jm = zakladni_tvar(c)
	if not jm then
		assert(not cit)
		return tostringcz(zak)
	end
	local res = ""
	if cit < 0 then
		cit = -cit
		res = "-"
	end
	if zak then
		res = res .. zak
	end
	res = res .. string.format("\\frac{%s}{%s}", cit, jm)
	return res
end

local function reseni_prikladu_tex(priklad)
	return priklad.reseni.tex_float or priklad.reseni.tex
end

local function priklad(diff, seed)
	if not seed then
		seed = HASH_RANDOM.random_string(random, 10).."_"..diff
	end
	assert(diff >=0 and diff <= 1, "obtiznost je "..diff)
	local rnd = HASH_RANDOM.new_random(seed)
	local maxnum = math.floor(diff * 15 + 10)
	local function randmaxnum()
		return 1 + math.floor((rnd()+rnd())*0.5*maxnum)
	end
	local function cis()
		local n = randmaxnum() + 1
		if rnd()*2 > diff then
			if rnd() < diff + 0.3 and rnd() > 0.5 then
				n = -n
			end
			return cislo(n)
		else --zlomek
			local cit = rnd(5)
			local jm = cit + math.floor(randmaxnum()/2)
			local pre
			if true then
				pre = rnd(4)
			else
				if rnd() > 0.5 then
					cit = -cit
				end
			end
			return cislo(pre, cit, jm)
		end
		error("WTF")
	end

	local op_scores = {plus = 1, minus = 1.5, krat = 2, lomeno = 2}
	local all_ops = {}
	for k, v in pairs(op_scores) do
		table.insert(all_ops, k)
	end
	
	local function rnd_operator()
		return all_ops[rnd(#all_ops)]
	end

	local remdif = math.floor(diff * 5 + 4)
	local ops = {}
	assert(remdif > 0 and remdif < 20)
	local op_scores = {plus = 1, minus = 1.5, krat = 2, lomeno = 2}
	while remdif > 0 do
		local op = rnd_operator()
		remdif = remdif - assert(op_scores[op], "Op = "..tostring(op))
		table.insert(ops,op)
	end
	local vyrazy = {}
	local extradif = 0
	for i = 1, #ops + 1 do
		vyrazy[i] = cis()
		if vyrazy[i].hodnota.jmenovatel ~= 1 then
			extradif = extradif + 0.2
		end
	end
	for i, op in ipairs(ops) do
		local c1 = assert(table.remove(vyrazy, rnd(#vyrazy)))
		local c2 = assert(table.remove(vyrazy, rnd(#vyrazy)))
		if op == "lomeno" and vypocti(c2).hodnota.citatel == 0 then
			c2 = all_operators.plus(c2, cislo(rnd(5)))
		end
		local res = all_operators[op](c1, c2)
		
		--mocnina?
		if rnd() < 0.3 + diff / 3 then
			local mocnitel = rnd(4) + 1
			local v = vypocti(res)
			local max = 1000
			if math.abs(v.hodnota.citatel) ^ mocnitel <= max and math.abs(v.hodnota.jmenovatel) ^ mocnitel <= max then
				res = all_operators.mocnina(res, mocnitel)
				extradif = extradif + mocnitel / 5
			end
		end

		assert(res)
		table.insert(vyrazy, res)
	end
	assert(#vyrazy == 1)
	local res = {zadani = assert(vyrazy[1]), obtiznost = extradif + diff, seed = seed}
	res.body = math.floor(res.obtiznost ^ 1.5 * 90) + 10
	if not res.zadani.render:match("frac") then
		res.body = math.floor(res.body / 2)
	end
	res.id = HASH_RANDOM.random_string(rnd, 6)..os.date("_%m%d_%H%M")
	local r = vypocti(res.zadani)
	local x,y,z, float = zakladni_tvar(r)
	local reseni = {x=x, y=y, z=z, float = float, tex = zakladni_tvar_tex(r), objekt = r}
	if #(tostring(float):match("%.(.+)") or "xxxxxxxxxxxxxxxxx") <= 3 then
		reseni.tex_float = tostringcz(float) --Reseni je desetinne, ne zlomek
	elseif not (y or z) and rnd()>.5 then --Reseni je cele cislo a chceme ho zadat jako desetinne (do jednoho policka misto 3)
		reseni.tex_float = tostringcz(x)
	end
	res.reseni = reseni
	return res
end

function dnesni_body()
	if not (USER and USER.body) then
		return 0
	end
	local tag = os.date("%d.%m.")
	local den = USER.body[#USER.body]
	if den and den.den == tag and den.body then
		return den.body, tag
	else
		return 0
	end
end

function pridej_body(plus)
	assert(plus > 0)
	local den_id = os.date("%d.%m.")
	if not USER.body then
		USER.body = {{den=den_id, body = 0, priklady = 0}}
	end
	dnes = table.remove(USER.body)
	if dnes.den ~= den_id then
		table.insert(USER.body, dnes)
		dnes = {den=den_id, body = 0, priklady = 0}
	end
	dnes.body = dnes.body + plus
	dnes.priklady = dnes.priklady + 1
	table.insert(USER.body, dnes)
	while #USER.body > 15 do
		table.remove(USER.body, 1)
	end
	return dnes.body
end

local function vsechny_animace()
	local fd = io.popen("ls -Q "..DIR.base.."joy/")
	local txt = fd:read("*a")
	fd:close()
	local result = {}
	for str in txt:gmatch('"(.-)"') do
		table.insert(result, str)
	end
	return result
end

local function intro_stranka()
	local pr0 = {}
	local add = function(str)
		table.insert(pr0, str)
	end
	add("(p)Matix (aktuální verze (b)"..VERZE.."(/b)) je online aplikace pro výuku základní matematiky (4 operace, úpravy zlomků) pro děti od 7. třídy dále. S překvapením jsem zjistil, že podobná online aplikace neexistuje, tak jsem ji narychlo spíchl sám (děti nemám, bylo to pro cizí dítě).")
	add('(p)Zkuste si (ahref "index--demo.htm")demo(/a) a pravděpodobně všechno pochopíte. Dítě dostává nabídku z 5 příkladů (různě obodovaných podle obtížnosti). Jakmile jeden z nich správně vyřeší, o trošičku se zvýší obtížnost a je vygenerováno 5 dalších. Pokud neumí vyřešit ani jeden, kliknutím na link pod 5 příklady může obtížnost snížit. Kliknutím na "historie" se zobrazí co přesně kdy dítě řešilo, a jestli bylo úspěšné. To je určeno pro rodiče. Takže můžete např. dítěti přikázat "dnes udělej správně 10 příkladů" nebo "dnes udělej správně příklady za 200 bodů" nebo "dnes se dostaň aspoň na obtížnost 0.15" a pak to zkontrolovat.')
	add('(p)Založení účtu pro vaše dítě: Podívejte se na URL dema v předchozím odstavci. Místo řetězce "demo" tam vložte unikátní řetězec pro vaše dítě. Tedy například "karlik9210666". Výsledné URL (v tomto případě (b)www.fuxoft.cz/vyplody/matix/index--karlik9210666.htm(/b)) zabookmarkujete svému dítěti. Pokud použijete pouze "karlik", je vysoce pravděpodobné, že totéž jméno použije později někdo jiný a dostane se na váš účet. Žádná autentifikace neexistuje. Uživatelská jména mohou obsahovat (b)pouze malá písmena a číslice(/b).')
	add('(p)(ahref "index.htm?test=jo")Zde(/a) je k dispozici stránka, která vygeneruje 100 náhodných příkladů (včetně řešení) s (přibližně) rostoucí obtížností - abyste viděli, o jaký typ příkladů jde.')
	add('(p)Neaktivní uživatelé se po nějaké době mažou.')
	add('(p)Zdrojáky jsou k dispozici (ahref "https://github.com/fuxoft/matix")zde(/a).')
	return table.concat(pr0)
end

local function main_test()
	if not FFTEMPL.args.test then
		return intro_stranka()
	end
	local prefix = HASH_RANDOM.random_string(random, 20)
	FFTEMPL.log("prefix: "..prefix)
	local pr0 = {}
	local add = function(str)
		table.insert(pr0, str)
	end
	for dif = 0, 1, 0.01 do
		local seed = prefix.."_"..dif
		--local dif, id = 0.45, "kivIhbVY4n_0.45"
		local pr = priklad(dif, seed)
		local sol, float = pr.reseni.tex, pr.reseni.tex_float
		add("(p)seed: "..pr.seed..", ")
		add("bodu="..pr.body..", ")
		add("<font size=+2>$$")
		add(pr.zadani.render)
		if float then
			add("=\\textcolor{white}{"..float.."}")
		else
			add("=\\textcolor{white}{"..sol.."}")
		end
		add("$$</font>")
		add("<code>")
		add(SERIALIZE.serialize(pr))
		add("</code>")
	end
	for i, addr in ipairs(vsechny_animace()) do
		add("(p)")
		add(addr)
		add(": ")
		add("<img src='joy/"..addr.."'>")
	end
	return [[
	(p)Nahodny test, priklady s rostouci obtiznosti...(/p)
]] ..
table.concat(pr0)
end
--https://katex.org/docs/supported.html

local function je_priklad_aktivni(priklad)
	local valid = false
	if USER.priklady then --Je tento priklad v aktivni nabidce?
		for i, pr in ipairs(USER.priklady) do
			if pr.id == priklad.id then
				valid = true
				break
			end
		end
	end
	return valid
end

local function resit_priklad(id)
	id = id:gsub("[%./]","x")
	local priklad = SERIALIZE.load(DIR.cache..id..".lua")
	if not priklad then
		return chyba("Příklad nenalezen: "..id)
	end
	local aktivni = je_priklad_aktivni(priklad)
	local res0 = {}
	local function add(txt)
		table.insert(res0, txt)
	end

	local args = FFTEMPL.args
	local zadal = {}
	local function sanitize(str)
		if not str or str == "" then
			return nil
		end
		str = str:gsub("%+", " ")
		str = str:gsub(" ", "")
		str = str:gsub("%a", "")
		str = str:gsub("\\", "")
		str = str:gsub("%.", ",")
		str = str:gsub(",", "{,}")
		return str
	end
	if args.citatel or args.jmenovatel or args.cislo then
		local cit = sanitize(args.citatel)
		local jm = sanitize(args.jmenovatel)
		local cis = sanitize(args.cislo)
		if cis or cit or jm then
			if not cis and (cit or ""):match("^%-") then
				cis = "-"
				cit = cit:match("^%-(.+)")
			end
			if cit then
				jm = jm or "??"
			end
			if jm then
				cit = cit or "??"
			end
			zadal.cis, zadal.cit, zadal.jm = cis, cit, jm
			zadal.render = (cis or "")
			if cit then
				zadal.render = zadal.render .. string.format("\\frac{%s}{%s}", cit, jm)
			end
			if zadal.render == reseni_prikladu_tex(priklad) then
				zadal.spravne = true
			end
		else
			zadal = false
		end
	else
		zadal = false
	end

	add("(center)")
	add("Příklad za "..priklad.body.." bodů.<br>")
	if zadal then
		add("Zadal jsi toto řešení:")
		if DEBUG then
			add("<br>"..zadal.render)
		end
	else
		if aktivni then
			if priklad.reseni.tex_float then
				add("Vypočti následující výraz. Výsledek zadej jako (b)celé nebo desetinné(/b) číslo (ne zlomek).")
			else
				add("Vypočti následující výraz. Pokud to jde, převeď výsledek na zlomek v základním tvaru a na smíšené číslo.")
			end
		else
			add("Tento příklad už není v aktivní nabídce. Jeho správné řešení bylo:")
		end
	end
	if DEBUG then
		add("<br>Reseni: "..reseni_prikladu_tex(priklad))
		add("<br>"..SERIALIZE.serialize(priklad))
	end
	add("<font size = +3>")
	add("$$")
	add(priklad.zadani.render)
	if not aktivni and not zadal then
		add("= \\textcolor{white}{"..reseni_prikladu_tex(priklad).."}")
	end
	if zadal then
		add("\\color{white}= "..zadal.render)
	end
	add("$$")
	if zadal then
		local msg = "😉 Úspěšné"
		if zadal.spravne then
			add("<font color=white>😉 SPRÁVNĚ! 😉")
		else
			msg = "(b)Neúspěšné(/b)"
			add("<font color=red>NESPRÁVNÉ ŘEŠENÍ")
		end
		add("</font>")
		msg = msg .. string.format(' řešení příkladu (ahref "%s")%s(/a), (%s bodů, obtížnost %s): ', HTML.priklad(priklad.id), priklad.id, priklad.body, priklad.obtiznost)
		msg = msg..zadal.render
		zadal.log = msg
		if not zadal.spravne then --Pro SPRAVNOU odpoved se loguje az dale
			user_log(msg)
		end
	end
	add("(/center)")
	add("</font>")
	if zadal and zadal.spravne then
		local valid = aktivni
		body = 0
		if valid then
			body = assert(priklad.body)
			USER.priklady = nil
			USER.obtiznost = USER.obtiznost + 0.001
			if USER.obtiznost > 1 then
				USER.obtiznost = 1
			end
		end
		add("(p)Získal jsi (b)"..body.."(/b) bodů! ")
		if body > 0 then
			user_log(zadal.log)
			local dnes = pridej_body(body)
			if dnes ~= body then
				add(" Za dnešek máš celkem "..dnes.." bodů.")
			end
		end
	elseif aktivni then
		if priklad.reseni.tex_float then
			add(string.format(
				[[<form align="center" action="%s" method="get">
				<input type="hidden" name="priklad" value="%s">
				(b)Zadej výsledek:(/b) <input type="text" size="6" name="cislo" value="">&nbsp;&nbsp;&nbsp;
				<input type="submit" value="ODESLAT">
				<br>Výsledek zadej jako celé nebo desetinné číslo (ne zlomek).
				</form>
				]], HTML.home(), priklad.id))
		else
			add(string.format(
			[[<form align="center" action="%s" method="get">
			<input type="hidden" name="priklad" value="%s">
			(b)Zadej výsledek:(/b) Celé číslo: <input type="text" size="6" name="cislo" value="">&nbsp;&nbsp;&nbsp;
			Čitatel: <input type="text" size="6" name="citatel" value="">&nbsp;&nbsp;&nbsp;
			Jmenovatel: <input type="text" size="6" name="jmenovatel" value="">&nbsp;&nbsp;&nbsp;
			<input type="submit" value="ODESLAT">
			<br>Pokud je výsledek celé číslo, vyplň pouze první políčko. Pokud je výsledek smíšené číslo, vyplň všechna tři políčka. Čitatel musí být (b)menší než jmenovatel(/b) a jmenovatel (b)nesmí být záporný(/b).
			</form>
			]], HTML.home(), priklad.id))
		end
	end
	add(HTML.home("(p)Zpět na hlavní stránku"))
	if zadal and zadal.spravne then
		local all = vsechny_animace()
		local ran
		add("(center)")
		add('<img width="300" src="joy/'..all[random(#all)]..'">')
		add("(/center)")
	end
	return table.concat(res0)
end

local function historie()
	local log = USER.log or {}
	local result0 = {}
	local function add(str)
		table.insert(result0, str)
	end

	local _x, dnes = dnesni_body()
	local barvit = false
	local function barv(str, sloupec)
		--FFTEMPL.log("barvit, sloupec = "..tostring(barvit)..","..tostring(sloupec))
		if barvit == sloupec then
			return "(b)"..str.."(/b)"
		end
		return str
	end


	add("Posledních 15 aktivních dní uživatele "..USER.id..":")
	local bd = USER.body or {}
	add("<table border=1><tbody>")

	add("<tr><td>Datum:</td>")
	for sloupec, d in ipairs(bd) do
		local str = d.den
		if str == dnes then
			barvit = sloupec
		end
		add("<td>"..barv(str, sloupec).."</td>")
	end
	add("</tr>")

	add("<tr><td>Příklady:</td>")
	for sloupec, d in ipairs(bd) do
		add("<td>"..barv(d.priklady, sloupec).."</td>")
	end
	add("</tr>")

	add("<tr><td>Body:</td>")
	for sloupec, d in ipairs(bd) do
		add("<td>"..barv(d.body, sloupec).."</td>")
	end
	add("</tr>")

	add("<tr><td>Průměr:</td>")
	for sloupec, d in ipairs(bd) do
		add("<td>"..barv(math.floor(d.body / d.priklady + 0.5), sloupec).."</td>")
	end
	add("</tr>")

	add("</tbody></table>")

	add(HTML.home("Zpět na hlavní stránku."))

	add("(p)Dnešní body: "..dnesni_body().."(/p)")

	for i=#log, 1, -1 do
		add("(p)")
		add(log[i])
		add("(/p)")
	end
	add(HTML.home("Zpět na hlavní stránku."))
	return (table.concat(result0))
end

local function main()
	if FFTEMPL.args.priklad then
		return resit_priklad(FFTEMPL.args.priklad)
	end
	if FFTEMPL.args.historie then
		return historie()
	end
	local result0 = {}
	local function add(str)
		table.insert(result0, str)
	end

	if USER and FFTEMPL.args.jednodussi == "takjo" then
		local sub = 0.005
		USER.obtiznost = USER.obtiznost - sub
		local prs = {}
		for i,priklad in ipairs(USER.priklady) do
			table.insert(prs, string.format('(ahref "%s")%s(/a)', HTML.priklad(priklad.id), priklad.id))
		end
		USER.priklady = nil
		if USER.obtiznost < 0 then
			USER.obtiznost = 0
		end
		local txt = "***** Obtížnost snížena o "..sub.." na "..USER.obtiznost.."."
		add("(b)"..txt.."(/b)(p)")
		user_log(txt.." Aktivní příklady byly: "..table.concat(prs,", ")..".")
	end

	add("Uživatel: (b)"..USER.id.."(/b)")
	add(" / Obtížnost: "..USER.obtiznost)
	add(string.format(' / Zobrazit (ahref "%s")historii(/a)', HTML.home().."historie=1"))
	add(" / Dnes jsi získal (b)"..dnesni_body().."(/b) bodů")
	if not USER.priklady then
		USER.priklady = {}
		local prikladu, diffstep = 5, 0.05
		for i = 1, prikladu do
			local pr = priklad(USER.obtiznost + (i-1)*diffstep)
			table.insert(USER.priklady, pr)
		end
		table.sort(USER.priklady, function (a,b) return a.body < b.body end)
	end

	for i, priklad in ipairs(USER.priklady) do
		SERIALIZE.save(priklad, DIR.cache .. priklad.id .. ".lua") --Priklady se ukladaji na disk pri KAZDEM zobrazeni hlavni stranky, aby bylo mozne se vratit k aktivnim prikladum i po hodne dlouhe dobe (kdyz je cache smazana)
		add("(h3)Příklad "..string.char(64+i).." za "..priklad.body.." bodů:(/h3)")
		add("<font size=+2>$$")
		add(priklad.zadani.render)
		--add("\\color{white}= x\\frac{y}{z}")
		add("$$</font>")
		add('(center)Chci (ahref "'..HTML.priklad(priklad.id)..'")vyřešit tento příklad(/a) za (b)'..priklad.body..'(/b) bodů(/center)')
		if DEBUG then
			add(SERIALIZE.serialize(priklad))
		end
		add("<hr>")
	end
	add(string.format('Všechny příklady ti připadají příliš těžké? (ahref "%s")Klikni sem(/a) a dostaneš jednodušší (za méně bodů).', HTML.home().."jednodussi=takjo"))
	local res = table.concat(result0)
	return res
end

----Zacatek
init()
local result
local title = "Matix"
if not USER then
	result = main_test()
else
	result = main()
	title = "Matix ("..USER.id..")"
end
SERIALIZE.save_all()
return result, title