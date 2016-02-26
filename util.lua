-- encoding: UTF-8
------------------------------------
-- 小R的信息处理中心所需的一些函数
------------------------------------
local log = require"lib.webqq.log"
local luacom = require"luacom"
local socket = require"socket"

function qfind(str, fstr)
	if fstr:find("|.-|") then
		local r={}
		local s=fstr:match("|(.-)|")
		if s=="" then
			return str:find(fstr)
		end
		s=s .. ","
		for i in s:gmatch("(.-),") do
			r[#r+1]=i
		end
		for i,v in pairs(r) do
			local res={qfind(str,fstr:gsub("|.-|",v,1))}
			if res[1] then
				return unpack(res)
			end
		end
	else
		return str:find(fstr)
	end
end

function escape(s)
	res={}
	s = string.gsub(s, "([&=+%c])", function (c)
		return string.format("%%%02X", string.byte(c))
	end)
	s = string.gsub(s, " ", "+")
	for i=1,#s do
		local char=s:sub(i,i)
		if string.byte(char)>128 then
			res[i]=string.format("%%%02X", string.byte(char))
		else
			res[i]=char
		end
	end
	return table.concat(res)
end

function rand(...)
	local t = {...}
	return t[math.random(1, #t)]
end

function checkTable(t)
	local res = {}
	for k in pairs(t) do
		res[#res + 1] = k
	end
	return table.concat(res, "\t")
end

function table2str(k,v,n)
	local r={}
	n=n or 0
	if type(v)~='table' then
		table.insert(r,table.concat{('\t'):rep(n),'[',type(k)=='string' and '"'..k..'"' or tostring(k),']\t= ',type(v)=='string' and '"'..tostring(v)..'"' or tostring(v),',\n'})
	else
		if n~=0 then
			table.insert(r,table.concat{('\t'):rep(n),'[',type(k)=='string' and '"'..k..'"' or tostring(k),']\t= {\n'})
		else
			table.insert(r,table.concat{k,"{\n"})
		end
		for i,t in pairs(v) do
			table.insert(r,table2str(i,t,n+1))
		end
		if n~=0 then
			table.insert(r,table.concat{('\t'):rep(n),'},\n'})
		else
			table.insert(r,table.concat{"}"})
		end
	end
	return table.concat(r)
end

function saveLuaTable(fn, t)
	local file = io.open(fn,"w")
	file:write(table2str("return ",t))
	file:close()
end

function loadLuaTable(fn)
	local file= io.open(fn,"r")
	local str = file:read("*all")
	file:close()
	local a,b = pcall(loadstring(str))
	if a then
		return b
	elseif a and b then
		log.show("---WARNING DATABASE ERROR---\n"..b)
		return {}
	end
end

function dexml(str)
	local xml={}
	xml.version,xml.encoding,xml.mod,xml.uin,xml.num,xml.pic,xml.tip,xml.title,xml.mod2,xml.mod3,xml.name=str:match('<%?xml version="(.-)" encoding="(.-)"%?><d><n t="(.-)" u="(.-)" i="(.-)" s="(.-)"/><n t="(.-)" s="(.-)"/><n t="(.-)"/><n t="(.-)" s="(.-)"/></d>')
	return xml
end

function getUrl(url,n)
	if not url then print(tr) return"No url" end
	local n=n or 0
	n=n+1
	if n==5 then return "No file" end
	ajax = luacom.CreateObject("msxml2.xmlhttp")
	ajax:open("get ",url,false)
	a,b=pcall(ajax.send,ajax)
	if a then
		return ajax.responseBody,url
	end
	host=url:match("://(.-)/")
	file=url:match("://.-/(.*)")
	c=socket.connect(host,8012)
	if not c then return"Time out" end
	c:send("GET "  ..  file  ..  " HTTP/1.0\r\n\r\n")
	tr=""
	while true do
		local s, status, partial=c:receive(2^10)
		tr=tr .. (s or partial)
		if status=="closed" then break end
	end
	return getUrl(tr:match("Location: (.-)\n"),n)
end