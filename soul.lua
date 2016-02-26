-- encoding: UTF-8
----------------------
-- Small Robot's Soul
----------------------
require("lib.moe.util")
dofile("lib/moe/admin.lua")
local log = require("lib.webqq.log")
local qqlib = require("lib.webqq.qqlib")
local json_moe = require("lib.mhttp.json_moe")
local TSError={
	[20]="要翻译的文本过长",
	[30]="无法进行有效的翻译",
	[40]="不支持的语言类型",
	[50]="无效的key"
}
local weekday = {
	["0"] = "星期天",
	["1"] = "星期一",
	["2"] = "星期二",
	["3"] = "星期三",
	["4"] = "星期四",
	["5"] = "星期五",
	["6"] = "星期六"
}
option = {
	black = true,
	single = true,
	short = false,
	news = false,
	wiki = true,
	dots = false,
	math = false,
	tra = false,
	rule = 8
}
local sended = {}
local event = {}
local botList = loadLuaTable("db/bot.rd") or {}
local recordList = {}

function setEvent(tag, wtime)
	event[get"发送者代号"] = {
		time = os.clock(),
		tag = tag,
		wtime = wtime
	}
end

function checkEvent(tag, ...)
	if event[get"发送者代号"] then
		if event[get"发送者代号"].tag == tag then
			if os.clock() - event[get"发送者代号"].time < event[get"发送者代号"].wtime then
				local res = rand(...)
				if type(res) == "string" then
					put(res)
				else
					put(unpack(res))
				end
				event[get"发送者代号"] = nil
				return true
			end
			event[get"发送者代号"] = nil
		end
	end
end

-- 用于临时修改
function extra()
	-- if get"群消息":find"test" then put "test" end
	-- return true
end

-- 应对群信息
function OnGroupMessage()
	if extra() then return end

	local suin = get"发送者代号"
	local gid = get"群号"

	if option.black then
		local sid = get"发送者QQ"
		if sid and botList[sid] then
			return
		end

		recordList[suin] = recordList[suin] or {retSum = 0}

		if recordList[suin].retSum == option.rule and unAdmin(sid) then
			put("{发送者}连续触发" .. option.rule .. "次Event，已经被加入bot列表。如有误判，请联系小约。", nil, {color = "FF0000"})
			if sid then botList[sid] = 5 end
			saveLuaTable("db/bot.rd", botList)
			recordList[suin] = nil
			return
		end

		recordList[suin].retSum = recordList[suin].retSum + 1
	end


	if admin() then return end

	-- log.show(get"从{群名}收到{发送者}的消息: {群消息}")

	-- 功能模块
	if option.tra then
		if qfind(get"群消息","|%*,完全,网络|.-翻译.+") or get"群消息":find("小R.-翻译.+") or get"群消息":find("^%s*翻译.+") then
			if string.len(get"群消息")>200 then
				put("消息过长，俺不翻译。")
				return
			end
			local r = json_moe.getResult(WQPD["翻译"], escape(get"群消息":match("翻译(.-)%s*$")))
			local p,lt=pcall(cjson.decode, r)
			if not p then
				put("需翻译的文本略过于奇葩，翻译系统傲娇了> <")
				return
			end
			local err=lt.errorCode
			local _,j=pcall(table.concat,lt.translation)
			if not _ then
				put("小R没有翻译成功，原因是" .. (TSError and err and TSError[err] or "连接失败") .. "。")
				return
			else
				setEvent("thank", 20)
				sres="翻译结果：\n\t" .. j
				if lt.basic then
					sres=sres .. "\n更多解释：\n\t" .. table.concat(lt.basic.explains,"\n\t")
				end
				if lt.web and qfind(get"群消息","|%*,完全,网络|.-翻译") then
					sres=sres .. "\n网络解释："
					for i,v in pairs(lt.web) do
						sres=table.concat{sres,"\n\t","词语：",v.key,"\n\t\t",table.concat(v.value,"\n\t\t")}
					end
				end
				put(sres)
				return
			end
		end
	end

	if option.short then
		if get"群消息":find"^s*缩短.-%s*$" or get"群消息":find"小R.-缩短.-%s$*" then
			setEvent("thank", 20)
			local T = json_moe.getResult(WQPD["短网址"], get"群消息":match("缩短(.-)%s*$"))
			if not T then put "短网址服务器傲娇了的说=。=" end
			local a,b=pcall(cjson.decode,T)
			if type(b)=="table" and b.shorturl then
				put("短网址: " .. b.shorturl)
			else
				put("呃，这个网址貌似不正确来着...")
			end
		end
	end

	if option.news then
		if get"群消息":find("新闻快递") then
			local r = json_moe.getResult(WQPD["新闻"])
			local result = {"小R新闻快递时间：\n"}
			local a, b
			for i=0,2 do
				a, b = nil, nil
				a, b = r:match('<div class="focus_newstitle link_title"><a href="([^\n]-)" target=_blank\n%s*onclick="hotNewsLog%(\'headlines\',\'all\', \'top3%.focus\',\'top3%.' .. i .. '%.focus\'%)">([^\n]-)</a></div>')
				b=b:gsub("&.-;"," ")
				b=b:gsub("<.->","")
				table.insert(result, b .. "\n传送门：" .. a .. "\n")
			end
			put(table.concat(result))
			return
		end
	end

	if option.math then
		if get"群消息":find("计算.+%s*$") then
			local exp = get"群消息":match("计算(.+)%s*$")
			if exp:find("N%s*%[") then
				put("……用N命令是很~危~险~的~哟~？")
				return
			end
			local obj = io.popen("math > tem.log", "w")
			obj:write(string.format("%s\n", exp))
			obj:close()
			local f = io.open("tem.log", "r")
			res = f:read("*a")
			if not res then put("计算失败了呢……") return end
			r = string.rep(" ", 8) .. res:match("Out%[1%]= (.-)\n") .. "  "
			t = res:match("In%[1%]:=.-\n(.-)\n")
			t = t .. string.rep(" ", #r - #t)
			if t:find("Out") then
				t = string.rep(" ", #r)
			end
			if r:gsub(" ", "") ~= "" then
				local arr = {}
				for k = 1, #r do
					arr[k] = r:sub(k, k)
				end
				for k = 1, #r do
					if t:sub(k, k) ~= " " then
						arr[k] = "^" .. t:sub(k, k)
					end
				end
				r = table.concat(arr)
			end
			f:close()
			put("小R计算完毕了：\n\t" .. r:gsub("%s", ""))
			setEvent("thank", 20)
			return
		end

		if get"群消息":find("方程%s*[%w%s%p]+%s*求%s*[%w%s%p]+%s*$") then
			local exp, ret = get"群消息":match("方程%s*([%w%s%p]+)%s*求%s*([%w%s%p]+)%s*$")
			local obj = io.popen("math > tem.log", "w")
			obj:write(string.format("Solve[%s, %s]\n", exp:gsub("==", "="):gsub("=", "=="), ret))
			obj:close()
			local f = io.open("tem.log", "r")
			res = f:read("*a")
			r = string.rep(" ", 8) .. res:match("Out%[1%]= (.-)\n") .. "  "
			if r:find("Solve") then
				put("你输入的方程(组)看上去有些问题哟？")
				return
			end
			t = res:match("In%[1%]:=.-\n(.-)\n")
			t = t .. string.rep(" ", #r - #t)
			if t:find("Out") then
				t = string.rep(" ", #r)
			end
			if r:gsub(" ", "") ~= "" then
				local arr = {}
				for k = 1, #r do
					arr[k] = r:sub(k, k)
				end
				for k = 1, #r do
					if t:sub(k, k) ~= " " then
						arr[k] = "^" .. t:sub(k, k)
					end
				end
				r = table.concat(arr)
			end
			f:close()
			if r:gsub("%s", ""):gsub("{", ""):gsub("}", ""):gsub("%s", "") == "" then
				put("该方程(组)没有给定元素的解哦~")
				return
			end
			put("方程求解完毕：\n\t" .. r:gsub("%s", ""):gsub("{", ""):gsub("}", ""))
			setEvent("thank", 20)
			return
		end

		if get"群消息":find("因式分解%s*[%w%s%p]+%s*$") then
			local exp = get"群消息":match("因式分解%s*([%w%s%p]+)%s*$")
			local obj = io.popen("math > tem.log", "w")
			obj:write(string.format("Factor[%s]\n", exp))
			obj:close()
			local f = io.open("tem.log", "r")
			res = f:read("*a")
			r = string.rep(" ", 8) .. res:match("Out%[1%]= (.-)\n") .. "  "
			t = res:match("In%[1%]:=.-\n(.-)\n")
			t = t .. string.rep(" ", #r - #t)
			if t:find("Out") then
				t = string.rep(" ", #r)
			end
			if r:gsub(" ", "") ~= "" then
				local arr = {}
				for k = 1, #r do
					arr[k] = r:sub(k, k)
				end
				for k = 1, #r do
					if t:sub(k, k) ~= " " then
						arr[k] = "^" .. t:sub(k, k)
					end
				end
				r = table.concat(arr)
			end
			f:close()
			put("小R分解完毕因式啦：\n\t" .. r:gsub("%s", ""))
			setEvent("thank", 20)
			return
		end

		if get"群消息":find("化简%s*[%w%s%p]+%s*$") then
			local exp = get"群消息":match("化简%s*([%w%s%p]+)%s*$")
			local obj = io.popen("math > tem.log", "w")
			obj:write(string.format("Simplify[%s]\n", exp))
			obj:close()
			local f = io.open("tem.log", "r")
			res = f:read("*a")
			r = string.rep(" ", 8) .. res:match("Out%[1%]= (.-)\n") .. "  "
			t = res:match("In%[1%]:=.-\n(.-)\n")
			t = t .. string.rep(" ", #r - #t)
			if t:find("Out") then
				t = string.rep(" ", #r)
			end
			if r:gsub(" ", "") ~= "" then
				local arr = {}
				for k = 1, #r do
					arr[k] = r:sub(k, k)
				end
				for k = 1, #r do
					if t:sub(k, k) ~= " " then
						arr[k] = "^" .. t:sub(k, k)
					end
				end
				r = table.concat(arr)
			end
			f:close()
			put("化简完了哟：\n\t" .. r:gsub("%s", ""))
			setEvent("thank", 20)
			return
		end
	end

	if option.wiki then
		if qfind(get"群消息","|查询,什么是|.+") then
			local t={qfind(get"群消息","|查询,什么是|(.+)")}
			t[3]=t[3] or t[3]:match("^(.-)%s*$")
			if t[3]:find"^%s*$" then
				put("小R才不会上当呢~")
				return
			elseif t[3]:find("这") or t[3]:find("那") then
				put("呃……我怎么知道这是什么……")
				return
			elseif t[3]:find("到底") or t[3]:find("还") then
				put("自己去问……")
				return
			end
			if t[3]:find("#.-#") then
				t[3]=t[3]:match("#(.+)#")
			elseif #t[3]>15 then
				put("这也太长了吧……")
				return
			end
			if t[3]:find("%[无视河蟹%]") then
				t[3]=t[3]:match("%[无视河蟹%](.-)$")
			else
				r=getUrl("http://www.baidu.com/s?wd=" .. escape(t[3]))
				if r:find("根据相关法律法规和政策，部分搜索结果未予显示。") then
					put("根据河蟹法律法规和政策，搜索结果未予显示。")
					return
				elseif r:find("搜索结果可能不符合相关法律法规和政策，未予显示。") then
					put("根据超级河蟹法律和法规，搜索结果全部未予显示。")
					return
				end
			end
			local r=getUrl("http://zh.wikipedia.org/zh-cn/" .. escape(t[3]))
			t[3]=r:match("<title>(.-) %- 维基百科，自由的百科全书</title>") or t[3]
			local YWK=t[3]

			if r:find("<div id=\"contentSub\" lang=\"zh%-CN\" dir=\"ltr\">重定向页</div>") then
				local s=r:match("<!%-%- bodycontent %-%->.-<a href=\"/w/index.->(.-)</a>")
				if s then
					r=getUrl("http://zh.wikipedia.org/zh-cn/" .. escape(s))
				else
					put("很遗憾，小R找到了一个重定向页，但无法连接上它。你可以访问" .. "http://zh.wikipedia.org/zh-cn/" .. escape(YWK) .. "来获取关于它的信息。")
					return
				end
			end
			if r:find("维基百科目前还没有与上述标题相同的条目。") or r:find("错误的标题") then
				put("维基百科里面没有关于『" .. t[3] .. "』的知识呢，小R也没办法咯。")
				return
			end
			if t[3]:find("^%a+$") then
				local r={}
				for i=1,#t[3] do
					r[i]="[" .. t[3]:sub(i,i):upper() .. t[3]:sub(i,i):lower() .. "]"
				end
				t[3]=table.concat(r)
			end
			local res=r:match('<div id="mw%-content%-text" lang="zh%-CN" dir="ltr" class="mw%-content%-ltr"><p>.-<b>.-' .. t[3] .. '.-</b>.-</p>.-</div>') or r:match("\n%s*(<p>[^\n]-<b>[^\n]-" .. t[3] .. "[^\n]-</b>[^\n]-)</p>") or	r:match("<p><b>" .. t[3] .. "</b>(.-)</p>") or r:match("\n%s*<b>" .. t[3] .. "</b>([^\n]+)\n") or r:match('<p>(<b>.-</b>.-)</p>\n<table id="toc" class="toc">')
			if res and res:find("\n\n") then
				res=res:match("^(.-)\n")
			end
			if not res then
				res="小R分析不出" .. YWK .. "，但是它的资料在这里的说：" .. "http://zh.wikipedia.org/zh-cn/" .. escape(YWK)
			end
			res=res:gsub("<.->",""):gsub("&(.-);",""):gsub("\n*$","")
			put(res)
			return
		end
	end

	-- 上下文接应模块
	if get"群消息":find"多谢" or get"群消息":find"谢谢" or get"群消息":find"谢了" or get"群消息":find"谢啦" or get"群消息":find"ありがど" or get"群消息":find"ありがと" or get"群消息":find"[Tt][Hh][Aa][Nn][Kk]" or get"群消息":find"[Tt][Hh][Xx]" then
		checkEvent("thank", "嘛，不用谢啦> <", "能帮忙我很开心哦~", "蹭~")
	end

	if get"群消息":find"[Yy][Ee][Ss]" then
		if checkEvent("Gsure", "{发送者}，你真的要触及世界的真实吗？接下来的五个选项你分别有20秒时间考虑：确认，请回复5，取消，请回复0。") then
			setEvent("G1", 20)
		end
	end

	if get"群消息":find"^%s*5%s*$" then
		if checkEvent("G1", "{发送者}，你真的要触及世界的真实吗？确认，请回复2，取消，请回复0。") then
			setEvent("G2", 20)
		end
	end

	if get"群消息":find"^%s*2%s*$" then
		if checkEvent("G2", "{发送者}，你真的要触及世界的真实吗？确认，请回复1，取消，请回复0。") then
			setEvent("G3", 20)
		end
	end

	if get"群消息":find"^%s*1%s*$" then
		if checkEvent("G3", "{发送者}，你真的要触及世界的真实吗？确认，请回复4，取消，请回复0。") then
			setEvent("G4", 20)
		end
	end

	if get"群消息":find"^%s*4%s*$" then
		if checkEvent("G4", "{发送者}，你真的要触及世界的真实吗？这是最后一次询问。确认，请回复3，取消，请回复0。")	 then
			setEvent("G5", 20)
		end
	end

	if get"群消息":find"^%s*3%s*$" then
		checkEvent("G5", "你已经没有回头的路了！这个世界的真实就是……在我大天朝，你想上facebook或者youtube，你都必须自备梯子...")
	end

	if get"群消息":find"^%s*0%s*$" then
		checkEvent("G1", "好的，事件已经取消...")
		checkEvent("G2", "好的，事件已经取消...")
		checkEvent("G3", "好的，事件已经取消...")
		checkEvent("G4", "好的，事件已经取消...")
		checkEvent("G5", "好的，事件已经取消...")
		return
	end

	if option.dots then
		if get"群消息"=="……" then
			if checkEvent("dots3", {"破！", nil, {size = 16}}) then
				return
			end
		end

		if get"群消息"=="……" then
			if checkEvent("dots2", "……") then
				setEvent("dots3", 20)
				return
			end
		end

		if get"群消息"=="……" then
			if checkEvent("dots1", "……") then
				setEvent("dots2", 20)
				return
			end
		end

		if get"群消息"=="……" then
			setEvent("dots1", 20)
			put"……"
			return
		end
	end
	-- 对话模块
	if get"群消息":find"我是谁" then
		put"你是{发送者}，小R记着呢~"
		return
	elseif get"群消息":find"我妈是谁" then
		if get"{发送者QQ}"==get"浩然" then
			put"你妈是梦飞花哦0 0"
		else
			put"谁知道你妈是谁。"
		end
		return
	elseif get"群消息":find"我爸是谁" then
		put"请不要问这种无厘头的问题..."
	elseif get"群消息":find"你妈是谁" or get"群消息":find"你爸是谁" then
		put"我没有爸妈，但是我有小约哥和大家哟~）蹭"
		return
	elseif get"群消息":find"你是谁" then
		put"我是小R，请多指教。"
		return
	elseif get"群消息":find"这是哪" then
		put"这是{群}，有{群人数}个人。和大家一起玩吧~"
		return
	elseif get"群消息":find"晚安" then
		put(rand("那，晚安~", "晚安啦。", "Stay cool~", "おやすみ~", "祝好梦~", "睡醒还要来玩哦）蹭"))
		return
	elseif get"群消息":find"小[Rr]好" and not get"群消息":find"小[Rr]好笨" then
		put(rand("你好0 0", "多多指教~！","好~）抱住）蹭> <"))
		return
	elseif get"群消息":find"小[Rr]" and (get"群消息":find"抱" or get"群消息":find"蹭") then
		put(rand("抱抱0 0", "wwwww", "蹭~", "> <~","）抱住）蹭> <"))
		return
	elseif get"群消息":find"小[Rr]" and (get"群消息":find"发张图") then
		put(string.format("[C#%d]", math.random(1, 7)))
		return
	elseif get"群消息":find"^%s*@小[Rr]%s*" then
		put(rand("{发送者}有事么0 0", "啊咧？","> <"))
		return
	elseif qfind(get"群消息", "|今个儿,今天,今日,昨天的明天,明天的明天的昨天的昨天,后天的后天的前天的前天,昨天的昨天的明天的明天,明天的昨天,后天的前天,前天的后天,大后天的大前天,大前天的大后天|.-几号") then
		setEvent("thank", 20)
		put(os.date("我看看...是%m月%d日来着0 0"))
		return
	elseif qfind(get"群消息", "|今个儿,今天,今日,昨天的明天,明天的昨天,后天的前天,前天的后天,大后天的大前天,大前天的大后天|.-|星期几,周几,礼拜几|") then
		setEvent("thank", 20)
		put("今天是"..weekday[os.date("%w")].."哟。")
		return
	elseif get"群消息":find"现在几点" then
		put("如果你用手机目光请移动到右上角，如使用电脑请把目光移动到右下角...")
		return
	elseif get"群消息":find"我要知道世界的真相" or get"群消息":find"怎么上外国网站" or get"群消息":find"我要翻墙"  or get"群消息":find"怎么翻墙" or get"群消息":find"我要触及世界的真实" or get"群消息":find"我要触及世界的真相" then
		setEvent("Gsure", 20)
		put("你真的做好觉悟了吗？确认，请回复yes，否则20秒后取消。")
		return
	elseif get"群消息":find"梯子是" or get"群消息":find"是梯子" then
		put("呵呵，梯子的种类很丰富，VPN（Astrxxx...），Goagxxx，Freexxxx都是哦~")
		return
	end

	if option.black then
		recordList[suin] = {retSum = 0}
	end
end

-- 应对个人信息
function OnMessage()
	log.show(get"收到来自{个人昵称}的消息: {个人消息}")
	if option.single then
		if not sended[get"个人uin"] then
			put"还是在群里聊吧> <"
			sended[get"个人uin"] = true
		end
	end
end

-- 好友状态改变
function OnChange()

end

-- 抖动
function OnShark()
	log.show("收到一个窗口抖动")
end

-- 系统提示
function OnTips()
	log.show("收到一个系统提示")
end

-- 正在输入
function OnInput()
	log.show("有人正在输入中")
end

-- 系统信息
function OnSystemMessage()
	log.show("收到一个系统信息")
end

-- 系统群信息
function OnGSMessage()
	log.show("收到一个系统群提示")
end

-- 群网络信息
function OnGroupWebMessage()
	if get"网络消息_xml":find("分享音乐") or get"网络消息_xml":find("分享文件") then
		local t=dexml(get"网络消息_xml")
		log.show("小R在“" .. get"网络消息_群名" .. "”(" .. get"网络消息_群号" .. ")" .. "中收到了" .. get"网络消息_发送者" .. "的" .. t.title .. "『" .. t.name .. "』")
	else
		log.show("收到了一个网络交互消息")
	end
end

-- 讨论组信息
function OnDiscuMessage()
	log.show("收到一个讨论组信息")
end

-- 临时信息
function OnSessMessage()
	log.show("收到一个临时信息")
end
