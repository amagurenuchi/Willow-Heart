-- Text-entry helpers ported from Til Death.
function easyInputStringWithParams(question, maxLength, isPassword, funcOK, params)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			funcOK(answer, params)
		end
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

function easyInputStringWithFunction(question, maxLength, isPassword, func)
	easyInputStringWithParams(
		question,
		maxLength,
		isPassword,
		function(answer)
			func(answer)
		end,
		{}
	)
end

function easyInputString(question, maxLength, isPassword, tablewithvalue)
	easyInputStringWithParams(
		question,
		maxLength,
		isPassword,
		function(answer)
			tablewithvalue.inputString = answer
		end,
		{}
	)
end

function easyInputStringOKCancel(question, maxLength, isPassword, funcOK, funcCancel)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			funcOK(answer)
		end,
		OnCancel = function()
			funcCancel()
		end,
	}
	SCREENMAN:GetTopScreen():Load(settings)
end
