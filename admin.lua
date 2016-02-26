-- encoding: UTF-8
----------------------
-- 小R的管理模块
----------------------
local log = require("lib.webqq.log")
local qqlib = require("lib.webqq.qqlib")
--local blink = require("blink")

local adminList = {
	["790934227"] = {
		nick = "小约哥",
		name = "Joshua",
		level = 10
	},
	["307439909"] = {
		nick = "船长",
		name = "Sen",
		level = 7
	},
	["421602022"] = {
		nick = "船长",
		name = "Sen",
		level = 7
	},
	["178459973"] = {
		nick = "浩然兄",
		name = "Shuenhoy",
		level = 5
	},
	["1017815010"] = {
		nick = "小梦哥",
		name = "Robotxm",
		level = 5
	},
	["467651627"] = {
		nick = "小熊哥",
		name = "Ditter",
		level = 5
	},
	["731458177"] = {
		nick = "柯罗罗",
		name = "Clock",
		level = 3
	}
}

local systemGroup = {
	["254098071"] = {
		name = "小R管理"
	}
}

function unAdmin(ID)
	return adminList[tostring(ID)] == nil
end

function getAction(level, creater)
	if systemGroup[get"群号"] then
		return true
	end
	local usr = get"发送者QQ"
	if creater and usr == get"群主" then
		return true
	elseif adminList[usr] then
		return adminList[usr].level >= level
	else
		return false
	end
end

function getUsrName()
	local gid = get"群号"
	if systemGroup[gid] then
		return systemGroup[gid].name
	end
	local usr = get"发送者QQ"
	if adminList[usr] then
		return adminList[usr].name
	else
		return "<nodata>"
	end
end

function getUsrNick()
	local gid = get"群号"
	if systemGroup[gid] then
		return systemGroup[gid].name
	end
	local usr = get"发送者QQ"
	if adminList[usr] then
		return adminList[usr].nick
	else
		return "<nodata>"
	end
end

function admin()

	if get"群消息":find("<dolua>.+") then
		if getAction(10) then
			local t={pcall(loadstring(string.match(get"群消息","<dolua>(.*)")))}
			local ts=""
			for i=1,table.maxn(t) do
				ts=ts .. string.format("[return %d] %s\n", i, tostring(t[i]))
			end
			put(ts .. "[finished]")
			return true
		elseif getAction(5) then
			if get"群消息":find("for") or get"群消息":find("while") or get"群消息":find("utill") then
				put("Check <for/while/utill>.")
				return true
			end
			local func, res = loadstring(string.match(get"群消息","<dolua>(.*)"))
			if func then
				setfenv(func, {math = math, string = string, pairs = pairs, checkTable = checkTable, rand = rand})
				local t={pcall(func)}
				local ts=""
				for i=1,table.maxn(t) do
					ts=ts .. string.format("[return %d] %s\n", i, tostring(t[i]))
				end
				put(ts .. "[finished]")
				return true
			else
				put("[return 1] false\n[return 2] ".. tostring(res) .."\n[finished]")
				return true
			end
		end
	end

	if get"群消息":find"^%s*Robot Send #(.+)#%s*$" then
		if getAction(5) then
			qqlib.setQQSign(get"群消息":match"^%s*Robot Send #(.+)#%s*$")
			put(string.format("OKay, %s.", getUsrName()))
		else
			put("I don't stand you. ;D")
		end
	end

	if get"群消息":find"^%s*Robot Reboot%s*$" then
		if getAction(7) then
			setreboot() -- 先设置标签
			put(string.format("Good bye, %s.", getUsrName()))
		else
			put"Oh, sorry. I can't reboot now."
		end
		return true
	end

	if get"群消息"=="Robot Logout" then
		if getAction(7) then
			put(string.format("Good bye, %s.", getUsrName()))
			log.show("--------------------------------------")
			qqlib.logoutWebQQ(true)
		else
			put"Oh, sorry. I can't logout now."
		end
		return true
	end

	if get"群消息":find"Robot Change Status {.-}" then
		if getAction(5) then

			sta = get"群消息":match"Robot Change Status {(.-)}"
			res = qqlib.SwitchState(sta)
			if res == 0 then
				put ("I can't select this status. (" ..sta.. ")")
			else
				put (string.format("%s, that's ok.", getUsrName()))
			end

		else
			put"Oh, sorry. I can't change status now."
		end
		return true
	end

	if get"群消息":find"Robot Reload" then
		if getAction(3) then
			setreload() -- 先设置标签
			put(string.format("Ok, %s.", getUsrName()))
		else
			put"Oh, sorry. I can't reload now."
		end
		return true
	end

	if get"群消息":find"小R.-返回.+" then
		if getAction(3) then
			put(get"群消息":match"小R.-返回(.+)")
		else
			put("No permissions.")
		end
		return true
	end

	if get"群消息":find"Robot Test" then
		if getAction(1) then
			put(string.format("%s, Test-OKay.", getUsrNick()))
		else
			put("No permissions.")
		end
		return true
	end
--[[
	if get"群消息":find"Check Blink" then
		if getAction(1) then
			blink.on()
			put("Blink, Blink.")
			blink.off()
		else
			put("No permissions.")
		end
		return true
	end
--]]
end
