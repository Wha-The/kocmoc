/*
Natro Macro (https://github.com/NatroTeam/NatroMacro)
Copyright © Natro Team (https://github.com/NatroTeam)

This file is part of Natro Macro. Our source code will always be open and available.

Natro Macro is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Natro Macro is distributed in the hope that it will be useful. This does not give you the right to steal sections from our code, distribute it under your own name, then slander the macro.

You should have received a copy of the license along with Natro Macro. If not, please redownload from an official source.
*/

#SingleInstance Force
#Requires AutoHotkey v2.0

#Include "%A_ScriptDir%\..\lib"
#Include "Gdip_All.ahk"
#Include "Gdip_ImageSearch.ahk"
#Include "Roblox.ahk"
#Include "DurationFromSeconds.ahk"
#Include "nowUnix.ahk"
Util_ObjCount(Obj) {
	if (!IsObject(Obj))
		return 0
	z:=0
	for k in Obj
		z+=1 ;or z:=A_Index
	return z
}
Jxon_Load(&src, args*) {
	key := "", is_key := false
	stack := [ tree := [] ]
	next := '"{[01234567890-tfn'
	pos := 0
	
	while ( (ch := SubStr(src, ++pos, 1)) != "" ) {
		if InStr(" `t`n`r", ch)
			continue
		if !InStr(next, ch, true) {
			testArr := StrSplit(SubStr(src, 1, pos), "`n")
			
			ln := testArr.Length
			col := pos - InStr(src, "`n",, -(StrLen(src)-pos+1))

			msg := Format("{}: line {} col {} (char {})"
			,   (next == "")      ? ["Extra data", ch := SubStr(src, pos)][1]
			  : (next == "'")     ? "Unterminated string starting at"
			  : (next == "\")     ? "Invalid \escape"
			  : (next == ":")     ? "Expecting ':' delimiter"
			  : (next == '"')     ? "Expecting object key enclosed in double quotes"
			  : (next == '"}')    ? "Expecting object key enclosed in double quotes or object closing '}'"
			  : (next == ",}")    ? "Expecting ',' delimiter or object closing '}'"
			  : (next == ",]")    ? "Expecting ',' delimiter or array closing ']'"
			  : [ "Expecting JSON value(string, number, [true, false, null], object or array)"
			    , ch := SubStr(src, pos, (SubStr(src, pos)~="[\]\},\s]|$")-1) ][1]
			, ln, col, pos)

			throw Error(msg, -1, ch)
		}
		
		obj := stack[1]
        is_array := (obj is Array)
		
		if i := InStr("{[", ch) { ; start new object / map?
			val := (i = 1) ? Map() : Array()	; ahk v2
			
			is_array ? obj.Push(val) : obj[key] := val
			stack.InsertAt(1,val)
			
			next := '"' ((is_key := (ch == "{")) ? "}" : "{[]0123456789-tfn")
		} else if InStr("}]", ch) {
			stack.RemoveAt(1)
            next := (stack[1]==tree) ? "" : (stack[1] is Array) ? ",]" : ",}"
		} else if InStr(",:", ch) {
			is_key := (!is_array && ch == ",")
			next := is_key ? '"' : '"{[0123456789-tfn'
		} else { ; string | number | true | false | null
			if (ch == '"') { ; string
				i := pos
				while i := InStr(src, '"',, i+1) {
					val := StrReplace(SubStr(src, pos+1, i-pos-1), "\\", "\u005C")
					if (SubStr(val, -1) != "\")
						break
				}
				if !i ? (pos--, next := "'") : 0
					continue

				pos := i ; update pos

				val := StrReplace(val, "\/", "/")
				val := StrReplace(val, '\"', '"')
				, val := StrReplace(val, "\b", "`b")
				, val := StrReplace(val, "\f", "`f")
				, val := StrReplace(val, "\n", "`n")
				, val := StrReplace(val, "\r", "`r")
				, val := StrReplace(val, "\t", "`t")

				i := 0
				while i := InStr(val, "\",, i+1) {
					if (SubStr(val, i+1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
						continue 2

					xxxx := Abs("0x" . SubStr(val, i+2, 4)) ; \uXXXX - JSON unicode escape sequence
					if (xxxx < 0x100)
						val := SubStr(val, 1, i-1) . Chr(xxxx) . SubStr(val, i+6)
				}
				
				if is_key {
					key := val, next := ":"
					continue
				}
			} else { ; number | true | false | null
				val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos)-pos)
				
                if IsInteger(val)
                    val += 0
                else if IsFloat(val)
                    val += 0
                else if (val == "true" || val == "false")
                    val := (val == "true")
                else if (val == "null")
                    val := ""
                else if is_key {
                    pos--, next := "#"
                    continue
                }
				
				pos += i-1
			}
			
			is_array ? obj.Push(val) : obj[key] := val
			next := obj == tree ? "" : is_array ? ",]" : ",}"
		}
	}
	
	return tree[1]
}

Jxon_Dump(obj, indent:="", lvl:=1) {
	if IsObject(obj) {
        If !(obj is Array || obj is Map || obj is String || obj is Number)
			throw Error("Object type not supported.", -1, Format("<Object at 0x{:p}>", ObjPtr(obj)))
		
		if IsInteger(indent)
		{
			if (indent < 0)
				throw Error("Indent parameter must be a postive integer.", -1, indent)
			spaces := indent, indent := ""
			
			Loop spaces ; ===> changed
				indent .= " "
		}
		indt := ""
		
		Loop indent ? lvl : 0
			indt .= indent
        
        is_array := (obj is Array)
        
		lvl += 1, out := "" ; Make #Warn happy
		for k, v in obj {
			if IsObject(k) || (k == "")
				throw Error("Invalid object key.", -1, k ? Format("<Object at 0x{:p}>", ObjPtr(obj)) : "<blank>")
			
			if !is_array ;// key ; ObjGetCapacity([k], 1)
				out .= (ObjGetCapacity([k]) ? Jxon_Dump(k) : escape_str(k)) (indent ? ": " : ":") ; token + padding
			
			out .= Jxon_Dump(v, indent, lvl) ; value
				.  ( indent ? ",`n" . indt : "," ) ; token + indent
		}

		if (out != "") {
			out := Trim(out, ",`n" . indent)
			if (indent != "")
				out := "`n" . indt . out . "`n" . SubStr(indt, StrLen(indent)+1)
		}
		
		return is_array ? "[" . out . "]" : "{" . out . "}"
	
    } Else If (obj is Number)
        return obj
    
    Else ; String
        return escape_str(obj)
	
    escape_str(obj) {
        obj := StrReplace(obj,"\","\\")
        obj := StrReplace(obj,"`t","\t")
        obj := StrReplace(obj,"`r","\r")
        obj := StrReplace(obj,"`n","\n")
        obj := StrReplace(obj,"`b","\b")
        obj := StrReplace(obj,"`f","\f")
        obj := StrReplace(obj,"/","\/")
        obj := StrReplace(obj,'"','\"')
        
        return '"' obj '"'
    }
}

#Warn VarUnset, Off

SetWorkingDir A_ScriptDir "\.."


; set version number
version := "2.3"

; ▰▰▰▰▰▰▰▰
; INITIAL SETUP
; ▰▰▰▰▰▰▰▰

; set image width and height, in pixels
w := 6000, h := 5800

; prepare graphics and template bitmap
pToken := Gdip_Startup()
pBM := Gdip_CreateBitmap(w, h)
G := Gdip_GraphicsFromImage(pBM)
Gdip_SetSmoothingMode(G, 4)
Gdip_SetInterpolationMode(G, 7)


; IMAGE ASSETS
; store buff icons for drawing
(bitmaps := Map()).CaseSense := 0

; buff graphs
bitmaps["pBMbabylove"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMballoonaura"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMbear"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMbombcombo"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMboost"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMhoneymark"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMpollenmark"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMfestivemark"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMReindeerFetch"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMhaste"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMfocus"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMinspire"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAHgAAAB4CAMAAAAOusbgAAAAkFBMVEX19hb///////v19hv///f///D29yr29yX///T39y/3+Dn3+DT29yD7/KL+/uH9/tD3+D7+/ub8/LX9/cD19h3+/ur3+ET//+3+/tb6+oL4+VX4+U/+/tz6+4f6+5P5+m74+Er9/cv8/bn7/J36+nr4+V78/Kz8/Kj9/cb7+5j6+435+nb5+WP5+Wf8/LD4+VoR+OGYAAAEV0lEQVRo3sXbZ3PiMBCA4d2V5F4wLtimmd7h//+74y650yXEFNkWz2dmXm9mR6MJBlSxzE8H54qBbtncIuSzUnfZ8AmvaO6CXqsI/xBTvSObG8IPcxt0KgP8lJ5AI3NB+In6BugzHOE/0YqBLt6OyzBt9I2c5fif4AKaJGP+f5h8E/TohfjFaAhaJIX1Ncx3HujgbPGbvAIN2FJ8D/O9jpHdmPC7MIPOsekAb1hFAl2z+4S3Zg507ZTiD8SBQbeMM+FPYhe6dYnwR4MuLwTyxnOLOr4QlAHWSE9djmwueF2YzgZ0pxphrWgFnfEmvD5MGxO6kuV4R1BCR5KxdS9Mi25GlhcASc+FgC2t+2E+8aALzpbwvjyDDrCDwAf4PoH2uTE+FPZA6u4C0PWFQF4AHts6rQ98TPEJYsnazXrOmZ4J0zYzWSvFxLR75XTsxwKfYm03+8Oqcg0vYapJw6lWh8k6ziPBCZ9GXKRB2PfH0zJzjRfyzPscch6OUk6EaohENJr1F8W07Nmmx+4VmVc/pHKeiyiP15PlcXjtM1Y7ZDCQxRYRHwR/+qvKMT7Xj9nlx5DWw79r8/EtEYRzvyjNa3fYjyxCnYgHewOymFC/QQG+he8QQkT4DhYIfAsBMcd3mMFqhG+QHsBbRqid2BsAZpGiZmJnw5U51ly2rt0/DL0zi4UNnwydM1sLF0CWB6iJ5V+7krHXVOYb2dVRll3n5t480VDma9mVMyuW1btyZoGd4uce/MjedVrmfdnVVJbd2vKiszKfZwzquQsLJQ1dWfY7KVNcya6esuw+4rRfpu2QwWPuxtLalZwNb7U7k91H5TVvs1vKrsYyhbL7hN6Zt9W9yO5T5TXX25Xlfgtlyo8JwBvK+ZEpvVRDDbujU6L271qlkZt/S5GMm06s+IqI5yuFm3/HasTYUFAphXt507BQWmooo6ZhXiiFp6JpmBaeQpeNeeOw0lqbPmFTocpa2zE2FgwVwk7YPDw4KoSHUfOwpfDdCJNLrY52nuallqe11pNamrkKJ3Ub4aDSfFLL0/r1pQ7aCPPX1/ok2gjTLnl1qQveSrhvqL3kqn+tjTm2YlRpPamldKX7pJZr3fpSUzSyHn9o4rW91IP+sdrnDz92Nto9qUU8tRl41S548MGt++JSE97Bw6XD4Dfzsono7lpn7S01z/dZIp/x2B/cSQ9WbZ3UFCyGXxaGuYet1dYl5ChqV3lzMW9W0SnCujTfsTaWWsxPBoNbSTYZUc1pbTY/qcV26tY9vzdcBNT4tDb6P65y0WP3nvayTqlurdWXmkaTLHn0vKe5qDmtVZeaAn9oQo37C84PTPmkpvS8Mp5cy9445OqndWGhRCI+2fAEueBf0uvn15rtOf7DZ0uXwSvM0o9I6VLP5MQ8H8tVfj69Oqek8sORMvi7yrvKAwXMnsZC4ZVvcy8+jsfSBEXMXc4sRBS+DS+wxzlP+0cDGkh641kwK2oOrl/0pFxoYz+MkgAAAABJRU5ErkJggg==")
bitmaps["pBMjbshare"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAHgAAAB4CAMAAAAOusbgAAAC/VBMVEX4zP3prf+Pvfg2NjZ/svRdmenATEznrP1Ch+BXVFg3Nze0MDChKSmMu/j3y/zlqvvvxf+8h89ZVlr2yvviqPhcWF6DtPVspe14rfGJufeGtvXfpvRkXGbc8/9aV1xjnutgnOpeWWH0yfnxx/ZhWWTYoex8sPJqo+3tw/Hco/BnoexEQUTowO3MqtBoXmw5OTq7vXlsYHDhuuZxZHU7NzbVn+lJi+J7bnxSS1NzqfCwlLN/a4dAPkCMc5WYm022MzPYs9yGb46oqlW9RkY9PDxwp+/Snea2OTm1t3TPnOLImNm2i8ZXUlXuwP/AktHEpMithruhgK6ki6d6aH+sLi5Ylue7j8t2bHecn1DCjNXQrNScfaieiKGVeJ91ZXqtr19kUlTEldWxicCRdptrY21hXWG6Pz/Tr9hQTlGYKCjsuf/rtP+ztWqjpVJOSU6UwPmOfZGKeY3AUFGVl0yCqd/Mmt6/idKlgrKZeqOTgJaLb5C3TEybPUHT7P+ZxPqGd4iCdISpz/yhyftOj+TOl+O7nb6phLZKRkrAocTsvb2Yg5uOufLJkt05QU5KNTXIps2qkK2XTVKFsOhmYGhyTlHI5f9Tk+bFjtm4mrtrbE03O0NOTj9TODjmuvaSuetDfstEd7vmtLQ9Z6FtgqCipl+AQkI4SWDBWVukRkhuPT242fxunuW0l7mnTVG3RkZeLy+NIiK9nsHgpaVmdY2tsHI5T2+kpmyQlWnHZ2eCLy/B4P6VpNdDg9aBpNLOdXWPVmqwVF6Tl1h7T1GNTU9fYESOOz0/MTLdse7n6M90k8HZk5PBwoZFUWSTruN3l9mbkbyNqLiTo6Wqd4mRn4JSZYE8WIGyZHd1dlVtLi5ektWZnMqXtcWgtrNui7HU1qvSiIierISLjVCuSEjJ3+yYutlfZnVtbVyBhEpdOzt+j8nh4sSBgbipgJ7BmppfdpbHyJOwuZGHiFxsWVqPs9WmfLaEfbLY2rPQ0qPBhISLYH2TdnhpbHLU6fXcs7OWZWavXbavAAAT90lEQVRo3uzYbWgScRwH8FaQnJFX511Udxxod+Axs9RkoUlzmfmU0xmucq6cq8ZWq42Wc4seoFoPoy0WWKyCqOiBCoqoKOg5eqKCgoKKngh6IOiRil71+5/OXUUU7ao3fRm+cfDh+/v95X/a63/+599HpVJ3R6Xq9bei1hVKo9f+FRvYWdbUvO6k2tvA/vO0yrS3rpKShimY1z5cr+31h6M7YKYwgil3JGKx1avn2QwUwVIdS9oL1dl/kOxf1kEXztNgBnso4rmwGXLBG2xsKtdgbKVVD+8CptUVTs2mUKeWcdAllQSXaKAV1RMHQCZW47TLZzcQ7JLhWjUy26ypxdmkNhQOU8k3aIK1Bci8GnBFuSZPQXobDUTH6qmz9oK5pJJiKRSWpcyplXqZZFMJgxmDgqKmekAOzsvDGxIM0VFXlzE1Rps9YbcZOYKgCpbLJJvKGMzmUeTBoLOpzoOQcTuHsSxGcOFENFThtfCueEXUZkCyTiUTTNkFNGgpDHIkjAFbHotYSBxXoOCCN1TOIlkmmInS38MKIcoQBrvPRSrycsH5pJGg6mZp5YENye9hQLxNxpgXWGkUngSHVVp1MjUOSWE4XJmQvmicRJhUJiM2lq0rVMsCczEhLy93qKtz7XgXDa80L5CSykKSwQqKh8kCU00WBVQW2YnVChLvQlBXuiLWGM/K4gkLhNnSlfLAWHkArOqJoNbUCJFgHIrmwtsZQ4zPbJ0UBBp3JShZYH17B8ZEEVVTUwMFfTZzo0shgR0cZ/OIfUlXa3oZLYQ0ssDDiksJwsHn9trIMAkpTK8Im6N8Zr3pgQOnuOigPLDKVDYDCwOVhaMGQ0g6apyPByx45r0pAwcObKUrOATLU9nso7MyHbHHvDisk4RzRNO4QnqgEZwW5IJVhSmNpsnbdXBpj4vMU1h8vgY+ngzFyW/hKRbZYD3cT4zkQEHwgKO8KWYzmkN8t4u7FqDGvEwwzLqtgMXMFaQEVngdDGPgOENUAtOtA2UdNVTeUEpo7A24dKrBMMMYw/YI3V3Ygia9YBkdlAsWDzYatlTmgw570OuiFTmXT4MLK+azn2OZhk0RxqTlqyPskqokbUkvQIVb6biNlQ1W6ZYXUKw5CZ9XaXIsbWlNw5zFwsIKhoDHQHlgWDOSjdEG8nuVFFytU6Ct6C4T4g5qRhk8dskpE4w98O3FT1qyKppz2iV44PGzdDlMWlYZ0zgC9FcybklnVbRfnrbAo49Mk1ZB1PpZbcXLUxoM4xwRQSrjyxZk1SnpZTzvTZazRGWJXiXD19O24uLilSVm/+jRtflVfoyzRcjvYGCntDZ4A8kmI7hlJrUMX08L/LWQFqeyT58+I5CssXuknyo+DbKvIpiMJhxmhsKgL7g9ZsOjx4CYDZJr/ZixQvqhgsPle283dzCchiUITWVBiUnbs9WitlJ2FKSPckytn2qkv7qNg3azhsA0lZDSlLW4p65+QxerHLV2UyZr146CaRP23FMB6QqEwgywM0pT7VYrqLph6h66VibDjlr7bPeO8wsXLjx/fsfu3ZvWjqnCbF4RxgVvMFHOobIFqQMmHQSpPXT3Mk5lVt3V3Lx/5oT9+x/v2rVwx+5nozGzD0fL9axAvw1gGFPXvtKk06pluRRWGkR3E1L79u07bsKEcX2bm5sfAz0d41bgcPnGG80shvmrqjTzStrbrXuH69Wqnl+DdflKqLt73dETJ04crQd55ri+9fX1qPYZPxvCFWTEwRHAtuSPceaj1BrL2vRasHu2YHZEnz5rd5x6cHDr1q0PdvbNBvwJE85OB5gOODQiO0KZPfdKZ4txtXU42D0bNMx5974HW1dBDkLlnDt27ML1bJSHvpi/FtiuIHrEmFpk636b1s9r6QOFz+88uEoKw6b7jR3bb+F6wpG0acAdo1Q6O89thJzrdOZss1Wv/V04PAIV3pWBt17ugmdOmtSvH8AYY0RuPqC33xw+5HYfOnzk9sYu28mVtelUv3e0zFAlf8e+U59gxQcvn4AdSxpP2uHHMHA7N4qoeyTKlVevj9w+1zkK0SNaoLT6d1a8nBmT31K1/syZk59vfDpxdGd999kSl3xm/fSqls7bh5Hpnu1G7v0XL+5fOfwG1RZLW3/lYlSpJVHBmU75a+EWIlDenlnXDGJOHtd86taNpqYwV7Vxe6ZrBv5w8eLFD6/ch9+cyx8FpZ3ML8ha09ThuUw1DdMtL4VRsoaww2akMP/6fVm0Hv7qb728fvzq/GvPL227eQjEbFBjkO9fcR8+vbETyb/QWTurZPGSXBaXFW+Arw1cOBYMeOHeMRLTzzZ3yTtvvbxzdU3v/oPGDx665d2916/daMVuUf74AsEj3dMmP+38lc7gpjoIlqI0KBTLzigopVhzY4RHv1yRDVEGEyujtsBuWdMb0n/oEHjd8uTea/fsTMB/df/jq5EAFyFZ+VNZW5hiCMpoi4WSyWQoFuYwAiMMoa7vDLjXxk7PbHnnjevQVhpEH5omBmyojY7atCKQzzmznbU/pE3WDsyQ2jv1Ag4h+YidwTBDrAFchSgLSQZg0b2zpfd3AblIDMJRpgFcNOfROSfqrEkV634kty2mNPZZm7M/XilIb8xAOeKkAqcFUqwcMCK4Htw1vecuWrRo7jel7z7cXpSzRRbJT0V5RItx74/GXdIBt+vm7p/rcE/IFhRw3uur8JA4SZJeM8Cw3uNr5i7dc+zYsaWLvpbXPLkH9JyiObkUdXdW/njRX/iy89CX4zAO4GGar6Nltn13GWOHDdPMaGYYRjNmM4ZmP7MhKbehua8plPsqlJBbOaLInUS5iyLJneQfxx+IvJ9n37GZPH/8fr//Xr/n+Rzfz+f5TBtvCvYfLMEsW6P9FdZYwB+IGhz9l/enjI9dGorhXXp2QcuWLTcvgVaTNLyeM3uO5JhMye99vv3/k3u62Tz3+m9YZVDxWEeDLndgrGP57NmjIlTqh+dW1194CC7i0NR/yiNnzpzZk2NkHxrvvbSg8dXqYezeuS1ORLUw+pToRPMYqwZGkmO9crkjG0wk/Nk1dP+LuTLrH97BvFq6GSri7NLfYjMpSB7ZEy5whrG8TlHO7RErx43eNgRPFTWwhVrCkybBlVuLfr+/6JCrMMLZYpLvnZ9dmYtzb+l0zcrwZoKZ1VHoEbrVkFHkkjxyMsHYwx7hWIQYZPSMmHakd9u/YXXOUU8KR7HO5ZqL27fKOjZsXTMbbiRtyVy8s0Gj0VfDcGFqZDKb1mbT6Fd/undakiX41Jk3avTRzRaLGQdCPFV0rJZXoXeG1cOu3JtKJIIRr0puiOSy1jWccMKUufhYJpNpFpbgBYcWSrBeY9P6fCExFNKCvnX3Acs9Ae8dcwouOFciXYzNydUZ1crx06vlbR6lhSymDdFYJBrNju0fKSSK1uUodQwnnMzX8zLEVEwuntVTy7BMGxLtzlatnHaiN9x9cBksYMin4aJ7nx14He9U3rHZgAtyVdu+9yqzYPbkstzfl6sMBm+skJsb9OPq71i+NRIw4vNUmEWwbsnZBQsWbEbCZVgbsrdq1ZqiFWiZJBO9F67JPXegCtOW5q0qT49F/D5WjnZDuo1XEp2krHnvmlPwB+fkafMKp1xwr6YZ1k9duBTBrgTbW7VuWIpWTlFrI3kmT+zLj5RKTzxMLp7m0FlX5NPG8as6V51kh6waAZofUwxEq6zRbNKr4M5/nXLQpmsH7mxgmJcPkVOnVsEcrVuJPtuG8/fOMP0WzalUfwU63DvXDj1ynVZqtM7UrWObSrltZ4n2BLBLMm3gX4pwQS1smt/k6GMZw5C0GpKxYROs8VXAkO0+rW3W3Qegnz9SCv6xinpo6l8f7V60FrDc6xe41rW0IJjdhQinKjU3im4hc3VAr0vnNARr9NrWDUU9El66VIKdcCvlEMr9CfTz7YIpxw2LnWunGxNJBS3VoGn8qt4dOnRoV5F2C9CLhEGgPamBBol2xOpMgzYdIFgv4/C1Hu7UcMZcalk1DNkpImmq9xvBElfxOonVuYJR+tORNqu7jV63bh1ePatu4aNXrpwI2hhEvUtHgKAaCR9jmFPGXiGGkLEUOluIKv03HUK9n46nrgHDyVwuYuWM51oEs3Hjxo3jplUt6Daje3TqMdGERe9ORx3ofhtQ6EFXDkwgWAeYq63R6Jr9hrUiwdUyFnVIO2uP+s8VOhxGL52f5RJ1CI/lr62k7egeDTpluvEsS8TDCrk1oEahjwE+emd1GaadmWnOuBamJS0CNgkB65/3oFKnJBnNh8PhaBpbybTeLSrupf0adPr44cN9zDKTK+VV5BNU6L6Aj92/hZQZpprrGZbGuMZFxgznDPUqQ9E/gnmL/0FFr78VL4Atjls6Nejy8cPuHx++fRTwXGyN1uF4SbeWXqh1M8gE808dL2isY6RcVWbU2enEcmZYVe4lh2mIcZsuJFWcOlqdePT8PcTr6CJ+5SauaM9+ZgSTvxh340DN16UmR89hX7ZpJRgpN5PRgtZpqncQpx3fC0xrDWBlGgozqWDcy7PbHZeeiIouwdP9Nzy0RwPAz/hueBWy0aLMrGd42LADd/Q2GD5beaQxr7S6+s0gi9is2ealpLXhf9PrAJtTKlYGBlzGQF6Oxyr63paqPrYOvb9qeN+FEwTPu7opg7hylC5LvYYNm1+Y5bNv6doQcnkPo5GGLNOKdqJ584CK8wJi1kkT2jOMFN0WT9GBt92gxR2jB1CMc7hgroH339wNeMa8o+vXrz/6gq/ETYY1bbr+Xci5rFHX1tqSjDKDRZDsC9ntKLIPn2SwfO688Vrpz8sZjnncKTQg5f1z7iD2UIXBapBb05YaeMaFEycAk1i+l8JtOv/9YbFho0bL8AUimtOVZBp8ChkvM44Ne9TSakKmc+bQe5XcEI2j6Ss3LF/jVXhzNRkfnLf/wrMLFddhrCaGC4dF55auw0VtSdagopLcDDb2FWalQKXVaWk1lZ/i5PjwkDtq9nJV3q+ugV/gavYnW7gTejWluPhOFJ2tnSGfr0QTVGlXsFxpVxFp/h3k4nHIGnOjwfsb7j6lcYPGO+bT8kFHC0Eqdo8mYCnl26JoF0VeLyyDZrk2dj01C4mo4h9u/1H0ZpH0q5XdVpThFh09nWiQ5/VtMgw9PC7ygF4IVJpiPVIG7cTxilcNAnStjOvVqz1qU8ArL2EcpXcaPsPNbh4rWKij/ecItKpU674Tek2gZEltgpDg+V8OE4zNCRO4PNI1ND7VSw49+a50zTHwuDq84YHJZN5B99DlW2eji59N11kEnIF4r5a2rlKt8VWgYLUCRq3tBGPFctK26qSZRBw6u+DlvfEmnD7oUh9L5QJ+jyeYKibzy9esWTMqEve7TIL0GlZd64NkcrJVMKbX+8N2lBpbJOTSJlWm2V1ydvMCRMuWgF1xfIUixaBRrcZ3VlCazJ5AKh6Pp5nduLg7J1xd61/t2k9Ik2EcB/BIBB3mweGfRLRSUnxZL1ls72JBB70FwtpLMMJLwdrFEnYoKFe9jIHyqgmNsYOOCTuE4GTssNjwpDAY0WGDCXkKIQi8eYg69P393mfMlzBnaHTwexAcyMff8/4eH5/neb++YLOWFr/fKPn7Rww2ZLHcOw/IoKs7OgN++Oz2vesDvc3tu7u9vIlpa+eDjvY2sG6b6QwMfa1Y6BjRDHv8qZQhv91nGSuhCnqQ5VrR2GbU4GaqFLmcLqwUJZdLevzIIRIEaz6ewFhPjFLJmx4TnKrC/o1vLPc1qqpala86nVdJPj/9oVrxz88/oLbvptPplXxgT8dOVW57MC7iZdacIfckH41nW8wVCze1ubGPyWySuzpVtZPWBjzjd0J++eUTmYV8PrA4my+hcSxS8M4VEatgzSU7XCTPZVs8pt4ScOoFGownM2heB8ewZNn7ugiG/B7dRVuc10sBMunJz67oFrj35v980zgUuo7+glzJeswuy37/5kSBZZpV3GONWpM2SPAFMMaEMv7lRhjeQ8HS/aPe+2mFTDXzcHvMMNxUthIubQ93Eo0eUyMomxYOJ61MHNbg8da5+/z0k8W03CDfGB8SQB3y3BpopFZttrK2tnWzGN/GdCb6UkSza5GIpmLIqcGMdPPk4gXr4vTrN4GSpcE1g6Ouo+V1h4LeZrqSzfo5KULntrbwcayYgDxIs0pramqy2zUtol7iv2UcanFarTpoc/lmaacI2I0tSx2y131N3HPhem0NqVQYFZH1cny7bxgjbQfMNmh63hwx7rxEL+b3ijG0FuD6LjJDpgvFLaThQCwkq2qEXEFz3REVwW8wPOzsAAy3UNJpLjVHrfW4XPRCjTaZsmzB11gmsWxnt2aLaIhddXZDDuwYritY/0t0VqYladRiYl1KT69EH5GcA/d7WI+MdXQvFvaK5DbIzbf6j3eDG7rlnmCcTLpKUxwL46FgWDbk+KG01jjWxeXyT0pTd1qP+V4A6l5fdd9QyJxwr66u+4as/b6nCsvJTOIQ266p2zulYgwsua/ExvB4uPUK8Gg0CpNuSfhY/WmYK4npyUw5EQdtHml8ycUzusHK4b9yBY7ArF0kTEHmyDEdD/uAm1tejiOJMncVLvUHnnvhnlAgT4quoyHHgFNyudxyvFxMZjKZZJK7avTuVHR+BO4JyjM9iiQbNkacUk4kEuVkjJZeWTaGWZnBC94YqZOUR2zrz3uUyUkx1/mJ63qs+p3oKp+Yvidse+dxPRXm6swRXeXAEnxKae23oW6KuERGNykiPXRGfHrpH/HZkNDUAGuXg1GbiA+vgpxqWinwvRTfCLpJ5Ny/SVU7y1n+i/wCM1Q12AqQncQAAAAASUVORK5CYII=")
bitmaps["pBMmelody"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMguiding"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMpopstar"] := Gdip_BitmapFromBase64("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")


; static buffs
bitmaps["pBMblessing"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMbloat"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMclock"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMmondo"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMtideblessing"] := Gdip_BitmapFromBase64("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")

; planters
bitmaps["pBMUnknown"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMTimer"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAADgAAAA4CAMAAACfWMssAAABgFBMVEUAAAD///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+X+QqjAAAAf3RSTlMAAQIDBAUGBwsMDxITFBUiJCYoKSotMDEyNjg6Oz9CQ0VHSEtOT1BSU1RVVldYWVteX2BiaWxtbnBydXd6e32Cg4WMjY6PkZKTmZqbn6GipKaqrLS3ury9vr/Bw8jKy9DR1NXW19jZ297g4uPl5ufo6e7v8PHz9PX3+fr7/P3+6QJidwAAAAFiS0dEAf8CLd4AAAyDSURBVHgBAXgMh/MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABLDs7Ozs7OysBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4f39/f39/f384AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABLf39/f39/f39KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUYn9/f39/f2ITAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABZf39ZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABZf39ZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARLj1rf39qOiMPAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEfSm9/f39/f39/f39/akUcAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACMWJ/f39/f39/f39/f39/f39/YCYBAAAAAAAdGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABpff39/f39/f39/f39/f39/f39/f39eGAAAAkx/fzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACP3x/f39/f39/f39/f39/f39/f39/f39/eTkETX9/f04AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlTf39/f39/f39/f39/f39/f39/f39/f39/f39qf39/eh4AAAAAAAAAAAAAAAAAAAAAAAAAAAAACFl/f39/f39/f39/f39/f39/f39/f39/f39/f39/f398LgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFV39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f38tAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABJf39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39IAAAAAAAAAAAAAAAAAAAAAAAAAAAAACd/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/JQAAAAAAAAAAAAAAAAAAAAAAAAAACnB/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/bAoAAAAAAAAAAAAAAAAAAAAAAAAAQn9/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f0EAAAAAAAAAAAAAAAAAAAAAAAANd39/f39/f39/f39/f39/f39/f39/f39/fTcJKHt/f39/f39/f3YLAAAAAAAAAAAAAAAAAAAAAAA8f39/f39/f39/f39/f39/f39/f39/f399MAAAAFV/f39/f39/f386AAAAAAAAAAAAAAAAAAAAAABkf39/f39/f39/f39/f39/f39/f39/f30wAAAAB2h/f39/f39/f39hAAAAAAAAAAAAAAAAAAAAABV/f39/f39/f39/f39/f39/f39/f39/fTAAAAAFUn9/f39/f39/f39/EgAAAAAAAAAAAAAAAAAAADZ/f39/f39/f39/f39/f39/f39/f399MQAAAANQf39/f39/f39/f39/NAAAAAAAAAAAAAAAAAAAAE9/f39/f39/f39/f39/f39/f39/cWwwAAAABVJ/f39/f39/f39/f39/TQAAAAAAAAAAAAAAAAAAAF1/f39/f39/f39/f39/f39/f2UbAAAAAAAFUn9/f39/f39/f39/f39/XAAAAAAAAAAAAAAAAAAAAG9/f39/f39/f39/f39/f39/dQ8AAAAAAAVSf39/f39/f39/f39/f39/bgAAAAAAAAAAAAAAAAAAAHd/f39/f39/f39/f39/f39/UQAAAAAAAD9/f39/f39/f39/f39/f39/dwAAAAAAAAAAAAAAAAAAAHx/f39/f39/f39/f39/f39/RAAAAAAAAEN/f39/f39/f39/f39/f39/ewAAAAAAAAAAAAAAAAAAAHN/f39/f39/f39/f39/f39/WgAAAAAAAFt/f39/f39/f39/f39/f39/cgAAAAAAAAAAAAAAAAAAAGl/f39/f39/f39/f39/f39/fyoAAAAAK39/f39/f39/f39/f39/f39/aAAAAAAAAAAAAAAAAAAAAFZ/f39/f39/f39/f39/f39/f3xHICBHfH9/f39/f39/f39/f39/f39/VQAAAAAAAAAAAAAAAAAAAEh/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/RgAAAAAAAAAAAAAAAAAAACt/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/JwAAAAAAAAAAAAAAAAAAAA58f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f397CwAAAAAAAAAAAAAAAAAAAABUf39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39TAAAAAAAAAAAAAAAAAAAAAAArf39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f38oAAAAAAAAAAAAAAAAAAAAAAADZn9/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f2cDAAAAAAAAAAAAAAAAAAAAAAAAL39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/fy0AAAAAAAAAAAAAAAAAAAAAAAAAAFh/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/WgEAAAAAAAAAAAAAAAAAAAAAAAAAABB0f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39yDwAAAAAAAAAAAAAAAAAAAAAAAAAAAAApfn9/f39/f39/f39/f39/f39/f39/f39/f39/f39/f34nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANX9/f39/f39/f39/f39/f39/f39/f39/f39/f39/fzkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD1+f39/f39/f39/f39/f39/f39/f39/f39/f39+PAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzeH9/f39/f39/f39/f39/f39/f39/f39/f3gyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAF2V/f39/f39/f39/f39/f39/f39/f39/YxYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAc+dn9/f39/f39/f39/f39/f39/f3U9BgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADUBuf39/f39/f39/f39/f39tPwwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADIkdhfH9/f39/f3xhRiEDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABhMeJCQeEwYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABzQaSBzyAU4AAAAABJRU5ErkJggg==")
bitmaps["pBMBlueClayPlanter"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAJYAAACWCAMAAAAL34HQAAADAFBMVEUAAAASEhI2NjYxMTEXFxcWFhY2NjY2NjYNDQ02NjYbGxswMDAWFhYTExMVFRU2NjYuLi4WFhYmJiY2NjY2NjYsLCwdHR02NjY1NTUkJCQgICA1NTUgICA2NjYxMTEsLCw1NTUfHx81NTUzMzMuLi4cHBwdHR0pKSklJSUqKio1NTUzMzM1NTU3NzctLS01NTUuLi4zMzMuLi42NjYzMzMxMTElJSUkJCQdHR0mJiY0NDQpKio1NTUrKysvLy9AZs85Wbo2NjY/UH9PctgxTqA4Wrk5WblAZs43NzdAZs05Wbs2NTcsRpI/UH44ODg0NjU4WbdNcdc2NTU3WLg+UIA1NTVOcdc4WLo1NTo1Njw4V7ZLbtVNc9g3V7RAZtAsR5RMcNcxTp9CZc01VbI1N0FBZMs5V7MxTJ0zUagyUKYvSpozUatQcto/T4FOctkxT6NFaNBBZMg5Wr03V7ZCZ9A/UYZBY8U2VbBCZs4/Zcw/Y8o2OkxKbtQ2N0NIa9E4U6g3UaRAU481QH41OEY1Nj40VK81NTctSZY/Uos4QWM3P15IbNJGatI/WKVAVZY2PVtJbdQ5Va81O1RLcNVBWqE/UINOcNI7XsM+Ycg0OUk6XL82WbdBWJovSZgrRpA6R3M2O1A9YMY3U6s2S444Q29AYMA3UJ81P2NAX7w1U6wxTqJAV55Ia9RFadI7XcEzU600TaAwTJ8tRpI+U5E/UYg1QWg4PlZKZr1GYbI3TZM2RHNOcNdAYsMsR5c2SINDZ9FLasg3VK5AXKxAW6kvSpw1QoM0OU1OcNRAZ85AXbc/W7M3T5pDZspLacRBYsE1VbQ2TJw+UII2R341RXhNbs1IZLhBX7Q/Wq84VKw0T6M3TpY1SZVAVZE6Q2pNbdBIas1BXrFFX6w9WKk0Ros6R3hEZcdDYr5DX7k2S5o8UJQ3SYg1Q4g6SXw1P3tOcdlHZsM/Xrk1Ro87Tow7TIhFXqY+VqE8U501SJI0O1c4PVEyQG1HaMo7SoE+VJkuQoUuQHfrGTkSAAAAP3RSTlMABPvhPArw6g35V+sSBzT01BeZzuFQGuSiiSXUIL5lNsUoqn9LRi+xdTuVj7DcxLijmUPZhl1/blCPb2h4qrxyD+XPAAAcX0lEQVR42sSae0ybVRjGHduAecO5C9M5r3Ne5m3qvGvpiLZds2GbtrZ2aZqG+pclrWmbspYaQkN6p64FnWkCRqpNAP8BGUoTFkjkEkaCbmAMMEa4BEOAwFicY4nPOV8LtStl04rPlvJB+/X79Xnf855z3q+3/SNl33/3lmTa/9bzudvYq8rIevjlXbEn734k+7a0a9PWrdkx7d5/6Ll7NidRblZOBjteGTlZudHn7nnu6f27cfLWrZvSR7X1oVfvuzemF57fmXM8qbhcsPD5q1xcLjf2VM7OfS/g5Nef3JKdDpu2H3j88dcOH9yRuXopdirFsITCxCfoiTl7Dz342pZ/F9C7su+8//ALezdvzsrcJmaLxWwqcUoqXJ0vlfLZyeC5INuWmbX54YMv7r7zH0fzzl2v3PvMw7nbaHRiPhSw+eyCggJyEfK7EH8FMJCFYqFQKBaXy2yFkEwqxjFbXEBxcMoKG8Ka8+y+F15/8qnsf+LU/Y+/8eiz27gJ4REX0H8IkVRWeNpsNl9tbm6+StUMOZ2O4eFqaNjZfOrUqas1NeYym5QtBFV8UOFl5o6nD2/ZvekWB972hx7bl5swsPBBpTKI2FFirml2VGs0lQZ7aWmTwWBosg95vcG6wOVLLRegloB3YXFxcXl5vNZZUyJDWBOTMiPzpUcP33/nXbcSvv0vP7M3c+V9EAUhLCq3lZlPVTjgxvi4xh4MXLpwBjoHRX+ehc6fryIaOTsXnp/v7u4ZHLuyMO74w3waronFfIQ/Nii4GVk79jz50NZbCl9GjImPoEkBdNU5XD1jsDcGL1+6BEfmzp6vav2YqKjo4zjlxyRv6OoymVRqXWQeZMsz47UOZ7NZJhbHRROhPLj/zpur4QfeigufkCsrLCyrcdYul9bBnXNwY6QK6uyUSCT5+UVFRfn5J4gYlhNFRTimR/IGHsTiEDJjJDTf3eO5slDtPF2CXFsRBuajL94M111P7dmbKWZ8gt3Ssubh8UVvgNgzUtUpEJyQ5H9cBIfAA1Gk2AH+HLNKckIgb+NwOCwFi8cymXCkUquNkfDglcVq5082KeJYXsCEMuuZ/dnr1/MXn86N5ZSYMB0rBRICJpkl8cpPJbwAdHhVK2Spb1NALFaXAmg8Do5MKp7aOD82vVjtuFpSzo/lbeaeXev5lf3Q01kZ0SrNL2muLe04A5OqOvPhDzVmVQKJAFJG1dpZ1Uky/fzIyMjFs9CckUqn06k5CuIbMQ54PF0fPFt2mAul3CjXunG866E9O9kQ/BWXm6u9LefO+5E/s7NMahMaklJQUb7AL5f7XG6rVmu9ePHatbm5yQstLZegy55AIFBXV4dHT0f7aM/UpE5VzON0ESg4h2TTRbo9C8NmGeoyBVsnjlufejqXJhXiZ3ZoLp+r6jwBmFVJiD1yi1wp99X7AHStd8LYNzk1SlCCQa93aKi01G43UDVBqGlDKGae9oFwyNirMrEYwTpd95WZihLkVyyO2SkjyBgrtp2qDp4Zac2PixuJmFxu8fm0kIoM/MnwwGh7h6fO24iC2i8SaTQaEXk8QiXSQHjoF/VX2r11ntFwn66YA8fa9HqTnlVsHF1wlMXimLMH9Wut1cue3OjSROZsajlbBZZVJL/F4iI8vb29OqNxcn6g3RMEj93eZKisxPWPHIuKIDE/Ifwgh5rKShQ8z2gIYA31PsS+zYTsn3aUcKOz5d6XH0he2Le8eWgnA1Vgc5ReqPpYQsNGkklucVmtVhKwMMp2e3tHIBD0DtkN/RrNsWMiypBKFFOkgWdLg6FrPuUsbHdZtV0nw9OOQmG0rj5/INkkuHvXob05XCbZZc7SM520FMEkucXis17sNfZNDZCAAaeUJA/CdQSiDzeFBTuPiAyNHXMj+ZgJJJ1yl9ak7l44FR2Px/c+lWyx9+DDWdHVglDmGDpTNZtPSrjS4m5owMjpm28PeBvtTZiTYRGQUliUAg1wpS3n84vogBa4tCp1R7W5HPEB1uYtN2Jtf3NfdG/A55YQKglquUQpr9dqTSZjuN1zvdGOBMJ7M4JV/0zHKoMXYjkrt5pMoetOKZ+6tXN/kgXDvgzCDJWXDQdBBbOUlvoGk84YmmoPDBmABJoVLBz+UzVdPucXMMUGs6a6p7qMXpeb+8buRKwDSHY6BUplp2vrzlUhrZTKengc6e6o89oNlatMR/6ljomGWi4qmSIod3cVhxorpEKa88+8lrgmfHxHDptIav5+OTDXSqY+uVvL0U11BEsNlZojNGZpwYLsHRM+v4Ri1euLdZ5aGcXKyH0yEeu1zTTbZTXVV3om/IKiIoHcrVcZBwKllQASrWRSOqiONQUi9XJafPxuPaI4w9QI7rZXErFuv+M49WpmLKLyCQT5oOIU67qD9n4R6mR6BbeMLiXFsmhZHFVosYzBEt+XHKvQsRThuZWodb6GLo56vq5Jc0STdiyRd7TXQnNe4FJxODxjo7kgFVa5eaZb1WWVC5QufIriSEepiFSCNGMdMwQmrUpauZRWstwxXr8qTYXFb14IKxRuOYZgMUuhmwqS8ZdeJphvCA5ck7fmMzEEFUt3xWnjp8KqmO5rU2itVi2Pp1DoBrwiQKVZlfa6gQlLaytdIllVHBaHo1tyFKYMonM60sZi6ckSnGKlP9tF9rruCZdSQELY6tPyWMBSe75fD6sPWAoFnGXc0qQ5rY4Y6rp7rXJJrGhxgGVaD0tcMR0CFkSw1MitdGd7/9DohAszD5HAp+XwGKzhQmEKLGHzYljPigoDt71RQyecdASPLBIr7cFLc7RiQUo5Rju9kHqstiQVFr9meZ6lWMFShz12kSg9WP2VaFV4L184izFI5bc0mKIXKh6sLYti3ZW0nJrHe+KweL1TntL+f41F/NY0DQUvt5w5d76zlcESWNywKoZVfZrJrUPbNyXBKiirHVSxYkL97Q23ew23Pj/HXo/FIjk2lHoDDBMlooNQ7matYPF6Zsxsquexi03iVsn3Y2peDIvG0ThQhxWE6GYn6fi1GJhE/QaDfSh46Qz25J1YkkYlwNxmWr2KqXuxRkyxdh66P1lulTg8ujgs7IGxMB2sG2qq7BcBDdeJS+G/iT5NQBj1V0L9/YZSJnS0iYJVCQOltFi1LF4cVni6WUixct45kMwtm9OjQ+ziyVgqY3jUgy2yFzsLsvMS0d1gJQ0QDZKon2AYSPOtkcjrvR6kG2raf8OmHP2S+L2vr75Bz4qXInQ9inX8nruT1S1ZxZJRlYCFTgu6QJOTU1OjHdiEYWNIRbeHTXaybaYswbolT0dHOzQ6MDU12dc3N3H2/AjJJjDFoJR+v6++Dd2bBKwrzvIUWGxp8/UI6+9YChZaBxzTRYh0Gc5cGGghGsVmuiPggTrAMdA9FQ71RUgbZGKit/faRavVZVEKWiXYkEfbcLRF4HZr9V2UKV76yJJTyl0bS8iumQ7hrBvU5pIrlSQAlpER6whFnCCtB6ivzwgQlUmrbXC73T6XC90SOXm1JG5HPjsr91ldYFKwkkgR8Tj5qdwSmhe7OYmnwi6XH5+aNmzw+T+ebe3s7LT4XPVWtEaw3qiHXC4L5Ad7K53vJKvZJBH4kU9avYmF4CWV0eOQpsISl4wP8m48GyvD/KhInwRwELHPL4cxAkYSCX2QAPxETIITAj825dY2PYuzFhOkG3PIkgfxNQarcHhJh9xKMJmjd/vI5fMTBY4YLXATpUQzxVWPTbk+FRNkHBu2JcfadU8G6bXZnNPGBCwIDTO922pBEjPWxOfNjVhwDVIici6XVk9rQWosuDVcyE+KteXtLC6wpDULIVXiezC/m/R6t8tnkUPRfI6i0GiRdML/2dlZYMlJl9DdgHRCLb8JLPVgbUlyt3Y/uANPCKXmxbBqzdNB1tbQQEZcPeD8fsEqloQWAAINj/ACRC6Wo+sL+/01sDY98vxxgnV6eV6tWOt0zop9+gZ3vTXqnR/CuLRC2rY2rQkzlkmhoCbfAlbSIMKuJ0jO88tmuoF1s9JTtbW10Z9xAWPeIg1Y258gNpaXjN8KFl2VJTUlfVjUrcLqQd3/gIWUXxOLPGOrHdOxbkE0Zv9WusFaG1uYIohCqeNKBJ9/AwXDI3TySYXFr1gIo5xuoJAGoesVYiGfvzYW3WWoNtYtXvE8WTSvgfU2m8rmWDJuLJZKN1ZdhtGWPIj3ZtI2M6Yf1PkNVeR6hQxmJcXKfvVh2gAXls1gU7ZR6UVul53sWT4tZrC4zx1IvF1w4OVMmvS26Npmg8RThaYdtoICipX1wiM33Eg8vJfaJW1u7ONsSI0gFY9THPIgswoYt/Y9uP22RD21J5dNVDLTo9sAKgVCUqw6GRobr+HH7t09/cCmJF9c2UGflTmmQxsQQ1D1nvwiNDZTI2MzytnxZrI7io+8c5wOxtO1S6H0D8bE+QqdhC8+/+693xwycewG/0GMwxv1AIOF7vz4UkjdlWaYxOmdo/7iu3ff/ej3CpmYTZWxY9fWZFi7mUJfUCDFvYy+/y6OwOJ18U5+9d3RvKMf/WyWRu+i5+6JVYfEiprFZlRuHh+MW0ikH0ulPvnVl0fz8j756JcSfhRr3+HtyW8Kv/lwBjfK1Twd/g/tKlbDqvfezcs7+tmPNi5ti2x76TEMw2TadP/LWVEsccmPYyur1PRTnfz8k6N57wLrg1//lPGFNN/feuSuNb9cc3BnlCu9UyPG3mqLsRhZ9QmgCNb7n34vZVOszbtSfWXk0M4MilVgq/00VJyuqoocJwUUA5CDqvD5l0ffy2P04Tffcpnl8ubHU36N8yATxwLZtz+8+9VJfAMlfVhdxCgwQXlRffSbE2ati0XjyETx1M+fffn5F+CKb0hxYuFQQAlrAUXS4xiWilf8Bcrnl5/kvfde3grWZ1//IV4fi3L9RbuZvDoNxHEc9wU33HdcUAT3BUVFqZCEZy02GB6xgVBq1EySQ9Ecgk9EUWPRi9iLPkvEjSftwbaChydUEKoXDwW9WD16Ef8C8aB+ZyZt3Wrq9oUXHkna+eT7+81vZtJk0QT+Q/qj0+pxgA0coQ/sMLUXOowN/3+F295y8L0dnTgxMHDs2rVblAk+faNX7/ORWFwLV6/l09R7Q1osBrBb1wYGjpw4gQbaBZqBYtOmCsmpT+wCOM4RaGCAAV0/DiSk1He6/TiPjkg1bXTUU2XL+COml4e9WDx+/Pjx6/fvX2VwJw4dQkOHuPZyFI6FGOEY20/NuUZ169atq1fvgwgmwaWfSIydfnHzAntWauzuKVHPUK7u78P058DN96fFeExVFJoMgAParVuswYGOYCNcwT8MA38QWBgNHBLhDz7eRWL8zMuTexjWguULI7BGbGVY/YOPhmSOFWOCdRSP2scEC7kYxvGW4sfjkEpPR8ls66dc8TP4tYdi9a2Jfspz1YT99BIO33stU6fa6lx4HELzVGgwzsRPgPg/7Y+E+pEJh+JD9w7zSc2y+SOi3No2aiTFSn24c1SOdRMFEpkfzJY/ELDE51jzMC2aNSkKa9b6sWx6c+7FK/mnDfKgfIUV+zNJR4fzFCtJf+1ZGRXEhTvYyHjg8N0zGlr8T1Jk2X1yJ5/qYyk/YcasyVF2bVqwn0/qX+v/Ecs1HOvOvXN9SWBhBrEl0q6V6yawuzeX7xyN/TfJPhGE4Onl8/tABbuW7Iyya/6GOXxYfPykIMX+jxSDCJWKfePzh1S4wNgahTVp8SKGNfjotPxPsHgX+XqPqvhWpmLnbnz6GJaIPdvHRCXXwo3secrDD4fcvwRqlTPKhE1LktIgQsa004kbnwf3Maz+6ZEFdcw80NPnIl4fjbAA219jiaKKLufqrqtpCj7CP1nQy01BqAaJ9I3Pz1LcrWisEfNGMqz8HQ9+Q/i+LpERJVlVY13GF0lRCg3D832/CPmGXhAVhX5I9y1BoGalE5+fHewZa+tYYB3oP/mYKJqu65oU+1mjoqQUNB1yaWMqdnx3gqzoRplY2Wy2JAgli5QNXVFxJvI9k8nUc4kHicTnwb6esbZtngCsPRitPcchpOgVFOn7kQPAhuGXHahcNgxNUb7DkhTZKFpZAb6YZiYDsCbxXWBphlPKMLMePLjx8dyFnrFWzRnJsd40S0JGaJJyQ1G/C4/ulQmxrGwJZlhAR4i+qwEKCqZQNW07CALbNAXIKusydguAhFmJBzc+3UNq9Yg1eSt/XvfZyzeCQK9TsHxNkb/KKxnRgRH0qInjUNYqNlzpazupKWg9yKWhXGDy0xzPc7IIoRmkEwl0xPzB/n28QERjzeunWPvyTwPaMlSyfFnuJFWhQaEypgkr7Cq4eIu+LrbAVEnzECrTBlSCKm0LTCWLXU7VzmEnzDq1J8kfo+wZqy//+B37gpxtCqQhtrEKNGcAZdNGczhczwiUnfi60uqmCFUWVBwKAMAKVaGXWg1Qs1BMnx1MsiXZyJmrJveEhbe+Bj++fS7YaSgwLb+AQsDmqEqjjAtGGHJhm+mcSblY6kiSyuslpULbSOsHiXS6Zps4g2Mxs0Kq80ACVt/YNbNG9OjWhdTgx2FSreGK00GGGDKbZKqyUWZVB1AtAasVSENWQSUbjAqBgsBUJUWSBVZLdXwppUq1blDOxG3T6JSn5TSJtfXl97dJvZa4kcjZzaKhsRaRV6U2VRihECtDU1pXFJdHMMcPVonjGa5RbApt2UGtHpz9kEIbDGvsIizIogtE+E7NwWcvX+nERhgeBGa2SKuhTr3KVFiTKDvYpBFDyxKgsEd6nk/QIegpNIBVx5UQeUWje3nPrlSrAhl6+exCMjRrwfL5PWBNXDSV3+c6/PGMppOARiKoZonfaHhOJ4Jos1YL7LrlGz5BMWj3tWazUjEZeKJW9VjdwBCFyFrAYqcQTzvzaLBFNZa+HxKtpcv5zfDkhUvPj0pGKYf8TCNpLcdB9253sFod308c3yi4rgGujioVgWGBCl6FZUV0dc8hFkTKekEa+ngu2aLCWz69vUY2k79Clr/zRNaKZhrRolwQo+KJXnUM1y0oKFYqSyfha9lp9MFa3Sl0BnFVdjXDhwxdlrXnWI0xjVsWTdV+tWYksHD77cVplHRSpyBBVWAyOVWt5LsSplIQG41YUW/LpB0lYZMGOxxKUiXJ1QuyBB0dxoSZmbVoE6h60/hVGK3h1rmHQxItQuBCzDI0PmbwgMYUGeV2lmfwC1xN5mYLC+eQxg+TIknmEzXvzs3wfcBds3t/yXTFXPbTVOrDsKaKqk7LBEoiw6rRIU5wDD6t6zih6ChOzdAyDA624DQK3aaJ7qvHJ5NJjjWpZyxM6Oewp4EGHz+R4nE4UbXrPIgZO6iXkFWK9K0RIvLFKCOns5CF1KbniN2w5NMvzv02FrRiFMVKHn50RqHO614RvZCKYILlUSjph9U7Pc8wPBQuo6HrNNm7KS6feXmqn2Nt+B2s0RwrdXH4qAwABblKp7+Y8rmy3P3GgyjKCCdzKf5LrOd3w9e0xm3/LawFI8PV4pXWbZiW2O2HiJWHiM0vsV4/ZFh9WLiO+Q2slWvGse57+O5pKQxSO1bdzOLsPS0cteGL5/tZLd2ydMRvYM3eMYOPixeH/vUdEmBJX2o5d9i0oSgMq7QlSV9Rm76b0iT03aat+n4NyYBlJVJrgSoHS56KrM7NwFAhWySNVBZkNsRSmQiUjYVKMCAxwMKCYCGgTnRA0AxMdOzva0NN+sTQXxGJEcEf55zre3zu4QrRoFvDsg1Chd6pOe37d2oRdeRYjNz8RrBeHDww4D4Cd7TsJtTcYkePVSnlV145TWCNH1ukSddnWULGOWIxlfLastOMtfY/Idd5FFELzOixxLQHibkZrEdTE8AiRVSHY1Tug9SBzElYGzOFtefadataQtwIl0RmYYRYSxBf+LABHw6OBXPZxlQs53qyKozQWrzg5RzelN7HTANrQD0ee6Fl9KUKNRQMSvBqjkUqS4xSbFQc2eY3PWHe+3hAKn22di6641V5KCxM4FvvBYZYi5PadYnDag9NsCZvXRoYC203hCtfknrlSuqX5vjjsYNTEo3EFkewhGKrJQlS+h2t3SDeuDwo1pE7Y3qzWTDqjXSnRIil+it+FKCNwrGDNWDxiVauVRQo/PlWaORaEhdL+rSMeQYZ84A6+mBGs/TyWjrGMfopOa7/6spEeBS3dnmN4wwVsYhcy+34OzKlWaveVuRoaEULrSvTg1KhtmvX3ej+1JQZloRGVpKy3MJSN21hHbxXFBWe7S9vK5LoRdKuZ0Ryx7+z065QxKFvikU5lvbp3wq5ctLMVjZ2uJFUnTdjPD6/I+It1usNhf2BxQjbnXpNcRndyr2ptToSz/Swav4dP8GC+GxFxDxtHgv2ujgzqWK92ghlFNVaq1sdv7+e4NkeFgUP+VsxzrFkwErU/bmioGNRFOIJTsySIxb/UfjsWdREA8uEZu/fI3f9y754gQMH876jfnBlVceiKEZp45mG7DBYC6PN72/wXScyXKKdazWEJVJzpVxSCZGlyXrsqBms/dduW8gNynI+o05B7OtGzr/T2ub1hQAHs6rUgVWTXUYnEiyB0lFZZitWKyociS2GE5tBH93tjrqKRN6ETt44blGxcE1NYQpiVyUYJ1f0LuzCyq7+Fgu/It5sltM8KkiZgIfu9d1dOGwKa//jm5NaX/HaF5FDKGURJ7maQvVq8xWCpfRhxUhsdbFIHcnFwOsuWUqVVVsta8a6Z9tvdlew52OLBMsdSAkYgLzYyQGrewFlF+ROzu/vAPmHXEotV9/mWcMzLIWwEsRqKfDOvdGN97E5VNtMcp2Y0YtdWDFDREV4qd0qZoHVje9EfTcWxW+3YT8D1hLLMrIULcexe81yb5e1KbSSmdWsfR5eJPWIKvJBnFNKiIZMJ5ItttuxLGPEorLbouDqNSpQCy6vVG2mYSlSV+7Gu/3sniF2m5uzalzhrxKlDnIGlTTwaWJdnFdUBI6ijFgu7RCPeDknizEY6qNvBY7rUU3ce44GN/Mav3tac6M7GOVI0gQ5dArwuTAD7l4UWnqLJX+CJFSkQjP9IRSG9xYNos89nTVNpaepKHZBtK8s8ihYoXmEdJA4VAFSdxVhJEhoGwGrIItSrBDNlJPBvGfF+bIPSvPgcNp3Wus2WwlmChVBEHjZK/AMS1IcdoHVmNQjhmMgQZAVEFWjmVI6Gfy45naTMDfIYj1n2oPGDGfqBdn6zBPazERTqVQ0VYhJiqxK4HnCAusI3qwiqhZKwUSbyUDoYzjsc7sBtEsTx+dssNXQmp2zYgrC+7vDoWA8Hg/Ek5vlcimTyTSj0VS1UChUq6korPM1nU5vJuPBUH6NbNFHdhbrmcrpJFWHc6ftJ06CamgdejRFpiCcg95YgVNW1j1r4Xf5/MdQMBCPJ1XFAyrMms/nWVedRgMBP31yIqas87ftF8YBNQIdvnwdUxCkdoG91D82+KD1dY+udeDSEEqb5DWLP8sycfym7dr0/pFtlfmMDEac7mc5yQNQDU/9gommx85ff/joRH+CNfxg1LH+rt1YtKrJU1N3bNOH9wzvvv4uf7XjGVQDi7ZYXlks2Orx4uyh0TKR242nN7FB5SA4L4gm5+fuX7169dGBI+MjRtIznBM3zs9b/5Vswjo/dUvVlTMXjUYaPdf49DX7DFYa/0XYRdd+d/YsNH0U4+7/6qTt9j9j3bYNMeS+A93wQM2dlEHaAAAAAElFTkSuQmCC")
bitmaps["pBMCandyPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMFestivePlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMHeatTreatedPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMHydroponicPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMPaperPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMPesticidePlanter"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAJYAAACWCAMAAAAL34HQAAAC/VBMVEUAAAA2NjY2NjY2NjYFBQUcHBwVFRU2NjYgICAcHBw2NjY2NjYjIyM2NjY2NjY1NTUbGxs1NTU0NDQsLCwyMjIxMTEQEBA2NjYyMjIuLi4xMTEzMzMvLy80NDQjIyMpKSkUFBQzMzMxMTEoKCgqKio0NDQyMjIsLCwwMDAlJSUxMTEoKCglJSVLyVg9pUc6mEQ2NjY1NTY9pkc6jkFMyVk4ODfi3hY1NjVLylg9pEc6mkRLxlg6nEQ8PTg5mkNLyFhI41k6OjhLv1fg3RlKyFY8l0Xh3xbj3xhJxFY8pEU6OjU6jEJFRjNLx1k9qkg8o0UzNDU/QDQ0NjQ0OzTk4Bfi3hhLu1Y7oEWnpSjd2RtI5Vk+aD9JsFM8PTXf2xpI51lMxFk9qEc8oUZLwVdAsEs9nUY7lUQzODQzNDNGvVM5OzNKuFVCQzRSUjBYVy9Iv1RJtFRCs007VDubmSo+rUo7kkO1siZIwVVvbi6JhyzOyyFH51g/bkE6Pjc0PzQ4ODNCQjCrqShBrEs8Wjs7RDdfXjJFuVFPTzJnZi6xryfT0CA6gkE6Szg0RTVJSjJMTDCBfy1Fkks6nkRBfEQ5dz87Tjk1TzdVVTCFgy2QjyvJxiLW0h/a1x3Y1R09PTF6eS1ycSxI3VhElUxAeUQ6fEA2WTk7QTaUkipI11dEtlC+uyXRzR9I4FhLzFhIrVJBdUM/c0I3ZzuYlix+fCx3dSy7uCXGxCNFmkxEjUlCgUY2Xjo1Ujc8Rzc4QDZraSyurCc6h0I4cj4zQjRcWy9jYi1fXSyNiirLyCJHoE48Xjw7UTk5Rjd1djKfnSpDr045bT02Yjo0SzZrazFjYzGjoSnDwSVJ0ldDyFFBt00+Yz9FRzBCikhDh0hBhUc0SDXAvSRI2ldIz1ZIqVE1VTdHpFBaWjJG1FS3tCZFzFNDw1BEs09Cvk48ikM+Xj6OjTDm4RZH4VZHnU9FqU5AgEVI6VlHp1BGnU0/mkg8Yz1FpE5DTzNApUpQWzZAkUdIpVIY5RBAAAAALXRSTlMA/fnlBBsI6yYV9tQg8u/cEc2zUaOGC8d/Y8CNarkxPA2cc1c3rZNJ0yxfQ3heFxtlAAAfWElEQVR42ryaCTyUeRjHo3aVilbp2q5tt3bblpiMGTMWOzMyykjOcSxyjtu4r3Umg5wbkitkyR2VKKkkEbolqSirRG271da2x2ef//uOwl41M/b3iSHz8v08z/P/Pc///77TBNeMmevnr14uJabwF4nNXST78fp170/7vzVv5ooVn679TEpKHKeaLHHJudIL5s9cNe3/04xVs9atXv6ZtLSUGJGIGBQnCP6DBB9EopT0mo/n/G8RW7hSVmaptCQRhBORSAqKJH1HRxIujA0Hmzt7zbI5M6b9D1q1frHMdESES1GP45iQnn7sXsOFU7tPHWwounfsvAFHTw/FDJFJzv5w3bSp16wlMhKvkRQ5nISGU/tHX2jaq0T2jAyPPIz8VcXed/+Fi+mOHD0IGJLE2innmrdi2WwFJBIQcU4fazh4sovRXVJerjFO+UMMruapotuOHCxkRKm166Y0j/PWLVs+XQyPk37opaL9vzoN9JebmZlZWVk9s7IKRv+ePXsWHBz8pH+AO9qQQMRTKSX7nigxJrvUahkodAWQvmNo+m7EpAEQAGNmpjFBABr8ZGjnaDoJj9fsJVO3HtetlRYn8iN1cTRyON8KAQFReX7/0MB1voZHRkaGr18f6tew0mAUHOPgJrZgysL13mIJ3KM4oQ3xXd0aVlZmZk/yhx6M9HC5drrbVWww2adSXrx4YW+jazfcb2bWPXpJXxEL18cLp02N1i8SQzaln1C0+6cBjWdm5SUPrg/3dKk4bNyyccsW+LQRveBC36r2DAVrjJwKJZGQTayZM21KNGu1BBFc0zF99y/UfDOonGE7G4rDRt+Nfy/gcuCWB5e8KHLEjFX683nTpkLzl4oTgaqowKVbA1basI2DLz88/wimm29Wzrx1Gyt78Q+mhGvh4rmo2NP7aN0Qq/IH8hCO/1JkvplG990QAz24UEHsg8+nYDWuX4481OCCBasCsPJ7HP6DCqg39JRbaXR7FoZygAoks17kVPNkJVC5t/9uq0Qu0YAc2kP+/p2KYjdkBliVVb+5u+phTegLUXv9jJUyKIWOIRbqZPIA5KZ/ZLuq72SyLWPy3aBqEjkyBDVY3v1TYUfNGX20GhXWijqLsz6cjrAS+oyNjankbug35f0PelI3OPj6voHZCN/4OjhobjDxGbkOTUkD3lVSAVilgeEYl8yKGaIN1ieLkI8atKX8WB/fxSR3P4G2Bx15uMeHQNH0dQAWTQpFVVtX16dn5PqDof78J2bBVmD/3RVKd6sDStnNWNOW+gi4RGrw05GTOnq9jEprv2kM5ZWvYQYuX55fMgSeCi3nAdLAUElJPgTpmRVQm2nkl3STGWSLwu9jSwP09VC4pBasECXWykX42PBNePMVV/O7VPWKAQQWHIx3RXgZL6xvl/eXDJDV1eXILk/dmoKSnfFpVWLxe6I1eEUYi3ViLnfW9KbVUeVAAyXl+LCApIGr/Ek5tO3+kpKS7u4BspySkpK6nHGfGzuuWAfzCDCvT0XaDaHeSUl5mX5ZTUmhN23JSqCKbvjz/flICGTA6YDHQEn3QAVZboI8+mJqWmsSN/MnwtWzRFdZUlBZejrJ13JMtfzcGutd5FAg5MgVZHIFJviC+uvutqpfbFF8JmEdfZV8PzDXGRvuieJL54vKSVdLi6Fxpjk2+wdDrcPR31WBecmBEBtgYCLTbv0W/Zt5HQ3xThDrxzT3q5lJ4blhWLzmyoqmNb4/H8wBgvVdXitdeZNhKc/VfFAJsCaKamHOqwl81VZAm4ylZHGj17u00/tsBgmfvESTxoVr56JuSEp8HKdFLyu7E+DqVfAXLLJtQfuha3dqE1+es57ERXapf1WcZWkZFKijpyA6rnlriAiLE1OcQ2/1LmZ36Ow4+lcsl+rztUGmd/b1htylkif+iJbSnryXbmQaewY8FWk2jDjCG/xS5KSkr690ZpmyozPyOhKdn1IZk6iYg1HhmaZaprEnXlVbTOKy/iOKF2upbHknAK8uoviiJULH6z1ZZPB6zlcCM9l7rzb3Xu5Icv6WpjQJy+NoWnQE3VA5h817VejJmlhcnuZJNYB8nwdYmMRnLxM2XjOXomUYlpEZmHGm029Pc0ByjEGV8WQsz+rjtUeMlJWN4rybvY66MMbXF/j8ruQgeo63exgRHZmgWWK5sK76yWcoWOF7Yms5vZlH7rDZNW5hVS6siVRK57x0anI2bdpklHU/OSmqznYCFu1oe0ApPedszDadRgP+/n+xcBuhObISRAiWe0RrJ+9ERI4RPYudQQypnFg+ZONbx92uZtHpyqaxmY8vHzcfZI3DUrIu8Gphm5Yl936f1/wdWo1oxlk5QxiqxRLQdvRcO66ym5qagiyVtUybMojmz1kTsBg/mbtefhwRRDdq3ePW8bjlOJSX0hss6mBb4tmcsrMBmewOV/5JznRwVWEGGgWEpdPBc9vHvpZtZKRFP+yucOMcRGt8OFLSkzpaWryzsv3yEjMeP3ZHw8/4YIZsyyuzjCu7lhnz5TcKONeilYKPqh+DwYNI29xcv3LlsXO0jLS0rrWQHhUwyeMry6JK50pHjHNArF9ERF7vPr89iVEpNMabN1BTvE5cs4Tl4J6741E7CW9CMp8Imsb3ZXGDd+u4nPQ1MfxQqyHd6Ie9Z8K8YIYYl0JqgVfGnhM6ubzAE7yrTWe9gw4H7DAftFV6jcWyMD/jF3cn0z238WVK/W3+6CU7R1ArXUBE3ZD0fWZE8aHLvOQj4AA/BO3blnaL9gaLzDIuNGiJKK4NrEnODQtszcoyzWY3nw+pZDFeZ9m2/rc9mYdiNn8TlWJ819xRUVGo0WshYCHT0uHV+B0+fLg0znIT3TAuWef8U2vyuMr6pW1bXlBcUFYZm9fSmQWJNiorjrnU50J+/RbW0VdJvbnfpN046qJOO5ruqAgpIM4VdFJdJ4NN8LvStiUGdB7JMaUbGhr+kJUZ01htLPfamZRoN8HhTQ2VlbOvdRZHBGkpKytrXavVafvRmj/kwHvroo7vSnt567kxVY5h8e0lEpxFQbgEG71WLZYGzyJdqr/l1ejqVhu7Ny7H1NQSCnezuYX6GBY4fMiOQ63QeLT2etc2t3hnI6zsiJYdhRbgEnwsi76qvjoLmjXMjjADFSboofqSXC3YCC+D+o7BhecuKVGNzr0t+/YUd7KbIh5nbL7xZkwgM89FJRVnaylvMmW3JH6Zy2uCwG0yCsqMSUuxlRuTrYuFC+zH0UUslu3gQbTjIHK+EMy1sNkh9OlDD+OCkF2bN+cmurlHX7nSrLP50Tgs46e7TvjRlZU3lQVu++rLzeGH7lhCvOill3eYP6cqYXmEDyUY/5GXqDOduF1dN9P1YS3qCYN1+6Qul2k9+G3UDuewzZi+Ol7lySCPmVZlW/jZMsgbPZbnTHQOC9/nZwolaNSarHO8nqbOYo2zXRaT6fFQN9Wk6+cGjqJwWJyEeHndA/5Ul4Lql1FeuKoGreWUxsbSunb3CC0tI0M6+4S7W0ZzXkQZ3Sin9X7NZdcdMABRqWNQ6kx/p50PI7VV1VIjC4qEjlboKU1tXa4Hk+Zi8fzHghRQXaW1+rgu/SrvjqWlpWn2Xr/OzBp2aVDQkcNXk88khp83P0dlMPhvk2MxPbi6BHkTipqaquaFBJKQWAqOl3bbq2zX5Tr5U61taZjG9WGyRXXvPnZp6WG/2Aj2Ve+aGu/iWp67W+K2b9KqB20ZY9kDqAM+BBsTe4raBjX70WMQLKFKHkRK32+vok3Q9XkIZCyoXTKZ8aZe7ppvS4rm8XhXoqObW6K/d8+I0XEmOZ6/8W1KpS2Lhepcneqxk2sXud3GnkLZAKJo7k/QQ1higmHNWiCJsBQdj8XbEAhAFsk9sNPDn8lkUGFxAR0ZTcT1bcedw8LCnBvP79qV1t7u5fXoRkhV36AnDZwT65i0A5GQPe2tqhswqaVuvNioiA03SwTrPUtmEzEug3snbQjy8gR5AkHXjnvgwM6dTv7+TBDUjrXnz/Uh5ubmIYX1t2713UxJKfh5sNLFGqABXI4BZd4F18HVNnwsVcpuqCyQ+JqVAo5bH0rgg41B0UkbbXlcBNB2XbsuLhdi5+QEpWbs6WnhaUwDWVtbU0EsKgPEZPp7OHF9tmPXqKiYqGpiWCZbigywfexcgW+4zAQuPF4NJ21QtDAwFRUVecS2HfFFRtpxuSh8TBAQsahUjGfngR47SB5BXkUe09ZUiiZeWadO48cREvMF3/fI8rlCG0ZVEBZfBEzAp60tj+DgGNDHxw7UZYfk4xOpC0gEbW0+FEHbhLIBYampnrxHwgYu8aWfCLEfw7aJ8ItCL9irECZhwRf8+IHQZ20CAXvBAjpBUPAYluqGC6GKCIs4Xag9/5wPgQukDzaBGP5VCPVvpWKihjKoSbGPP6aPH8AtgvNK4bhwm7g3upUgIBYEi4+leRHtFFGwFkOwhOL6SBxhKZ4+6PAfWCCotb8Rqiy+k16CDCItF/pwd8lshKWgf2m/qoBYY1ZK2YLqXeh94phNzMXTWDSKavzdpZKqhjspZg5Yaa2B7ZiwWrkAcZFgNToQBMDStoHKwswhPt0RfwJn+XxR3Gf5ZIEUsgk0TMgLgIUvQ4r9lgZH/lZ/2fuiuRO1CEsj6Vi8vfY7Y8EyHEshXliS0A1FolmyfJcoOmnyrnlUsQEqNTU1+/h7JL45LFklqntRa8TwJnTxncsLliGG5XvQAH9QSVJmhcjuCc9fLoa51+3dlHfD4hu8mv3+dBIsG8CSXiK6u9bvr0ZNmwTldXKrIO6QOs7f54jyLtkaSbQa9U7HbxWg4FXt99/mYFiSH4mQCsK1RAJbjEV1ke+EZYI5vIlDgwHfHL4Q6a3hhcskgEov4VuLh/hg83ZU+KCVqvvLqQRFRZFHC2peRhKwOPfO+XvYEeTfHisV1bs81/hc29jTSctWiYxq1edLsQZ0utqFSsW53toeNNW2cv1pdY8McC5xmZkiK6z1y7ETOE5RHU2dQXWy0327NBLkt8IIrxrpBMdNadHNzor44zaiCtestRKYmzYWuqBDBdiQ2hHepguh3T1FVX4ns6KyPTewJiMMfzppnYiw8A22on5UHZOBn7U7cWETwR9J/21ctbE3IXD9GRWVXl8H3k/O5WCLUVR++ifr1hrTVhmGo8b7dV6jznu8xhtLzyBiPTk9us56OjlbW9uU04DoHL2BFLu2oaO17Uqb2rIgtrSFNkwhQmQIbYEIJUopMCBOLsnYxSWLZImJM9N4+6Hx/U4LlIkRhi/hB5fC0/f9vue9Pef+LZm+H2Bl53vC/ZKDb1WX/sfhh+bn9dJ3ocH+rNjG9Cakvuwi/f8J4/0PZWJITDZIlvbBuBBNhj4FoRvqBf/Vdr316X4hDrDkbYb4fIzOTB+2QLL+3+R3SppZ6CqE0dayQeucgVaKOkaWz3ZBV4v6sVehgN5W/e7B8p04vAvYgw46rKHhUWVmBft/qLluux6l6SLG4aBsfauXvmA4XrgfoFVX74KQvfDKK3ufe3Pbq9tKq6Hf/r58p5CDozV7QcXPHo1OEerRACxkdz1+52avISjKUI+h7TE6j568eEcOBgMHaPErDh5/6+0P5ceOff1eaXV2tsPBM9oEYUHFyaMWY7MiEWvJzwgiHrpys84CdQbcQn/P/PQie7jWMJh5Fe7cX/zzUTulHvz6j4qdMG5avbFurartDXbo05qivEwYN0mqt7CNTxEVGGu2Otq6Yfe1puEvc3j9VUp/IKAZPNKFht25xinrq6qNSaMpLQXHlCXVBzZXmN52H8vvsy5Soa9rqVFxct2Quyjj9U2YT9Qngmnn5OHiEghe7k9Lxm21M8YTRRhBZBewmxOG3/LYTQiWJe2GLXiSkVfia6JC/1jexswMKxSJCOVpgAUtZ9XO8Tsb4ZjyMjQt2L2PJa8rHttEr/jgbXexgoOUi+Qr4skhOYzk10QlPFvTJtDo3PztsuEk3ThQ+UzBKtBnJwTOGUMyGp11QmpEduNjN1x6jr6HnUC0pDtJmTtuUK4NC0KoavBwvYGEGNYsIZ1f0NivysVVgBfLBRaDfn4soW8fFSyVOJfqrmseugk5q3bURbpd7XNR5UJx4cVRZJcnvD+rCCoaV2wHI4MBi3miL0ctARSsAmfWnVHwyeZEk3df3uYE2LfdzDKppWlsTFfnnxpFsDhrOKvswkKbQGttRqh27CD1dXSbfLwk9zclDR5scVj2I98kNTqLlvTqd17iVITVx9f6rfPtIwLG6RWs5S3YRp+tmRRo0p3iHSwsUWe7T2BvqMQLcoD3V2EaXUgk7ogtUs9ncF2qAPspNu3kARtNR1u4XDXNlRf/82wVcCobBjGqPkGiHScCpjgTo2qr+nm5MpzxHwRUb1AkOjOlFqjp2vw8RF5br72kCTicd+Qt5kRgiuFyGYYrr1yDSSWnGgnacE4GqDKwtsv0STUBa8ecxXBlN4T5HCkaM1IWQ8yX0bVcUqV69xa2kwYKtNRHWgjkrTV46+WyVhuXGZWGSVKcxUXKTNKUYHBAlXv8TnsIn84NAdakrB29bEWIXX7rAxt31kPXsTma4BIn0r0thHrWb5ZXCtc4WG1cX3swFFJkYYlD1oA04FPafs2RHRSOL0AUE6Jma2zOHTS2FGVnSnduuMy6GVWkuzFCoI5K65WYxeAAWIX/SDoDHoLqjQ8bdZ1iPjrx2xX6pNfQPuWz13RB/bCUzCsPt9EpF+je4u4Oo8P8Tj5L9vds8HGIa7eyM9Nar3ZRaxgOzsUM0XpHW83FQcRLfvldQKeG9TGLFjhejHRJpjRFWAznZ2jPobIVDSPvpMfsmwuDBOBMvW/S9smBffkI18ZUQFdu3YLOexHmr2+fPheSucfmO6YdQzWqi5WSqoFGzNkUNzoJ2qHr3AEWls4ycBAj5zWIvJa3j4UXJoYsTW5xOF7vFFSdOjSRmQ1efccG3HXL1uxzRph6ds4tg9NMkmHpCqzci29m6ly6RYYgaK0utF0kDkaATLjKGV3AOwSavGXZQdeRNro+0eyKerlmeZfkZPYpoEc3UD8/ft9lWJYcLL2dYrjz/B9lCJZktXQL1q+DAk27Ptli5nKJlqRLRsqGU0oz4NL26JMgfJEsr9srTtmZOqvLQJmHJlrL8OKaPeya5b4NFIRPo3IGPUOhZJQxkxhdL5FsbsTeDbAu0kly6ViHS4sBEEZjdOmlelfaz8BXdK9pTqucGC9bdmxrI+M1GChiUt4nwTllJ7/JjOEeXr+77mD7QoauVXKpQEiUgTWttR9ZBasA/04+xCzOhVwagAXsZu1JOmaarAEKE9TuS5pMRu9kd9fS3cXPyu0CihJ4usd5QrxAeMGWj3Bdd+sN665J78VAX9gyG9Myzzt1ChG69qJwj3/yCO+zVfK7gUGBOhAMD2vygUe0UumskmBGpPpIMmkwNJlkHVHac1qy1IlI+o+a7R7bYZAGIGb5RV5bhJQHTzy57hx9O4blAaCgLuWP6BV8BOvHcDuUw6tglVxYMNMpq0IWj46Mjtal53UaDGO00ubgfMLkDivI5mktY4Mw4hwEC+Q18pqGVhU0dXhJSflPH36FDj3xxHoP11Vbr8eA3v0609i5+FgzuT0Dq8k5mas5LcBVDXbC22Tii8NjiUQi2NksTVFqX6SDJBWkWCTi88mg0WLv7noZz3KEqlIl2Y+CuhNNfd47tid/A7BAucXmaMtIwBqUIVeRbBDTPs8AL7dY6Zsg6JRegWoZMECR6IlMGfXwPjJZm89XuOpozyk44JlXsIYkJAerYeTzyud7NuItECOxyxSP54Sj12qSkSx3i5qNXmhfC1bKd1DBYj5wFqoZkJEhazoQqdeHyaWUTYpR6fXDhZWKEGeT+8H3X3/z9WdPf/T8BmCBGH0LBqg+ajg9sadl1jitD8pYRVmAqupfSb4c3qEqgk5CoZw1kcxl0Dj8zti57LdQ6MmOqBoqwlxJKGf/p9Wvv/giiFreyWOD+OR6SwdgrX0Hvuzi/So/StO+OqM0HoTmIErbWldgCYtr7AT0OuCqLCx3wMtwGTNlNPH5S5UX6Jy1hO3QystwYdn3u55947nn9n78RX7+bpSt1+mta7agvuKrkxXPlBX3L3gm7ZRvtDfQa9C05Px9uO6NXDo6rwCXIBOLFWdSXGRMShrmL7uQH4xQ5ppi4dLLQANU+iaMxfe+dmzP7t27YX9w77XrhMUKmT84xINpjKTr0OGJbw/QlJdS0wJbK2+pUHn5r4UhxjEXFi05ix+a1hAIFmGJJBQIF/pUKNzTi1hVa1lBBlT58V3b0I74pb0fNuYjOsXughJiA7CGTqkqKspBJFP5R+vPcpC7mduG0NMDyyfLA0yKwrUDDBFIMEoxCJbSEutABTQfiKOzQ6ozLmKQHYDvODhMg0uzm+vXslIb7FZw1vph5e35/bf334JhHkjpSlS/9Dd01zSc7lPh2QKKIzllV2ragyZUXpBiMVyJzvQsyHm5zpm0q1Mha3YH49Km3uisVktx2+SVn4GrkFwqi2ovrKayzfV6y/kb7kO0lf/B169se7X0eDmUTICMV1wsKSkULl+niv5BRjNlTLfPDbv08TPz8GE9b1j0OmfOD3ecG57TNdVHtRalkmEEtdzGAR5nJ8ynYSIOqFhnfX4g46y7HrlqvbSFpJ1I2/kxTEW3VR8v54HLhDhw4orWDy8cr4IqQW2hfNoRhyESicUi9ZGZRb9jdiZqSI1oTlhomvm7l7P7SToK4/jQsgSkLLLMl2ZU9jY1nGMQ0rz4Xagt8scWF9VF1A9qtbk1mTfJRbluiIsA+QMS3LypuCqpC+CytoQ71wsX0ZXLGy9srbX1fc45mS414Yd958smOr4+53DOw3k+5xno7esdn7i7EFkcHX3IMCC44sEqyDKDWo7VbnqjbuXVAV+qu8Ns7bgG2O3h8NlzdMBMYORvmHRyorevr2/g6tUh2DtPen/+DtPQ0FDfwADm/9T46zeXPyx9WbwxgkNV/I8oxZJsCNZN2KJT5xLOaUQROJBUzIyXuXZhZPrWKDAonBpDzNb1z5N3X49PjfWOIemDvT4SGSWvY9DU+MTC85mXL8wjF8iTtYN4qU6ueF5mL0Ntk76k6mEX6WYeoJuAVK4BiZqbu3VrFMePOLui6XblxcuPkXsLD+5OjI8N9DKNTU0hQq8fPQDzFpn59POb5z5Z6qfZQFU8PoTSIHZDfltkb2l3oQ5qOLjl7bByWwgaCEF4myacbHgUwBtBjLefLj15/HJm8hn0/NmzSSgSicx8eLL0fXGRCC7BVDk9HneY01JQnOfxPYamnSVWNatZuEJxBb5WiQ7fR4BqzU/PgScbhsXhS5emp8G8vXv3dH7+Hek+RNyZIFz6PQQsIlLClV8ES6Nr31Zi5eKolvN3g+ZlO8vGWAA5jgeNMN3HBAICh0/SypqLE4sCyM4/8kbzchcj3tp2llrXPMnALRAsEp6BxnAtHIo/4hQPmleCZ+KvPG633SE8CTm6Kf0j1bfXlFzoadGy4vTbqMLYvrA97ARVxySedl0SqN9Jv2B1uhVYWu2J7YYxXiA2lHEcuLtxF6/WFYPAFd0Okv23PE6kcVx/WaPp7YbCdrzu1tLXlEss8OUQQHq+eFlcqcF+cz9xA/gQspG3MMntdpJFq4gjPCmKAkM0mxxrmbL5RTUdu2FZxJueZ/TEuXWYneHO9QQLCmLDhQhtKAeyP3Flq95U3kmz6MIiFzKKmehfqfNv4YclSOq0BQmHJVU1bVfBuZ1hBIuHYVjr25I26c7WLTIH7IamskGkNm2PoIdRxwQto1reTEHmYFId7h+V78vQwzahpN8KeEC1KylIvVos5Mp4RA1/R8VE7PWFzDdCLdTJ0fk14bLw9V3d9f1aonSRg8ixoEd1tBz+2ayYWC2qUEoM454qFi5Xyu9RGy1vtCALLumAytJ+Qzt8UU+tUMZmVzmEwaKPdw3TqOdOa+CLlgncfbCpG0UkypYuXiTAFq1W2xp5Bu3K+RUVpmwShlBm62gLXKlXq5G3bMpGJTvllyVJog8HdkhbOoGYs+q5qaYySBmO6CHQsG53GePI8lJvGnkDX0eNOysElZl0fFFNdfdjyy5JyIYUxRvMpGLYdJh0exsqBUoZ68QbNK9VKSFekmT3/FDSmdyrkOuMcFVnrBgciKYQPCUM5aJBr+RwbG7wwnabNBi/l8ii/5wwBVzE1FDBLihULZNliy9bzKS7/Z22f84nxS51p6PJRMglW0Sk2HwXtx0qBVvX0RaLT18oMRsNDvq9EDfgYG9rHBB9FamrzZ+O5mJZn2/Zk1jeK9tObW+9hl+Rki2uQLaAboHxaDSYTqcH/UJeyStJ/H6KBE+pfCjgky1/PKEFoqb6cGVdCbaMXNF1+ZuBUCFfCOWLxWIil8wlk8nZaDweZIrPziYTsZCLd4VcIc2Olma4qqxONDFfQqzxJC78XpR9rkAgm82GHsVixVekfCgLxHRFmBh3pzt2+nDjqcp3LEMKrdOKXpRColEmJL5dJDs0w1d7QmPKtmasoVuibfpm40GdoWuVM8tqk6SVhiCNQXfQ2LiVbTwbavXtbcerDVU9TPC0oRCl6upd9W3t+tqtbnpao289ta/eoK2CNBva0lRpMcUPtbb+r0as+lMmqHHffoNmfVfaXW3NpkOY4v9bh4zVGwSrbr865PUXgsTmJ+GGTnQAAAAASUVORK5CYII=")
bitmaps["pBMPetalPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMPlanterOfPlenty"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMPlasticPlanter"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAJYAAACWCAMAAAAL34HQAAADAFBMVEUAAAA2NjYKCgoWFhYODg4UFBQUFBQuLi42NjY1NTUkJCQ2NjYqKiojIyMbGxsWFhY2NjYkJCQ1NTU2NjY1NTY2NjY3NzYjIyM1NTUxMTEjIyM2NjY2NjY1NTUzMzMxMTEjIyM2NjYgICAbGxsqKiozMzMyMjI2NjUxMTE0NDQwMDAvLy80NDQYGBgmJiYuLi4mJiYyMjL/4T42NjaunEP/4T/cxUmtnEI2NjX/4D00NTb94T3+4D81NTT/8KHbxUj/8KA4ODitm0E2NDczMzWtm0P53D/32kD/4z783kD/8aL12UHdxUeunUA3NzP/8J3/4UKunEA6OTP73T7y1kHex0f93z7gyEfIsz/12j702ED73z4xMjPr0UW1oz+yoT/v1EK7pz/ly0bcxEG+qj7pz0Tu0kL33EBGQjNCPzPOuECunUSrm0Lz2D7LtUHt0j5zaDXexkndxkf63ULnzkOxnj+vn0Hw1UA0NDKyoULZwT//7pP84EDVvT7Mtj09PDViWjT/5V3RuT/BrD1XUTRNSTP/75r/75b+7Y7/40Hozj/iyD/fxj/Frz7Xv0HDr0FBPjZTTTTw1D7/41LnzEWwn0L53j/dxD5JRTRLRzHiykXfyETjy0O4pkH77Zz/6HL+5FjArEHlzD6wnDtcVTLSvUDqzz+smjvx1UTs0EGcjTo+PDG1pENtYzRQSzL/6n7+5mP+4kiXiTp8cDfiyUe4pT+5pDv/7Im2pU3IsTyoljqIejeDdjd4bDb56pjizmnkyj7l1oHmy0K1oTuNfzdnXjP25pP96oa6qlK9qDqUhDj16J3/6nijkjrw4Y7p24zQv2n/4kxcVjb044b/6GyFfVvUv1P/86Lu4Jbg0XvayGLGt2C8qkSpmUBrYjj/8qDZy4ju3Hq7sXfXyXS9rV5RTj+gjzjNwYNrZElzaT2BdTudlGjLulJybE5gXEfYwUZ8dFWNgECklD+upHGMhV/HuXjz3WPGskro1XP14XGkmFvn0liNg1Hz21DkzVGilEjS/P4fAAAAMnRSTlMA/Qw5BwQc2fv1lPGziRgS7DP9+b/f5yPHZyvWt4Z8T0HPaFZWpF+v6ZDj0ppJfauhcj1wSp8AABy4SURBVHjavJoHWFNXFIALQgulraIgKNVqWzutbRMiGS8IAQIhZhEaGRpGIpugRfbeexfFwbKCEwEtwz1qwUFFRetErXvVOrr3uTcvIIgVFfn9jC+G8eecc++799y88MTovjbecMSINyYYjdXTog6Ilt4o0wlvTBrx/xiaaL8wFOjq6gDaJuOmmH74kvFYA2T1KC/9scYvPcSHQO+TVyaMGKn77FY649+a9iow1WjsGGtra+rjsH4MBpOnTHzbROdZlLRfHG84aaLRWH290aNHa/WNko0aqg2TyaTSqYNGS2uM8bvjxms/ZeoAbcOJH5uaGRvoUYEBfzNosak21CdEb5TZ++N1nkbqxY/enDZt2lTTUf1CxARsgdmzbdlsJ6eEQn//wsIEJyE7crYtBr9KXjFtmGp1gM5ksh8ImdkEQ50nz53hO++a6evp6T2QOCRkQweRQr+ytPVFRUWpKxITv6mrm1dX903iihWpRevTFvv5IUt/BLZ1Qt9nY4PeihA9g5+gCZjxxCeNl/aIaR9PHjWG2re82WwmXbg27cjZbVv3fyuQe1Wn5Lmo4uMDkpNVLi4FymaPld9u2HNj2zxg2zb0z9nE1DS/tRBIdmRkpFNZUep6Pyd6T8TGPFEeR454681Pp042IJXodKgcyAtbmFC2/sjZ62DksW9Tcm5tsbMrl8sNdV8odXdfyPXluxWHZOdEJ+ftawb2Ac3NX2++sn/Lxnl1yLBu3p41V8D6bGohlU2qmU0cZB51Rpq88b7pBwb6eloaK7qNjdApwb+sKPH63X/33vrunzkR4MNjEDKCQRAsBgtgMOCSkMXypFxfVzc+3x7Bd3MuXr1TEZ+SsikgPmXfpkW1zqtqF+3bn+jnpNbSQnnUHoyVybipRsb6Wg/kjc62FfqnXr/x1x+XDl3c1dnV1dHQKGZQHoRGg78YBwrAIp/Bo0wmdQ0uDikODg4JKfZlMWgMbnG0ZONiJ+bg86g70vBtmKH0NEOObmtLT/C7fPn2D6B0+uKurswM0TlLq/T6KjGDQSEoFAZAavXAwKgDSKHhlx0csLaDA/5KB+ny5o1p1mThaz02j7qvvTF18iiUPRKhUyEoHbt5/+eTB9u2b6+oEFmJrCwtLVuONjIoTw/DvVa5zY+uiZfxBIjX/1mNe91Yvyd5traRCbeP3b9w9fz5zrYY0TlHR0dLSysrK0tHx8yjhylkfBwQ6vSRlxr+T8x9+dfzhLaaecLs/f+Jl67JO0Zk+ugwnhMu37525+bVE5bHjzs6nrPSYAl/RO0NofZ854gQRHFxcYQzUByhxjk42A1hbw+jVCqVuvNkMhZLDP4o2QT5Zri7v6zzE9Ifm0eI1TumBlrkhGCdUHj7pwvnO08cgPhAlDTAM1FFRebvf/ssU8QFqFwwqoBkIICkJi4/OjpaocjNWbZsQXZtSLGns3Owqz2XFysjeCyCos4+wXWu2egnpPbk0UTnEXeacUYGZPoiC28fu3nh6okKlDew0mjBlVVFW+fJU98FqPKUXuXyKEAuX1deXt5ULl+HgGsvrzNnlMrq6pSCgjwXPNmCdly0Imd5rQ/fnUUhyfKN3+rP1OTRaNxrA1tBBnGsmNTCyz9A8g5Y4egA+EIEUdredrBz18VDp8+sixJILCzMLRDmEonE3Bxd2yEs4AV4BSORCASCsPBSDw95k1d1gUtA/qLsYCkBAxQjVqY6Mdl0nEbjKeMHrnZTMlbCwms3r3YeqLByRDpo5Fmh1JFKl/a2RpWWlprDrx4EduCGJQNLBaUosF6bokO4hGayi9uSulZog7XGmI4YMIOvgxWO1eU7988fcASsQAp5IaNdJyFIp09fag0M4nDAaLBAtNSRDAy0Q5jLU2pq7Wmk1ur4lTeKEtR1/+Ek3YHG4BicQbbw8rGfT1iRxQRO6ZldXbtOHjq9F4Tgpz4doIUe8bXEK85HRs4eRCxftTWNjbWMx72o+6gMMul+P50/UaGRshRltP9y6tbeVkhcoIUFh2P+7HDClLlcgtDcs0KUZyNxGke9+7bOQxnEkygsWi7/dLWip8hjur7fcepWtVzAQVU9NEC1edRESMnxSDCkim2RTPUcMVGn3xg0hQwinIqOnd8ussRO6THt35+6dSZKAASaDyF24S7ZUnIswpjM3gpaCP1XtR8xBtP+uoqmBRyp9t//vHVmXSlZEkOpJcnL4fZoOazas5aKGf2ydt8MjlHX1eyyOz+3WTqiospor/zlH1WTABfTUGsFFuRwYfVBwl+z3skWl9CDWiPfMNUnx+Daaxc60Ri0Ss/saPjbWyUPCjJ/DtgJ8paFHi45LMaj0cH+67q1tlR6Xy3dSVPHUjFOadf/6KyA5YEoo76hpNE5QI7m8ecAJyx+TkNHfWUVaAHc+C1+D2u9OVlfPTOkbmm9WHHcyjG9vSMplhWcq+SYPx8smn78pT4jvaUBVohgJl20puyhJOpMM9DCGfTbMv2XdpFlekx9Awrv8rwoO/PnQ9SvO+ozLNPbG8Sy2FiCJatdufhhrVfxCsvWf6OSn9QRk1l/tKqRgAVvbhNk8Hkg8fh1R1eMyDKmsoTHj/Dk89yLPRbPflhrNNrwMtO6s3mNSZWVSY0EjcJg8RRywVALWQBBga23drSlw+2jPUm8cM6SJXP50uDmtEdpCVek8Cg0cWOjOJZFQVq5zeZDrhUI7D20C1lZZVaWyOy9p89fuppn77XedkAtKjXhm3gHBgVtVtSzXGxIcpPdEBpx4HYa2Lr39KGTB7eL4N4W01EllvG9p0+fMZfLVa4fKFr4Bj0v2YHyACxptkuUZNA3HXI9yOGgxz4ILCxAKKq1de+l04cunjxYgSfrFrCi8fjeM2fMWLAwtEdrZD8tdtrWaFKLhOGa6yIXCCSDtQoKCgIhTlB/LbTQwkq7Dh5sa9sOa0u4r3UkHRZTerR41aCFmGKi20+raM+ivlos9+Dl+S7l4Rw7c4vHhgmsEJCpbngkCULYtUKMLp7ctQtyhzZ0OFRHYe9LYWi0uEQeqWU07sV+WqkbckGrDwTPbVlyipdcHoZW6RCFXgs7zUU4orQ0PDwMiFqnoRXYi7kExQRbXke07MaLyoxMmBfRTptBcYfamjHjC3uaRmvsx4b9tI6syQGtfvB8nVfnxKmUUeGgIREgyJWmBLCAxfm68jPV1QUIePz11neYU6d27DgJAQI6D7ahCsc7JpFIBHP10aQScj/eo5W1idQaM3lSP63Eb3c+rEVzoMnsi5cramA/WADbL8BLiTTQ1lClCvju0ClQ6OG3375X09UFfQHUGaiwwqtvR1RPme31HZUgBb2LPlrerlkuRVhLy/qlj/prbV6QBW2Wh2DQYmO5rhGrs3Oj82uAuOhFuTthSxri47Pq79+72tvbM4GYjHSMSI0VgNImwjsnyBw4dVQ2VB0WiwnIHwmN5wYTxPSv3LICVsB+GbD+oJ9WZGLQn1ViykAQBNy2eFzYwMN+PgK28K72aAfP41XVx5Ay2OPcOVTSGDJCVghRRmZLfWVSScnhRjGp1KPFx1qrxHHz/NkDa51t/a0jqXFAL9TjwP0qsTgrS0yAqPq/kzLTsQ+uHPDA4PiADADlHdOCEtdAZo7W/w3bYy2f0EV7itg2A2pdu9SZUV9FGQRkaTBoVfUtkD5ExgPA00xEC1Bf2YCCBFAGQuYKWjNn+XB3XkkUDhQtm8hrFw6ey0x6kpYV0VhSVVWVBDQcrewFYoOowpQ0ZrEQlIGxR1pL5/iGNNcJmXiGeFunX7QunDge0wBag4elbvgRhPhwSS9oVcTALjiq8PBocBJnzbV3i9+o1ho1wVC3T7R++PmEI9J6ChhQfOIeYJocNK7eM2ZO/2wBX5pD7sn0jd7U7qt1tQ1rPSu4QzrYr/UFrZmfebsRnnvUjUG9sa+O7DNv3Tm/3TEGauvZAS3GoLVmQnF5u2W57SHbznqf9GjZkloipDWc0LhQWzAUV9F895NabI3WyPdxtI7BVixzmLUI7oKZEK6lq7J8969l99HSHjEF1Rb72AmRaHi1APfVS0DrM0+a7waY5jGfqDuVL04wwyUPWuktw67lNne+WmuNH/QEEe+qG/TjXzHQQvPWsQOwPKsiKMOKzH6OOlqhm1PJ4jIdZ4K0RnwIVjY2oOUIN59hjpbM12f+jBmfrXII/TIxgUmuBCdhrZesqai2fjpwfLi1APdVs6Z/tizYAaKVwKTjleCHH/Vq0RNAK6ajZJiTyGLx5+6e68klnFcmFtqSS663erSYwrKbB45nVh5mUYYZd1dnt4WEqyJsYxkbtID3erXYTpeR1tHh12K5L1y4kLc7JexuEXj007ItvHb/gGNLQ+Owa8HxlFuOQhXG2ZDqNIDWDxcqzoEWZTihwWJDxnXN9fLwkNy7u144gNadCxXHW5KGU8uBgEPYLP6iAKWAI+BsuO7HZg8YLdASU4YNB5q7b3DxgvyCKA40KbpvHEmwwbsf6wdLvvD2/QOi+mGcH1iwM94Znaz0KIXmi6R7zVl/qhqtl97u1RL6HTvfhU6fhwMazAvOO+NUKV7lYRw71OG9t+UILJoxBka9szx4Xbt06s+FtOfvRYNCl6KmS5OEw0E9HjtzjzP36vwggRizCeN7p1Oq//WgdSofKeN5zxAMd14oP0SRJw8XoF4L9DQkTS413evZZLD03h2h3atlXbatmyOPD8miZTk4PLcKc8hyINx25we4KD3gjDYQtVs4gur83TkrF88m18zGr6L1Vq/W9X8hx/k+q30i3LiaEhgiNAfAaOjVKlRNX0rwMakAzsrC5MoaH/vsHi0D8uyOrC2h05G79ywCy6uVKS75taE8HgEMlRRs1wiZjBfqk5uc5yX3CIfsIS1oRoVVB/y4dK7zzs2klp4ZnHT2atHZdL9v7nZDXDkCDy+XuOicBbVukM4hCZg719kze3muIl9V0BQGh+zqJhmYyatVNTM+/3zZHMW3i22x1mT84ZFeLRgHftfXdOMun7kgrLlaFaDwceb7SmW0p4iOJm3Q53ENjqjdqaiJz1M2eQgkuMzNwSrQPNzDS6VYMuvz6fNnecddIbWmkFZodUolDzhTb9xTn/nCGwr3kDcr82qW1RaHimlPsiNFLXS8hSUI6D35LIePcim9vOSQOqwEgBJM62FeAUt9fL5YCmvm+d5xa8ogiX06zYavGIymYtYmbuguhWLETWt8jlXuokrOhw9VhLiGhsL6Q0ZQWI8SVH/ABjcQKe5Srptndo4iuibApbq8FPLGscCYq990eFR5QYCilm/vueTzmTNBK/9KmS2zb1/eZIKZOlo27LSNG7rDSiGPGiCdpdCp9YrP3b0gO7vWx9OzOBgSK3VnEFDDMhY2ZMAliLi68vlufMDZc3X2TkWci1IeFiYpDe/bkA60CJc3KQuSc5xDCRl/LlhBD+IrxeaHzny0/+vlXIKausI4Xqy1UFoeFcEHIihotVZr6KV5XCbDw4QMISN5GkIggkkAG/LUIMNrBBY8LQwlkKSLGhACowvAzvCaYXgsZMaNi646Xbroxmk33fY7555IFW7FQPiPSpCY+/N83zn33O9835eeFROFsfitI2OLD2/D4pvP5C2QxIV8SAC8DULJKe19LY2PrNZip8QphpyZri6Kgldl1kee5gd19aCbfe3t8NZbzyru4RQSYjik0u/gk0tuP+h5bFCKdRweYNlzwIaqOVX+aDmXYIUUfz41gSQhFcps/R4I3t6quJuP4XDUGz77B6x8UGnl7zfrULpMY38/Su7p7fVUNzaDsWDmQ77NTyWl6H3wawsH4eVfz8//6efbfTfrqoMKDp7hPEmxUcVg+Uo7t2FBIlkSSUPil9uGmizubk/L7Yo1uMjdeyQRBQvuFDgSD4ks9yvf0l2Izd9BE+w6ft+drRMZ/D1+e8Wz9jpPcFI8LEFBOMSlduqlwhyQyhdg1i2CRRSXeSEGYxWU24xFAoHIYn3U6+lvfnCzveJeaX4pNisIMiEwHPJhfLgDv69jMRMspDsh90Q7qdKSnx+2wMTp7em2WkRNFMzRUMZZ06QKY0mrd8IidozCWKtFNA/tHGHBGQyuVo/Xg6/AQcZ9GDcm0whODcjF4erbVIqEgH/4vqSksuLn39vnW8Z7H1shDbSJxiwwVgwWKIS102gROyK/zy1/Uk1ToeVHLZE4ncrHsEA3t8C8qoQTFExEBIPEOM6d0GqEVQKLJhy1VFbChKsf96xYteZhuJepaYKyJYoOYfUGOrdhYS6w41GwYnlb3yD138WoiFKIxGWGIGJ7UP8Q0sgq74NNsQ2xKeGsCV5f/yG/5N5P9+/ev1+JUqF+QWlaPavdj+G2L6HAkQgRG1Y1CxakdaYh92oYC6yGPoGMNHUDFmx4KbFYu2EVaGmpn2+/9UbPUGbbrdsogZioBRzJ88iqbYKzAQzEQ2LDYvctorMxeYDVsdBDsYTI4EHTrMVpt9aeak+vrxqElon+6mq/y1pWVsxIWyzWiiQ6mrctxMyOJS19H9aLXhYsdIDN5LN20cUWi0VLDlsMbotWO6yDcdm6BaFx3g2Wm2AJJzrZsbL/H4vE2Rm7vjEyMjBPwDDzyPu2RePZsAwOjCV8jfIgWLBQTlL5wJQHY0VeQN9kkuZgrH7YbxWwjxa/fGCz+eCwJCYHorK/vrVY+79YDSOzLV2ciItgDesJ1lTbNDsW+vvWsecH9sAvEBsxlua3RZyry45V0DAaOIjRIvFcI56Hjt9mZbnsWHmAVTg9cWBYijIjcnmV9J9lLlQIsWB9lX2gWBSlUw5Jgcr/uuIPWQEb1rlTMQeNZahCg6Xvf/UylxUrPSsZZ3FNHNACweMoghqM9WBxgB3ryPkMPFoLTs7BgNFiF95rGftsNQQr+ottWJ+cTMpDWDOPRAeD5TRohDBY3p7AmJyLsaKTr2xP5E/5HEUr5UvzZUWcSAslMJQN2e05Qq++eaYTkBBWbNL57VhHEBZf/iQwCFgRF09k0gBWjsvQ/mcNObNLTjv5yc5YBfKxV9aDwFIrIf/OblcZXQttrQTr2BkYrB2xcuUDm64ideS9S2RE09BRZWxeHCVVW3mfpn/EhsWtWa4royIeQ20q9kvRNDSsQOKwjMtgff0xGxY418upZlHEqcwwDYU5Um9x8/oA3BBJLUYiGxZwtXZM9WppOpJkAtoAJhTm+FaDv26EDqmjjl0+uTMWEyKRv5xpcdORdC/BMLN3cBlb1jtDdVHRqZk71fnEfUsiN9kNnet9q86iiMXCBQp3lVAIWEb/C3QWzNTTJFyEsOl2xV85RcrH+LJO24I/Ym7Po8VDUkhicXiH6pdrQ8cEscdPHN6x0vVMVmw24Sqs/SPQQ1ORMSQ97Nagh0PVUN1MB5f4e/ax04ks9ZInMiCgRCKDtU8CJh1v/+/aFCWgIQoIDm/XVE8QfwdFH08/xFYFeAJVARI71tjWXDci4V4CncGLt/DSZ1BvhzbxpICMvbb7WqhmkssvHLEtNJqpfYcS6LQu9NRqFz5cJEsW6Gjq+fj3VJhGM/WJstqxzX6lmrPPHkaL3F6gEgofzsCGhowVFB6h4kR2rsTMi8nEjtzpgeV5J7W/WDzKbFQB1uv6qTbkWLstrT788eVjpKAzt3x6qb1Hu69YlEJZBfkr9vG/n9Rm88lgxV6AjMD36FDixeSjAIViqQXTbS8anVC3un+3HYvLjkz4u61GBhchmcxXjuyiVD/94jFUd44ygspb2zbny27Q+wRVREtMGuTuv/w1IOMXEKzYy7A47IIL7BhN/glf/nSpz0Tt08POsHgSkqsBK2CrLczmM9dISM0kVLuxY6jgG+5E7U56r2akwX4SkdvlzRHCKU/Or7NQB4WNGBWTeiYOe9Zu7AiNVwgXP290qa9bRO/9Bq3U+5k4m6aqb32knMGKvXA+bvetIE5ey8ogt8jChoH1Oot6r2u72D2kImE2r+nBTGdhAcZKuPYh/VkOxyWSYlgUXtpoHwSsMJYwJoJKQf1Esd6vyWEk9RsapwALfAvnrnyYSOEpSL5xU4xzhMOMr1G02TCkkeKRUs1pCBZ2+bwPxCKl8hir9ck4RHEVZrHYbBYpdO/Ea7fBAj4BAjdXQNm+WGzwARHavftcemOVS9k8EyYWKYnF631D23gXxSl2VXn9LldQKcFdIJgUcHyUgAC2hKLPaGR59LBZPKk3Gl3+qjlAQrt3r0krclq05pZFVPoXFhYo5SrGKh+rozmU0pcDH+7wuUyTk2W4Y4cZ5DSLxFqQGP7EX5HgIFY5aTCZYGTmVCqpEIRGS1NlEsFKo+M5n9tqCdalMLDiv8Wb+/KOm2YBR+nD/2WHVOXzVrmM+qDeZIJzYoMpqH9HRuPQqk/lAIE/YSaHXaVS+bqVw7QAjbR4oq21kIvDIV9/Ew7WlxhrYM1Kcyx+uAqW0KFSaZDm5rzeOc3b8sFvQGIGiKGSzg0ZjUGDRSxR4+kpMEyN5vGzmSU+PQysL5KjEVbnK4+CMptc/jkVMiQIXZAIXpNvyIv/fAcjO1c1FJxUlhVrFU0kQYJS9CxOk91DRlpKGC2bzibFAFZhzdK8iKIlYnfQ5dWoVHY7A7clR47UjmwmdThUdpADTKaZ84Kx9QbIBZBImprUPJqsYjcGH9pkBOsCbLQ+WIcTTyegmdjatmBVQCnaMGpL4zYZq1TSt6lUGq/fCyb1g7X0SCY4pkKHZmKzSCfgvVOa1r/+NLQvzYoLq+lW5iXAypWPLM0PdnFonEHCUxS79cahkFaBBFAMIJgBSiBBGsYsuI8N793IVs9EaLscnQBhyXD0zaU8mMd8ecdmo4THHMnTHLVOopA4RW+kkCArSSQ6hULdpFbTIMFb9x8ivMCJV+9CDRSDFXP8bPhYOBuubcEjAufYWsR54cQmiwTu5gXbCLeBwUqG+pm9YHFza2yBR2aaYIUnnlpkWemb2YAM01wus1uG+F94WJ8yjxvwPLt8y6XAx88fhILF4aFEAa3bX78w2/GjLBc+kHlmTfwoPH2cFApMyJ7++WxF0UXtjuaN1ShOF63TKcSD3Y3za1NLGyPy3FwMBVhJsAMMTydPZ2STjm7y0dlAo1XBzlKEhL4KBACiEKEUDwNqxzWOet4EZpaedNTKwSFAzDS8mBKOZ5HClpgowpU3srH+fEUsoWlUs9hEI3HgJZp6XU1IN26glA4nLG6GoKvH09wy/3xtYWZxGbVXG+isqW2FGBsftIdpSBSfmRVKWOIX/NgxO/XrfLOnB7K5IJ0Ea2Wlp9fTCBkS8/OQ+ILbkwUmFl5MTc1sLi7NLts2OoAHWqhBdzpiPcDayzQk8aUzqQlkvMCQtQMbs5svJtbWKtbW1gKBwATSi1dTCGEWWrnhxnMvoe/c6OhITe30tFwux/5dACxcJIIFfRhTz+yp+2PcmQsxpBMelwtgI087XraBxohednQMQPu7kZEaUO2PoFbodifDMaIC1JyPGxJ8AGaKioqKPX46nfh7+Ha8ELIjCLmGTIauCy/xdiyb9BCEHnkh5SKCAqIQ1ZYFozMun03cc6dMsGNsFMHCAVhiD0zALI3E+7DIdwUIjWjLpfjQYy72VFrKIeJXe7NjFnBtFyFk+8nOP8KtKPcOReyYnL0n5YGiEzJSr3772ZVMCHXvj+JgPh79Mio8JOh/Gpvw1VeXjqWmJR6Jjz90eF+oSPzyIjz9v095O3fqTE5NO3Hu3LnMdLZQZPhchz5O++xq0qmEo2ytao8mnEr6fEdd/eIE8ERIh+PjUtJPH0+IZmteCktRypEdFQfhjwjqk5RrSexYSddS9uvq/wLjG60frO8ZVAAAAABJRU5ErkJggg==")
bitmaps["pBMRedClayPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMTackyPlanter"] := Gdip_BitmapFromBase64("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")
bitmaps["pBMTicketPlanter"] := Gdip_BitmapFromBase64("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")

; nectars
bitmaps["pBMComforting"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAkFBMVEUAAADD5v+w2vmw2/mw2/my5v+v2/my3/+v2/iw2vmw2/iw2/mw2/m23/+44v+w2/mw2/mw3Pix3vqw2/mw2/mw3Pmx3Pmz3vq03v+w2/mw2/mw2/ix3Pqx3Pix3Pu03/+w2/iw3Pqx3Pmx3Pmx3Pu03vm76f+w2vmw2/iw2/mw2/mw2/qw3Pqw2/my3fuv2vkne52EAAAAL3RSTlMAB/v38A36Id705dPJFxLYppYug31vVjUet6qaXU1BG8GPd1BIJwvsvLGfjGaJOy8Vi5UAAAH9SURBVFjD7dfnkqMwDABgGUyvoYcESO+J3v/tbnbnbm42kbEY/u73Xx5bxQb4pXFq+uKWtum96h1rcrQ47i7Sxm+GbSa3MhMTwqOulfjGW+6Z+7D6hWsjwd4cBGPvh4uJKrLUrmDtJI4wF5Hm8Csbx22csXhniVphMxK/QYbQUe5/iSxXocjfSh1jSzcIfClN46sj6C2IQpU/Gd73x8iy4qGp1ysfE7qh9h4d7j9r8SNR5YuMbxK68GkGPDkZ71bcEXJ8smIZcOWaiuvELhGfHIFtbXzGex0/XlA92IoJN5AkCtjBvBMk8YQTXPHTAviGMzE+D+A7EGMk+5kp8I/AV1JdFAHfjlggiIEvn7vAnRrkAfgWxALnDPhS6iqqgO+KMzuRvM+TZl4V0CyBbU++CAH/QrN88jXanoAk9hlRR/7nRLOVwfvb1NOv2rn4bMdoHdrovi9guUgyl4cfxxBZEX69gJuPrW1R4dxWjiW+g+O6vPqGokdqE1U8d5Nu8+LZBvLftWE8PhOb4ijDMPA/nyjw4CKbkQOhM5ErGTQzreFVinZcMg9wE0CLbwYyBOopPRWMPLg1qIlKWwv/BaOyy/gxwlo72YU3kv/VAFqiT6Visi4HASzZM5TGe7Sfdqcpv1zrrWv+XcT2gnb3imCquK4ej919lXeOgF9KfwAh9QdWpNjfcQAAAABJRU5ErkJggg==")
bitmaps["pBMInvigorating"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAk1BMVEUAAAD/jY35fHH5fXL5fHH/h3n/g3f/gnn5fHH4fHL/gnT5fXL6fXL5fXL7f3P7fnP4fXL5fXH5fXL5fXP5fHL/gn34fXL5fHH5fXH4fXL5fXL5fXX5fHL5fHL6fXL6fnP6f3P5fXT/gXb4fXH4fXL5fXH5fXH6fXL6fXL4fXL5fXL6fnT4fXL7f3P/g3T4fXL5fHEC1AEuAAAAMHRSTlMABfr37wkVEPPBHMyJWkM36NWlgnkN5NCxcFMmxp+QXkkqIeDcrqtqZJd1Mrg/GrqIU/1NAAACmklEQVRYw82W2XqCMBCFybBIAQXEBWtdcG3det7/6SowopiA8nHT/26+6GHmZCaJ9t8R+4loJTAd2U4rAV/Xe60EPgmHVgJzYCfaeNgH1sMWAp0xYExbCKx0wPBbCPQIsNtsQwRA77bwcAeAonvc2MMAV35NDi+7bkMJ38aVUVL0dbAw38o84a2fIIX2Wo7pwn5ntjqHzerWRhmxycJfQPB6T5yYtiL/4gcyQocF0vi3o9VzdAGPUwmREfgsME939fNF74UA8W+SABl04MIXBOCjdjaSNEudU/4m5Hxx2l16lYKVVW1fbh4yxrEQqE+Bv7mxcjdDMLQoBOp723KRMs4z7tm40RfsQV6RVZ8A5ygiFIzyxvDySP+uPD7Ys2EWcRdw1twHtSns2fV1tu4buPMj0i1e3/TOtQkguwrEAA+s03NtSWAioTzCdeRQmvDFxQM0uUrOivAkD2VpPUonkTgoyp4GRWSsVHuYV8BHiOOihL7MP3BvjDJl08izPEKZWU8ytUQ5Z/1k4AnDfoxG8pVrxmgAyb3kbNCEvlAcoE1wJYEloQljSaDbVmBPLUsYoJ2JwkMTaC9NwhwKyI372xAytv+eQN8SQiQKBcPU3vHAPlZVZygfdBLhMG8RXV6RBRKj0uokwDM/ssBwCwk+uS7SmCifr0s5hcHtXSAtqC4nc1YlIGLJQiXHdZXAVnJAiYgIZeZCKTBaVd/NZXYssJMdVHMeocTJVAl4olJAfBtKgZK9rqVVYw5KClsu4Qd3NvVvb3PxWMVMSIM2Pmv1iPMX3at9HjSKp9pLnHkA5vB03AVRR3sDcfTC/B+T0r1NHz2hvYdwurFB2Z1ezDNtDpbWAHP6GcWLYs70tTcVWlPE7S9Wz+8I7b/yB0fzC6SJbr9CAAAAAElFTkSuQmCC")
bitmaps["pBMMotivating"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAllBMVEUAAADatf/Jpu3Jp+3LqvLPru/Ip+zJp+3Jp+zMqu/Jp+3Jp+3Jp+3Kp+7Oq/TJpu3Jp+3Jp+3Jpu3Jp+3Jp+3KqO7Lqu7MrPDJpu3Jp+3LqO7PtvnJp+zKqPDKqfDMqe7QrfLJp+zJp+3Kp+3KqO3KqO/Jp+3Jp+7IpuzJp+3Jp+3KqO7IpuzJp+7JqO7Jp+3MqO7IpuzcI6R9AAAAMXRSTlMACPP7Jg/349wc0MO2WBbXyvnfoZU8KSDtmkgM6kExLBLnjHFgTLx427KqZ+mCUWw21tfBtQAAAoFJREFUWMPlldeyo0AMRBmGnJMBA8YGnOPV///cki7G9sBA+WVr9zxSqEtq0YL5m0EVcRyjkvnVgX7z3JNWcTq73k3354jIu1xhMfTA7NFdoanlDzXE8Il42Ewp5+97AciwuUGvX7shDCKc17T6HxXDCNiKxuu5PVA47kbnX9pAw/JHBPQQqNi34W0ae5jAMR0U2LIwAbzkKQ3QuA5tImJhGt6ACx5MRJHJE1gwkWxBFFgkMBHhQhS4YHghPJ3C3xxa9gQTlm/Re8To0thq3uX8JaEqKddIhT52zpfPatGwXNvG7ffnBCQBBfqoch1uE4CtJw76+iHJxfhFIGxDdz+CGzdBl3rj3UlJ7AvgzqZdl76L8BTQaQJi2k3GdS+4+ClA82BJ2pNvdgIRScD6SOyqNYJDb2m9puPfAS6acB2lqF6Aprc+n6HBNIjXoBvR5Oo6C0BJy9ZyQWmN0FsfXTSeBbe5j5Wg9pMe2O6G3BsBdsuQiPe/ExwqS8q6iiTBVUmBeh04A3e1EJ5ZQfr19Qpd0FNAiwdO2gkaxMeqcN5vwCHg180LwpYZYGH+7jkRPo+AaUlNqC2ZGULPgI5dMGRa56hYwVf/tucOyXAqUDjzzCg7EUaRCDGYY4NQMDQMd8iGdoVUfKINz0tCJxIpDtJA7U8AY2zbNpuJNY4jmeqCmQSXLz3Py2/FVt9Fi3Rd4fs+x8nM/4Rh8BtDDvz0Z1GyqpnjgKwqlqKYpiSKWXZNkiRMwmw7R0CCTx7fChQzBALSx3ib04FJENjHM5ZACpS0+VIgmyGw0QgCzgwB5BEEXMRMZ3fW9pqmmlKJUyEpWsTMAfEbnjcCrsLnSgKe+Vf5A0jPGTYJYry9AAAAAElFTkSuQmCC")
bitmaps["pBMRefreshing"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAjVBMVEUAAACo+aOo+aO9/720/7Sv/6mo+KKo+KOo+aOq+aWq/6m3/6eo+aOo+aOn+aKn+aOu/6ao+aOo+aOo+aOo+aOn+KOo+aSq/qWp/6So+KKo+aOo+qSp+aSp+6Wn+KOo+aOn+aOo+KOo+qOo+aOo+6Sq+qWw/6Wo+aOo+qOp+6Wo+aOr+qap+6So+aOn+aJaflyzAAAALnRSTlMA+vYFCBDgvdcoHAvbz8muFcR0b/DrfSMg5YNnUTrptKCXi1k+MBenYEaTNEKd6vo8CwAAAmRJREFUWMO1lul2qjAUhTMwCTIJKFpRQZw6nPd/vHslaRPSQiBd/X6yFjsnZ8g+aJysOaPfYBMg/m8EXgAgQ+YERwBwbXOBxQEAtm/mAhkGALw2T6ELTyLjNLZ5J0DuyAz6Cgw3MUyhAwzyYhbAGgMnLE0ESg8+wWvjADhLgyxsPBDg3XyBHQaJYjO7BEvoERsGQMI0Z5d4NyqB90jsKoInqTVLYIW7/yv0n2rbhTCrof1Q6kAas24K5rxEhFVfDofs0WSu7NpHfu0zZlmwZwYAcV8AZ5MzEPEx5gINMJyp3ZQR/oMtktjRTOyBEBjkwTISAme7mDmGr92HB4GvDxTpuYgpcMqnYANfHCY88VaNxRRn7GUTnPQN/TiAILW6NhIUrdYLjiCRvyMrBpgTwp6AjOuvcpApNGMdxNADLwn0+bDGS1CABo3X7kBLPRQCbzoth2pyClX07RjcQIGcbt80l4vhFB5AIQ3sE4Y+eDU4RsJMJF/2lbyMbE2JBwqRzRadPk45NAbkx2B9oat5mdbqUcWlu1k9UYB+gIJr8eJOEwjkQZTNyFeM1vMHJjlSe87noblKapOBImzVjgmEVcvcggEBBwQ9Q773BMiKDuTAhT4nioQ1CZwW6csoeaPaSvh2HVxrRBKEM3FrEhRnOm0WhKGXchlx7OtWO0FaMrOWdZ091W02skJrW1YrB0Ca0S0hUQuRp7e46F1A469vIYyB3QppqMYUyLGl+hX1lA9aQn2ZYu/B3iU/Hu/er1OXtMzDoECi1cKasWrXRb8Y0foSoDlQO6maiO/ZXn3eWMgEStHf8w/NNugFDcEO/AAAAABJRU5ErkJggg==")
bitmaps["pBMSatisfying"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAqFBMVEUAAAD50+j51Of/////2//51Oj/1+v51Oj/5v341Of51Oj/3ez51Oj61ur51Oj51Oj71er71Oj51+z/3+/51Of40+j51Oj51Oj61ej71un41Oj41Oj51Oj/1+r/2Ov/1+v/1/L51Oj41Oj41Oj51ej61On51Oj61On51un51Oj61en51ej71er51Oj51ej41Oj71ur61ur51Oj51ej61ej51Oj51Oj50+cLW9dDAAAAN3RSTlMA/PkEB/UM8gninxbKLsJ0R0AoD+zq2oBrN+Xe1iIeGRLRvJuUirVdUKtlVDuvpm89NIV6YVjv1FflqgAAA0FJREFUWMPdV+t6ojAQdVDkUm6CCiIgeL/WWrV5/zfb7RpCMiFb21/77fnXjjOZc3JmjJ3/G90yP2791er4s/TI3dtOamgAzuT72f1LYmcfQP5AW5nfTH+576YaEArwLvT/Ydh9ivrkZBAO44AGci87l1/nz5IK+PzRvvcIlAuNGIviq+OPJ53wMOI+leU6/NRjffm7eLcMhHzNfqGV96OHIs7gL0JE/oiIcFwaepsSimqgzO8lQ5Q/2tQXc4KmqJJFwE5hBCJKwOeUgXnenh96KB8YgYEl1i1bBVgCKmBtawJzMWDcWoTsbrAAemxSbVYaClVhC4GKhTHVYERwLO7hfFM6xTrUpR0iYfqGCwxSFYH+AogEsPtIwR3+xLqg2iQGaUGK7LQdYgIBtiBuIRIaWGMLLWmLxZy0IxX21BHrPKbhaKEpCmg+74F3wA2YdAY/iALwysk4cxQNTDKihJNzDAzUwHsP36AMi7PCFVADF3o3I6LG8NDsgdd2l/R3n38Y1nTY1oiRNGvcQybc08BmnNrngxtu7RYt9TMbSddCzQX17cxm5uOId0Mu4PfYHOhokQXyst+BTIEVCDQUunckDMaSiM1WuaHqQH3Mo/euYS9vWTAGaRXIK2uChyp7UxqZQCWrUOKpmoesQAxEqnCIur8j3Z5p1ivLRm5dvLDie9knkL6e9/71Gi9XJRVhiZQ+m43CbSMLuq6BpoFHDzIXyO7cSsotogTE3VYN4FRwVyTsI4Wp3KnIwOev2ldPrVdLlYh2rYS9HmIR5ImJdugOZsK7olI2ULQzsO7iV9NGwWG4YSx1UcIcPW08xeIs62mci9ImzATICvjbhbX4IX5thdKwiRrhqSzEDtOb/HZ1hyyMljt74TDo6LWo8oLBdpZbCY15rS+9yJMUpB5CLxTINpQZQp5JT0SKy5jPHye0sAR3hF5YFOZS489n+TLuBifAtdm5FmdhZ1N21Nha7KAdO2e2hkb/dYD4IwycemNOGIFYb5xtT2hfSriP44yky3ilrCsrLp74vbGy6A1iD+rzQ/TcLx47PYXNmNnwOH4a550nYbr8sjh+dqRnyyNm/3S51dixD7nZ+THKsOh1/mH8At2tdh4Kz42QAAAAAElFTkSuQmCC")

; other
bitmaps["pBMNatroLogo"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAMAAAC5zwKfAAAC91BMVEUAAAASEg+Oj4e/wblvVjWci2g0MS2gj2t1XT4yMSwfHBosKialpp4zLiiIbEVKQDI4NjE2LiUnJSFaVk4oJiCllXBFPzRDOzGCg31oaGVSQiw6NCtrbGdiUTl0dHAzKyFjTC1RUU5ZWVRHR0SGhoBhYV1FOCd7YTteSS16Y0KDhH5xcmxxWDWcnpV/Z0Z9fniUlo9MPCg/MiOKi4SGh3+Bgnyen5aAgXpbSjJ+aEh4eXNMRjx7fHdsVDSYmZGQkYpgSiylpp1oUTKMjYekp56Cg3x4eXNlUjpNQCxfX1qCaUh6e3VwcWyam5NrUzSQd1BmUDNuWDl3YkSXelCKioQxJhl5enSbf1NyWjhFOiuRdk6trqZUQimKi4RlZWGZmpLb3NRSPiWnqaF5enSihFiqjVxmTzGBhoCKbU1oVTl1dnCggVRjY19tcGlRUU+0tq95enSCgn6APT0/AAEGKmUHHkV1AABGRUI4ODWxsqmcfE6pq6CQkYqIioOLjIWSk4yChH21tq6Ehn+AgXuen5ibnZWipJyBaESYmZJ6e3SFakWgoZutr6eMjYZ+f3l/ZUO7vLWGiIGnqKKVl4+pqqN8ZEJzWzyrrKR3eHNeSCyUlY23ubGLb0emqJ+am5R8fXeZek2FbUl4Xz6ys6ukpZ6RdUxzWjdrUzRtVDFkTS+wsamXmJCsraegoZiVd0xoTi2Pe1iOcUljSyzFx79wcmxtbmmdhV2VflmGcVB7YkF+Yj2MdVF4YUE7Lh2YhmWVgmB1dnBzdHCgi2SliFl3XDhIPCqulWmZgFaUelGQfl6hhFaJdlZVV1M0LygyKB3Ky8NpamWBbU0/PjlnUTRYRCqkjGGAaEdFQz17YDo+NCWtkmSRc0dsVjpSPyamkWlZW1p7ZkdEMh6wnXWqmHGymm2hglGDZz9wWz9LOCG8qX1jZWJKS0irjVxOT0w/OC7R0suqmnVjYFy3n3AmHxYTEA5cUkNKSEAURpSxoXqAdF17X1uSU1N2DhM291lfAAAAenRSTlMABf7+/v4n/v4XChv+MP5f/jgQWiD+SVD9mX1BvKdoUvRsTDmfbGTyyaaNi+jWycO5n338+vPn3pOQhXP88/Lo5N/a1ca9noyLg+vS0s7Nvr28efXp6eXi29HPyratpqD+8/Ly7Orf1qmDe/bw7Onls1v9/fz8/Pjl3izTeSQAAA/ASURBVFjDrVl1XFtXFA4REiC4F2np6q5r17m7u7u7b/Ak7u7uHhIguLu7F4rWZbW5/bGXFQZr17WT70fILzf3fe+cc8899zsvqMtCSMjcO+p/QUjwFYbg/2ELQV7Lr3rqlVdffeX+h0L/vZULHkbE3//VV+MtLS0HK7+766rQ/+h6QvKbj38V5BsfH29p/uSHmlejURFznP84bKHRazc9Pj7+VWNjY8eh7OzsQx3mnxK//uqhzM0rI/8xZXjS7U+93VjSUlLa0YGwmRC+IGVj43jLV88U+eAP4sMvmxKZlvDQU22NJQdw+PzKNn/2AkwmxMzGyWkDzOPdHB9yuXSxa19p7ZzC43ENZXZ5+WLCQ4ey/SZXjEoKSOge8i3xl2Vk2FUPV9bu/xGHy28jCC1Mnc60YOCR6b59eT0kDUAHuTSyCLPlikvzJT3VUVKLO4MrMRMInKqofQX79vlNJlOQ7pD60x++u6G7nr1dRQf0Ug/ZJiK/FX4JI+OjhnFn9u8vHSEIFXsrKvY2VRw+fDhKh9DuK9BVqANLIlIfYYMQGjbCEI/B0/be8vdG3t7Rjt+P75yRY5scTzywe1VkbGxk0pIHVyPcCHlTRmww0a++h6/a4WXxGbbcXg/5pfi/4bvK3nAmcaqMgMVu2Lo0bGGhQlctQXB15PznrF1GyjV8AUDhcbUYzJ0X5+vAJR6oHXE23RcdsVBkkP8XJELEnTuNIMQAPSwe2apdf5GEuapt6kxirdwRuCPu/I0QguDPxLHpoIqtElN4HhGGvOci8cMl4vNH3BuWIgSXTtfwO6kCKkDh0+mYv/Y63t+QmJhf1fRa7N/TLfid/BioqgN4Uq7V5ou/4KLQx0uC9jkfiECFLODvC1voPWw0GwLphSzWI6HnT1nbhkvMn9n7QNh5V16MLTwyKSl260DXcUBJglnWnC0hf55yxdvtiTiz5b5wZAWXZ65Ycdvzzz+/4q0rwv+aLvKh+x9/WNfW6lc4hpq7ivR8CJatPM/AVjy+TL4hNiFzy3UsG0Ok9TJ4SpZn454Li35I/KYos72tpHS4tKO1stHvHPq+z0dk3Zjwpwg+XJvYPuJ4NP06JQ9jFZ2WcQtfyBVxGWTflevOi07y/abW4dKDpVVmv25QV8DMNmfrJr9H0w2pi2e92XgA128JDPBZXBHZhrHqMTaJjH4aw7NCniuzFhkZcVVBZelUf6X8iMk/ITQx/VVVHOYhk2Vsmnh9wiIvNpXgGoRNs9MGkQRDZBDZUg3AZygNWpool8jz3RYxP3HVXW0ltflt5aZynfCIXyiUV5nK/Uwhx3xIfcKzEhWy4HFDYifBdUpFJko1Ai8V7WVTABVIoRElp7m87bx7I8/l8putw7XjcrtCJyQI5YcnOISocjmHYGdyzPZG9+jNIX+sW3QjDlemmBwwsqgACYKppHp+HRVk8+tgMQ0jU9Ks1yUjs+LWdjTUljHLmYpyxV4XdsOGa52uvQoTh6Nj7iv367Cfp6FC5givLsVNHWk6elIKU2ASRaWhQBRQLKBQjRCDKmP00qy065JQsZtKcV+X2cs5Dkcg774lSRFhsdG7X8tzEhQcgq5cWGV6IuEPCx8qTSxjOsemAaNYpRFT+6ZPjg4MnDiuorJJJAjk6mloxpWh94/j2+0K4cSg2rUmej5B46LXuN06JnNfgV1nWoKax4MlNaWWvd19NApgPD7a80310aOzQ5OzY11iap2UTiHLyF7Plgx8g9kvPOzOu2FV+O/1Z+74XrUsr6JKXlWl46yOnF+WB/Px+RZnTx9bfDymelYdVTXRZjdnC12z3cV8AZpEAmmMHPo731UKy53qvIzQ+Ro5Rxu7Bltl4hTIhYfXnhu94sO1JTWVnKZqgWDgGxezs7Yff6y9Jr9suI3j6J7mi0EGoOGDUt6ok+PIWzbnV3hYWNy8mop80cK0CJmmoInBkfT0Bypx+eUVY/Uxs5b+zmMH9uNrp9q/bmgZr2w0NXeBRoAk1dDoPqAbq14WHTxpl6c+u/H6RzY+f9s5TRIbk2c3R8kJURW7f68LnqKhNlwlR978zexIA25/e20LskVLykr7S8vkUQVj0zAA8UkQBDME1ctWIXQrb6TDRLoeBCQa6LrNV8ehrijuYZbJ/fuqHE8ErV6nTBlq6yyR+4d6LLj2qYbSVjnHxGTKC+z2DnO23N9zlmT0wVI+Wup7ZykqYf31Wr2ESCNLeB6WVsbSAruSk6AB5/AMk+k/3JSE3PB6ougUs7NBLqzomcDXlHD2rl597YbD2MPMKEIUgcN0T54yglSSmC81eG+MiL5Sz1VyybZCmYzOkGh7iXSWYft7J4qbSytNCqG8CYlwPFLBv3c2dhYI/bNjZmHTg9EJCJY+48Iq5AU6TvNQy0+jJBKFzofAzZnP6snk07kimhbY4UPDrBSAwaVJAFtXTHdrQ5VfdwSbgULdhvFw+45y8lsJBY6eydXRf2iSZ1wOzuDYRMv+H7/rolJTWL71mTdKRbRcLh0NSUloUAyqDBAIkWiARNr1bX7LDDOKM7gWFX6vtZDe1z1ozjcT7I5H0+ZKVTBrlyxrrjYfOHOspqRbBQGPxa8jkkVaJRmdQyIJNqeuXB6fes/2erQYhEC07MRMTUc5J8q1FhV2I71Xyj5ZzelvI3A4q2MXtxDbmkvxx3A1/cKhGEr68i1kPcMK0ECBmHJP9FwViEzdwU6hsihcwWjtyD5mlSMDFXZlocQqOB6jPlI6whRm35W8uNSPH0g80KlTDDqOdqdu1EtEXBaoqee/G1Sv82di2mPiFAoAAfWjZjtT4c5ALaeLRDQK+2y1QzdjVsjt/jeiE4IbISJ6U+vUgZqvy6Im1O7ANyf1vFwJDaKyjaoTXyT9UcIR0tBdAAhR0PxRxZECgns3arme94IGNtaNVluqzEx5lJCZfdemN97YdFfrcE1iQxlzAut2HP22OEciy4VJAraqaGCgOOXOuDl1gtTmPcuvRxJAQ60fK1BgHdGIyzTyaageOvlttdNC4Mg5BcKoKp2wtbJ0uMxepRt0udU936rIZA+DRhIUU/sGpiExJL4Z2R9BxGXtAp/LlDJIaAgerZhoWhaLirvew8DIWOy+nupqtdpCUDDLy/0TdnNVQXm5RYF15z356LeQViaRgWCfStDV3VdMgQwADb55fVZWVurNdBZIytoi3Q5C8MnJCvWaEFTIFlqhlUEHSTFDj25dFnAq5NnMIwUWRYHFgrAN3RQdsnSHyEpmAVRjseDkCTaFD+XQCiVEwOqTKpUwV0KXpmdq+GgWm928N29JcCtrcjEv0EHadPV9qLRnAu6hANbpxFrUgaFA3g3bIlCR95IlEi6JWiQgxcRQivgsqo/CNdDJMoyByLAVwkCR6kk02gbC1JjAhojgjoBo3EIRA4JjnkRinHbHgy8GAupJdV7esvuWIN9H3qwlk72wgF1XH1M9dpzBMvD5NLGVgZEAokKDnoTWC4wxRRrABqgG8m4Prn743T6uSCKTMnZEo85lVnL01oyMVcmhIcEPN5IlXKmYVM+u6550OcfOKvWIt1Ixi+1VQmIP3csqJolP9Mk0PDFl4MVzp+2daLSIXGiVwbdGoM5XcJlcWS5ZA7ER+7pn3YMFdveo0QB6kczTA16YzgZzQFIRu6sP4LHogozkOXWxSwWxeFqR1nMv0iIs1oYRK0S8XA2LSilmG7uPWmZGCLoCx6lp2Ef08JEoaKQAuo4qZlNjztoALYUaPZ/uyVQNbLUpaRjyS+uCu2TOzrjML/VaBgNtQNy9JmbS7cw/mN+BVDTnqa56kA8bvAK0hkriF53o/oZKUyKFZ+kfUiQVLeDaCm29GJHo/XVXnBsNy9wownBZAJpCKVbtTE6+Vo2dweFryoQ6DmeweaCrqKjYKCg62zV6ajBQTUXn2qCXF2TatmJKHQQr4VxGr5bsefrZPR+uu+X907ZcKY0EkIzX1D+GyPilyxxRJQf3H2tvLGfqoioGmxGcah6btMy0qk/BBivNuJhw7DgFDWoZhRIRxsCjaTGeXiWZm6tBSynoIgH17lAkCAjjYXlZJx5fO9xvV9hH7HbOyEhj5cGals7JUZjB9ZHuXpC7Cat7jqOpbApaBiuVEj1LadMo6RCLioxdU2R8LuFcbCLXYCvsCMN+XHtD53B/51T7wZqaqfZaQnVxjkG7nb1YcGY0VZ8EVXwBywBIQJnECwNSlVcj9hZdY9x5dch8DY/Yiogtgrn/YMNBfOfXx9pr97cfrO0nBLohDY8mXlhkFOKOAlsd0wfyiwV1kI0KUUk2PgDXqVR17PRI1CIsvckV2KsQmo8gorizpKWsv9wZyJvt8tFlXOrO0MU6/AGHQ90zUEQloVX17GIvXFS8Q1BEEt+6/DzJHrfqpjzXkBuLtUxgnS61O8910x13gDBRn1J/G2oxIldjFYGj1TFdKohNIdUVq8Rs48vPIXQXIC454ya3y5WndrmW3bRmd3Jc+K1Ic8+lpJzXN++uMM8E3Edne2JOvHf366/fk74+PvRiLVR4bFJaEvIXGx78tIKlkdlS2Okh5934CWZLvkXtUg8dfTIMFR5+kTbqwsE9Bq5NSRfvvOD2adf2475mNjnVAfWayL/qki/sdoOyex1djPQfKZSV598I0dlNpWfaEZWJRSTq5TS4wSlhm2G6zIqcXojDF357O2f4WG2lhVmOVectCUddBtI2+tC5udztpM1hf92BN5UktrQKmcGjaU3avJEXvM/HI+6t6wAJT5vLEiN8f407HJUHcPnZcpMCq3ZuTQhSXBi8eRGyfiNRRvPw6CmkWy/+pHLbtZV4/NQMU2EZdAZe2xYxp8NW3PL000/fu2JlwhxrxPI9t9K5NCkXk2vgg+lhfxPw5BssNcfwiFpHCpTadcMdsYik31LYW9jb21tYWIi5Zd369Xue3Xilj8HgyrRkBgsQGBG+v1u30IyKfDz+QD/zSFSFw+nGbst86eez2tO9hRiMSKsVicg+H4vugxkyJVLivSBfkBqHugRWbRjJP3amocTMmRAqeop7f/msx4Cxeng8ZU5ODldDzKXxJLkGHkPGryum7IpHXRoRu/eWNdQk1pZw9jXXF2KUXg85Zx4MOgVkUVgwkMK+RkDdmZpwmQ8QtxKEZfllbc3HRWQy2Zqjz/kDsBhNAsCUOqqR9Ehq5GU/5EQor3UMVozREUf1xEV8OT5vyo4iowDc+UFWBOofIXTbGlf1u2Q9IjStvDk2pD0RI/qasis9KxT1zxGetipyvYdX89FZqTJIp2fQkZN983NZaWH/+LnzwgXxt6B//bhLSSQyaF6Yf3dW5L/8UWBhx4Znvk4xeL0aGEDfujJubvg/ICjP4lNXII+aVoZe2rLLd/3yHf0NKw5yehD21oQAAAAASUVORK5CYII=")
#Include "%A_ScriptDir%\..\nm_image_assets\offset\bitmaps.ahk"



; ▰▰▰▰▰▰▰▰▰▰▰▰
; INITIALISE VARIABLES
; ▰▰▰▰▰▰▰▰▰▰▰▰


; INFO FROM MAIN SCRIPT
; status_changes format: (A_Min*60+A_Sec+1):status_number (0 = other, 1 = gathering, 2 = converting)
status_changes := Map()

; stats format: number:[string, value]
stats := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0]]

; backpack_values format: A_Min*60+A_Sec:percent
backpack_values := Map()



; OCR TEST
; check that classes needed for OCR function exist and can be created
ocr_enabled := 1
ocr_language := ""
if (ocr_enabled = 1)
{
	list := ocr("ShowAvailableLanguages")
	for lang in ["ko","en-"] ; priority list
	{
		Loop Parse list, "`n", "`r"
		{
			if (InStr(A_LoopField, lang) = 1)
			{
				ocr_language := A_LoopField
				break 2
			}
		}
	}
	if (ocr_language = "")
		if ((ocr_language := SubStr(list, 1, InStr(list, "`n")-1)) = "")
			msgbox "No OCR supporting languages are installed on your system! Please follow the Knowledge Base guide to install a supported language as a secondary language on Windows.", "WARNING!!", 0x1030
}


; HONEY MONITORING
; honey_values format: (A_Min):value
honey_values := Map()

; obtain start honey
start_honey := ocr_enabled ? DetectHoney() : 0

; honey_12h format: (minutes DIV 4):value
honey_12h := Map()
honey_12h[180] := start_honey


; BUFF MONITORING
; buff_values format: buff:{time_coefficient:value}
(buff_values := Map()).CaseSense := 0
for v in ["haste","melody","redboost","blueboost","whiteboost","focus","bombcombo","balloonaura","clock","jbshare","babylove","inspire","bear","pollenmark","honeymark","festivemark","popstar","comforting","motivating","satisfying","refreshing","invigorating","blessing","bloat","guiding","mondo","reindeerfetch","tideblessing"]
	buff_values[v] := Map()

; buff_characters format: character:pBM
buff_characters := Map()
buff_characters[0] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAKCAAAAAC2kKDSAAAAAnRSTlMAAHaTzTgAAAA9SURBVHgBATIAzf8BAADzAAAA8wAAAAAAAAAA8wAAAAIAAAAAAgAAAAACAAAAAAAAAAAAAADzAAABAADzAIAxBMg7bpCUAAAAAElFTkSuQmCC")
buff_characters[1] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAIAAAAMCAAAAABt1zOIAAAAAnRSTlMAAHaTzTgAAAACYktHRAD/h4/MvwAAABZJREFUeAFjYPjM+JmBgeEzEwMDLgQAWo0C7U3u8hAAAAAASUVORK5CYII=")
buff_characters[2] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAALCAAAAAB9zHN3AAAAAnRSTlMAAHaTzTgAAABCSURBVHgBATcAyP8BAPMAAADzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPMAAADzAAAA8wAAAPMAAAAB8wAAAAIAAAAAtc8GqohTl5oAAAAASUVORK5CYII=")
buff_characters[3] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAKCAAAAAC2kKDSAAAAAnRSTlMAAHaTzTgAAAA9SURBVHgBATIAzf8BAPMAAAAAAAAAAAAAAAAAAAAAAAAAAADzAAAAAAAAAAAAAAAAAAAAAPMAAAABAPMAAFILA8/B68+8AAAAAElFTkSuQmCC")
buff_characters[4] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAGCAAAAADBUmCpAAAAAnRSTlMAAHaTzTgAAAApSURBVHgBAR4A4f8AAAAA8wAAAAAAAAAA8wAAAPMAAALzAAAAAfMAAABBtgTDARckPAAAAABJRU5ErkJggg==")
buff_characters[5] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAALCAAAAAB9zHN3AAAAAnRSTlMAAHaTzTgAAABCSURBVHgBATcAyP8B8wAAAAIAAAAAAPMAAAACAAAAAAHzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHzAAAAgmID1KbRt+YAAAAASUVORK5CYII=")
buff_characters[6] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAJCAAAAAAwBNJ8AAAAAnRSTlMAAHaTzTgAAAA4SURBVHgBAS0A0v8AAAAA8wAAAPMAAADzAAACAAAAAAEA8wAAAPPzAAAA8wAAAAAA8wAAAQAA8wC5oAiQ09KYngAAAABJRU5ErkJggg==")
buff_characters[7] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAMCAAAAABgyUPPAAAAAnRSTlMAAHaTzTgAAABHSURBVHgBATwAw/8B8wAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8wIAAAAAAgAAAABDdgHu70cIeQAAAABJRU5ErkJggg==")
buff_characters[8] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAKCAAAAAC2kKDSAAAAAnRSTlMAAHaTzTgAAAA9SURBVHgBATIAzf8BAADzAAAA8wAAAgAAAAABAPMAAAEAAPMAAADzAAAAAAAAAADzAAAAAADzAAABAADzALv5B59oKTe0AAAAAElFTkSuQmCC")
buff_characters[9] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAKCAAAAAC2kKDSAAAAAnRSTlMAAHaTzTgAAAA9SURBVHgBATIAzf8BAADzAAAA8wAAAPMAAAAAAPMAAAEAAPMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA87TcBbXcfy3eAAAAAElFTkSuQmCC")

; buff_bitmaps format: pBMBuff:pBM
;0xffe81a06:"flames",0xfff99d27:"tabby",0xff86ebff:"polar"
(buff_bitmaps := Map()).CaseSense := 0
buff_bitmaps["pBMHaste"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMHaste"]), Gdip_GraphicsClear(pGraphics, 0xfff0f0f0), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMBoost"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMBoost"]), Gdip_GraphicsClear(pGraphics, 0xff90ff8e), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMFocus"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMFocus"]), Gdip_GraphicsClear(pGraphics, 0xff22ff06), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMBombCombo"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMBombCombo"]), Gdip_GraphicsClear(pGraphics, 0xff272727), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMBalloonAura"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMBalloonAura"]), Gdip_GraphicsClear(pGraphics, 0xfffafd38), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMClock"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMClock"]), Gdip_GraphicsClear(pGraphics, 0xffe2ac35), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMJBShare"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMJBShare"]), Gdip_GraphicsClear(pGraphics, 0xfff9ccff), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMBabyLove"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMBabyLove"]), Gdip_GraphicsClear(pGraphics, 0xff8de4f3), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMPrecision"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMPrecision"]), Gdip_GraphicsClear(pGraphics, 0xff8f4eb4), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMInspire"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMInspire"]), Gdip_GraphicsClear(pGraphics, 0xfff4ef14), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMReindeerFetch"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMReindeerFetch"]), Gdip_GraphicsClear(pGraphics, 0xffcc2c2c), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMScience"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMScience"]), Gdip_GraphicsClear(pGraphics, 0xfff4a90d), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMBloat"] := Gdip_CreateBitmap(4,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMBloat"]), Gdip_GraphicsClear(pGraphics, 0xff4880cc), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMComforting"] := Gdip_CreateBitmap(3,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMComforting"]), Gdip_GraphicsClear(pGraphics, 0xff7e9eb3), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMMotivating"] := Gdip_CreateBitmap(3,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMMotivating"]), Gdip_GraphicsClear(pGraphics, 0xff937db3), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMSatisfying"] := Gdip_CreateBitmap(3,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMSatisfying"]), Gdip_GraphicsClear(pGraphics, 0xffb398a7), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMRefreshing"] := Gdip_CreateBitmap(3,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMRefreshing"]), Gdip_GraphicsClear(pGraphics, 0xff78b375), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMInvigorating"] := Gdip_CreateBitmap(3,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMInvigorating"]), Gdip_GraphicsClear(pGraphics, 0xffb35951), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMMark"] := Gdip_CreateBitmap(5,1)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMMark"]), Gdip_GraphicsClear(pGraphics, 0xff3d713b), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMMelody"] := Gdip_CreateBitmap(3,2)
pGraphics := Gdip_GraphicsFromImage(buff_bitmaps["pBMMelody"]), Gdip_GraphicsClear(pGraphics, 0xff242424), Gdip_DeleteGraphics(pGraphics)
buff_bitmaps["pBMTideBlessing"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAABAAAAALAgMAAAALjOWqAAAACVBMVEUAAACRwv3z8/MeJ4W2AAAAAXRSTlMAQObYZgAAAEJJREFUeAEBNwDI/wAAAACAAAAAAIAAAAAAgAAAAACAAAAgAIAAAAgAgAAAAACAAAAAAIAAAAAAgAAAAAAAAFVVVVWUCQX9+4UpmQAAAABJRU5ErkJggg==")
buff_bitmaps["pBMMondo"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACYAAAARCAMAAACGnC6JAAAAOVBMVEUAAAC+oq30w1L0w1HzxFbzxFXzxFnwx2rvyW/szIHn0Jnl0aTg1rvg1rzc2tHc2tLa29vZ3OHZ3OLV3/OdAAAAAXRSTlMAQObYZgAAAqJJREFUeAEBlwJo/QAAAAAAAAAAAAMCAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUGBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcJCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsMCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8QDQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABERDgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABISEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAbbRAQaOZh5MAAAAAElFTkSuQmCC")
buff_bitmaps["pBMFestiveMark"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAsAAAABBAMAAAD6GUlzAAAAIVBMVEU7QDNvQzmtSDmySTizSTm2STi4STi5STi5TDsyWDA9cTvalFRvAAAAEklEQVR4AQEHAPj/AKkBh0I2UAegAfr1a/UAAAAAAElFTkSuQmCC")
buff_bitmaps["pBMHoneyMark"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAkAAAAEBAMAAACuIQj9AAAAMFBMVEUcJhYXKxsXKxwZLx0xNRc0YDI1YTM4ZzZ3axp8cBs9cTueih2vlx7WtiDYtyHsxyJxibSYAAAAI0lEQVR4AQEYAOf/AKqqcwvwAKqqUZ7wAKqqUY3wAKqqYkzwjf0MCuMjsQoAAAAASUVORK5CYII=")
buff_bitmaps["pBMPollenMark"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAoAAAAFCAMAAABLuo1aAAAAQlBMVEUPHBYRHRcUIhgUJRoaMB0pMiQcNSAuNyYfOSI5QCwnSChdYD81YzQ2ZDQ5ajg8bjo8cDo9cTuEglSknWS9tHLk1YZKij78AAAAQklEQVR4AQE3AMj/ABERERERDggCCxQAERERERERDAYABQAREREREREPCgMBABEREREREAoDBxIAERERERENBAkTFUoXAq+Dil5HAAAAAElFTkSuQmCC")
buff_bitmaps["pBMGuiding"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAwAAAACCAMAAABboc2lAAAAOVBMVEWPf02QgE6RgE+SgU/SuHDTunHUunHhxnjhx3niyHrjyXvky3zn0oPp1ITq1obq2Yju4o7u44/v5JDO0m0EAAAAJUlEQVR4AQEaAOX/ABIQDAgEAwEECQ0REgASDgoHBQACBgcLDxIMQwDt+rZJwwAAAABJRU5ErkJggg==")
buff_bitmaps["pBMBearBrown"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAwAAAABBAMAAAAYxVIKAAAAD1BMVEUwLi1STEihfVWzpZbQvKTt7OCuAAAAEklEQVR4AQEHAPj/ACJDEAE0IgLvAM1oKEJeAAAAAElFTkSuQmCC")
buff_bitmaps["pBMBearBlack"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAABBAMAAAAcMII3AAAAFVBMVEUwLi1TTD9lbHNmbXN5enW5oXHQuYJDhTsuAAAAE0lEQVR4AQEIAPf/ACNGUQAVZDIFbwFmjB55HwAAAABJRU5ErkJggg==")
buff_bitmaps["pBMBearPanda"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAABAAAAABBAMAAAAlVzNsAAAAGFBMVEUwLi1VU1G9u7m/vLXAvbbPzcXg3dfq6OXkYMPeAAAAFElEQVR4AQEJAPb/AENWchABJ2U0CO4B3TmcTKkAAAAASUVORK5CYII=")
buff_bitmaps["pBMBearPolar"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAABBAMAAAAcMII3AAAAElBMVEUwLi1JSUqOlZy0vMbY2dnc3NtuftTJAAAAE0lEQVR4AQEIAPf/AFVDIQASNFUFhQFVdZ1AegAAAABJRU5ErkJggg==")
buff_bitmaps["pBMBearGummy"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAABBAMAAAAcMII3AAAAFVBMVEWYprGDrKWisd+hst+ctNtFyJ4xz5uqDngAAAAAE0lEQVR4AQEIAPf/ACNAFWZRBDIFqwFmOuySwwAAAABJRU5ErkJggg==")
buff_bitmaps["pBMBearScience"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAABBAMAAAAcMII3AAAAFVBMVEUwLi1TTD+zjUy0jky8l1W5oXHevny+g95vAAAAE0lEQVR4AQEIAPf/ACNGUQAVZDIFbwFmjB55HwAAAABJRU5ErkJggg==")
buff_bitmaps["pBMBearMother"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAABAAAAABBAMAAAAlVzNsAAAAJFBMVEVBNRlDNxtTRid8b0avoG69r22+sG7Qw4PRw4Te0Jbk153m2Z5VNHxxAAAAFElEQVR4AQEJAPb/AFVouTECSnZVDPsCv+2QpmwAAAAASUVORK5CYII=")
buff_bitmaps["pBMBlessing"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAAMAgMAAAAv7mRJAAAACVBMVEUAAADIyjzz8/PLJx4rAAAAAXRSTlMAQObYZgAAAEdJREFUeAEBPADD/wAAgAAAAAAAgAAAACIAAAAACAAAAAAIAAAAACIAAAAAAIAAAACAAAAAAgAgAAAAAAAAAAAAAAAAVVVVUGMZA8YHWu2lAAAAAElFTkSuQmCC")



; enable receiving of messages
; OnMessage(0x5554, SetStatus, 255)
; OnMessage(0x5555, IncrementStat, 255)
OnMessage(0x5556, SetAbility, 255)
OnMessage(0x5557, SetBackpack, 255)



; ▰▰▰▰▰▰▰▰
; STARTUP REPORT
; ▰▰▰▰▰▰▰▰


; OBTAIN DATA
; detect OS version
os_version := "cant detect os"
for objItem in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_OperatingSystem")
	os_version := Trim(StrReplace(StrReplace(StrReplace(StrReplace(objItem.Caption, "Microsoft"), "Майкрософт"), "مايكروسوفت"), "微软"))

; obtain natro version and other options (if exist)
if ((A_Args.Length > 0) && (natro_version := A_Args[1]))
{
	; read information from statconfig.ini
	Loop 3
		FieldName%A_Index% := IniRead("statconfig.ini", "Gather", "FieldName" A_Index, "N/A")
	HiveSlot := IniRead("statconfig.ini", "Settings", "HiveSlot", "N/A")

	global HotkeyWhile2, HotkeyWhile3, HotkeyWhile4, HotkeyWhile5, HotkeyWhile6, HotkeyWhile7
	Loop 6
	{
		i := A_Index+1
		HotkeyWhile%i% := IniRead("statconfig.ini", "Boost", "HotkeyWhile" i, "Never")
		consumables .= (HotkeyWhile%i% != "Never") ? (((StrLen(consumables) = 0) ? "" : ", " ) . "#" . i) : ""
	}

	PlanterMode := IniRead("statconfig.ini", "Planters", "PlanterMode", 0)
	MaxAllowedPlanters := IniRead("statconfig.ini", "Planters", "MaxAllowedPlanters", 0)
}

; FORM MESSAGE
message := "Hourly Reports will start sending in **" DurationFromSeconds(60*(59-A_Min)+(60-A_Sec), "m'm 's's'") "**\n"
	. "Version: **StatMonitor v" version "**\n"
	. "Detected OS: **" os_version "**\n"
	. ("OCR Status: MEMORYREAD")

message .= (IsSet(natro_version) ? "\n\nMacro: **Natro v" natro_version "**\n"
	. "Gather Fields: **" FieldName1 ", " FieldName2 ", " FieldName3 "**\n"
	. "Consumables: **" ((StrLen(consumables) = 0) ? "None" : consumables) "**\n"
	. "Planters: **" ((PlanterMode = 2) ? ("ON (" MaxAllowedPlanters " Planters)") : (PlanterMode = 1) ? ("ON (MANUAL)") : "OFF") "**\n"
	. "Hive Slot: **" HiveSlot "**"
	: "")


; SEND STARTUP REPORT
; create postdata
postdata :=
(
'
{
	"embeds": [{
		"title": "[' A_Hour ':' A_Min ':' A_Sec '] Startup Report",
		"description": "' message '",
		"color": "14052794"
	}]
}
'
)

; post to status
Send_WM_COPYDATA(postdata, "Status.ahk ahk_class AutoHotkey")



; ▰▰▰▰▰▰▰▰▰
; CREATE TEMPLATE
; ▰▰▰▰▰▰▰▰▰


; DRAW REGIONS
; draw background (fill with rounded dark grey rectangle)
pBrush := Gdip_BrushCreateSolid(0xff121212), Gdip_FillRoundedRectangle(G, pBrush, -1, -1, w+1, h+1, 60), Gdip_DeleteBrush(pBrush)

; regions format: region_name:[x,y,w,h]
regions := Map("honey/sec", [120,120,4080,1080]
	, "stats", [w-1560-120,120,1560,h-240]
	, "backpack", [120,240+1080,4080,678]
	, "buffs", [120,360+1758,4080,h-480-1758])

stat_regions := Map("lasthour", [regions["stats"][1]+100,regions["stats"][2]+100,regions["stats"][3]-200,1206]
	, "session", [regions["stats"][1]+100,regions["stats"][2]+1406,regions["stats"][3]-200,1289]
	, "buffs", [regions["stats"][1]+100,regions["stats"][2]+2795,regions["stats"][3]-200,720]
	, "planters", [regions["stats"][1]+100,regions["stats"][2]+3615,regions["stats"][3]-200,495]
	, "stats", [regions["stats"][1]+100,regions["stats"][2]+4220,regions["stats"][3]-200,620]
	, "info", [regions["stats"][1]+100,regions["stats"][2]+4940,regions["stats"][3]-200,regions["stats"][4]-4940-100])

; draw region backgrounds (dark grey background for each region)
for k,v in regions
{
	pPen := Gdip_CreatePen(0xff282628, 10), Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20), Gdip_DeletePen(pPen)
	pBrush := Gdip_BrushCreateSolid(0xff201e20), Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20), Gdip_DeleteBrush(pBrush)
}
for k,v in stat_regions
{
	pPen := Gdip_CreatePen(0xff353335, 10), Gdip_DrawRoundedRectangle(G, pPen, v[1], v[2], v[3], v[4], 20), Gdip_DeletePen(pPen)
	pBrush := Gdip_BrushCreateSolid(0xff2c2a2c), Gdip_FillRoundedRectangle(G, pBrush, v[1], v[2], v[3], v[4], 20), Gdip_DeleteBrush(pBrush)
}

; draw region titles
Gdip_TextToGraphics(G, "HONEY/SEC", "s64 Center Bold cffffffff x" regions["honey/sec"][1] " y" regions["honey/sec"][2]+16, "Segoe UI", regions["honey/sec"][3])
Gdip_TextToGraphics(G, "BUFF UPTIME", "s64 Center Bold cffffffff x" regions["buffs"][1] " y" regions["buffs"][2]+16, "Segoe UI", regions["buffs"][3])
Gdip_TextToGraphics(G, "BACKPACK", "s64 Center Bold cffffffff x" regions["backpack"][1] " y" regions["backpack"][2]+16, "Segoe UI", regions["backpack"][3])


; DRAW GRAPHS AND OTHER ASSETS
; declare coordinate bounds for each graph
graph_regions := Map("honey/sec", [regions["honey/sec"][1]+320,regions["honey/sec"][2]+130,3600,800]
	, "backpack", [regions["backpack"][1]+320,regions["backpack"][2]+130,3600,400]
	, "boost", [regions["buffs"][1]+320,regions["buffs"][2]+135,3600,280]
	, "haste", [regions["buffs"][1]+320,regions["buffs"][2]+435,3600,280]
	, "focus", [regions["buffs"][1]+320,regions["buffs"][2]+735,3600,280]
	, "bombcombo", [regions["buffs"][1]+320,regions["buffs"][2]+1035,3600,280]
	, "balloonaura", [regions["buffs"][1]+320,regions["buffs"][2]+1335,3600,280]
	, "inspire", [regions["buffs"][1]+320,regions["buffs"][2]+1635,3600,280]
	, "reindeerfetch", [regions["buffs"][1]+320,regions["buffs"][2]+1935,3600,280]
	, "honeymark", [regions["buffs"][1]+320,regions["buffs"][2]+2235,3600,120]
	, "pollenmark", [regions["buffs"][1]+320,regions["buffs"][2]+2375,3600,120]
	, "festivemark", [regions["buffs"][1]+320,regions["buffs"][2]+2515,3600,120]
	, "popstar", [regions["buffs"][1]+320,regions["buffs"][2]+2655,3600,110]
	, "melody", [regions["buffs"][1]+320,regions["buffs"][2]+2785,3600,110]
	, "bear", [regions["buffs"][1]+320,regions["buffs"][2]+2915,3600,110]
	, "babylove", [regions["buffs"][1]+320,regions["buffs"][2]+3045,3600,110]
	, "jbshare", [regions["buffs"][1]+320,regions["buffs"][2]+3175,3600,110]
	, "guiding", [regions["buffs"][1]+320,regions["buffs"][2]+3305,3600,110]
	, "honey", [stat_regions["lasthour"][1]+200,stat_regions["lasthour"][2]+650,1080,480]
	, "honey12h", [stat_regions["session"][1]+200,stat_regions["session"][2]+734,1080,480])

; draw graph grids and axes
pPen := Gdip_CreatePen(0x40c0c0f0, 4)
Loop 61
{
	n := (Mod(A_Index, 10) = 1) ? 45 : 25
	Gdip_DrawLine(G, pPen, graph_regions["honey/sec"][1]+graph_regions["honey/sec"][3]*(A_Index-1)//60, graph_regions["honey/sec"][2]+graph_regions["honey/sec"][4]+20, graph_regions["honey/sec"][1]+graph_regions["honey/sec"][3]*(A_Index-1)//60, graph_regions["honey/sec"][2]+graph_regions["honey/sec"][4]+20+n)
	Gdip_DrawLine(G, pPen, graph_regions["backpack"][1]+graph_regions["backpack"][3]*(A_Index-1)//60, graph_regions["backpack"][2]+graph_regions["backpack"][4]+20, graph_regions["backpack"][1]+graph_regions["backpack"][3]*(A_Index-1)//60, graph_regions["backpack"][2]+graph_regions["backpack"][4]+20+n)
	Gdip_DrawLine(G, pPen, graph_regions["boost"][1]+graph_regions["boost"][3]*(A_Index-1)//60, regions["buffs"][2]+regions["buffs"][4]-125, graph_regions["boost"][1]+graph_regions["boost"][3]*(A_Index-1)//60, regions["buffs"][2]+regions["buffs"][4]-125+n)

	if (Mod(A_Index, 10) = 1)
	{
		i := A_Index
		for k,v in graph_regions
			Gdip_DrawLine(G, pPen, v[1]+v[3]*(i-1)//60, v[2], v[1]+v[3]*(i-1)//60, v[2]+v[4])
	}

	if (A_Index < 5 && A_Index > 1)
		y := regions["honey/sec"][2]+130+(regions["honey/sec"][4]-280)*(A_Index-1)//4, Gdip_DrawLine(G, pPen, regions["honey/sec"][1]+260, y, regions["honey/sec"][1]+regions["honey/sec"][3]-100, y)
}
for k,v in graph_regions
{
	if ((v[4] = 280) || (v[4] = 400))
		Gdip_DrawLine(G, pPen, v[1]-60, v[2]+v[4]//2, v[1]+v[3]+60, v[2]+v[4]//2)
	else if (v[4] = 480)
		Loop 3
			Gdip_DrawLine(G, pPen, v[1]-60, v[2]+v[4]*A_Index//4, v[1]+v[3]+60, v[2]+v[4]*A_Index//4)
}

; draw buff images and graph backgrounds
pBrush := Gdip_BrushCreateSolid(0x80141414)
for k,v in graph_regions
{
	Gdip_FillRectangle(G, pBrush, v[1]-60, v[2], v[3]+120, v[4])

	if bitmaps.Has("pBM" k)
	{
		Gdip_DrawImage(G, bitmaps["pBM" k], regions["buffs"][1]+75, v[2]+v[4]//2-55, 110, 110), Gdip_DisposeImage(bitmaps["pBM" k])
		Gdip_DrawLine(G, pPen, v[1]-60, v[2]+v[4]+10, v[1]+v[3]+60, v[2]+v[4]+10)
	}
}
Gdip_DeleteBrush(pBrush), Gdip_DeletePen(pPen)
if (ocr_enabled = 0)
{
	pBrush := Gdip_BrushCreateSolid(0x40cc0000)
	for k,v in ["honey/sec","honey","honey12h"]
		Gdip_FillRectangle(G, pBrush, graph_regions[v][1], graph_regions[v][2], graph_regions[v][3], graph_regions[v][4])
	Gdip_DeleteBrush(pBrush)
}

; draw static buff images
for k,v in ["clock","blessing","bloat","tideblessing","mondo"]
	Gdip_DrawImage(G, bitmaps["pBM" v], stat_regions["buffs"][1]+48+(A_Index-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+124, 220, 220), Gdip_DisposeImage(bitmaps["pBM" v])

; leave pBM as final graph template
Gdip_DeleteGraphics(G)

; ▰▰▰▰
; TESTING
; ▰▰▰▰
/*
start_time := A_Now
status_changes[A_Min*60+A_Sec] := 0

honey_values[0] := 170000000000000
honey_12h[180] := 170000000000000

Loop 60
	honey_values[A_Index] := honey_values[A_Index-1] + ((Mod(A_Index, 15) < 4) ? 100000000000 : 10000000000)

Loop 3601
{
	if (Mod(A_Index, 5) = 1)
		x := Random(0, 6)
	backpack_values[A_Index-1] := ((Mod(A_Index, 900) < 240) ? 100 : 10) - x
}

status_changes := Map(0,2, 180,1 ,780,2, 1080,1, 1680,2, 1784,3 ,1832,2, 1980,1, 2100,3, 2120,1, 2580,2, 2880,1, 3480,2)

stats[1][2] := 1000
stats[6][2] := 100

for k,v in buff_values
{
	v[0] := 2
	Loop 600
	{
		x := Random(0, (k = "redboost" || k = "whiteboost" || k = "precision") ? 2 : 10)
		x := (x > 6) ? 10 : x
		v[A_Index] := Abs(x-v[A_Index-1]) > 4 ? 10 : x
	}
}

Loop 601
{
	buff_values["tideblessing"][A_Index-1] := "1.10"
	buff_values["bloat"][A_Index-1] := "6.00"
}
buff_values["comforting"][600] := 100

start_honey := 170000000000000
start_time := DateAdd(start_time, -1, "Hours")

SendHourlyReport()
KeyWait "F4", "D"
Reload
ExitApp
*/

; ▰▰▰▰▰
; MAIN LOOP
; ▰▰▰▰▰

; startup finished, set start time
start_time := A_Now
status_changes[A_Min*60+A_Sec] := 0

; set emergency switches in case of time error
last_honey := last_report := time := 0

; indefinite loop of detection and reporting
Loop
{
	; obtain current time and wait until next 6-second interval
	DllCall("GetSystemTimeAsFileTime", "int64p", &time)
	Sleep (60000000-Mod(time, 60000000))//10000 + 100
	time_value := (60*A_Min+A_Sec)//6

	; detect buffs every 6 seconds
	DetectBuffs()

	; detect honey every minute if ocr is enabled
	if ((ocr_enabled = 1) && ((Mod(time_value, 10) = 0) || (last_honey && time > last_honey + 580000000)))
	{
		DetectHoney()
		DllCall("GetSystemTimeAsFileTime", "int64p", &time)
		last_honey := time
	}
	; send report every hour
	if ((time_value = 0) || (last_report && time > last_report + 35980000000))
	{
		;SendHourlyReport()
		;DllCall("GetSystemTimeAsFileTime", "int64p", &time)
		;last_report := time
	}
}



; ▰▰▰▰▰
; FUNCTIONS
; ▰▰▰▰▰

/********************************************************************************************
* @description: detects buffs in BSS and updates the relevant arrays with current buff values
* @returns: (string) list of buffs and their values (buff:value) delimited by new lines
* @author SP
********************************************************************************************/
DetectBuffs()
{
	global buff_values, buff_characters, buff_bitmaps

	; ; set time value
	; time_value := (60*A_Min+A_Sec)//6
	; i := (time_value = 0) ? 600 : time_value

	; ; check roblox window exists
	; hwnd := GetRobloxHWND()
	; GetRobloxClientPos(hwnd), offsetY := GetYOffset(hwnd)
	; if !(windowHeight >= 500)
	; {
	; 	for k,v in buff_values
	; 	{
	; 		v[i] := 0
	; 		str .= k ":" 0 "`n"
	; 	}
	; 	return str
	; }

	; ; create bitmap for buffs
	; pBMArea := Gdip_BitmapFromScreen(windowX "|" windowY+offsetY+30 "|" windowWidth "|50")

	; ; basic on/off
	; for v in ["jbshare","babylove","festivemark","guiding"]
	; 	buff_values[v][i] := (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], , , 30, , , InStr(v, "mark") ? 6 : (v = "guiding") ? 10 : 0, , 7) = 1)

	; ; bear morphs
	; buff_values["bear"][i] := 0
	; for v in ["Brown","Black","Panda","Polar","Gummy","Science","Mother"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBMBear" v], , , 43, , 45, 8, , 2) = 1)
	; 	{
	; 		buff_values["bear"][i] := 1
	; 		break
	; 	}
	; }

	; ; basic x1-x10
	; for v in ["focus","bombcombo","balloonaura","clock","honeymark","pollenmark","reindeerfetch"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, , InStr(v, "mark") ? 20 : 30, , 50, InStr(v, "mark") ? 6 : 0, , 7) != 1)
	; 	{
	; 		buff_values[v][i] := 0
	; 		continue
	; 	}

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	Loop 9
	; 	{
	; 		if (Gdip_ImageSearch(pBMArea, buff_characters[10-A_Index], , x-20, 15, x, 50) = 1)
	; 		{
	; 			buff_values[v][i] := (A_Index = 9) ? 10 : 10 - A_Index
	; 			break
	; 		}
	; 		if (A_Index = 9)
	; 			buff_values[v][i] := 1
	; 	}
	; }

	; ; mondo
	; for v in ["mondo"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, , 20, , 46, 21, , 7) != 1)
	; 	{
	; 		buff_values[v][i] := 0
	; 		continue
	; 	}

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	Loop 9
	; 	{
	; 		if (Gdip_ImageSearch(pBMArea, buff_characters[10-A_Index], , x+16, 20, x+36, 46) = 1)
	; 		{
	; 			buff_values[v][i] := (A_Index = 9) ? 10 : 10 - A_Index
	; 			break
	; 		}
	; 		if (A_Index = 9)
	; 			buff_values[v][i] := 1
	; 	}
	; }

	; ; melody / haste
	; x := 0
	; Loop 3 ; melody, haste, coconut haste
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBMHaste"], &list, x, 30, , , , , 6) != 1)
	; 		break

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	if ((s := Gdip_ImageSearch(pBMArea, buff_bitmaps["pBMMelody"], , x+2, 15, x+34, 40, 12)) != 1)
	; 	{
	; 		if !buff_values["haste"].Has(i)
	; 		{
	; 			Loop 9
	; 			{
	; 				if (Gdip_ImageSearch(pBMArea, buff_characters[10-A_Index], , x+6, 15, x+44, 50) = 1)
	; 				{
	; 					buff_values["haste"][i] := (A_Index = 9) ? 10 : 10 - A_Index
	; 					break
	; 				}
	; 				if (A_Index = 9)
	; 					buff_values["haste"][i] := 1
	; 			}
	; 		}
	; 	}
	; 	else if (s = 1)
	; 		buff_values["melody"][i] := 1

	; 	x += 44
	; }
	; for v in ["melody","haste"]
	; 	if !buff_values[v].Has(i)
	; 		buff_values[v][i] := 0

	; ; colour boost x1-x10
	; x := windowWidth
	; Loop 3
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBMBoost"], &list, , 30, x, , , , 7) != 1)
	; 		break

	; 	x := SubStr(list, 1, InStr(list, ",")-1)
	; 	y := SubStr(list, InStr(list, ",")+1)

	; 	; obtain colour of boost buff
	; 	pBMPxRed := Gdip_CreateBitmap(1,2), pBMPxBlue := Gdip_CreateBitmap(1,2)
	; 	pGRed := Gdip_GraphicsFromImage(pBMPxRed), pGBlue := Gdip_GraphicsFromImage(pBMPxBlue)
	; 	Gdip_GraphicsClear(pGRed, 0xffe46156), Gdip_GraphicsClear(pGBlue, 0xff56a4e4)
	; 	Gdip_DeleteGraphics(pGRed), Gdip_DeleteGraphics(pGBlue)
	; 	v := (Gdip_ImageSearch(pBMArea, pBMPxRed, , x-30, 15, x-4, 34, 20, , , 2) = 2) ? "redboost"
	; 		: (Gdip_ImageSearch(pBMArea, pBMPxBlue, , x-30, 15, x-4, 34, 20, , , 2) = 2) ? "blueboost"
	; 		: "whiteboost"
	; 	Gdip_DisposeImage(pBMPxRed), Gdip_DisposeImage(pBMPxBlue)

	; 	; find stack number
	; 	Loop 9
	; 	{
	; 		if Gdip_ImageSearch(pBMArea, buff_characters[10-A_Index], , x-20, 15, x, 50)
	; 		{
	; 			buff_values[v][i] := (A_Index = 9) ? 10 : 10 - A_Index
	; 			break
	; 		}
	; 		if (A_Index = 9)
	; 			buff_values[v][i] := 1
	; 	}

	; 	x -= 2*y-53 ; take away width of buff square to prevent duplication
	; }
	; for v in ["redboost","blueboost","whiteboost"]
	; 	if !buff_values[v].Has(i)
	; 		buff_values[v][i] := 0

	; ; 2 digit
	; for v in ["blessing","inspire"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, , 20, , , (v = "blessing") ? 21 : 0, , (v = "blessing") ? 6 : 7) != 1)
	; 	{
	; 		buff_values[v][i] := 0
	; 		continue
	; 	}

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	(digits := Map()).Default := ""

	; 	Loop 10
	; 	{
	; 		n := 10-A_Index
	; 		if ((n = 1) || (n = 3))
	; 			continue
	; 		Gdip_ImageSearch(pBMArea, buff_characters[n], &list:="", ((v = "blessing") ? x+8 : x-20), 15, ((v = "blessing") ? x+36 : x), 50, 1, , 5, 5, , "`n")
	; 		Loop Parse list, "`n"
	; 			if (A_Index & 1)
	; 				digits[Integer(A_LoopField)] := n
	; 	}

	; 	for m,n in [1,3]
	; 	{
	; 		Gdip_ImageSearch(pBMArea, buff_characters[n], &list:="", ((v = "blessing") ? x+8 : x-20), 15, ((v = "blessing") ? x+36 : x), 50, 1, , 5, 5, , "`n")
	; 		Loop Parse list, "`n"
	; 		{
	; 			if (A_Index & 1)
	; 			{
	; 				if (((n = 1) && (digits[A_LoopField - 5] = 4)) || ((n = 3) && (digits[A_LoopField - 1] = 8)))
	; 					continue
	; 				digits[Integer(A_LoopField)] := n
	; 			}
	; 		}
	; 	}

	; 	num := ""
	; 	for x,y in digits
	; 		num .= y

	; 	buff_values[v][i] := num ? Min(num, (v = "inspire" ? 50 : 100)) : 1
	; }

	; ; scaled
	; for v in ["bloat","comforting","motivating","satisfying","refreshing","invigorating"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, , 30, , , , , 6) != 1)
	; 	{
	; 		buff_values[v][i] := 0
	; 		continue
	; 	}

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, x, 6, x+38, 44) != 1)
	; 	{
	; 		buff_values[v][i] := 0
	; 		continue
	; 	}

	; 	y := SubStr(list, InStr(list, ",")+1)

	; 	buff_values[v][i] := String(Round(Min((44 - y) / 38, 1) * ((v = "bloat") ? 5 : 100) + ((v = "bloat") ? 1 : 0), (v = "bloat") ? 2 : 0))
	; }

	; ; tide
	; for v in ["tideblessing"]
	; {
	; 	if (Gdip_ImageSearch(pBMArea, buff_bitmaps["pBM" v], &list, , 30, , , , , 6) != 1)
	; 		continue

	; 	x := SubStr(list, 1, InStr(list, ",")-1)

	; 	pBM := Gdip_CreateBitmap(36, 1), Gdip_SetPixel(pBM, 0, 0, 0xff91c2fd), Gdip_SetPixel(pBM, 35, 0, 0xff91c2fd)

	; 	s := Gdip_ImageSearch(pBMArea, pBM, &list, x-16, 6, x+36, 44)
	; 	Gdip_DisposeImage(pBM)
	; 	if (s != 1)
	; 		continue

	; 	y := SubStr(list, InStr(list, ",")+1)
	; 	buff_values[v][i] := String(Round(1.01 + 0.19 * (44.3 - y) / 38, 2))
	; }

	; ; form string
	; str := ""
	; for k,v in buff_values
	; 	str .= k ":" (v.Has(i) ? v[i] : 0) "`n"

	; ; clean up and return
	; Gdip_DisposeImage(pBMArea)
	; return str
	KOCMOC_SendCommand("send_buffs")
	return KOCMOC_YieldUntilData("update_buffs")
}

KOCMOC_SendCommand(command)
{
	; write to pipe file
	PipeDir := IniRead("statconfig.ini", "Pipe", "PipeDir")
	; pipe file = PipeDir\toRoblox.pipe
	pipeFile := PipeDir "\toRoblox.pipe"
	; parse json
	f := FileRead(pipeFile)
	obj := Jxon_Load(&f)
	obj.Push(command)
	; save json to pipe file
	FileDelete(pipeFile)
	FileAppend(Jxon_Dump(obj), pipeFile)
}

KOCMOC_GetData(command)
{
	; read from pipe file
	PipeDir := IniRead("statconfig.ini", "Pipe", "PipeDir")
	pipeFile := PipeDir "\toAHK.pipe"
	; load pipe file as json
	f := FileRead(pipeFile)
	try{
		obj := Jxon_Load(&f)
	}
	catch
	{
		return 0
	}
	; overwrite pipe file
	FileDelete(pipeFile)
	; parse commands
	ret := 0
	for k,v in obj
	{
		; remove command from Array
		obj.RemoveAt(k)
		if (v["Type"] = command)
		{
			ret := v
			break
		}
		else if (v["Type"] = "set_script_status")
		{
			; process generic commands
			SetStatus(v["Status"], GetSecondOfHour())
		}
		else if (v["Type"] = "increment_stat")
		{
			; process generic commands
			IncrementStat(v["Stat"], 1)
		}
		else if (v["Type"] = "update_backpack")
		{
			SetBackpack(v["Percent"], GetSecondOfHour()) ; Percent = 0-100
		}
	}
	; save json to pipe file
	FileAppend(Jxon_Dump(obj), pipeFile)
	return ret
}

KOCMOC_YieldUntilData(command)
{
	; call KOCMOC_GetData until a return value of non-zero is received
	data := 0
	i := 0
	while (data = 0)
	{
		data := KOCMOC_GetData(command)
		i += 1
		if (i > 100){
			; write warning to log
			FileAppend("Warning: KOCMOC_YieldUntilData timed out after 100 iterations. Waiting for Command: " command "`n", "KOCMOC.log")
			i := 0
		}
		Sleep 100
	}
	return data
}

/********************************************************************
* @description: uses OCR to detect the current honey value in BSS
* @returns: (string) current honey value or (integer) 0 on failure
* @note function is a WIP, and OCR readings are not 100% reliable!
* @author SP
********************************************************************/
DetectHoney()
{
	global honey_values, start_honey, start_time, ocr_language

	; ; check roblox window exists
	; hwnd := GetRobloxHWND()
	; GetRobloxClientPos(hwnd), offsetY := GetYOffset(hwnd)
	; if !(windowHeight >= 500)
	; 	return 0

	; ; initialise array to store detected values and get bitmap and effect ready
	; detected := Map()
	; pBM := Gdip_BitmapFromScreen(windowX+windowWidth//2-241 "|" windowY+offsetY "|140|36")
	; pEffect := Gdip_CreateEffect(5,-80,30)

	; ; detect honey, enlarge image if necessary
	; Loop 25
	; {
	; 	i := A_Index
	; 	Loop 2
	; 	{
	; 		pBMNew := Gdip_ResizeBitmap(pBM, ((A_Index = 1) ? (250 + i * 20) : (750 - i * 20)), 36 + i * 4, 2)
	; 		Gdip_BitmapApplyEffect(pBMNew, pEffect)
	; 		hBM := Gdip_CreateHBITMAPFromBitmap(pBMNew)
	; 		;Gdip_SaveBitmapToFile(pBMNew, i A_Index ".png")
	; 		Gdip_DisposeImage(pBMNew)
	; 		pIRandomAccessStream := HBitmapToRandomAccessStream(hBM)
	; 		DllCall("DeleteObject", "Ptr", hBM)
	; 		try detected[v := ((StrLen((n := RegExReplace(StrReplace(StrReplace(StrReplace(StrReplace(ocr(pIRandomAccessStream, ocr_language), "o", "0"), "i", "1"), "l", "1"), "a", "4"), "\D"))) > 0) ? n : 0)] := detected.Has(v) ? [detected[v][1]+1, detected[v][2] " " i . A_Index] : [1, i . A_Index]
	; 	}
	; }

	; ; clean up
	; Gdip_DisposeImage(pBM), Gdip_DisposeEffect(pEffect)
	; DllCall("psapi.dll\EmptyWorkingSet", "UInt", -1)

	; ; evaluate current honey
	; current_honey := 0
	; for k,v in detected
	; 	if ((v[1] > 2) && (k > current_honey))
	; 		current_honey := k

	; ; update honey values array and write values to ini
	; index := (A_Min = "00") ? 60 : Integer(A_Min)
	; if current_honey
	; {
	; 	honey_values[index] := current_honey
	; 	if (FileExist("statconfig.ini") && IsSet(start_time))
	; 	{
	; 		session_time := DateDiff(A_Now, start_time, "S")
	; 		session_total := current_honey - start_honey
	; 		try IniWrite FormatNumber(session_total), "statconfig.ini", "Status", "SessionTotalHoney"
	; 		try IniWrite FormatNumber(session_total*3600/session_time), "statconfig.ini", "Status", "HoneyAverage"
	; 	}
	; 	return current_honey
	; }
	; else
	; 	return 0
	KOCMOC_SendCommand("send_honey")
	data := KOCMOC_YieldUntilData("update_honey") ; data: {"Honey": int}
	return data["Honey"]
}

/********************************************************************************************************
* @description: creates an hourly report (image) from the honey and buff arrays, then sends it to Discord
* @author SP
********************************************************************************************************/
SendHourlyReport()
{
	global pBM, regions, stat_regions, honey_values, honey_12h, backpack_values, buff_values, buff_colors, status_changes, start_time, start_honey, stats, latest_boost, latest_winds, graph_regions, version, natro_version, os_version, bitmaps, ocr_enabled, ocr_language
	static honey_average := 0, honey_earned := 0, convert_time := 0, gather_time := 0, other_time := 0, stats_old := [["Total Boss Kills",0],["Total Vic Kills",0],["Total Bug Kills",0],["Total Planters",0],["Quests Done",0],["Disconnects",0]]

	if (honey_values.Count > 0)
	{
		; identify and exterminate misread values
		max_value := maxX(honey_values)

		str := ""
		for k,v in honey_values
			if (v < max_value//8) ; any value smaller than this is regarded as a misread
				str .= (StrLen(str) ? " " : "") k

		Loop Parse str, A_Space
			honey_values.Delete(Integer(A_LoopField))

		min_value := minX(honey_values), max_value := Max(maxX(honey_values), min_value+1000), range_value := max_value - min_value
	}
	else
		min_value := 0, max_value := 1000, range_value := 1000

	; populate honey_values array, fill missing values
	enum := honey_values.__Enum()
	enum.Call(&x2,&y2)
	for x1,y1 in honey_values
	{
		if (enum.Call(&x2,&y2) = 0)
		{
			if (x1 < 60)
				Loop (60 - x1)
					honey_values[x1+A_Index] := y1
			break
		}
		delta_x := x2 - x1
		if (delta_x > 1)
		{
			delta_y := y2 - y1
			Loop (delta_x - 1)
				honey_values[x1+A_Index] := y1 + A_Index * (delta_y/delta_x)
		}
	}
	Loop 61
		if !honey_values.Has(A_Index-1)
			honey_values[A_Index-1] := min_value

	; update honey gradients and 12h data
	honey_gradients := Map()
	for k,v in honey_values
		if (k < 60)
			honey_gradients[k+1] := (honey_values[k+1]-honey_values[k])/60
	honey_gradients[0] := honey_gradients[1], honey_gradients[61] := honey_gradients[60]

	Loop 166
		try honey_12h[A_Index - 1] := honey_12h[A_Index + 14]
	Loop 15
		honey_12h[A_Index + 165] := honey_values[4*A_Index]

	; set time arrays (10 min interval and 2 hour for 12h graph)
	times := [], times_12h := []
	time := A_Now
	Loop 7
		times.InsertAt(1, FormatTime(time, "HH:mm")), time := DateAdd(time, -10, "m")
	time := DateAdd(time, 70, "m")
	Loop 7
		times_12h.InsertAt(1, FormatTime(time, "HH:mm")), time := DateAdd(time, -2, "h")

	; create report bitmap and graphics
	pBMReport := Gdip_CloneBitmap(pBM)
	G := Gdip_GraphicsFromImage(pBMReport)
	Gdip_SetSmoothingMode(G, 4)
	Gdip_SetInterpolationMode(G, 7)

	; set variable graph bounds
	min_gradient := 0, max_gradient := Max(maxX(honey_gradients), min_gradient+1000), range_gradient := Floor(max_gradient - min_gradient)
	min_12h := minX(honey_12h), max_12h := Max(maxX(honey_12h), min_12h+1000), range_12h := max_12h - min_12h

	; draw times
	for v in ["honey/sec","backpack","buffs"]
		Loop 7
			Gdip_TextToGraphics(G, times[A_Index], "s44 Center Bold cffffffff x" regions[v][1]+320+(regions[v][3]-480)*(A_Index-1)//6 " y" regions[v][2]+regions[v][4]-85, "Segoe UI")
	for k,v in Map("honey","times", "honey12h","times_12h")
		Loop 7
			Gdip_TextToGraphics(G, %v%[A_Index], "s30 Center Bold cffffffff x" graph_regions[k][1]+graph_regions[k][3]*(A_Index-1)//6 " y" graph_regions[k][2]+graph_regions[k][4]+14, "Segoe UI")

	; draw graphs
	for k,v in graph_regions
	{
		pBMGraph := Gdip_CreateBitmap(v[3]+8, v[4]+8)
		G_Graph := Gdip_GraphicsFromImage(pBMGraph)
		Gdip_SetSmoothingMode(G_Graph, 4)
		Gdip_SetInterpolationMode(G_Graph, 7)

		switch k
		{
			case "honey/sec":
			Loop 5
				Gdip_TextToGraphics(G, FormatNumber(max_gradient-(range_gradient*(A_Index-1))//4), "s40 Right Bold cffffffff x" v[1]-320 " y" v[2]+v[4]*(A_Index-1)//4-28, "Segoe UI", 240)

			enum := status_changes.__Enum()
			enum.Call(&m)
			for i,j in status_changes
			{
				if (enum.Call(&m) = 0)
					m := 3599
				points := []
				points.Push([4+i*v[3]/3600, 4+v[4]])
				points.Push([4+i*v[3]/3600, 4+v[4]-(honey_gradients[(i+30)//60]+((i+30)/60-(i+30)//60)*(honey_gradients[(i+30)//60+1]-honey_gradients[(i+30)//60])-min_gradient)/range_gradient*v[4]])
				for x,y in honey_gradients
					((y != "") && (x >= (i+30)/60 && x <= (m+30)/60)) && points.Push([4+(x-0.5)*v[3]/60, 4+v[4]-((y > 0) ? (((y-min_gradient)/range_gradient)*v[4]) : 0)])
				points.Push([4+m*v[3]/3600, 4+v[4]-(honey_gradients[(m+30)//60]+((m+30)/60-(m+30)//60)*(honey_gradients[(m+30)//60+1]-honey_gradients[(m+30)//60])-min_gradient)/range_gradient*v[4]])
				points.Push([4+m*v[3]/3600, 4+v[4]])

				color := (j = 1) ? 0xffa6ff7c
						: (j = 2) ? 0xfffeca40
						: 0xff859aad

				pBrush := Gdip_BrushCreateSolid(color - 0x80000000)
				Gdip_FillPolygon(G_Graph, pBrush, points)
				Gdip_DeleteBrush(pBrush)

				points.RemoveAt(1), points.Pop()
				pPen := Gdip_CreatePen(color, 6)
				Gdip_DrawLines(G_Graph, pPen, points)
				Gdip_DeletePen(pPen)
			}


			case "honey":
			Loop 5
				Gdip_TextToGraphics(G, FormatNumber(max_value-(range_value*(A_Index-1))//4), "s28 Right Bold cffffffff x" v[1] - 310 " y" v[2]+v[4]*(A_Index-1)//4 - 20, "Segoe UI", 240)

			enum := status_changes.__Enum()
			enum.Call(&m)
			for i,j in status_changes
			{
				if (enum.Call(&m) = 0)
					m := 3599
				points := []
				points.Push([4+i*v[3]/3600, 4+v[4]])
				points.Push([4+i*v[3]/3600, 4+v[4]-(honey_values[i//60]+(i/60-i//60)*(honey_values[i//60+1]-honey_values[i//60])-min_value)/range_value*v[4]])
				for x,y in honey_values
					((y != "") && (x >= i/60 && x <= m/60)) && points.Push([4+x*v[3]/60, 4+v[4]-((y > 0) ? (((y-min_value)/range_value)*v[4]) : 0)])
				points.Push([4+m*v[3]/3600, 4+v[4]-(honey_values[m//60]+(m/60-m//60)*(honey_values[m//60+1]-honey_values[m//60])-min_value)/range_value*v[4]])
				points.Push([4+m*v[3]/3600, 4+v[4]])

				color := (j = 1) ? 0xffa6ff7c
						: (j = 2) ? 0xfffeca40
						: 0xff859aad

				pBrush := Gdip_BrushCreateSolid(color - 0x80000000)
				Gdip_FillPolygon(G_Graph, pBrush, points)
				Gdip_DeleteBrush(pBrush)

				points.RemoveAt(1), points.Pop()
				pPen := Gdip_CreatePen(color, 6)
				Gdip_DrawLines(G_Graph, pPen, points)
				Gdip_DeletePen(pPen)
			}


			case "honey12h":
			Loop 5
				Gdip_TextToGraphics(G, FormatNumber(max_12h-Floor((range_12h*(A_Index-1))/4)), "s28 Right Bold cffffffff x" v[1]-310 " y" v[2]+v[4]*(A_Index-1)//4-20, "Segoe UI", 240)

			points := []
			if (honey_12h.Count = 0){
				honey_12h[0] := 0
			}
			for k, value in honey_12h{
				x := value
				break
			}
			points.Push([4+v[3]*x/180, 4+v[4]])
			for x,y in honey_12h
				(y != "") && points.Push([4+v[3]*(max_x := x)/180, 4+v[4]-((y-min_12h)/range_12h)*v[4]])
			points.Push([4+v[3]*max_x/180, 4+v[4]])
			color := 0xff0e8bf0

			pBrush := Gdip_BrushCreateSolid(color - 0x80000000)
			Gdip_FillPolygon(G_Graph, pBrush, points)
			Gdip_DeleteBrush(pBrush)

			points.RemoveAt(1), points.Pop()
			pPen := Gdip_CreatePen(color, 6)
			Gdip_DrawLines(G_Graph, pPen, points)
			Gdip_DeletePen(pPen)


			case "backpack":
			Loop 3
				Gdip_TextToGraphics(G, 150-50*A_Index "%", "s40 Right Bold cffffffff x" v[1]-320 " y" v[2]+v[4]*(A_Index-1)//2-28, "Segoe UI", 240)

			points := []
			
			if (backpack_values.Count = 0){
				backpack_values[0] := 0
			}
			; set x to first value in Map backpack_values
			for key, value in backpack_values
			{
				x := value
				break
			}
			points.Push([4+x*v[3]/3600, 4+v[4]])
			for x,y in backpack_values
				(y != "") && points.Push([4+(max_x := x)*v[3]/3600, 4+v[4]-(y/100)*v[4]])
			points.Push([4+max_x*v[3]/3600, 4+v[4]])

			pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, 0x00000000)
			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0xffff0000, 0xffff8000, 0xff41ff80])
			pPen := Gdip_CreatePenFromBrush(pBrush, 6)
			Gdip_SetLinearGrBrushPresetBlend(pBrush, [0.0, 0.2, 0.8], [0x80ff0000, 0x80ff8000, 0x8041ff80])
			Gdip_FillPolygon(G_Graph, pBrush, points)
			points.RemoveAt(1), points.Pop()
			Gdip_DrawLines(G_Graph, pPen, points)
			Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)


			case "boost":
			Gdip_TextToGraphics(G, "x0-10", "s44 Center Bold cffffffff x" v[1]-190 " y" v[2]+190, "Segoe UI")

			Loop 3
			{
				i := (A_Index = 1) ? "whiteboost"
					: (A_Index = 2) ? "redboost"
					: "blueboost"

				total := 0
				count := 0
				enum := status_changes.__Enum()
				enum.Call(&m)
				for a,b in status_changes
				{
					if (enum.Call(&m) = 0)
						m := 3600
					if (b != 1)
						continue
					for x,y in buff_values[i]
					{
						if (x >= a//6 && x <= m//6)
						{
							total += y
							count++
						}
					}
				}

				color := (i = "whiteboost") ? 0xffffffff
					: (i = "redboost") ? 0xffe46156
					: 0xff56a4e4

				pBrush := Gdip_BrushCreateSolid(color), Gdip_TextToGraphics(G, "x" . (count ? Round(total/count, 3) : "0.000"), "s32 Center Bold c" pBrush " x" v[1]-190 " y" v[2]+(72-36*A_Index), "Segoe UI"), Gdip_DeleteBrush(pBrush)

				points := []
				if (buff_values[i].Count = 0)
					; no data available, assume 0%
					buff_values[i][0] := 0
				; set x to first value in Map buff_values
				for key, value in buff_values[i]
				{
					x := value
					break
				}
				points.Push([4+v[3]*x/600, 4+v[4]])
				for x,y in buff_values[i]
					points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-((y <= 10) ? (y/10)*(v[4]) : 10)])
				points.Push([4+v[3]*max_x/600, 4+v[4]])

				if (points.Length > 2)
				{
					pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, color - 0x40000000)
					Gdip_SetLinearGrBrushSigmaBlend(pBrush, 0, 0.3)
					Gdip_FillPolygon(G_Graph, pBrush, points)
					Gdip_DeleteBrush(pBrush)

					points.RemoveAt(1), points.Pop()
					pPen := Gdip_CreatePen(color, 4)
					Gdip_DrawCurve(G_Graph, pPen, points, 0)
					Gdip_DeletePen(pPen)
				}
			}


			case "honeymark","pollenmark","precisemark":
			color := (k = "honeymark") ? 0xffffd119
				: (k = "pollenmark") ? 0xffffe994
				: 0xff8f4eb4

			pBrush := Gdip_BrushCreateSolid(color-0x60000000)
			for x,y in buff_values[k]
				(y && y < 4 && y > 0) && Gdip_FillRectangle(G_Graph, pBrush, 4+v[3]*x//600, 4+v[4]*(3-y)//3, 6, v[4]*y//3)
			Gdip_DeleteBrush(pBrush)


			case "festivemark","popstar","melody","bear","babylove","jbshare","guiding":
			color := (k = "festivemark") ? 0xffc84335
				: (k = "popstar") ? 0xff0096ff
				: (k = "melody") ? 0xfff0f0f0
				: (k = "bear") ? 0xffb26f3e
				: (k = "babylove") ? 0xff8de4f3
				: (k = "jbshare") ? 0xfff9ccff
				: 0xffffef8e

			pBrush := Gdip_BrushCreateSolid(color-0x60000000)
			enum := buff_values[k].__Enum()
			enum.Call(&x2)
			for x,y in buff_values[k]
			{
				if (enum.Call(&x2) = 0)
					x2 := 600
				(y) && Gdip_FillRectangle(G_Graph, pBrush, 4+v[3]*x//600, 4, (x2-x)*6, v[4])
			}
			Gdip_DeleteBrush(pBrush)


			default:
			max_buff := (k = "inspire") ? Max(ceil(maxX(buff_values[k])/5)*5, 5) : 10
			Gdip_TextToGraphics(G, "x0-" max_buff, "s44 Center Bold cffffffff x" v[1]-190 " y" v[2]+190, "Segoe UI")

			total := 0
			count := 0
			enum := status_changes.__Enum()
			enum.Call(&m)
			for a,b in status_changes
			{
				if (enum.Call(&m) = 0)
					m := 3600
				if (b != 1)
					continue
				for x,y in buff_values[k]
				{
					if (x >= a//6 && x <= m//6)
					{
						total += y
						count++
					}
				}
			}

			color := (k = "focus") ? 0xff22ff06
				: (k = "haste") ? 0xfff0f0f0
				: (k = "bombcombo") ? 0xffa0a0a0
				: (k = "balloonaura") ? 0xff3350c3
				: (k = "inspire") ? 0xfff4ef14
				: (k = "precision") ? 0xff8f4eb4
				: (k = "reindeerfetch") ? 0xffcc2c2c : 0

			pBrush := Gdip_BrushCreateSolid(color), Gdip_TextToGraphics(G, "x" . (count ? Round(total/count, 3) : "0.000"), "s32 Center Bold c" pBrush " x" v[1]-190 " y" v[2]+36, "Segoe UI"), Gdip_DeleteBrush(pBrush)

			points := []

			if (buff_values[k].Count = 0)
				; no data available, assume 0%
				buff_values[k][0] := 0
			; set x to first value in Map backpack_values
			for key, value in buff_values[k]
			{
				x := value
				break
			}
			points.Push([4+v[3]*x/600, 4+v[4]])
			for x,y in buff_values[k]
				points.Push([4+v[3]*(max_x := x)/600, 4+v[4]-(y/max_buff)*(v[4])])
			points.Push([4+v[3]*max_x/600, 4+v[4]])

			if (points.Length > 2)
			{
				pBrush := Gdip_CreateLinearGrBrushFromRect(4, 4, v[3], v[4], 0x00000000, color - 0x40000000)
				Gdip_SetLinearGrBrushSigmaBlend(pBrush, 0, 0.3)
				Gdip_FillPolygon(G_Graph, pBrush, points)
				Gdip_DeleteBrush(pBrush)

				points.RemoveAt(1), points.Pop()
				pPen := Gdip_CreatePen(color, 4)
				Gdip_DrawLines(G_Graph, pPen, points)
				Gdip_DeletePen(pPen)
			}
		}

		Gdip_DeleteGraphics(G_Graph)
		Gdip_DrawImage(G, pBMGraph, v[1]-4, v[2]-4)
		Gdip_DisposeImage(pBMGraph)
	}

	; calculate times
	time := DateAdd(DateAdd(A_Now, -A_Min, "Minutes"), -A_Sec, "Seconds")
	session_time := DateDiff(time, start_time, "Seconds")

	local hour_gather_time, hour_convert_time, hour_other_time
		, hour_gather_percent, hour_convert_percent, hour_other_percent
		, gather_percent, convert_percent, other_percent

	status_list := ["Gather","Convert","Other"]
	for i,j in status_list
		hour_%j%_time := 0
	enum := status_changes.__Enum()
	enum.Call(&m)
	for i,j in status_changes
	{
		if (enum.Call(&m) = 0)
			m := 3600
		status := (j = 1) ? "Gather"
			: (j = 2) ? "Convert"
			: "Other"
		hour_%status%_time += m-i
	}
	for i,j in status_list
		%j%_time += hour_%j%_time

	unix_now := DateDiff(SubStr(A_NowUTC, 1, 10), "19700101000000", "Seconds")

	; calculate percentages
	cumul_hour := 0, cumul_hour_rounded := 0
	cumul_total := 0, cumul_total_rounded := 0
	for i,j in status_list
	{
		cumul_hour += hour_%j%_time*100/3600
		hour_%j%_percent := Round(cumul_hour) - cumul_hour_rounded . "%"
		cumul_hour_rounded := Round(cumul_hour)

		cumul_total += %j%_time*100/session_time
		%j%_percent := Round(cumul_total) - cumul_total_rounded . "%"
		cumul_total_rounded := Round(cumul_total)
	}

	; session stats
	current_honey := honey_values[60]
	session_total := current_honey - start_honey

	; last hour stats
	hour_increase := (honey_values[60] - honey_values[0] < honey_earned) ? "0" : "1"
	honey_earned := honey_values[60] - honey_values[0]
	average_difference := honey_average ? ((session_total * 3600 / session_time) - honey_average) : 0
	honey_change := (average_difference = 0) ? "(+0%)" : (average_difference > 0) ? "(+" . Ceil(average_difference * 100 / Abs(honey_average)) . "%)" : "(" . Floor(average_difference * 100 / Abs(honey_average)) . "%)"
	honey_average := session_total * 3600 / session_time


	; WRITE STATS
	; section 1: last hour
	Gdip_TextToGraphics(G, "LAST HOUR", "s64 Center Bold cffffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2 " y" stat_regions["lasthour"][2]+4, "Segoe UI")

	Gdip_TextToGraphics(G, "Honey Earned", "s60 Right Bold ccfffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2-40 " y" stat_regions["lasthour"][2]+96, "Segoe UI")
	pos := Gdip_TextToGraphics(G, FormatNumber(honey_earned), "s60 Left Bold cffffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+40 " y" stat_regions["lasthour"][2]+96, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)
	pBrush := Gdip_BrushCreateSolid(hour_increase ? 0xff00ff00 : 0xffff0000), (x) && Gdip_FillPolygon(G, pBrush, hour_increase ? [[x+45, stat_regions["lasthour"][2]+119], [x+20, stat_regions["lasthour"][2]+161], [x+70, stat_regions["lasthour"][2]+161]] : [[x+20, stat_regions["lasthour"][2]+119], [x+70, stat_regions["lasthour"][2]+119], [x+45, stat_regions["lasthour"][2]+161]]), Gdip_DeleteBrush(pBrush)

	Gdip_TextToGraphics(G, "Hourly Average", "s60 Right Bold ccfffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2-40 " y" stat_regions["lasthour"][2]+180, "Segoe UI")
	pos := Gdip_TextToGraphics(G, FormatNumber(honey_average), "s60 Left Bold cffffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+40 " y" stat_regions["lasthour"][2]+180, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)
	Gdip_TextToGraphics(G, honey_change, "s60 Left Bold c" . (InStr(honey_change, "-") ? "ffff0000" : InStr(honey_change, "+0") ? "ff888888" : "ff00ff00") . " x" x " y" stat_regions["lasthour"][2]+180, "Segoe UI")

	angle := -90
	for i,j in status_list
	{
		color := (j = "Gather") ? 0xffa6ff7c
				: (j = "Convert") ? 0xfffeca40
				: 0xff859aad
		pBrush := Gdip_BrushCreateSolid(color)
		Gdip_FillPie(G, pBrush, stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2-464, stat_regions["lasthour"][2]+318, 280, 280, angle, hour_%j%_time/10)
		angle += hour_%j%_time/10

		Gdip_FillRoundedRectangle(G, pBrush, stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+74, stat_regions["lasthour"][2]+348+(A_Index-1)*88, 44, 44, 4)
		Gdip_DeleteBrush(pBrush)

		Gdip_TextToGraphics(G, j, "s48 Right Bold ccfffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+56 " y" stat_regions["lasthour"][2]+335+(A_Index-1)*88, "Segoe UI")
		Gdip_TextToGraphics(G, DurationFromSeconds(hour_%j%_time), "s48 Left Bold cefffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+135 " y" stat_regions["lasthour"][2]+335+(A_Index-1)*88, "Segoe UI")
		Gdip_TextToGraphics(G, hour_%j%_percent, "s48 Right Bold cefffffff x" stat_regions["lasthour"][1]+stat_regions["lasthour"][3]//2+476 " y" stat_regions["lasthour"][2]+335+(A_Index-1)*88, "Segoe UI")
	}

	; section 2: session
	Gdip_TextToGraphics(G, "SESSION", "s64 Center Bold cffffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2 " y" stat_regions["session"][2]+4, "Segoe UI")

	Gdip_TextToGraphics(G, "Current Honey", "s60 Right Bold ccfffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2-40 " y" stat_regions["session"][2]+96, "Segoe UI")
	Gdip_TextToGraphics(G, FormatNumber(current_honey), "s60 Left Bold cffffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+40 " y" stat_regions["session"][2]+96, "Segoe UI")

	Gdip_TextToGraphics(G, "Session Honey", "s60 Right Bold ccfffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2-40 " y" stat_regions["session"][2]+180, "Segoe UI")
	Gdip_TextToGraphics(G, FormatNumber(session_total), "s60 Left Bold cffffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+40 " y" stat_regions["session"][2]+180, "Segoe UI")

	Gdip_TextToGraphics(G, "Session Time", "s60 Right Bold ccfffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2-40 " y" stat_regions["session"][2]+264, "Segoe UI")
	session_time_F := DurationFromSeconds(session_time)
	Gdip_TextToGraphics(G, session_time_F, "s60 Left Bold cffffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+40 " y" stat_regions["session"][2]+264, "Segoe UI")

	angle := -90
	for i,j in status_list
	{
		color := (j = "Gather") ? 0xffa6ff7c
				: (j = "Convert") ? 0xfffeca40
				: 0xff859aad
		pBrush := Gdip_BrushCreateSolid(color)
		Gdip_FillPie(G, pBrush, stat_regions["session"][1]+stat_regions["session"][3]//2-464, stat_regions["session"][2]+402, 280, 280, angle, %j%_time/session_time*360)
		angle += %j%_time/session_time*360

		Gdip_FillRoundedRectangle(G, pBrush, stat_regions["session"][1]+stat_regions["session"][3]//2+74, stat_regions["session"][2]+432+(A_Index-1)*88, 44, 44, 4)
		Gdip_DeleteBrush(pBrush)

		Gdip_TextToGraphics(G, j, "s48 Right Bold ccfffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+56 " y" stat_regions["session"][2]+419+(A_Index-1)*88, "Segoe UI")
		Gdip_TextToGraphics(G, DurationFromSeconds(%j%_time), "s48 Left Bold cefffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+135 " y" stat_regions["session"][2]+419+(A_Index-1)*88, "Segoe UI")
		Gdip_TextToGraphics(G, %j%_percent, "s48 Right Bold cefffffff x" stat_regions["session"][1]+stat_regions["session"][3]//2+476 " y" stat_regions["session"][2]+419+(A_Index-1)*88, "Segoe UI")
	}

	; section 3: buffs
	Gdip_TextToGraphics(G, "BUFFS", "s64 Center Bold cffffffff x" stat_regions["buffs"][1]+stat_regions["buffs"][3]//2 " y" stat_regions["buffs"][2]+4, "Segoe UI")

	for k,v in ["clock","blessing","bloat","tideblessing","mondo"]
	{
		i := A_Index
		Loop 601
		{
			if (buff_values[v].Has(601-A_Index) && (buff_values[v][601-A_Index] > 0))
			{
				if (i = 3 || i = 4)
					pBrush := Gdip_BrushCreateSolid(0x70000000), Gdip_FillRectangle(G, pBrush, stat_regions["buffs"][1]+47+(i-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+123, 221, 1+Min((1-((buff_values[v][601-A_Index]-1)/((i = 3) ? 5.00 : 0.20))) * 220, 220)), Gdip_DeleteBrush(pBrush)

				pBrush := Gdip_BrushCreateSolid(0xffffffff), pPen := Gdip_CreatePen(0xff000000, 10)
				Gdip_DrawOrientedString(G, "x" buff_values[v][601-A_Index], "Segoe UI", 72, 1, stat_regions["buffs"][1]+48+(i-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+254, 220, 90, , pBrush, pPen, 2)
				Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)
				break
			}
			if (A_Index = 601)
			{
				pBrush := Gdip_BrushCreateSolid(0x70000000), Gdip_FillRectangle(G, pBrush, stat_regions["buffs"][1]+47+(i-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+123, 221, 221), Gdip_DeleteBrush(pBrush)
				pBrush := Gdip_BrushCreateSolid(0xffffffff), pPen := Gdip_CreatePen(0xff000000, 10)
				Gdip_DrawOrientedString(G, "x0", "Segoe UI", 72, 1, stat_regions["buffs"][1]+48+(i-1)*(stat_regions["buffs"][3]-96-220)/4, stat_regions["buffs"][2]+254, 220, 90, , pBrush, pPen, 2)
				Gdip_DeletePen(pPen), Gdip_DeleteBrush(pBrush)
			}
		}
	}

	planters := 0

	local PlanterName1, PlanterName2, PlanterName3
		, PlanterField1, PlanterField2, PlanterField3
		, PlanterHarvestTime1, PlanterHarvestTime2, PlanterHarvestTime3
		, PlanterNectar1, PlanterNectar2, PlanterNectar3
		, MPlanterHold1, MPlanterHold2, MPlanterHold3
		, MPlanterSmoking1, MPlanterSmoking2, MPlanterSmoking3


	KOCMOC_SendCommand("send_planters")
	planter_data := KOCMOC_YieldUntilData("update_planters")

	; Loop 3
	; {
	; 	PlanterName%A_Index% := IniRead("statconfig.ini", "Planters", "PlanterName" A_Index, "None")
	; 	PlanterField%A_Index% := IniRead("statconfig.ini", "Planters", "PlanterField" A_Index, "None")
	; 	PlanterHarvestTime%A_Index% := IniRead("statconfig.ini", "Planters", "PlanterHarvestTime" A_Index, "20211106000000") ; PlanterHarvestTime = time left until can be harvested in seconds.
	; 	PlanterNectar%A_Index% := IniRead("statconfig.ini", "Planters", "PlanterNectar" A_Index, "None")
	; 	if (PlanterName%A_Index% && (PlanterName%A_Index% != "None"))
	; 		planters++
	; }
	for k, v in planter_data["Planters"]
	{
		planters++
		PlanterName%planters% := v["PlanterName"]
		PlanterField%planters% := v["FieldName"]
		PlanterHarvestTime%planters% := v["EstimatedDurationLeft"]
		PlanterNectar%planters% := v["NectarType"]
	}

	for i,j in ["comforting","motivating","satisfying","refreshing","invigorating"]
	{
		color := (j = "comforting") ? 0xff7e9eb3
			: (j = "motivating") ? 0xff937db3
			: (j = "satisfying") ? 0xffb398a7
			: (j = "refreshing") ? 0xff78b375
			: 0xffb35951 ; invigorating

		nectar_value := 0
		Loop 601
		{
			if (buff_values[j].Has(601-A_Index) && (buff_values[j][601-A_Index] > 0))
			{
				nectar_value := buff_values[j][601-A_Index]
				break
			}
		}
		projected_value := 0

		pPen := Gdip_CreatePen(color, 32), Gdip_DrawArc(G, pPen, stat_regions["buffs"][1]+50+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4, stat_regions["buffs"][2]+410, 200, 200, -90, nectar_value/100*360), Gdip_DeletePen(pPen)

		pBrush := Gdip_BrushCreateHatch(color, color-0xa0000000, 34), pPen := Gdip_CreatePenFromBrush(pBrush, 32), Gdip_DeleteBrush(pBrush), Gdip_DrawArc(G, pPen, stat_regions["buffs"][1]+50+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4, stat_regions["buffs"][2]+410, 200, 200, -90-1+nectar_value/100*360, projected_value/100*360+1), Gdip_DeletePen(pPen)

		pPen := Gdip_CreatePen(color-0xd0000000, 32), Gdip_DrawArc(G, pPen, stat_regions["buffs"][1]+50+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4, stat_regions["buffs"][2]+410, 200, 200, -90-1+(nectar_value+projected_value)/100*360, 360+2-(nectar_value+projected_value)/100*360), Gdip_DeletePen(pPen)

		pBrush := Gdip_BrushCreateSolid(color)
		Gdip_TextToGraphics(G, nectar_value "%", "s54 Center Bold c" pBrush " x" stat_regions["buffs"][1]+150+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4 " y" stat_regions["buffs"][2]+(projected_value ? 456 : 472), "Segoe UI")
		Gdip_TextToGraphics(G, Format("{1:Us}", SubStr(j, 1, 3)), "s48 Center Bold c" pBrush " x" stat_regions["buffs"][1]+150+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4 " y" stat_regions["buffs"][2]+630, "Segoe UI")
		Gdip_DeleteBrush(pBrush)

		if projected_value
		{
			pBrush := Gdip_BrushCreateSolid(color-0x40000000)
			Gdip_TextToGraphics(G, "(+" Round(projected_value) "%)", "s28 Center Bold c" pBrush " x" stat_regions["buffs"][1]+150+(A_Index-1)*(stat_regions["buffs"][3]-100-200)/4 " y" stat_regions["buffs"][2]+516, "Segoe UI")
			Gdip_DeleteBrush(pBrush)
		}
	}

	; section 4: planters
	Gdip_TextToGraphics(G, "PLANTERS", "s64 Center Bold cffffffff x" stat_regions["planters"][1]+stat_regions["planters"][3]//2 " y" stat_regions["planters"][2]+4, "Segoe UI")

	if planters
	{
		i := 0
		Loop 3
		{
			if (PlanterName%A_Index% = "None")
				continue

			i++
			Gdip_DrawImage(G, bitmaps["pBM" PlanterName%A_Index%], stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i-1)*440, stat_regions["planters"][2]+110, 220, 220)

			pos := Gdip_TextToGraphics(G, PlanterField%A_Index%, "s52 Center Bold cffffffff x" stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i-1)*440+74 " y" stat_regions["planters"][2]+340, "Segoe UI")
			x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)
			Gdip_DrawImage(G, bitmaps["pBM" ((PlanterNectar%A_Index% = "None") ? "Unknown" : PlanterNectar%A_Index%)], x+6, stat_regions["planters"][2]+348, 60, 60)

			duration := ((time := PlanterHarvestTime%A_Index%) > 360000) ? "N/A" : (time > 0) ? hmsFromSeconds(PlanterHarvestTime%A_Index%) : ("Ready")
			pos := Gdip_TextToGraphics(G, duration, "s46 Center Bold ccfffffff x" stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i-1)*440+130 " y" stat_regions["planters"][2]+406, "Segoe UI")
			x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)
			Gdip_DrawImage(G, bitmaps["pBMTimer"], x-60, stat_regions["planters"][2]+410, 56, 56, , , , , 0.811765)

			if (i >= planters)
				break
		}
		Loop (planters - i)
		{
			Gdip_DrawImage(G, bitmaps["pBMUnknown"], stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i+A_Index-1)*440, stat_regions["planters"][2]+110, 220, 220)

			pos := Gdip_TextToGraphics(G, "None", "s52 Center Bold cffffffff x" stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i+A_Index-1)*440+74 " y" stat_regions["planters"][2]+340, "Segoe UI")
			x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)
			Gdip_DrawImage(G, bitmaps["pBMUnknown"], x+6, stat_regions["planters"][2]+348, 60, 60)

			pos := Gdip_TextToGraphics(G, "N/A", "s46 Center Bold ccfffffff x" stat_regions["planters"][1]+stat_regions["planters"][3]//2-(110+220*(planters-1))+(i+A_Index-1)*440+130 " y" stat_regions["planters"][2]+406, "Segoe UI")
			x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)
			Gdip_DrawImage(G, bitmaps["pBMTimer"], x-60, stat_regions["planters"][2]+410, 56, 56, , , , , 0.811765)
		}
	}

	; section 5: stats
	pos := Gdip_TextToGraphics(G, "STATS", "s64 Center Bold cffffffff x" stat_regions["stats"][1]+stat_regions["stats"][3]//2 " y" stat_regions["stats"][2]+4, "Segoe UI")
	y := SubStr(pos, InStr(pos, "|", , , 1)+1, InStr(pos, "|", , , 2)-InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 3)+1, InStr(pos, "|", , , 4)-InStr(pos, "|", , , 3)-1)+4

	for i,j in stats
	{
		Gdip_TextToGraphics(G, j[1], "s60 Right Bold ccfffffff x" stat_regions["stats"][1]+stat_regions["stats"][3]//2-40 " y" y, "Segoe UI")
		pos := Gdip_TextToGraphics(G, j[2], "s60 Left Bold cffffffff x" stat_regions["stats"][1]+stat_regions["stats"][3]//2+40 " y" y, "Segoe UI")
		if (j[2] > stats_old[i][2])
		{
			x := stat_regions["stats"][1]+stat_regions["stats"][3]//2+240
			pBrush := Gdip_BrushCreateSolid((j[1] = "Disconnects") ? 0xffff0000 : 0xff00ff00), Gdip_FillPolygon(G, pBrush, [[x+45, y+23], [x+20, y+65], [x+70, y+65]]), Gdip_DeleteBrush(pBrush)
			x := stat_regions["stats"][1]+stat_regions["stats"][3]//2+312
			Gdip_TextToGraphics(G, j[2]-stats_old[i][2], "s40 Left Bold cafffffff x" x " y" y+16, "Segoe UI")
		}
		else
		{
			pBrush := Gdip_BrushCreateSolid(0xff666666)
			Gdip_FillRoundedRectangle(G, pBrush, stat_regions["stats"][1]+stat_regions["stats"][3]//2+260, y+36, 50, 12, 6)
			Gdip_DeleteBrush(pBrush)
		}
		y := SubStr(pos, InStr(pos, "|", , , 1)+1, InStr(pos, "|", , , 2)-InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 3)+1, InStr(pos, "|", , , 4)-InStr(pos, "|", , , 3)-1)-4
	}

	; section 6: info
	; row 1: statmonitor and natro version
	y := stat_regions["info"][2]+60
	pos := Gdip_TextToGraphics(G, "StatMonitor v" version " by SP+W", "s56 Center Bold c00ffffff x" stat_regions["info"][1]+stat_regions["info"][3]//2 " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)

	pos := Gdip_TextToGraphics(G, "StatMonitor v" version " by ", "s56 Left Bold cafffffff x" x " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)

	pos := Gdip_TextToGraphics(G, "SP+W", "s56 Left Bold cffff5f1f x" x " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)

	; row 2: report timestamp
	y := stat_regions["info"][2]+140
	FormatStr := Buffer(256), DllCall("GetLocaleInfoEx", "Ptr",0, "UInt",0x20, "Ptr",FormatStr.Ptr, "Int",256)
	DateStr := Buffer(512), DllCall("GetDateFormatEx", "Ptr",0, "UInt",0, "Ptr",0, "Str",StrReplace(StrReplace(StrReplace(StrReplace(StrGet(FormatStr), ", dddd"), "dddd, "), " dddd"), "dddd "), "Ptr",DateStr.Ptr, "Int",512, "Ptr",0)
	pos := Gdip_TextToGraphics(G, times[1] " - " times[7] " • " StrGet(DateStr), "s56 Center Bold c00ffffff x" stat_regions["info"][1]+stat_regions["info"][3]//2 " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)

	pos := Gdip_TextToGraphics(G, times[1] " - " times[7] " ", "s56 Left Bold cffffda3d x" x " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)

	pos := Gdip_TextToGraphics(G, "•", "s56 Left Bold cafffffff x" x " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)

	Gdip_TextToGraphics(G, StrGet(DateStr), "s56 Left Bold cffffda3d x" x " y" y, "Segoe UI")

	; row 3: OCR status
	y := stat_regions["info"][2]+220
	pos := Gdip_TextToGraphics(G, "OCR: MEMORYREAD", "s56 Center Bold c00ffffff x" stat_regions["info"][1]+stat_regions["info"][3]//2 " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)

	pos := Gdip_TextToGraphics(G, "OCR: ", "s56 Left Bold cafffffff x" x " y" y, "Segoe UI")
	x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)

	Gdip_TextToGraphics(G, "MEMORYREAD", "s56 Left Bold c" (ocr_enabled ? "ff4fdf26" : "ffcc0000") " x" x " y" y, "Segoe UI")

	; row 4: windows version
	y := stat_regions["info"][2]+300
	Gdip_TextToGraphics(G, "Edited to work with MEMORYREAD by WHUT", "s56 Center Bold cff04b4e4 x" stat_regions["info"][1]+stat_regions["info"][3]//2 " y" y, "Segoe UI")

	; row 5: natro information
	if IsSet(natro_version)
	{
		y := stat_regions["info"][2]+380
		x := stat_regions["info"][1]+stat_regions["info"][3]//2-50

		pos := Gdip_TextToGraphics(G, "Natro v" natro_version, "s56 Left Bold c00ffffff x" x " y" y, "Segoe UI")
		x -= SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)/2
		pos := Gdip_TextToGraphics(G, "CREDIT TO WHUT", "s56 Left Bold c00ffffff x" x " y" y, "Segoe UI")
		x -= SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)/2

		pos := Gdip_TextToGraphics(G, "CREDIT TO WHUT", "s56 Left Bold Underline cff3366cc x" x " y" y, "Segoe UI")
		x := SubStr(pos, 1, InStr(pos, "|", , , 1)-1)+SubStr(pos, InStr(pos, "|", , , 2)+1, InStr(pos, "|", , , 3)-InStr(pos, "|", , , 2)-1)
		Gdip_DrawImage(G, bitmaps["pBMNatroLogo"], x+10, y, 80, 80)
		Gdip_TextToGraphics(G, "Natro v(notrunning)", "s56 Left Bold cffb47bd1 x" x+100 " y" y, "Segoe UI")
	}

	Gdip_DeleteGraphics(G)

	webhook := IniRead("statconfig.ini", "Status", "webhook")
	bottoken := IniRead("statconfig.ini", "Status", "bottoken")
	discordMode := IniRead("statconfig.ini", "Status", "discordMode")
	ReportChannelID := IniRead("statconfig.ini", "Status", "ReportChannelID")
	if (StrLen(ReportChannelID) < 17)
		ReportChannelID := IniRead("statconfig.ini", "Status", "MainChannelID")

	try
	{
		chars := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"
		chars := Sort(chars, "D| Random")
		boundary := SubStr(StrReplace(chars, "|"), 1, 12)
		hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
		DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream:=0, "UInt")

		str :=
		(
		'
		------------------------------' boundary '
		Content-Disposition: form-data; name="payload_json"
		Content-Type: application/json

		{
			"embeds": [{
				"title": "**[' A_Hour ':' A_Min ':00] Hourly Report**",
				"color": "14052794",
				"image": {"url": "attachment://file.png"}
			}]
		}
		------------------------------' boundary '
		Content-Disposition: form-data; name="files[0]"; filename="file.png"
		Content-Type: image/png

		'
		)

		utf8 := Buffer(length := StrPut(str, "UTF-8") - 1), StrPut(str, utf8, length, "UTF-8")
		DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")

		pFileStream := Gdip_SaveBitmapToStream(pBMReport)
		DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")
		DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
		DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
		ObjRelease(pFileStream)

		str :=
		(
		'

		------------------------------' boundary '--
		'
		)

		utf8 := Buffer(length := StrPut(str, "UTF-8") - 1), StrPut(str, utf8, length, "UTF-8")
		DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")
		ObjRelease(pStream)

		pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
		size := DllCall("GlobalSize", "Ptr", pData, "UPtr")

		retData := ComObjArray(0x11, size)
		pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
		DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)

		DllCall("GlobalUnlock", "Ptr", hData)
		DllCall("GlobalFree", "Ptr", hData, "Ptr")
		contentType := "multipart/form-data; boundary=----------------------------" boundary

		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
		wr.Open("POST", (discordMode = 0) ? webhook : ("https://discord.com/api/v10/channels/" ReportChannelID "/messages"), 0)
		if (discordMode = 1)
		{
			wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
			wr.SetRequestHeader("Authorization", "Bot " bottoken)
		}
		wr.SetRequestHeader("Content-Type", contentType)
		wr.SetTimeouts(0, 60000, 120000, 30000)
		wr.Send(retData)
	}
	catch as e
	{
		message := "**[" A_Hour ":" A_Min ":" A_Sec "]**`n"
		. "**Failed to send Hourly Report!**`n"
		. "Gdip SaveBitmap Error: " result "`n`n"
		. "Exception Properties:`n"
		. ">>> What: " e.what "`n"
		. "File: " e.file "`n"
		. "Line: " e.line "`n"
		. "Message: " e.message "`n"
		. "Extra: " e.extra
		message := StrReplace(StrReplace(message, "\", "\\"), "`n", "\n")

		postdata :=
		(
		'
		{
			"embeds": [{
				"description": "' message '",
				"color": "15085139"
			}]
		}
		'
		)

		Send_WM_COPYDATA(postdata, "Status.ahk ahk_class AutoHotkey")
	}

	Gdip_DisposeImage(pBMReport)

	; save old stats for comparison
	for k,v in stats_old
		v[2] := stats[k][2]
	; reset honey values map
	honey_values.Clear()
	honey_values[0] := current_honey
	; reset backpack values map
	for k,v in backpack_values
		if (A_Index = backpack_values.Count)
			current_backpack := v
	backpack_values.Clear()
	backpack_values[0] := current_backpack
	; reset status changes array
	for k,v in status_changes
		if (A_Index = status_changes.Count)
			current_status := v
	status_changes.Clear()
	status_changes[0] := current_status
	; reset buff values array
	for k,v in buff_values
		v.Clear()
}

/*************************************************************************************************************
* @description: rounds a number (integer/float) to 4 s.f. and abbreviates it with common large number prefixes
* @returns: (string) result
* @author SP
*************************************************************************************************************/
FormatNumber(n)
{
	static numnames := ["M","B","T","Qa","Qi"]
	digit := floor(log(abs(n)))+1
	if (digit > 6)
	{
		numname := (digit-4)//3
		numstring := SubStr((round(n,4-digit)) / 10**(3*numname+3), 1, 5)
		numformat := (SubStr(numstring, 0) = ".") ? 1.000 : numstring, numname += (SubStr(numstring, 0) = ".") ? 1 : 0
		num := SubStr((round(n,4-digit)) / 10**(3*numname+3), 1, 5) " " numnames[numname]
	}
	else
	{
		num := Buffer(32), DllCall("GetNumberFormatEx","str","!x-sys-default-locale","uint",0,"str",n,"ptr",0,"Ptr",num.Ptr,"int",32)
		num := SubStr(StrGet(num), 1, -3)
	}
	return num
}

/**************************************************************************************************
* @description: responsible for receiving messages from the main macro script to set current status
* @param: wParam is the status number, lParam is the second of the hour when status started
* @author SP
**************************************************************************************************/
SetStatus(wParam, lParam, *){
	for k,v in status_changes
		if (lParam < k)
			return 0
	status_changes[lParam] := wParam
	return 0
}

/***********************************************************************************************
* @description: responsible for receiving messages from the main macro script to increment stats
* @param: wParam is the stat to be incrememted, lParam is the amount
* @author SP
***********************************************************************************************/
IncrementStat(paramName, lParam, *){
	; find wParam in stats array
	wParam := ""
	for k,v in stats{
		if (paramName = v[1]){
			wParam := k
			break
		}
	}
	if (wParam = ""){
		; raise error
		MsgBox("Stat not found in stats array! Stat: " paramName)
		MsgBox("Valid stats are: " Jxon_Dump(stats))
	}
	stats[wParam][2] += lParam
	return 0
}

/************************************************************************************************************
* @description: receives messages from the background script to update ability values (pop/scorch star, etc.)
* @param: wParam is the ability (buff) to be changed, lParam is the value
* @author SP
************************************************************************************************************/
SetAbility(wParam, lParam, *){
	static arr := ["popstar"]
	time_value := (60*A_Min+A_Sec)//6, i := (time_value = 0) ? 600 : time_value
	buff_values[arr[wParam]][i] := lParam
	return 0
}

/**********************************************************************************************************
* @description: receives messages from the background script to set the current (filtered) backpack percent
* @param: wParam is the backpack percent, lParam is the second of the hour
* @author SP
**********************************************************************************************************/
SetBackpack(wParam, lParam, *){
	for k,v in backpack_values
		if (lParam < k)
			return 0
	backpack_values[lParam] := wParam
	return 0
}

GetSecondOfHour(){
	return 60*A_Min+A_Sec
}

/***************************************************************************************
* @description: these functions return the minimum and maximum values in maps and arrays
* @author modified versions of functions by FanaticGuru
* @url https://www.autohotkey.com/boards/viewtopic.php?t=40898
***************************************************************************************/
minX(List)
{
	X := 999999999
	for key, element in List
		if (IsNumber(element) && (element < X))
			X := element
	return X
}
maxX(List)
{
	X := 0
	for key, element in List
		if (IsNumber(element) && (element > X))
			X := element
	return X
}

/*************************************************************
* @description: OCR with UWP API
* @author malcev, teadrinker
* @url https://www.autohotkey.com/boards/viewtopic.php?t=72674
*************************************************************/
HBitmapToRandomAccessStream(hBitmap) {
	static IID_IRandomAccessStream := "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"
			, IID_IPicture            := "{7BF80980-BF32-101A-8BBB-00AA00300CAB}"
			, PICTYPE_BITMAP := 1
			, BSOS_DEFAULT   := 0
			, sz := 8 + A_PtrSize * 2

	DllCall("Ole32\CreateStreamOnHGlobal", "Ptr", 0, "UInt", true, "PtrP", &pIStream:=0, "UInt")

	PICTDESC := Buffer(sz, 0)
	NumPut("uint", sz
		, "uint", PICTYPE_BITMAP
		, "ptr", hBitmap, PICTDESC)

	riid := CLSIDFromString(IID_IPicture)
	DllCall("OleAut32\OleCreatePictureIndirect", "Ptr", PICTDESC, "Ptr", riid, "UInt", false, "PtrP", &pIPicture:=0, "UInt")
	; IPicture::SaveAsFile
	ComCall(15, pIPicture, "Ptr", pIStream, "UInt", true, "UIntP", &size:=0, "UInt")
	riid := CLSIDFromString(IID_IRandomAccessStream)
	DllCall("ShCore\CreateRandomAccessStreamOverStream", "Ptr", pIStream, "UInt", BSOS_DEFAULT, "Ptr", riid, "PtrP", &pIRandomAccessStream:=0, "UInt")
	ObjRelease(pIPicture)
	ObjRelease(pIStream)
	Return pIRandomAccessStream
}

CLSIDFromString(IID, &CLSID?) {
	CLSID := Buffer(16)
	if res := DllCall("ole32\CLSIDFromString", "WStr", IID, "Ptr", CLSID, "UInt")
	throw Error("CLSIDFromString failed. Error: " . Format("{:#x}", res))
	Return CLSID
}

ocr(file, lang := "FirstFromAvailableLanguages")
{
	static OcrEngineStatics, OcrEngine, MaxDimension, LanguageFactory, Language, CurrentLanguage:="", BitmapDecoderStatics, GlobalizationPreferencesStatics
	if !IsSet(OcrEngineStatics)
	{
		CreateClass("Windows.Globalization.Language", ILanguageFactory := "{9B0252AC-0C27-44F8-B792-9793FB66C63E}", &LanguageFactory)
		CreateClass("Windows.Graphics.Imaging.BitmapDecoder", IBitmapDecoderStatics := "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}", &BitmapDecoderStatics)
		CreateClass("Windows.Media.Ocr.OcrEngine", IOcrEngineStatics := "{5BFFA85A-3384-3540-9940-699120D428A8}", &OcrEngineStatics)
		ComCall(6, OcrEngineStatics, "uint*", &MaxDimension:=0)
	}
	text := ""
	if (file = "ShowAvailableLanguages")
	{
		if !IsSet(GlobalizationPreferencesStatics)
			CreateClass("Windows.System.UserProfile.GlobalizationPreferences", IGlobalizationPreferencesStatics := "{01BF4326-ED37-4E96-B0E9-C1340D1EA158}", &GlobalizationPreferencesStatics)
		ComCall(9, GlobalizationPreferencesStatics, "ptr*", &LanguageList:=0)   ; get_Languages
		ComCall(7, LanguageList, "int*", &count:=0)   ; count
		loop count
		{
			ComCall(6, LanguageList, "int", A_Index-1, "ptr*", &hString:=0)   ; get_Item
			ComCall(6, LanguageFactory, "ptr", hString, "ptr*", &LanguageTest:=0)   ; CreateLanguage
			ComCall(8, OcrEngineStatics, "ptr", LanguageTest, "int*", &bool:=0)   ; IsLanguageSupported
			if (bool = 1)
			{
				ComCall(6, LanguageTest, "ptr*", &hText:=0)
				b := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
				text .= StrGet(b, "UTF-16") "`n"
			}
			ObjRelease(LanguageTest)
		}
		ObjRelease(LanguageList)
		return text
	}
	if (lang != CurrentLanguage) or (lang = "FirstFromAvailableLanguages")
	{
		if IsSet(OcrEngine)
		{
			ObjRelease(OcrEngine)
			if (CurrentLanguage != "FirstFromAvailableLanguages")
				ObjRelease(Language)
		}
		if (lang = "FirstFromAvailableLanguages")
			ComCall(10, OcrEngineStatics, "ptr*", OcrEngine)   ; TryCreateFromUserProfileLanguages
		else
		{
			CreateHString(lang, &hString)
			ComCall(6, LanguageFactory, "ptr", hString, "ptr*", &Language:=0)   ; CreateLanguage
			DeleteHString(hString)
			ComCall(9, OcrEngineStatics, "ptr", Language, "ptr*", &OcrEngine:=0)   ; TryCreateFromLanguage
		}
		if (OcrEngine = 0)
		{
			msgbox 'Can not use language "' lang '" for OCR, please install language pack.'
			ExitApp
		}
		CurrentLanguage := lang
	}
	IRandomAccessStream := file
	ComCall(14, BitmapDecoderStatics, "ptr", IRandomAccessStream, "ptr*", &BitmapDecoder:=0)   ; CreateAsync
	WaitForAsync(&BitmapDecoder)
	BitmapFrame := ComObjQuery(BitmapDecoder, IBitmapFrame := "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
	ComCall(12, BitmapFrame, "uint*", &width:=0)   ; get_PixelWidth
	ComCall(13, BitmapFrame, "uint*", &height:=0)   ; get_PixelHeight
	if (width > MaxDimension) or (height > MaxDimension)
	{
		msgbox 'Image is to big - ' width 'x' height '.`nIt should be maximum - ' MaxDimension ' pixels'
		ExitApp
	}
	BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, IBitmapFrameWithSoftwareBitmap := "{FE287C9A-420C-4963-87AD-691436E08383}")
	ComCall(6, BitmapFrameWithSoftwareBitmap, "ptr*", &SoftwareBitmap:=0)   ; GetSoftwareBitmapAsync
	WaitForAsync(&SoftwareBitmap)
	ComCall(6, OcrEngine, "ptr", SoftwareBitmap, "ptr*", &OcrResult:=0)   ; RecognizeAsync
	WaitForAsync(&OcrResult)
	ComCall(6, OcrResult, "ptr*", &LinesList:=0)   ; get_Lines
	ComCall(7, LinesList, "int*", &count:=0)   ; count
	loop count
	{
		ComCall(6, LinesList, "int", A_Index-1, "ptr*", &OcrLine:=0)
		ComCall(7, OcrLine, "ptr*", &hText:=0)
		buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
		text .= StrGet(buf, "UTF-16") "`n"
		ObjRelease(OcrLine)
	}
	Close := ComObjQuery(IRandomAccessStream, IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")
	ComCall(6, Close)   ; Close
	Close := ComObjQuery(SoftwareBitmap, IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")
	ComCall(6, Close)   ; Close
	ObjRelease(IRandomAccessStream)
	ObjRelease(BitmapDecoder)
	ObjRelease(SoftwareBitmap)
	ObjRelease(OcrResult)
	ObjRelease(LinesList)
	return text
}

CreateClass(str, interface, &Class)
{
	CreateHString(str, &hString)
	GUID := CLSIDFromString(interface)
	result := DllCall("Combase.dll\RoGetActivationFactory", "ptr", hString, "ptr", GUID, "ptr*", &Class:=0)
	if (result != 0)
	{
		if (result = 0x80004002)
			msgbox "No such interface supported"
		else if (result = 0x80040154)
			msgbox "Class not registered"
		else
			msgbox "error: " result
	}
	DeleteHString(hString)
}

CreateHString(str, &hString)
{
	DllCall("Combase.dll\WindowsCreateString", "wstr", str, "uint", StrLen(str), "ptr*", &hString:=0)
}

DeleteHString(hString)
{
	DllCall("Combase.dll\WindowsDeleteString", "ptr", hString)
}

WaitForAsync(&Object)
{
	AsyncInfo := ComObjQuery(Object, IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
	loop
	{
		ComCall(7, AsyncInfo, "uint*", &status:=0)   ; IAsyncInfo.Status
		if (status != 0)
		{
			if (status != 1)
			{
				ComCall(8, AsyncInfo, "uint*", &ErrorCode:=0)   ; IAsyncInfo.ErrorCode
				msgbox "AsyncInfo status error: " ErrorCode
				ExitApp
			}
			break
		}
		sleep 10
	}
	ComCall(8, Object, "ptr*", &ObjectResult:=0)   ; GetResults
	ObjRelease(Object)
	Object := ObjectResult
}

Send_WM_COPYDATA(StringToSend, TargetScriptTitle, wParam:=0)
{
	CopyDataStruct := Buffer(3*A_PtrSize)
	SizeInBytes := (StrLen(StringToSend) + 1) * 2
	NumPut("Ptr", SizeInBytes
		, "Ptr", StrPtr(StringToSend)
		, CopyDataStruct, A_PtrSize)
	DetectHiddenWindows 1
	try ret := SendMessage(0x004A, wParam, CopyDataStruct,, TargetScriptTitle)
	DetectHiddenWindows 0
	return IsSet(ret) ? ret : 0
}
