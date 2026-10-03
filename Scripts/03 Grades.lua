-- Central grade definitions, including the mid-grade variants.
GRADE_LABELS = {
	Grade_Tier01 = "AAAAA", Grade_Tier02 = "AAAA:", Grade_Tier03 = "AAAA.", Grade_Tier04 = "AAAA",
	Grade_Tier05 = "AAA:", Grade_Tier06 = "AAA.", Grade_Tier07 = "AAA",
	Grade_Tier08 = "AA:", Grade_Tier09 = "AA.", Grade_Tier10 = "AA",
	Grade_Tier11 = "A:", Grade_Tier12 = "A.", Grade_Tier13 = "A",
	Grade_Tier14 = "B", Grade_Tier15 = "C", Grade_Tier16 = "D",
	Grade_Failed = "F", Grade_None = "-",
}

GRADE_COLORS = {
	Grade_Tier01 = "#000000", Grade_Tier02 = "#66CCFF", Grade_Tier03 = "#66CCFF", Grade_Tier04 = "#66CCFF",
	Grade_Tier05 = "#EEBB00", Grade_Tier06 = "#EEBB00", Grade_Tier07 = "#EEBB00",
	Grade_Tier08 = "#66CC66", Grade_Tier09 = "#66CC66", Grade_Tier10 = "#66CC66",
	Grade_Tier11 = "#DA5757", Grade_Tier12 = "#DA5757", Grade_Tier13 = "#DA5757",
	Grade_Tier14 = "#5B78BB", Grade_Tier15 = "#C97BFF", Grade_Tier16 = "#8C6239",
	Grade_Failed = "#CDCDCD",
}

function GetGradeString(grade)
	if not grade then return "N/A" end
	return GRADE_LABELS[tostring(grade)] or "CLEARED"
end

function GetGradeColor(grade)
	return color(GRADE_COLORS[tostring(grade)] or "#666666")
end

function GetGradeForPercent(percent)
	percent = tonumber(percent) or 0
	if percent >= 99.9935 then return "Grade_Tier01"
	elseif percent >= 99.98 then return "Grade_Tier02"
	elseif percent >= 99.97 then return "Grade_Tier03"
	elseif percent >= 99.955 then return "Grade_Tier04"
	elseif percent >= 99.90 then return "Grade_Tier05"
	elseif percent >= 99.80 then return "Grade_Tier06"
	elseif percent >= 99.70 then return "Grade_Tier07"
	elseif percent >= 99.00 then return "Grade_Tier08"
	elseif percent >= 96.50 then return "Grade_Tier09"
	elseif percent >= 93.00 then return "Grade_Tier10"
	elseif percent >= 90.00 then return "Grade_Tier11"
	elseif percent >= 85.00 then return "Grade_Tier12"
	elseif percent >= 80.00 then return "Grade_Tier13"
	elseif percent >= 70.00 then return "Grade_Tier14"
	elseif percent >= 60.00 then return "Grade_Tier15"
	else return "Grade_Tier16" end
end
