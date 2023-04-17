/*
RainbowVis-JS 
Released under Eclipse Public License - v 1.0
*/

function Rainbow()
{
	"use strict";
	var gradients = null;
	var minNum = 0;
	var maxNum = 100;
	var colours = ['ff0000', 'ffff00', '00ff00', '0000ff']; 
	setColours(colours);
	
	function setColours (spectrum) 
	{
		if (spectrum.length < 2) {
			throw new Error('Rainbow must have two or more colours.');
		} else {
			var increment = (maxNum - minNum)/(spectrum.length - 1);
			var firstGradient = new ColourGradient();
			firstGradient.setGradient(spectrum[0], spectrum[1]);
			firstGradient.setNumberRange(minNum, minNum + increment);
			gradients = [ firstGradient ];
			
			for (var i = 1; i < spectrum.length - 1; i++) {
				var colourGradient = new ColourGradient();
				colourGradient.setGradient(spectrum[i], spectrum[i + 1]);
				colourGradient.setNumberRange(minNum + increment * i, minNum + increment * (i + 1)); 
				gradients[i] = colourGradient; 
			}

			colours = spectrum;
		}
	}

	this.setSpectrum = function () 
	{
		setColours(arguments);
		return this;
	}

	this.setSpectrumByArray = function (array)
	{
		setColours(array);
		return this;
	}

	this.colourAt = function (number)
	{
		if (isNaN(number)) {
			throw new TypeError(number + ' is not a number');
		} else if (gradients.length === 1) {
			return gradients[0].colourAt(number);
		} else {
			var segment = (maxNum - minNum)/(gradients.length);
			var index = Math.min(Math.floor((Math.max(number, minNum) - minNum)/segment), gradients.length - 1);
			return gradients[index].colourAt(number);
		}
	}

	this.colorAt = this.colourAt;

	this.setNumberRange = function (minNumber, maxNumber)
	{
		if (maxNumber > minNumber) {
			minNum = minNumber;
			maxNum = maxNumber;
			setColours(colours);
		} else {
			throw new RangeError('maxNumber (' + maxNumber + ') is not greater than minNumber (' + minNumber + ')');
		}
		return this;
	}
}

function ColourGradient() 
{
	"use strict";
	var startColour = 'ff0000';
	var endColour = '0000ff';
	var minNum = 0;
	var maxNum = 100;

	this.setGradient = function (colourStart, colourEnd)
	{
		startColour = getHexColour(colourStart);
		endColour = getHexColour(colourEnd);
	}

	this.setNumberRange = function (minNumber, maxNumber)
	{
		if (maxNumber > minNumber) {
			minNum = minNumber;
			maxNum = maxNumber;
		} else {
			throw new RangeError('maxNumber (' + maxNumber + ') is not greater than minNumber (' + minNumber + ')');
		}
	}

	this.colourAt = function (number)
	{
		return calcHex(number, startColour.substring(0,2), endColour.substring(0,2)) 
			+ calcHex(number, startColour.substring(2,4), endColour.substring(2,4)) 
			+ calcHex(number, startColour.substring(4,6), endColour.substring(4,6));
	}
	
	function calcHex(number, channelStart_Base16, channelEnd_Base16)
	{
		var num = number;
		if (num < minNum) {
			num = minNum;
		}
		if (num > maxNum) {
			num = maxNum;
		} 
		var numRange = maxNum - minNum;
		var cStart_Base10 = parseInt(channelStart_Base16, 16);
		var cEnd_Base10 = parseInt(channelEnd_Base16, 16); 
		var cPerUnit = (cEnd_Base10 - cStart_Base10)/numRange;
		var c_Base10 = Math.round(cPerUnit * (num - minNum) + cStart_Base10);
		return formatHex(c_Base10.toString(16));
	}

	function formatHex(hex) 
	{
		if (hex.length === 1) {
			return '0' + hex;
		} else {
			return hex;
		}
	} 
	
	function isHexColour(string)
	{
		var regex = /^#?[0-9a-fA-F]{6}$/i;
		return regex.test(string);
	}

	function getHexColour(string)
	{
		if (isHexColour(string)) {
			return string.substring(string.length - 6, string.length);
		} else {
			var name = string.toLowerCase();
			if (colourNames.hasOwnProperty(name)) {
				return colourNames[name];
			}
			throw new Error(string + ' is not a valid colour.');
		}
	}
	
	// Extended list of CSS colornames s taken from
	// http://www.w3.org/TR/css3-color/#svg-color
	var colourNames = {
		aliceblue: "F0F8FF",
		antiquewhite: "FAEBD7",
		aqua: "00FFFF",
		aquamarine: "7FFFD4",
		azure: "F0FFFF",
		beige: "F5F5DC",
		bisque: "FFE4C4",
		black: "000000",
		blanchedalmond: "FFEBCD",
		blue: "0000FF",
		blueviolet: "8A2BE2",
		brown: "A52A2A",
		burlywood: "DEB887",
		cadetblue: "5F9EA0",
		chartreuse: "7FFF00",
	        chocolate: "D2691E",
		coral: "FF7F50",
		cornflowerblue: "6495ED",
		cornsilk: "FFF8DC",
		crimson: "DC143C",
		cyan: "00FFFF",
		darkblue: "00008B",
		darkcyan: "008B8B",
		darkgoldenrod: "B8860B",
		darkgray: "A9A9A9",
		darkgreen: "006400",
		darkgrey: "A9A9A9",
		darkkhaki: "BDB76B",
		darkmagenta: "8B008B",
		darkolivegreen: "556B2F",
		darkorange: "FF8C00",
		darkorchid: "9932CC",
		darkred: "8B0000",
		darksalmon: "E9967A",
		darkseagreen: "8FBC8F",
		darkslateblue: "483D8B",
		darkslategray: "2F4F4F",
		darkslategrey: "2F4F4F",
		darkturquoise: "00CED1",
		darkviolet: "9400D3",
		deeppink: "FF1493",
		deepskyblue: "00BFFF",
		dimgray: "696969",
		dimgrey: "696969",
		dodgerblue: "1E90FF",
		firebrick: "B22222",
		floralwhite: "FFFAF0",
		forestgreen: "228B22",
		fuchsia: "FF00FF",
		gainsboro: "DCDCDC",
		ghostwhite: "F8F8FF",
		gold: "FFD700",
		goldenrod: "DAA520",
		gray: "808080",
		green: "008000",
		greenyellow: "ADFF2F",
		grey: "808080",
		honeydew: "F0FFF0",
		hotpink: "FF69B4",
		indianred: "CD5C5C",
		indigo: "4B0082",
		ivory: "FFFFF0",
		khaki: "F0E68C",
		lavender: "E6E6FA",
		lavenderblush: "FFF0F5",
		lawngreen: "7CFC00",
		lemonchiffon: "FFFACD",
		lightblue: "ADD8E6",
		lightcoral: "F08080",
		lightcyan: "E0FFFF",
		lightgoldenrodyellow: "FAFAD2",
		lightgray: "D3D3D3",
		lightgreen: "90EE90",
		lightgrey: "D3D3D3",
		lightpink: "FFB6C1",
		lightsalmon: "FFA07A",
		lightseagreen: "20B2AA",
		lightskyblue: "87CEFA",
		lightslategray: "778899",
		lightslategrey: "778899",
		lightsteelblue: "B0C4DE",
		lightyellow: "FFFFE0",
		lime: "00FF00",
		limegreen: "32CD32",
		linen: "FAF0E6",
		magenta: "FF00FF",
		maroon: "800000",
		mediumaquamarine: "66CDAA",
		mediumblue: "0000CD",
		mediumorchid: "BA55D3",
		mediumpurple: "9370DB",
		mediumseagreen: "3CB371",
		mediumslateblue: "7B68EE",
		mediumspringgreen: "00FA9A",
		mediumturquoise: "48D1CC",
		mediumvioletred: "C71585",
		midnightblue: "191970",
		mintcream: "F5FFFA",
		mistyrose: "FFE4E1",
		moccasin: "FFE4B5",
		navajowhite: "FFDEAD",
		navy: "000080",
		oldlace: "FDF5E6",
		olive: "808000",
		olivedrab: "6B8E23",
		orange: "FFA500",
		orangered: "FF4500",
		orchid: "DA70D6",
		palegoldenrod: "EEE8AA",
		palegreen: "98FB98",
		paleturquoise: "AFEEEE",
		palevioletred: "DB7093",
		papayawhip: "FFEFD5",
		peachpuff: "FFDAB9",
		peru: "CD853F",
		pink: "FFC0CB",
		plum: "DDA0DD",
		powderblue: "B0E0E6",
		purple: "800080",
		red: "FF0000",
		rosybrown: "BC8F8F",
		royalblue: "4169E1",
		saddlebrown: "8B4513",
		salmon: "FA8072",
		sandybrown: "F4A460",
		seagreen: "2E8B57",
		seashell: "FFF5EE",
		sienna: "A0522D",
		silver: "C0C0C0",
		skyblue: "87CEEB",
		slateblue: "6A5ACD",
		slategray: "708090",
		slategrey: "708090",
		snow: "FFFAFA",
		springgreen: "00FF7F",
		steelblue: "4682B4",
		tan: "D2B48C",
		teal: "008080",
		thistle: "D8BFD8",
		tomato: "FF6347",
		turquoise: "40E0D0",
		violet: "EE82EE",
		wheat: "F5DEB3",
		white: "FFFFFF",
		whitesmoke: "F5F5F5",
		yellow: "FFFF00",
		yellowgreen: "9ACD32"
	}
}


var hp1345a = [
    [
	[0,8],
	[12,8]
    ],
    [
	[6,18],
	[8,18],
	[8,16],
	[6,16],
	[6,18]
    ],
    [ 
	[3,18],
	[9,18],
	[12,12],
	[12,6],
	[9,0],
	[3,0],
	[0,6],
	[0,12],
	[3,18],
	[-1,-1],
	[1,16],
	[11,2]
    ],
    [ 
	[3,18],
	[9,18],
	[-1,-1],
	[6,18],
	[6,0],
	[3,3]
    ],
    [ 
	[12,18],
	[0,18],
	[2,13],
	[12,7],
	[12,3],
	[9,0],
	[3,0],
	[0,3]
    ],
    [ 
	[0,16],
	[3,18],
	[9,18],
	[12,15],
	[12,11],
	[9,9],
	[3,9],
	[9,9],
	[12,7],
	[12,3],
	[9,0],
	[3,0],
	[0,2]
    ],
    [ 
	[12,12],
	[0,12],
	[9,0],
	[9,18]
    ],
    [ 
	[0,16],
	[3,18],
	[9,18],
	[12,16],
	[12,10],
	[9,8],
	[3,8],
	[0,9],
	[2,0],
	[12,0]
    ],
    [ 
	[0,11],
	[3,8],
	[9,8],
	[12,11],
	[12,15],
	[9,18],
	[3,18],
	[0,15],
	[0,8],
	[3,3],
	[7,0]
    ],
    [ 
	[4,18],
	[12,0],
	[0,0]
    ],
    [ 
	[3,18],
	[9,18],
	[12,15],
	[12,11],
	[9,8],
	[3,8],
	[0,5],
	[0,2],
	[3,-1],
	[9,-1],
	[12,2],
	[12,5],
	[9,8],
	[3,8],
	[0,11],
	[0,15],
	[3,18]
    ],
    [ 
	[5,18],
	[9,15],
	[12,10],
	[12,3],
	[9,0],
	[3,0],
	[0,3],
	[0,7],
	[3,10],
	[9,10],
	[12,7]
    ]
]

function drawHP1345A(ctx, x, y, str, scale, rot, wid) {

    // function requires a string to be passed ... formatting to be done
    // by caller. Ignores non number or . characters
    //
    // x,y:   start location in pixels (upper left or first char)
    // str:   string to draw
    // scale: size multiplier .. 1 is nominal
    // rot:   rotation angle (radians)
    // wid:   width of polyline (pixels)
    
    let xc = x;
    let yc = y;
    let xr;
    let yr;
    let shape = [];
    let b0 = 48 // string.byte("0")
    let np;
    let first;
    let v = [];

    for (let char of str) {
	if (char == "-") {
	    np = 0
	} else if (char == ".") {
	    np = 1
	} else {
	    np = char.charCodeAt() - b0 + 2
	}
	shape = hp1345a[np]
	ctx.strokeStyle = "white";
	ctx.lineWidth = wid;
	ctx.lineJoin = "round";
	
	if (typeof shape != "undefined") {
	    ctx.beginPath();
	    first = true;
	    for (let k = 0, len = shape.length; k < len; k++) {
		v = shape[k]
		if (v[0] == -1) { // pick up pen
		    ctx.stroke();
		    ctx.beginPath();
		    first = true;
		} else {
		    xr = xc + scale*v[0]*Math.cos(-rot) - scale*v[1]*Math.sin(-rot)
		    yr = yc + scale*v[0]*Math.sin(-rot) + scale*v[1]*Math.cos(-rot)
		    if (first == true) {
			ctx.moveTo(xr, yr);
			first = false;
		    } else {
			ctx.lineTo(xr, yr);
		    }
		}
	    }
	    ctx.stroke();
	    xc = xc + scale * 18 * Math.cos(-rot)
	    yc = yc + scale * 18 * Math.sin(-rot)
	}
    }
}
    
function go() {
    let t = document.getElementById("input-json").value;
    var obj = null, err = null;
    
    try {
        obj = JSON.parse(t);
    } catch (e) {
        err = e;
    }
    if (obj) {
        document.getElementById("json-parse-status").innerText = "JSON OK";
        draw(obj);
    } else if (err) {
        document.getElementById("json-parse-status").innerText = ""+err;
    } else {
        document.getElementById("json-parse-status").innerText = "????";
    }
}

function jsonchanged() {
    go();
}

function savepng() {
    let cvs = document.getElementById("output-canvas");
    let imgurl = cvs.toDataURL("image/png");
    var a = document.createElement("a");
    a.href = imgurl;
    a.download = "canvas.png";
    a.click();
}

function getRGB(cfs) {
    // assumes we have already set context color to the desired color
    // and cfs is the resulting value
    if (cfs != "transparent") {
	let rgbI = parseInt(cfs.slice(1), 16)
	let r = (rgbI >> 16) & 255;
	let g = (rgbI >> 8) & 255;
	let b = rgbI & 255;
	return {r:r, g:g, b:b, t:"false"}
    } else {
	return {r:0, g:0, b:0, t:"true"}
    }
}

function getTextHeight(ctx, text) {
    let mtx = ctx.measureText(text)
    return Math.abs(mtx.actualBoundingBoxAscent) + Math.abs( mtx.actualBoundingBoxDescent)
}

function getTextAscent(ctx, text) {
    let mtx = ctx.measureText(text)
    return mtx.fontBoundingBoxAscent
}

function getTextDescent(ctx, text) {
    let mtx = ctx.measureText(text)
    return mtx.fontBoundingBoxDescent
}


function getTextWidth(ctx, text) {
    let mtx = ctx.measureText(text)
    return mtx.width
}

function arcsegment(ctx, x0, y0, ri, ro, a1, a2) {
    ctx.beginPath();
    ctx.arc(x0, y0, ro, a1, a2);
    ctx.lineTo(x0 + ri * Math.cos(a2),
	       y0 + ri * Math.sin(a2));
    ctx.arc(x0, y0, ri, a2, a1, true);
    ctx.lineTo(x0 + ro * Math.cos(a1),
	       y0 + ro * Math.sin(a1));
    ctx.fill();
}

function returnColorVals(spec, minI, maxI) {
    var cval = [];
    let min, max

    min = minI
    max = maxI
    /*
    if (maxI >= minI) {
	min = minI
	max = maxI
    } else {
	min = maxI
	max = minI
    }
    */
    let normal
    if (max >= min) {
	normal = true
    } else {
	normal = false
    }
    const step = Math.abs(max - min) / spec.length;
    //console.log("step", step);
    let k
    for (var i = 0; i < spec.length; i++) {
	if (normal) {
	    k = i
	} else {
	    k = spec.length - i - 1
	}
	if (normal) {
	    cval[i] = {color: spec[i], val: step * (i + 1) };
	} else {
	    cval[i] = {color: spec[k], val: step * (i + 1) };
	}
	//console.log(i, k, spec[i], step * (i+1), cval[i])
    }
    return cval;
}

function drawNeedleCustom(ctx, arr, points, f, angle) {
    
    if (typeof points == "undefined") {
	//console.log("returning")
	return
    }
    
    ctx.beginPath();
    for (let k = 0, len = points.length; k < len; k++ ) {
	ctx.lineTo(arr.x0 + f * points[k].x * Math.cos(angle) -
		   f * points[k].y * Math.sin(angle),
		   arr.y0 + f * points[k].x * Math.sin(angle) +
		   f * points[k].y * Math.cos(angle))
    }
    ctx.fill();
    
}

function drawNeedle(ctx, arr, arrR, type, f, angle) {
    const nL = 58
    var needles = { needle: [ {x:-1,y:0}, {x:-2,y:1}, {x:-4,y:4}, {x:-1,y:nL},
			      {x:1,y:nL}, {x:4, y:4}, {x:2, y:1}, {x:1,y:0}],
		    needleAlt:  [ {x:0,y:0}, {x:-3,y:3}, {x:-3,y:50}, {x:0,y:nL},
				  {x:3, y:50}, {x:3, y:0}, {x:3, y:3},{x:0,y:0} ],
		    needleFat:  [ {x:0,y:0}, {x:-3, y:3}, {x:-5,y:35}, {x:0,y:nL},
				  {x:5, y:35}, {x:3,y:3},{x:0,y:0} ],
		    inner:      [ {x:0,y:0}, {x:-3,y:3}, {x:0,y:45},{x:3,y:3},{x:0,y:0} ],
		    needleTrim: [ {x:-5,y:0}, {x:-1,y:nL}, {x:1, y:nL}, {x:5, y:0}],
		    innerTrim: [ {x:-3,y:0}, {x:-1,y:nL-10}, {x:1, y:nL-10}, {x:3, y:0}],
	      }

    //console.log("drawneedle", type);
    
    if (typeof needles[type] == "undefined" || type == "none" ) {
	//console.log("RETURNING", type)
	return
    }

    let ncolor
    if (typeof arr.needleColor != "undefined") {
	ncolor = arr.needleColor;
    } else {
	ncolor = "white";
    }

    if (type == "needleTrim") {
	const aa = arr.needleTrim || 0

	needles.needleTrim[0].x = needles.needleTrim[0].x * (100 - aa) / 100 +
	    needles.needleTrim[1].x * aa / 100;
	needles.needleTrim[0].y = nL * aa / 100
	needles.needleTrim[3].x = needles.needleTrim[3].x * (100 - aa) / 100 +
	    needles.needleTrim[2].x * aa / 100
	needles.needleTrim[3].y = nL * aa / 100

	needles.innerTrim[0].x = needles.innerTrim[0].x * (100 - aa) / 100 +
	    needles.innerTrim[1].x * aa / 100;
	needles.innerTrim[0].y = nL * aa / 100
	needles.innerTrim[3].x = needles.innerTrim[3].x * (100 - aa) / 100 +
	    needles.innerTrim[2].x * aa / 100
	needles.innerTrim[3].y = nL * aa / 100
    }

    arrR.needle = [];
    let tL = needles[type].length;
    for (let i = 0; i < tL; i++) {
	arrR.needle[i] = needles[type][i];
    }
    
    ctx.fillStyle = "white";
    if (typeof arr.value != "undefined") {
	let ndl = new Path2D();
	for (let k = 0, len = needles[type].length; k < len; k++ ) {
	    ndl.lineTo(arr.x0 + f * needles[type][k].x * Math.cos(angle) -
		       f * needles[type][k].y * Math.sin(angle),
		       arr.y0 + f * needles[type][k].x * Math.sin(angle) +
		       f * needles[type][k].y * Math.cos(angle))
	}
	ndl.closePath();
	ctx.fill(ndl);
    }

    let tt
    if (type == "needleTrim") {
	tt = "innerTrim"
    } else {
	tt = "inner"
    }
    
    arrR.inner = [];
    tL = needles[tt].length;
    for (let i = 0; i < tL; i++) {
	arrR.inner[i] = needles[tt][i];
    }
    
    ctx.fillStyle = ncolor;
    arrR.rgbInnerFillColor = getRGB(ctx.fillStyle);
    
    if (typeof arr.value != "undefined") {
	ctx.beginPath();
	for (let k = 0, len = needles[tt].length; k < len; k++ ) {
	    ctx.lineTo(arr.x0 + f * needles[tt][k].x * Math.cos(angle) -
		       f * needles[tt][k].y * Math.sin(angle),
		       arr.y0 + f * needles[tt][k].x * Math.sin(angle) +
		       f * needles[tt][k].y * Math.cos(angle))
	}
	ctx.fill();
    }
}

function jetiFont(font) {
    const jetiFonts = ["Mini", "Normal", "Bold", "Big", "Maxi"] 
    const jetiSizes = [10, 16, 16, 20, 40]
    let jF = 0
    let dF = Math.abs(font - jetiSizes[0]) // assume MINI
    for (let i = 1; i < 5; i++) {
	if (Math.abs(font - jetiSizes[i]) < dF) {
	    dF = Math.abs(font - jetiSizes[i]);
	    jF = i;
	}
    }
    return jetiFonts[jF]
}

function jetiHeight(font) {
    const jetiFonts = ["Mini", "Normal", "Bold", "Big", "Maxi"]
    const jetiSizes = [10, 16, 16, 19, 34]
    let iF = 1
    for (let i = 0; i < 4; i++) {
	if (font == jetiFonts[i]) {
	    iF = i;
	}
    }
    return jetiSizes[iF]
}

function jetiToCtx(jfont) {
    // note - these sizes are what is needed to match pixel height to jeti fonts
    // checked with special background file
    const point = {Mini:10, Normal:16, Bold:16, Big: 20, Maxi: 34, None:3}
    //ctx.font="bold " + fontScale * ro + "px sans-serif"
    let bstr = "";
    if (jfont == "Bold") {
	bstr = "bold ";
    }

    let pstr = point[jfont]
    if (typeof pstr == "undefined") {
	pstr = "10"
    }
    //console.log("jetiToCtx returning", bstr + pstr + "px sans-serif")
    
    return bstr + pstr + "px sans-serif"

}


function roundG(ctx, arr, x0, y0, ro, start, end, min, max, nseg, minmaj, specIn, colors, value, label, type, ndlarc) {

    var ri;

    if (typeof arr.arcWidth == "undefined") {
	if (ndlarc == "needle") {
	    ri = ro * 0.85;
	} else {
	    ri = ro * 0.80;
	}
    } else {
	ri = (100 - arr.arcWidth) / 100 * ro
    }

    //const fontScale = 0.24;
    //console.log("type, ndlarc", type, ndlarc)
    
    var arrR = {};
    arrR.gaugeRadius = ro
    
    arrR.divs = nseg;
    
    var spec = specIn;

    if (typeof specIn == "object" && specIn != null) {
	if (specIn.length == 1) {
	    spec[1] = spec[0];
	}
    }
    
    arrR.ri = ri;
    arrR.ro = ro;


    if (typeof arr.tickFont == "undefined") {
	//console.log("tickFont undefined")
	ctx.font = jetiToCtx("Mini")
	arrR.tickFont = "Mini"
    } else {
	ctx.font = jetiToCtx(arr.tickFont)
    }
    
    //ctx.font="bold " + fontScale * ro + "px sans-serif"
    //var fontoffset = fontScale * ro / 4;

    if (typeof spec == "object") {
	var rainbow = new Rainbow();
	rainbow.setSpectrumByArray(spec); 
	rainbow.setNumberRange(0,Math.max(nseg-1,1))

	// if this is beign drawn as an arc gauge need to send colors and vals to TX
	// needle gauges have arc pre-draw and it's in the png

	if (ndlarc == "arc") {
	    var vv;
	    arrR.TXspectrum = []; // save colors at vals to send to TX
	    for (let i = 0; i < nseg; i++) {
		vv = min + i * (max - min) / (nseg - 1);
		let rgbI = parseInt(rainbow.colourAt(i), 16)
		let r = (rgbI >> 16) & 255;
		let g = (rgbI >> 8) & 255;
		let b = rgbI & 255;
		arrR.TXspectrum[i] = {v:vv, r:r, g:g, b:b}
	    }
	}
	//console.log("done. arrR", arrR.TXspectrum)
    }

    if (typeof colors == "object") {
	if (ndlarc == "arc") {
	    arrR.TXcolorvals = []; // send rgb colors to TX
	    for(let i = 0, lcv = colors.length;i < lcv; i++) {
		ctx.fillStyle = colors[i].color; //side effect turns "colorname" to hex on return
		let rgbI = parseInt(ctx.fillStyle.slice(1), 16)
		let r = (rgbI >> 16) & 255;
		let g = (rgbI >> 8) & 255;
		let b = rgbI & 255;
		arrR.TXcolorvals[i] = {v:colors[i].val, r:r, g:g, b:b}
	    }
	}
    }

    var a;
    var delta;
    arrR.tickLabels = [];
    var idxT = 0;
    //arrR.jFont = jetiFont(fontScale * ro);
    //console.log(ctx.font, fontScale * ro, jetiFont(fontScale * ro))    
    let normal = (max >= min);
    let valdelta = Math.abs(max-min) / nseg;
    const fudge = 1 / (100*nseg);
    for (let i = 0; i <= nseg; i++) {

	delta = (end - start) / nseg;
	a = start + i * delta


	var aFrac = (a - start) / (end - start)
	var val = (min + aFrac * (max - min))

	//console.log(i, a, aFrac, val)
	
	if (type != "altimeter") {
	    //ctx.fillStyle = "gray";
	    if (typeof colors == "object") {
		const cl = colors.length - 1;

		if (val != 0) {
		    if (normal) {
			val = val + fudge;
		    } else {
			val - val - fudge;
		    }
		}
		if (val <= colors[0].val) {
		    ctx.fillStyle = colors[0].color
		} else if (val >= colors[cl].val) {
		    ctx.fillStyle = colors[cl].color
		} else {
		    if (normal) {
			for (let j = 1; j <= cl; j++) {
			    if (val >= colors[j-1].val && val < colors[j].val) {
				ctx.fillStyle = colors[j].color;
				break;
			    }
			}
		    } else {
			for (let j = 1; j <= cl; j++) {
			    //console.log("$", j, val, colors[j-1].val, colors[j].val, colors[j].color)
			    if ( (val - valdelta) >= colors[j-1].val && (val - valdelta) < colors[j].val) {
				//console.log("#", j, val, colors[j].val, colors[j].color)
				ctx.fillStyle = colors[j].color;
				break;
			    }
			}
		    }
		}
	    } else if (typeof spec == "object") {
		ctx.fillStyle = "#"+rainbow.colourAt(i);
	    } else {
		ctx.fillStyle = "white";
	    }
	} else {
	    ctx.fillStyle = "#202020";
	}

	if ( (i < nseg) && (ndlarc != "arc") ) {
	    var a1 = start + i * delta - 0*delta
	    var a2 = start + i * delta + 1*delta;
	    //console.log(i, spec, x0, y0, ri, ro, ctx.fillStyle)
	    if (arr.scaleVis != "off") {
		arcsegment(ctx, x0, y0, ri, ro, a1, a2 )
	    }
	}

	ctx.lineWidth = ro / 46;	
	ctx.strokeStyle="white";
	const tO = 1.0; //0.98;
	const tI = 2 - tO;
	if (arr.scaleVis != "off") {
	    ctx.beginPath();
	    ctx.moveTo(x0 + tO * ro * Math.cos(a), y0 + tO * ro * Math.sin(a))
	    ctx.lineTo(x0 + tI * ri * Math.cos(a), y0 + tI * ri * Math.sin(a))
	    ctx.stroke();
	}
	
	//const label2C = 1.8;//1.6;
	let label2C
	if (typeof arr.tickSpace != "undefined") {
	    label2C = 1.8 * arr.tickSpace / 100
	} else {
	    label2C = 1.8
	}

	if (minmaj > 0 && i % minmaj == 0) {
	    ctx.fillStyle = "white";
	    ctx.textAlign = "center";
	    var rt = ri - label2C * (ro - ri)
	    arrR.TS = rt
	    var val = (min + i * (max - min) / nseg)
	    if (1==1) { //(val <=  max) {
		if (type == "airspeed") {
		    //ctx.font="bold " + 0.60 * fontScale * ro + "px sans-serif"
		    ctx.font=jetiToCtx(arr.tickFont)
		    //fontoffset = fontScale * ro / 4;		    
		}
		var sign;
		if (val >= 0) {
		    sign = 1.0
		} else {
		    sign = -1.0
		}
		var rval = sign * Math.floor(sign * val * 100000.0) / 100000.0;
		let vs = rval.toString();
		// console.log(vs);
		let vi = vs.indexOf(".");
		let vl = vs.length
		let dp = 0
		var tval;
		if (vi == -1) {
		    tval = vs;
		} else {
		    tval = vs.substring(0, vi+4);
		    dp = (vl - vi) - 1
		}
		// here are the tick labels
		ctx.font = jetiToCtx(arr.tickFont)
		if (typeof(arr.value) != "undefined") {
		    let xt = x0 + rt * Math.cos(a);
		    let yt = y0 + rt * Math.sin(a);
		    ctx.textBaseline = "middle";
		    ctx.textAlign = "center";
		    if (arr.tickFont != "None" && arr.scaleVis != "off") {
			ctx.fillText(tval, xt, yt)
		    }
		}
		arrR.tickLabels[idxT] = {rt:rt, ca:Math.cos(a), sa:Math.sin(a), dp:dp}
		idxT = idxT + 1;
	    }
	    ctx.lineWidth=ro/23;	
	    ctx.strokeStyle="white";
	    var rr = ri - (ro - ri) / 4; //2;
	    if (arr.scaleVis != "off") {
		ctx.beginPath();
		ctx.moveTo(x0 + tO * ro * Math.cos(a), y0 + tO * ro * Math.sin(a))
		ctx.lineTo(x0 + rr * Math.cos(a), y0 + rr * Math.sin(a))
		ctx.stroke();
	    }
	}
    }

    
    if ( ndlarc == "arc") {
	ctx.fillStyle = "gray"; // draw gray arc on png file
	if (arr.scaleVis != "off") {	
	    arcsegment(ctx, x0, y0, ri, ro, start, end);
	}
	if (typeof value == "number") { // done only if arc to be rendered
	    cf = "white";
	    
	    if (typeof colors == "object") {
		const cl = colors.length - 1;
		if (value <= colors[0].val) {
		    cf = colors[0].color
		} else if (value >= colors[cl].val) {
		    cf = colors[cl].color
		} else {
		    for (let j = 1; j <= cl; j++) {
			if (value >= colors[j-1].val && value < colors[j].val) {
			    cf = colors[j].color;
			    break;
			}
		    }
		}
	    }
	    if (typeof spec == "object") {
		//rainbow.setNumberRange(0,nseg-1)
		var ns = Math.floor((nseg - 1) * (value - min) / (max - min));
		cf = "#"+rainbow.colourAt(ns);
		//console.log(ns, ctx.fillStyle)
	    }
	    
	    var valFrac = (arr.value - min) / (max - min)
	    ctx.fillStyle = cf;
	    arcsegment(ctx, x0, y0, ri, ro, start, start + (end-start) * valFrac);
	}
    }
    
    ctx.fillStyle = "white";
    ctx.textAlign = "center";

    if (typeof arr.labelFont == "undefined") {
	//console.log("labelFont undefined")
	ctx.font = jetiToCtx("Mini")
	arrR.labelFont = "Mini"
    } else {
	ctx.font = jetiToCtx(arr.labelFont)
    }

    let lpx, lpy
    
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx= arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy= arr.labelPosY
    }
    
    if (ndlarc == "needle") {
	arrR.yL = y0 + 0.90 * ro + lpy
	arrR.xL = x0 + lpx;
	//console.log("needle, yL", arrR.yL)
	//ctx.font = jetiToCtx(arr.labelFont);
	//ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
    } else {
	arrR.yL = y0 + 0.70 * ro + lpy;
	arrR.xL = x0 + lpx;
	//console.log("arc, yL", arrR.yL)
	//ctx.font = jetiToCtx(arr.labelFont);
	//ctx.font = "bold " + 1.0 * fontScale * ro + "px sans-serif"
    }
    ctx.textBaseline = "middle";
    ctx.textAlign = "center";

    //console.log(arr.labelFont, arr.label, lpx, lpy, arrR.xL, arrR.yL)

    if (arr.labelFont != "None") {
	ctx.font = jetiToCtx(arr.labelFont);
	let lblclr
	if (typeof arr.labelColor != "undefined"){
	    lblclr = arr.labelColor;
	} else {
	    lblclr = "white"
	}
	if (typeof arr.labelBoxColor != "undefined" && arr.labelBoxColor != "transparent") {
	    ctx.fillStyle = arr.labelBoxColor
	    arrR.rgbLabelBoxColor = getRGB(ctx.fillStyle)
	    let ltw = Math.floor(getTextWidth(ctx, label) + 1.5);
	    let lta = Math.floor(getTextAscent(ctx, label));
	    let ltd = Math.floor(getTextDescent(ctx, label));
	    arrR.xLB = arrR.xL - ltw / 2;
	    arrR.wLB = ltw;
	    arrR.hLB = Math.floor(lta) + Math.floor(ltd);
	    arrR.yLB = arrR.yL - arrR.hLB / 2 - 1;
	    arrR.rLB = (lta+ltd) / 4
	    if (typeof label != "undefined") {
		roundedRect(ctx,arrR.xLB, arrR.yLB, arrR.wLB, arrR.hLB, arrR.rLB)
	    }
	}
	ctx.fillStyle = lblclr;
	arrR.rgbLabelColor = getRGB(ctx.fillStyle);
	if (typeof arr.label != "undefined") {
	    ctx.fillText(label, arrR.xL, arrR.yL);
	}
	ctx.fillStyle = "white";
	ctx.font = jetiToCtx(arr.tickFont);
	var dig
	dig = Math.max(2 - Math.floor(Math.log10(Math.abs(max - min))), 0);
	//console.log("log, digits", Math.log10(max - min), digits)
	if (ndlarc != "needle") {
	    arrR.xLV = x0 - 0.55 * ro;
	    arrR.xRV = x0 + 0.55 * ro;
	    arrR.yLV = y0 + 0.92 * ro;
	    arrR.yRV = arrR.yLV;
	    if (arr.tickFont != "None") {
		if (typeof label != "undefined") {
		    ctx.fillText(parseFloat(min).toFixed(digits), arrR.xLV, arrR.yLV);
		    ctx.fillText(parseFloat(max).toFixed(digits), arrR.xRV, arrR.yRV);
		}
	    }
	}
    }

    if (type == "altimeter") {
	//ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
	ctx.font = jetiToCtx(arr.labelFont)
	const xA = x0 + ro * 0.25;
	const yA = y0 - ro * 0.1;
	ctx.textBaseline = "middle";
	ctx.textAlign = "center";
	if (arr.labelFont != "None") {
	    ctx.fillText("ALT", xA, yA);
	}
	const x10 = x0 - ro * 0.03;
	const y10 = y0 - ro * 0.40;
	//ctx.font = "bold " + 0.60 * fontScale * ro + "px sans-serif"
	ctx.font = jetiToCtx(arr.labelFont);
	if (arr.labelFont != "None") {
	    ctx.fillText("10 m", x10, y10);
	}
    }

    if (typeof arr.valueFont == "undefined") {
	//console.log("valueFont undefined")
	ctx.font = jetiToCtx("Mini")
	arrR.valueFont = "Mini"
    } else {
	//console.log("valueFont", arr.valueFont)
	ctx.font = jetiToCtx(arr.valueFont)
    }

    ctx.font = jetiToCtx(arr.valueFont);
    
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";

    let rpX,rpY
    if (typeof arr.readoutPosX != "undefined") {
	rpX = arr.readoutPosX;
    } else {
	rpX = 0
    }

    if (typeof arr.readoutPosY != "undefined") {
	rpY = arr.readoutPosY;
    } else {
	rpY = 0
    }
    
    if (ndlarc  == "needle") {
	arrR.xV = x0 + rpX;
	arrR.yV = y0 + 0.6 * ro + rpY;
    } else {
	arrR.xV = x0 + rpX;
	arrR.yV = y0 + rpY;
    }

    var digits
    if (max != min) {
	digits = Math.max(2 - Math.floor(Math.log10(Math.abs(max - min))), 0);
    } else {
	digits = 0;
    }
    if (arr.valueFont != "None" && typeof arr.label != "undefined") {
	ctx.fillText(parseFloat(value).toFixed(digits), arrR.xV, arrR.yV);
    }

    if (type == "altimeter") {
	var val1C = value / 100.0;
	var valTC = Math.floor(value / 100.0)
	var valT  = 10 * (val1C - valTC);
	var frac = Math.max(Math.min( (val1C - min) / (max - min), 1), 0);
	var angle = start + frac * (end - start) - Math.PI/2;
	ctx.fillStyle = "white";
	var f = 0.90 * ro / 58;
	drawNeedle(ctx, arr, arrR, "needleFat", f)
	frac = Math.max(Math.min( (valT - min) / (max - min), 1), 0);
	angle = start + frac * (end - start) - Math.PI/2;
	ctx.fillStyle = "white";
	f = 0.90 * ro / 58;
	drawNeedle(ctx, arr, arrR, "needleAlt", f)
    } else {
	if (ndlarc != "arc") {
	    var frac = Math.max(Math.min( (value - min) / (max - min), 1), 0);
	    var angle = start + frac * (end - start) - Math.PI/2;
	    ctx.fillStyle = "white";
	    let f = 0.90 * ro / 58;
	    let ntype
	    if (typeof arr.needleType != "undefined") {
		ntype = arr.needleType;
	    } else {
		ntype = "needle";
	    }
	    drawNeedle(ctx, arr, arrR, ntype, f, angle);
	}
    }
    return arrR;
}

function roundNeedleGauge(ctx, arr) {
    return roundGauge(ctx, arr, "needle");
}

function roundArcGauge(ctx, arr) {
    return roundGauge(ctx, arr, "arc");
}

function roundGauge(ctx, arr, indicator) {

    var start = -1.25 * Math.PI;
    var end = 0.25 * Math.PI;
    const eTrim = 1.0 //0.99;
    var rotate = arr.rotate;
    
    if (arr.gaugetype == "airspeed") {
	arr.start = 22.5
	arr.end = -22.5 + 360
	//rotate = 180;
    }

    if (typeof arr.start == 'number') {
	start = (arr.start - 90) * Math.PI / 180.0;
    }
    if (typeof arr.end == 'number') {
	end   = (arr.end   - 90)   * Math.PI / 180.0;
    }
    
    if (typeof rotate == 'number') {
	start = start + rotate * Math.PI / 180.0;
	end   = end   + rotate * Math.PI / 180.0;
    }

    var bezel=4;
    
    if (arr.radius < 40) {
	bezel = 3;
    }
    
    const radius = arr.radius - 2*bezel - 14; // 12 pix to allow for outer tick labels 
    const gradient = ctx.createRadialGradient(arr.x0, arr.y0, 0, arr.x0, arr.y0, radius) 

    gradient.addColorStop(0  , "black");
    gradient.addColorStop(0.6, "#202020");
    gradient.addColorStop(  1, "#303030");

    ctx.fillStyle = gradient;

    if (arr.faceVis != "off") {
	ctx.beginPath();
	ctx.ellipse(arr.x0, arr.y0, radius * eTrim, radius * eTrim, 0, 0, 2*Math.PI);
	ctx.fill();
    }

    const b1gradient = ctx.createRadialGradient(arr.x0, arr.y0, radius, arr.x0, arr.y0, radius+bezel);

    b1gradient.addColorStop(0, "black");
    b1gradient.addColorStop(0.2, "#101010")
    b1gradient.addColorStop(1, "#303030");

    ctx.fillStyle = b1gradient;
    if (arr.faceVis != "off") {
	arcsegment(ctx, arr.x0, arr.y0, radius, radius+bezel, 0, 2*Math.PI);
    }

    const b2gradient = ctx.createRadialGradient(arr.x0, arr.y0, radius+bezel,
						arr.x0, arr.y0, radius+2*bezel);
    b2gradient.addColorStop(1, "black");
    b2gradient.addColorStop(0.2, "#101010")
    b2gradient.addColorStop(0, "#303030");

    ctx.fillStyle = b2gradient;

    var max = arr.max;
    var min = arr.min;
    var subdivs = arr.subdivs;
    var majdivs = arr.majdivs;
    var divs = subdivs * majdivs;

    //note: divs is returned in arrR in roundG()

    if (divs == 0) {
	if (typeof arr.divisions == "number") {
	    divs = arr.divisions;
	} else {
	    divs = 10;
	}
    }

    var clr = [];
    clr = arr.colorvals;
    if (arr.gaugetype == "altimeter") {
	max = 10;
	min = 0;
	divs = 50;
	subdivs = 5;
	majdivs = divs / subdivs;
	start = -Math.PI/2;
	end = 2*Math.PI + start;
	rotate = arr.rotate;
    } else if (arr.gaugetype == "airspeed") {
	console.log("airspeed", arr.Vspeeds.Vso)
	min = 0;
	max = 240;
	clr = [ {color: "black", val: arr.Vspeeds.Vs},
		{color: "green", val: arr.Vspeeds.Vno},
		{color: "yellow", val: arr.Vspeeds.Vne},
		{color: "red", val: 2 * arr.Vspeeds.Vne}
	      ]
    }

    var spec = [];
    spec = arr.spectrum;

    return roundG(ctx, arr, arr.x0, arr.y0, radius, start, end, min, max,
		  divs, subdivs, spec, clr,
		  arr.value, arr.label, arr.gaugetype, indicator);
}

function virtualGauge(ctx, arr) {

    var start = -1.25 * Math.PI;
    var end = 0.25 * Math.PI;
    var rotate = arr.rotate;

    //console.log(arr)
    
    //const fontScale = 0.24;

    var arrR = {};
    const ro = arr.radius - 2;
    const ri = ro * 0.85;
    const nL = 58;
    needleTri = [ {x:-5,y:0}, {x:-1,y:nL}, {x:1, y:nL}, {x:5, y:0}]

    const aa = arr.needleClip || 0;

    needleTri[0].x = needleTri[0].x * (100 - aa) / 100 + needleTri[1].x * aa / 100
    needleTri[0].y = nL * aa / 100
    needleTri[3].x = needleTri[3].x * (100 - aa) / 100 + needleTri[2].x * aa / 100
    needleTri[3].y = nL * aa / 100


    /*
    ctx.fillStyle = "black"

    ctx.font = jetiToCtx("Mini");
    console.log("Mini", ctx.font)
    ctx.fillText("Mini Font Test", arr.x0+10, arr.y0 - arr.radius/2)
    
    ctx.font = jetiToCtx("Normal");
    console.log("Normal", ctx.font)
    ctx.fillText("Normal Font Test", arr.x0+10, arr.y0 - arr.radius/2 + 15)
    
    ctx.font = jetiToCtx("Bold");
    console.log("Bold", ctx.font)
    ctx.fillText("Bold Font Test", arr.x0+10, arr.y0 - arr.radius/2 + 30)

    ctx.font = jetiToCtx("Big");
    console.log("Big", ctx.font)
    ctx.fillText("Big Font Test", arr.x0+10, arr.y0 - arr.radius/2 + 45)
    
    ctx.font = jetiToCtx("Maxi");
    console.log("Maxi", ctx.font)
    ctx.fillText("Maxi Font Test", arr.x0+10, arr.y0 - arr.radius/2 + 80)

    return

    */
    
    arrR.needle = [];
    const tL = needleTri.length;

    for (let i = 0; i < tL; i++) {
	arrR.needle[i] = needleTri[i];
    }
    
    if (typeof arr.value == "undefined") {
	//console.log("arr.value not number - returning - type:", typeof arr.value)
	return arrR;
    }

    if (typeof arr.start == 'number') {
	start = (arr.start - 90) * Math.PI / 180.0;
    }

    if (typeof arr.end == 'number') {
	end   = (arr.end   - 90)   * Math.PI / 180.0;
    }

    if (typeof rotate == 'number') {
	start = start + rotate * Math.PI / 180.0;
	end   = end   + rotate * Math.PI / 180.0;
    }

    arrR.startArc = start;
    arrR.endArc = end;
    
    ctx.strokeStyle = "lightgray";

    ctx.beginPath();
    ctx.moveTo(arr.x0 - ro, arr.y0);
    ctx.lineTo(arr.x0 + ro, arr.y0);
    ctx.stroke()

    ctx.beginPath();
    ctx.moveTo(arr.x0, arr.y0 - ro);
    ctx.lineTo(arr.x0, arr.y0 + ro);
    ctx.stroke();

    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(arr.x0, arr.y0, ro, ro, 0, 0, 2*Math.PI);
    ctx.stroke();

    const frac = Math.max(Math.min( (arr.value - arr.min) / (arr.max - arr.min), 1), 0);
    const angle = start + frac * (end - start) - Math.PI/2;

    ctx.fillStyle = "rgba(255,255,255,0.4)";
    let f = 0.90 * ro / 58;

    arcsegment(ctx, arr.x0, arr.y0, ri, ro, start, end);

    ctx.fillStyle = "white";
    drawNeedleCustom(ctx, arr, needleTri, f, angle);

    ctx.textAlign = "center";
    
    if (arr.label) {
	//ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
	ctx.font = jetiToCtx(arr.labelFont)
	arrR.xL = arr.x0;
	arrR.yL = arr.y0 + 0.90 * ro;
	if (arr.labelFont != "None") {
	    ctx.fillText(arr.label, arrR.xL, arrR.yL);
	}
	ctx.font = jetiToCtx(arr.valueFont)
	arrR.xV = arr.x0;
	arrR.yV = arr.y0 + 0.60 * ro;
	if (arr.valueFont != "None") {
	    ctx.fillText(arr.value.toString(), arrR.xV, arrR.yV);
	}
    }
    
    return arrR;
}

function roundedRect(ctx, x, y, w, h, r) {
    if (w < 2 * r) r = w / 2;
    if (h < 2 * r) r = h / 2;
    ctx.beginPath();
    ctx.moveTo(x+r, y);
    ctx.arcTo(x+w, y,   x+w, y+h, r);
    ctx.arcTo(x+w, y+h, x,   y+h, r);
    ctx.arcTo(x,   y+h, x,   y,   r);
    ctx.arcTo(x,   y,   x+w, y,   r);
    ctx.closePath();
    ctx.fill();
}

function roundedRectBezel(ctx, xi, yi, wi, hi, r, b) {

    x = xi;
    y = yi;
    w = wi;
    h = hi;
    
    if (w < 2 * r) r = w / 2;
    if (h < 2 * r) r = h / 2;
    ctx.lineWidth = b;
    ctx.beginPath();
    ctx.moveTo(x+r, y);
    ctx.arcTo(x+w, y,   x+w, y+h, r);
    ctx.arcTo(x+w, y+h, x,   y+h, r);
    ctx.arcTo(x,   y+h, x,   y,   r);
    ctx.arcTo(x,   y,   x+w, y,   r);

    ctx.stroke();
}

function sequencedTextBox(ctx, arr) {
    return textBox(ctx, arr, "sequence");
}

function stackedTextBox(ctx, arr) {
    return textBox(ctx, arr, "stack");
}

function textBox(ctx, arr, type) { 

    var arrR = {}
    const hFrac = 0.5
    var h = arr.height;

    const x0 = arr.x0;
    const y0 = arr.y0;
    
    h = h * hFrac;

    arrR.tBoxHgt = h;
    arrR.tBoxWid = arr.width;

    const bezel = 2;

    if (typeof arr.bezelColor == "undefined") {
	arr.bezelColor = "transparent";
    }
    if (arr.bezelColor != "transparent") {
	//console.log("bezel", arr.bezelColor);
	ctx.strokeStyle = arr.bezelColor;
	roundedRectBezel(ctx, x0 - arr.width/2 + bezel, y0 - h/2 + bezel,
			 arr.width - 2 * bezel, h - 2 * bezel, 3, bezel + 1);
    }

    if (typeof arr.backColor == "undefined") {
	arr.backColor = "yellowgreen";
    }
    if (arr.backColor != "transparent") {
	ctx.fillStyle = arr.backColor;
	roundedRect(ctx, x0 - arr.width/2 + bezel + 1, y0 - h/2 + bezel + 1,
		    arr.width - 2 * bezel - 2, h - 2 * bezel - 2, 3);
    }

    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle"
    
    let lpx, lpy
    
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx= arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy= arr.labelPosY
    }

    arrR.xL = x0 + lpx;
    arrR.yL = y0 + h/4 + jetiHeight(arr.labelFont) + lpy;

    if (typeof arr.label != "undefined" && arr.labelFont != "None") { 
	ctx.fillStyle = "white";
	ctx.font = jetiToCtx(arr.labelFont);
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
    }

    arrR.xV = x0;
    arrR.yV = y0;

    if (typeof arr.value != "undefined") {
	ctx.fillStyle = "black";
	ctx.textAlign = "center";
	ctx.textBaseline = "middle"
	ctx.font = jetiToCtx(arr.textFont)
	var str;
	if (type != "stack") {
	    str = arr.text[Math.floor(arr.value)];
	    if (typeof str != "undefined" && (str.startsWith("luaS:") || str.startsWith("luaE:"))) {
		str = "<lua script>";
	    }
	    if (arr.textFont != "None") {
		ctx.fillText(str, arrR.xV, arrR.yV);
	    }
	} else  {
	    let txH = jetiHeight(arr.textFont);
	    let jsH = getTextHeight(ctx, arr.text[0])
	    //console.log("textFont, txH, jsH, arr.text[0]", arr.textFont, txH, jsH, arr.text[0])
	    var yc = y0 +  1.10 * txH - 0.5 * (txH / 2) * (3 * arr.text.length + 1);
	    for(let i = 0, len = arr.text.length; i < len; i++) {
		let str = arr.text[i];
		let txW = getTextWidth(ctx, str);
		if (str.startsWith("luaS:") || str.startsWith("luaE:")) {
		    str = "<lua script>";
		}
		if (arr.textFont != "None") {
		    ctx.fillText(str, x0, yc + i * 1.45 * txH);
		}
	    } 
	}
    }
    return arrR
}

function rad(deg) {
    return deg * Math.PI / 180.0
}

function drawPitch(ctx, arr, roll, pitch, pitchR, radAH, X0, Y0, scl) {

    let XH,YH,X1,X2,X3,Y1,Y2,Y3,X4,Y4;
    let pp;
    const XHS = 18 * radAH / 70;
    const XHL = 40 * radAH / 70;
    const scale = scl * radAH / 70;
    
    let sinRoll = Math.sin(rad(-roll))
    let cosRoll = Math.cos(rad(-roll))
    let delta = pitch % 15    

    for (let i = delta - 45; i < 45 + delta; i = i + 15) {
	if (Math.abs(pitch - i % 360) < 0.01) {
	    XH = XHL;
	} else {
	    XH = XHS;
	}

	YH = pitchR * i                      
	pp = pitch - i;
    
	X1 = -XH * cosRoll - YH * sinRoll;
	Y1 = -XH * sinRoll + YH * cosRoll;
	X2 = (XH - 0) * cosRoll - YH * sinRoll;
	Y2 = (XH - 0) * sinRoll + YH * cosRoll;
	X3 = (XH + 5) * cosRoll - (YH - 3) * sinRoll;
	Y3 = (XH + 5) * sinRoll + (YH - 3) * cosRoll;	
	X4 = (-XH - 18*scale*pp.toString().length - 5) * cosRoll - (YH - 3) * sinRoll;
	Y4 = (-XH - 18*scale*pp.toString().length - 5) * sinRoll + (YH - 3) * cosRoll;	
	
	if ( !( (X1 < -radAH && X2 < -radAH) ||  (X1 > radAH && X2 > radAH)
		|| (Y1 < -radAH && Y2 < -radAH) ||  (Y1 > radAH && Y2 > radAH) ) ) {

	    ctx.strokeStyle = "white";
	    ctx.lineWidth = 2;
	    ctx.beginPath();
	    ctx.moveTo(X0 + radAH + X1, Y0 + radAH + Y1);
	    ctx.lineTo(X0 + radAH + X2, Y0 + radAH + Y2);
	    ctx.stroke();
	    if (XH == XHS) {
		drawHP1345A(ctx, X0 + radAH + X3, Y0 + radAH + Y3, "" + pp, scale, rad(roll), 1);
		drawHP1345A(ctx, X0 + radAH + X4, Y0 + radAH + Y4, "" + pp, scale, rad(roll), 1);
	    }
	}
    }
}

function artHorizon(ctx, arr) {

    /*
      function artHorizon is based on code in the Jeti Artificial Horizon App

      Copyright (c) 2016 JETI
      Copyright (c) 2015 dandys.
      Copyright (c) 2014 Marco Ricci.

      Use here conforms with the license terms
    */

    
    var arrR = {};
    
    let pitch = arr.pitch;
    let roll = arr.roll;

    let rowAH = arr.width / 2 - 20;
    let radAH = arr.width / 2 - 20;
    let pitchR = radAH / 25;

    //console.log(arr.width, rowAH);

    let tanRoll;
    let cosRoll;
    let sinRoll;
    
    let dPitch_1;
    let dPitch_2;

    dPitch_1 = pitch % 180

    //console.log(pitch, dPitch_1)
    
    if (dPitch_1 > 90) {
	dPitch_1 = 180 - dPitch_1
    }

    if (roll == 270) {
	roll = 269.99;
    }
    if (roll == 90) {
	roll = 89.99;
    }
    
    cosRoll = 1 / Math.cos(rad(roll))

    if (pitch > 270) {
	dPitch_1 = -dPitch_1 * pitchR * cosRoll
	dPitch_2 = radAH * cosRoll
    } else if (pitch > 180) {
	dPitch_1 = dPitch_1 * pitchR * cosRoll
	dPitch_2 = -radAH * cosRoll
    } else if (pitch > 90) {
	dPitch_1 = -dPitch_1 * pitchR * cosRoll
	dPitch_2 = -radAH * cosRoll
    } else {
	dPitch_1 = dPitch_1 * pitchR * cosRoll
	dPitch_2 = radAH * cosRoll
    }
    
    tanRoll = -Math.tan(rad(roll))

    X0 = arr.x0 - radAH
    Y0 = arr.y0 - radAH

    X1 = 0

    YH = (-radAH) * tanRoll
    Y1 = YH + dPitch_1
    Y2 = YH + 1.5 * dPitch_2 

    ctx.fillStyle = arr.skyColor;
    arrR.rgbSkyColor = getRGB(ctx.fillStyle);
    ctx.fillStyle = arr.landColor;
    arrR.rgbLandColor = getRGB(ctx.fillStyle)
    
    if (typeof arr.value != "undefined") {
	
	// define clipping region 
	let region = new Path2D();
	region.rect(X0, Y0, 2 * radAH, 2 * radAH)

	//console.log(X0, Y0, 2 * radAH, 2 * radAH)
	
	ctx.save();
	ctx.clip(region);
	ctx.strokeStyle = "white";
	ctx.fillStyle  = arr.skyColor;
	ctx.fillRect(X0, Y0, 2 * radAH + 1, 2 * radAH + 1);

	ctx.fillStyle = arr.landColor;
	ctx.beginPath();
	
	if (Y1 < Y2) {
	    ctx.moveTo(X0 + X1, Y0 + rowAH + Y1)
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y2)
	    //ren:addPoint(X1, rowAH + Y1)
	    //ren:addPoint(X1, rowAH + Y2 )
	} else if (Y1 > Y2) {
	    ctx.moveTo(X0 + X1, Y0 + rowAH + Y2)
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y1)
	    //ren:addPoint(X1, rowAH + Y2)
	    //ren:addPoint(X1, rowAH + Y1) 
	}

	X1 = 2 * radAH + 1
	YH = (radAH) * tanRoll
	Y1 = YH + dPitch_1
	Y2 = YH + 1.5 * dPitch_2 
	
	if (Y1 < Y2) {
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y2)
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y1)
	} else if (Y1 > Y2) {
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y1)
	    ctx.lineTo(X0 + X1, Y0 + rowAH + Y2)
	}

	ctx.fill();

	ctx.strokeStyle = "white";
	ctx.beginPath();
	
	//lcd.drawLine(0, 0, 0, 2*radAH + 1 )
	ctx.moveTo(X0, Y0);
	ctx.lineTo(X0, Y0 + 2 * radAH + 1);

	//lcd.drawLine(2* radAH, 0, 2* radAH , 2*radAH  )
	ctx.moveTo(X0 + 2 * radAH, Y0);
	ctx.lineTo(X0 + 2 * radAH, Y0 + 2 * radAH)
	
	//lcd.drawLine(0, 2*radAH,2* radAH , 2* radAH )
	ctx.moveTo(X0, Y0 + 2 * radAH);
	ctx.lineTo(X0 + 2 * radAH, Y0 + 2 * radAH);

	//lcd.drawLine(0, 0, 2*radAH, 0)
	ctx.moveTo(X0, Y0);
	ctx.lineTo(X0 + 2 * radAH, Y0);

	ctx.stroke();

	ctx.beginPath();
	ctx.moveTo(X0 + radAH - 0.7 * radAH, Y0 + radAH);
	ctx.lineTo(X0 + radAH - 0.2 * radAH, Y0 + radAH);
	ctx.lineTo(X0 + radAH - 0.2 * radAH, Y0 + radAH + radAH / 10);
	ctx.lineWidth = 2;
	ctx.stroke();

	ctx.beginPath();
	ctx.moveTo(X0 + radAH + 0.7 * radAH, Y0 + radAH);
	ctx.lineTo(X0 + radAH + 0.2 * radAH, Y0 + radAH);
	ctx.lineTo(X0 + radAH + 0.2 * radAH, Y0 + radAH + radAH / 10);
	ctx.lineWidth = 2;
	ctx.stroke();

	drawPitch(ctx, arr, roll, pitch, pitchR, radAH, X0, Y0, 0.4);

	ctx.restore();
    }
    
    let lpx, lpy
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx = arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy = arr.labelPosY
    }    
	
    arrR.xL = arr.x0 + lpx;
    arrR.yL = arr.y0 + radAH + jetiHeight(arr.labelFont) + lpy;

    //console.log(arrR.xL, arrR.yL)

    //console.log("arr.label, arr.labelFont, arrR.xL, arrR.yL", arr.label, arr.labelFont, arrR.xL, arrR.yL)
    
    if (typeof arr.label != "undefined" && arr.labelFont != "None") { 
	ctx.fillStyle = "white";
	ctx.textAlign = "center";
	ctx.textBaseline = "middle"
	ctx.font = jetiToCtx(arr.labelFont);
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
    }
    return arrR;
}


function verticalTape(ctx, arr) {

    var arrR = {};
    
    let width = arr.width;
    let height = arr.height;
    let barW = width - 110;
    let barH = height - 30;
    
    let val = arr.value

    //arr.handed = "right";
    if (typeof arr.handed == "undefined") {
	arr.handed = "left";
    }
    
    // background rectangle
    if (arr.backColor != "transparent" && typeof val != "undefined") {
	ctx.fillStyle = arr.backColor;
	arrR.rgbBackColor = getRGB(ctx.fillStyle);
	ctx.fillRect(arr.x0 - barW/2, arr.y0 - barH/2, barW, barH);
    } else {
	ctx.fillStyle = arr.backColor;
	arrR.rgbBackColor = getRGB(ctx.fillStyle);
    }
    
    // outline
    ctx.strokeStyle = "white";
    if (typeof val != "undefined") {
	ctx.beginPath();
	ctx.rect(arr.x0 - barW/2, arr.y0 - barH/2, barW, barH);
	ctx.stroke();
    }

    ctx.textAlign = "center";
    ctx.textBaseline = "middle"

    // draw label
    arrR.xL = arr.x0
    arrR.yL = arr.y0 + barH / 2 + jetiHeight(arr.labelFont)
    if (typeof arr.label != "undefined" && arr.labelFont != "None") { 
	//console.log(arrR.xL, arrR.yL)
	ctx.font = jetiToCtx(arr.labelFont)
	ctx.fillStyle = "white";
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
    }

    // draw value on top
    if (arr.valuePos == "Top") {
	arrR.xV = arr.x0;
	arrR.yV = arr.y0 - barH / 2 //- jetiHeight(arr.valueFont);
	if (typeof val != "undefined" && arr.labelFont != "None") {
	    ctx.font = jetiToCtx(arr.valueFont);
	    ctx.fillStyle = "white";
	    if (typeof ("" + val) == "undefined") {
		console.log("One");
	    }
	    ctx.fillText("" + val, arrR.xV, arrR.yV)
	}
    }
    
    // draw pointer triangle

    let dx;
    let dx1;
    if (arr.handed == "left") {
	dx = barW / 2;
	dx1 = -5;
    } else {
	dx = -barW / 2;
	dx1 = 5;
    }
    ctx.fillStyle = "white";
    if (typeof val != "undefined") {
	ctx.beginPath()
	ctx.moveTo(arr.x0 + dx, arr.y0 + 5)
	ctx.lineTo(arr.x0 + dx, arr.y0 - 5)
	ctx.lineTo(arr.x0 + dx + dx1, arr.y0)
	ctx.lineTo(arr.x0 + dx, arr.y0 + 5)
	ctx.fill();
    }

    // draw side value label box and number
    if (arr.valuePos == "Side") {
	if (arr.handed == "left") {
	    arrR.xV = arr.x0 + barW + 18;
	} else {
	    arrR.xV = arr.x0 - barW - 18;
	}
	arrR.yV = arr.y0 + .04 * jetiHeight(arr.valueFont);
	//console.log("side", arr.backColor)
	ctx.fillStyle = "black";
	if (arr.backColor != "transparent" && typeof val != "undefined") {
	    ctx.fillStyle = arr.backColor;
	    if (arr.handed == "left") {
		ctx.fillRect(arr.x0 + barW/2, arr.y0 - 10, barW, 20)
	    } else {
		ctx.fillRect(arr.x0 - 3 * barW/2, arr.y0 - 10, barW, 20)
	    }
	}
	if (typeof val != "undefined") {	
	    ctx.strokeStyle = "white";
	    if (arr.handed == "left") {
		ctx.rect(arr.x0 + barW/2, arr.y0 - 10, barW, 20)
	    } else {
		ctx.rect(arr.x0 - 3 * barW/2, arr.y0 - 10, barW, 20)
	    }
		    ctx.stroke()
	}
	
	ctx.font = jetiToCtx(arr.valueFont);
	if (arr.handed == "left") {
	    ctx.textAlign = "right";
	} else {
	    ctx.textAlign = "left";
	}
	ctx.fillStyle = "white";

	if (typeof val != "undefined" && arr.valueFont != "None") {
	    ctx.fillText("" + val, arrR.xV, arrR.yV);
	}
    }

    // define clipping region for use with tape box
    let region = new Path2D();
    region.rect(arr.x0 - barW / 2, arr.y0 - barH / 2, barW, barH)

    let step = arr.step;
    let delta = val % step;
    let yp;
    let xp;
    let yv;
    let nums = arr.numbers; // # of numbers shown in tape
    let zp = nums / 2;
    let inc = step / nums;
    let k1 = (zp * nums) / step - (zp+1); // should be zp .. + 1 to make sure 
    let k2 = (zp * nums) / step + (zp+1); // we go past clip point on both ends
    if (arr.handed == "left") {
	xp = arr.x0 + barW/4 + 3;
    } else {
	xp = arr.x0 - barW/4 - 2;
    }
    
    // draw the actual tape
    ctx.save();
    ctx.clip(region);
    ctx.font = jetiToCtx(arr.tapeFont);
    if (arr.handed == "left") {
	ctx.textAlign = "right";
    } else {
	ctx.textAlign = "left";
    }
    ctx.fillStyle = "white";
    for(let kdx = k1; kdx <= k2; kdx = kdx + 1) {    
	let idx = kdx * inc
	yp = arr.y0 - zp * (barH / step) + (barH/step) * (delta/step) * inc + (barH / step) * idx
	yv = zp * step / inc - step * idx / inc  + (val - delta)
	yv = Math.round( (yv + Number.EPSILON) * 100) / 100;
	if (typeof yv != "undefined" && arr.tapeFont != "None") {
	    if (typeof ("" + yv) == "undefined") {
		console.log("Three");
	    }

	    ctx.fillText(""+ yv, xp, yp)
	}
	if (arr.handed == "left") {
	    ctx.moveTo(arr.x0 - barW/2, yp)
	    ctx.lineTo(arr.x0 - barW/2 + 7, yp)
	    ctx.stroke();
	} else {
	    ctx.moveTo(arr.x0 + barW/2, yp)
	    ctx.lineTo(arr.x0 + barW/2 - 7, yp)
	    ctx.stroke();
	}
	
    }
    ctx.restore();

    // draw the value in overlay mode
    if (arr.valuePos == "Overlay") {
	if (arr.backColor != "transparent") {
	    ctx.fillStyle = arr.backColor;
	    ctx.fillRect(arr.x0 - barW/2, arr.y0 - 14, barW, 28);
	}
	ctx.beginPath();
	ctx.rect(arr.x0 - barW/2, arr.y0 - 12, barW, 24);
	ctx.stroke();
	ctx.textAlign = "right";	
	ctx.fillStyle = "yellow";
	ctx.font = jetiToCtx(arr.valueFont);    
	arrR.xV = arr.x0 + 20;
	arrR.yV = arr.y0;
	if (typeof val != "undefined" && arr.valueFont != "None") {
	    console.log(val, arrR.xV, arrR.yV)
	    if (typeof ("" + val) == "undefined") {
		console.log("Four");
	    }

	    ctx.fillText(""+val, arrR.xV,arrR.yV);
	}
	ctx.strokeStyle = "white";
	ctx.beginPath();
	ctx.rect(arr.x0 - barW/2, arr.y0 - barH/2, barW, barH);
	ctx.stroke();
    }
    return arrR
}

function horizontalBar(ctx, arr) {

    const hPad = arr.height / 4;
    const vPad = arr.height / 4;
    const h = arr.height - 2 * vPad;
    const w = arr.width - 2 * hPad;
    const start = arr.x0 - w / 2;
    const end = arr.x0 + w / 2;

    var arrR = {};
    var divs = arr.subdivs * arr.majdivs;
    arrR.divs = divs;
    
    ctx.fillStyle = "black";

    ctx.font = jetiToCtx(arr.tickFont)

    if (typeof arr.spectrum == "object") {
	var rainbow = new Rainbow();
	
	var spectrum = arr.spectrum;
	
	if (spectrum.length == 1) {
	    spectrum[1] = spectrum[0];
	}
	
	rainbow.setSpectrumByArray(spectrum); 
	rainbow.setNumberRange(0,divs-1)
    } else {
	//setup for colorvals goes here
    }
    
    const cellMult = 0.5;
    const cellOff  = (1 - cellMult) / 2 * h;
    const yOff = 4;
    
    arrR.barW = w;
    arrR.barH = h * cellMult;

    const bezel = 2;

    if (arr.backColor != "transparent") {
	ctx.fillStyle = arr.backColor;
	arrR.rgbBackColor = getRGB(ctx.fillStyle);
	ctx.fillRect(arr.x0 - arrR.barW/2, arr.y0 - arrR.barH/2, arrR.barW, arrR.barH)
    } else {
	arrR.rgbBackColor = getRGB(arr.backColor);
    }
    
    if (arr.bezelColor != "transparent") {
	ctx.fillStyle = arr.bezelColor;
	ctx.strokeStyle = arr.bezelColor;
	arrR.rgbBezelColor = getRGB(ctx.fillStyle);
	roundedRectBezel(ctx, arr.x0 - arrR.barW/2 - bezel, arr.y0 - arrR.barH/2 - bezel,
			 arrR.barW + 2*bezel, arrR.barH + 2 * bezel, 3, bezel+1);
    } else {
	arrR.rgbBezelColor = getRGB(arr.bezelColor);
    }

    var delta;
    var a;

    arrR.rects = [];
    var rgbI, cfs, r, g, b;

    let region = new Path2D();
    let ff = (arr.value - arr.min) / (arr.max - arr.min); // goes from 0 to 1 over min to max
    //console.log("ff, w, w*ff", ff, w, w*ff);
    region.rect(arr.x0 - w / 2, arr.y0 - cellMult * h / 2, w * ff, cellMult * h);
    
    var colors = arr.colorvals;
    var idxL = 0;
    arrR.hbarLabels = [];
    var val;
    var aFrac;
    for (var i = 0; i <= divs; i++) {

	delta = w / divs;
	a = start + i * delta;
	const fudge = 1 / (100 * divs);	
	if (typeof colors == "object") {
	    const cl = colors.length - 1;
	    aFrac = (a - start) / (end - start);
	    val = (arr.min + aFrac * (arr.max - arr.min))
	    //console.log("val, aFrac", val, aFrac);
	    if (val != 0) {
		val = val + fudge;
	    }
	    if (val <= colors[0].val) {
		ctx.fillStyle = colors[0].color
		cfs = ctx.fillStyle; // sets rgbI to standard hex format even if color is "red"
		//rgbI = colors[0].color
	    } else if (val >= colors[cl].val) {
		ctx.fillStyle = colors[cl].color
		//rgbI = colors[cl].color
		cfs = ctx.fillStyle;
	    } else {
		for (let j = 1; j <= cl; j++) {
		    if (val >= colors[j-1].val && val < colors[j].val) {
			ctx.fillStyle = colors[j].color;
			//rgbI = colors[j].color
			cfs = ctx.fillStyle;
			break;
		    }
		}
	    }
	} else {
	    ctx.fillStyle = "#"+rainbow.colourAt(i);
	    //rgbI = parseInt(rainbow.colourAt(i), 16)
	    cfs = ctx.fillStyle;
	}
	
	if (i < divs) {
	    rgbI = parseInt(cfs.slice(1), 16)
	    r = (rgbI >> 16) & 255;
	    g = (rgbI >> 8) & 255;
	    b = rgbI & 255;
	    arrR.rects[i] = {x:a, y: arr.y0 - h / 2 + cellOff,
			     w: delta, h: cellMult * h,
			     r:r, g:g, b:b}
	    //console.log("cfs, cfs.slice(1), rgbI", cfs, r,g,b)
	    //console.log(i, rainbow.colourAt(i), r, g, b)
	    ctx.save();
	    ctx.clip(region);
	    if (typeof arr.value != "undefined") {
		ctx.fillRect(a, arr.y0 - h / 2 + cellOff, delta, cellMult * h)
		ctx.lineWidth = h / 60;	
		ctx.strokeStyle="white";
		ctx.beginPath();
		ctx.moveTo(a, arr.y0 - h / 2 + cellOff)
		ctx.lineTo(a, arr.y0 + h / 2 - cellOff)
		ctx.stroke();
	    }
	    ctx.restore();
	}

	ctx.font = jetiToCtx(arr.tickFont)
	if (arr.subdivs > 0 && i % arr.subdivs == 0) {
	    ctx.fillStyle = "white";	
	    ctx.textAlign = "center";
	    ctx.textBaseline = "middle";
	    var val = Math.floor(arr.min + i * (arr.max - arr.min) / divs)
	    //console.log("i, subdivs, idxL", i, arr.subdivs, idxL)
	    arrR.hbarLabels[idxL] = {x:a, y:arr.y0 - h/2}
	    idxL = idxL + 1;
	    if (arr.tickFont != "None") {
		if (typeof arr.value != "undefined") {
		    ctx.fillText(val.toString(),
				 a,
				 arr.y0 - (h/2 + yOff));
		}
	    }

	    ctx.save();
	    //ctx.clip(region);
	    ctx.lineWidth = h / 23;	
	    ctx.strokeStyle="white";
	    if (typeof arr.value != "undefined") {
		ctx.beginPath();
		ctx.moveTo(a, arr.y0 - h / 2 + cellOff)
		ctx.lineTo(a, arr.y0 + h / 2  - cellOff)
		ctx.stroke();
	    }
	    //ctx.restore();
	}
    }
    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    let lpx, lpy;
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx = arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy = arr.labelPosY
    }
    arrR.xL = arr.x0 + lpx;
    arrR.yL = arr.y0 +  h / 2 + lpy;
    ctx.font = jetiToCtx(arr.labelFont)
    
    if (typeof arr.label != "undefined") {	
	if (arr.labelFont != "None") {
	    ctx.fillText(arr.label, arrR.xL, arrR.yL);
	}
    }
    return arrR;
}

function verticalBar(ctx, arr) {

    //console.log("arr.width, arr.height", arr.width, arr.height)
    
    const hPad = arr.width / 3;
    const vPad = arr.width / 4
    const h = arr.height - 2 * vPad;
    const w = arr.width - 2 * hPad;
    const start = arr.y0 - h / 2;
    const end = arr.y0 + h / 2;

    var arrR = {};
    var divs = arr.subdivs * arr.majdivs;
    arrR.divs = divs;
    
    ctx.fillStyle = "black";

    ctx.font = jetiToCtx(arr.tickFont)

    if (typeof arr.spectrum == "object") {
	var rainbow = new Rainbow();
	
	var spectrum = arr.spectrum;
	
	if (spectrum.length == 1) {
	    spectrum[1] = spectrum[0];
	}
	
	rainbow.setSpectrumByArray(spectrum); 
	rainbow.setNumberRange(0,divs-1)
    } else {
	//setup for colorvals goes here
    }
    
    const cellMult = 0.5;
    const cellOff  = (1 - cellMult) / 2 * w;
    const xOff = 0;
    
    arrR.barH = h;
    arrR.barW = w * cellMult;

    const bezel = 2;

    if (arr.backColor != "transparent") {
	ctx.fillStyle = arr.backColor;
	arrR.rgbBackColor = getRGB(ctx.fillStyle);
	//console.log("~", arr.x0 - arrR.barW/2, arr.y0 - arrR.barH/2, arrR.barH, arrR.barW)
	ctx.fillRect(arr.x0 - arrR.barW/2, arr.y0 - arrR.barH/2, arrR.barW, arrR.barH)
    } else {
	arrR.rgbBackColor = getRGB(arr.backColor);
    }
    
    if (arr.bezelColor != "transparent") {
	ctx.fillStyle = arr.bezelColor;
	ctx.strokeStyle = arr.bezelColor;
	arrR.rgbBezelColor = getRGB(ctx.fillStyle);
	roundedRectBezel(ctx, arr.x0 - arrR.barW/2 - bezel, arr.y0 - arrR.barH/2 - bezel,
			 arrR.barW + 2 * bezel, arrR.barH + 2*bezel, 3, bezel+1);
    } else {
	arrR.rgbBezelColor = getRGB(arr.bezelColor);
    }

    var delta;
    var a;

    arrR.rects = [];
    var rgbI, cfs, r, g, b;

    let region = new Path2D();
    let ff = (arr.value - arr.min) / (arr.max - arr.min); // goes from 0 to 1 over min to max
    //console.log("ff, w, w*ff", ff, w, w*ff);
    //console.log("@", arr.x0 - cellMult * w / 2, arr.y0 - h / 2, h * ff, cellMult * w);
    region.rect(arr.x0 - cellMult * w / 2, arr.y0 - h / 2 + h * (1-ff), cellMult * w, h * ff);
    
    var colors = arr.colorvals;
    var idxL = 0;
    arrR.vbarLabels = [];
    var val;
    var aFrac;
    for (var i = 0; i <= divs; i++) {
	delta = h / divs;
	//a = start + i * delta;
	a = start + h - i * delta
	//console.log(i, a, h, divs, delta)
	const fudge = 1 / (100 * divs);	
	if (typeof colors == "object") {
	    const cl = colors.length - 1;
	    aFrac = 1 - (a - start) / (end - start);
	    val = (arr.min + aFrac * (arr.max - arr.min))
	    //console.log("val, aFrac", val, aFrac);
	    if (val != 0) {
		val = val + fudge;
	    }
	    if (val <= colors[0].val) {
		ctx.fillStyle = colors[0].color
		cfs = ctx.fillStyle; // sets rgbI to standard hex format even if color is "red"
		//rgbI = colors[0].color
	    } else if (val >= colors[cl].val) {
		ctx.fillStyle = colors[cl].color
		//rgbI = colors[cl].color
		cfs = ctx.fillStyle;
	    } else {
		for (let j = 1; j <= cl; j++) {
		    if (val >= colors[j-1].val && val < colors[j].val) {
			ctx.fillStyle = colors[j].color;
			//rgbI = colors[j].color
			cfs = ctx.fillStyle;
			break;
		    }
		}
	    }
	} else {
	    ctx.fillStyle = "#"+rainbow.colourAt(i);
	    //rgbI = parseInt(rainbow.colourAt(i), 16)
	    cfs = ctx.fillStyle;
	}
	
	if (i < divs) {
	    rgbI = parseInt(cfs.slice(1), 16)
	    r = (rgbI >> 16) & 255;
	    g = (rgbI >> 8) & 255;
	    b = rgbI & 255;
	    arrR.rects[i] = {y:a - delta, x: arr.x0 - w / 2 + cellOff,
			     h: delta, w: cellMult * w,
			     r:r, g:g, b:b}
	    //console.log("cfs, cfs.slice(1), rgbI", cfs, r,g,b)
	    //console.log(i, rainbow.colourAt(i), r, g, b)
	    ctx.save();
	    ctx.clip(region);
	    if (typeof arr.value != "undefined") {
		//console.log("$", arr.x0 - w / 2 + cellOff, a, cellMult * w, delta)
		ctx.fillRect(arr.x0 - w / 2 + cellOff, a - delta, cellMult * w, delta)
		ctx.lineWidth = w / 60;	
		ctx.strokeStyle="white";
		ctx.beginPath();
		ctx.moveTo(arr.x0 - w / 2 + cellOff, a)
		ctx.lineTo(arr.x0 + w / 2 - cellOff, a)
		ctx.stroke();
	    }
	    ctx.restore();
	}

	ctx.font = jetiToCtx(arr.tickFont)
	if (arr.subdivs > 0 && i % arr.subdivs == 0) {
	    ctx.fillStyle = "white";
	    //console.log("arr.labelside", arr.labelside)
	    let lroff
	    if (arr.labelside == "left") {
		ctx.textAlign = "right";
		lroff = 0
	    } else {
		ctx.textAlign = "left";
		lroff = w
	    }
	    ctx.textBaseline = "middle";
	    var val = Math.floor(arr.min + i * (arr.max - arr.min) / divs)
	    //var val = Math.floor(arr.max - i * (arr.max - arr.min) / divs)	    
	    //console.log("i, subdivs, idxL", i, arr.subdivs, idxL)
	    arrR.vbarLabels[idxL] = {y:a, x:arr.x0 - w/2}
	    idxL = idxL + 1;
	    if (arr.tickFont != "None") {
		if (typeof arr.value != "undefined") {
		    ctx.fillText(val.toString(),
				 arr.x0 - (w/2 + xOff) + lroff, a);
		}
	    }

	    ctx.save();
	    //ctx.clip(region);
	    ctx.lineWidth = w / 23;	
	    ctx.strokeStyle="white";
	    if (typeof arr.value != "undefined") {
		ctx.beginPath();
		ctx.moveTo(arr.x0 - w / 2 + cellOff, a)
		ctx.lineTo(arr.x0 + w / 2 - cellOff, a)
		ctx.stroke();
	    }
	    //ctx.restore();
	}
    }
    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    let lpx, lpy;
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx = arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy = arr.labelPosY
    }
    const yOff = 10;
    arrR.xL = arr.x0 + lpx;
    arrR.yL = arr.y0 +  h / 2 + yOff + lpy;
    //console.log("%", arrR.xL, arrR.yL, xOff)
    ctx.font = jetiToCtx(arr.labelFont)

    let tboff
    if (arr.labeltopbot == "bottom") {
	tboff = 0
    } else {
	tboff = h + 2 * yOff
    }
    
    if (typeof arr.label != "undefined") {	
	if (arr.labelFont != "None") {
	    ctx.fillText(arr.label, arrR.xL, arrR.yL - tboff);
	}
    }
    return arrR;
}

function panelLight(ctx, arr) {

    let arrR = {};

    // prepare rgb values for TX
    
    ctx.fillStyle = arr.lightColor;
    arrR.rgbLightColor = getRGB(ctx.fillStyle)

    if (arr.backColor != "transparent") {
	ctx.fillStyle = arr.backColor;
	arrR.rgbBackColor = getRGB(ctx.fillStyle);
    } else {
	arrR.rgbBackColor = getRGB(arr.backColor);
    }
    
    if (arr.bezelColor != "transparent") {
	ctx.fillStyle = arr.bezelColor;
	arrR.rgbBezelColor = getRGB(ctx.fillStyle);
    } else{ 
	arrR.rgbBezelColor = getRGB(arr.bezelColor);
    }

    let lpx, lpy
    
    if (typeof arr.labelPosX == "undefined") {
	lpx = 0
    } else {
	lpx= arr.labelPosX
    }
    if (typeof arr.labelPosY == "undefined") {
	lpy = 0
    } else {
	lpy= arr.labelPosY
    }

    if (typeof arr.label != "undefined") {
	ctx.beginPath();
	ctx.fillStyle = "white";
	ctx.textAlign = "center";
	ctx.font = jetiToCtx(arr.labelFont);
	arrR.xL = arr.x0 + lpx;
	arrR.yL = arr.y0 + jetiHeight(arr.labelFont) + arr.radius + lpy;
	if (arr.labelFont != "None") {
	    ctx.fillText(arr.label, arrR.xL, arrR.yL);
	}
    }
    
    if (typeof arr.value != "undefined") {
	if (arr.bezelColor != "transparent") {
	    ctx.strokeStyle = arr.bezelColor;
	    ctx.lineWidth = 2;
	    ctx.beginPath();
	    ctx.ellipse(arr.x0, arr.y0, arr.radius, arr.radius, 0, 0, Math.PI*2);
	    ctx.stroke();
	}
	if (arr.value > (arr.min + arr.max) / 2) {
	    ctx.fillStyle = arr.lightColor;
	    ctx.beginPath();
	    ctx.ellipse(arr.x0, arr.y0, arr.radius, arr.radius, 0, 0, Math.PI*2);
	    ctx.fill();
	} else {
	    if (arr.backColor != "transparent") {
		ctx.fillStyle = arr.backColor;
		ctx.beginPath();
		ctx.ellipse(arr.x0, arr.y0, arr.radius, arr.radius, 0, 0, Math.PI*2);
		ctx.fill();
	    }
	}
    }
    
    return arrR;
}


function setAlignmentGrid(ctx, arr, text) {
    const w = 320;
    const h = 160;
    const num = {Halves:2,Thirds:3,Fourths:4,Fifths:5,Sixths:6,Seventh:7,Eighths:8}
    if ( (typeof text != "string") || text == "None") {
	return
    }
    const nn = num[text];
    if (typeof nn != "number") {
	return
    }
    ctx.strokeStyle = "rgba(255,255,255,0.3)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.setLineDash([8,5]);
    for (i=2; i <= num[text]; i++) {
	ctx.moveTo(0, (i - 1) * h / nn);
	ctx.lineTo(w, (i - 1) * h / nn);
	ctx.moveTo((i - 1) * w / nn, 0);
	ctx.lineTo((i - 1) * w / nn, h);
    }
    ctx.stroke();
    ctx.setLineDash([]);
}

function rawText(ctx, arr) {
    var arrR = {};


    /*
    ctx.fillStyle = "white";
    ctx.strokeStyle = "Yellow";
    ctx.rect(0,0,158,158)
    ctx.rect(2,2,154,154)
    ctx.stroke();
    */


    let tF
    if (typeof arr.textFont != "undefined") {
	tF = arr.textFont;
    } else {
	tF = "Mini";
    }

    ctx.font = jetiToCtx(tF)	

    let bC
    if (typeof arr.backColor != "undefined") {
	bC = arr.backColor;
    } else {
	bC = "transparent";
    }
    ctx.fillStyle = bC
    arrR.rgbBackColor = getRGB(ctx.fillStyle)

    ctx.fillStyle = arr.textColor;
    arrR.rgbTextColor = getRGB(ctx.fillStyle);

    if (typeof arr.textJust != "undefined") {
	tJ = arr.textJust;
    } else {
	tJ = "center"
    }
    
    ctx.textAlign = tJ;
    ctx.textBaseline = "middle";

    let maxW = getTextWidth(ctx, arr.text[0]);
			    
    for (let i = 1, len = arr.text.length; i < len; i++) {
	if (getTextWidth(ctx, arr.text[i]) > maxW) {
	    maxW = getTextWidth(ctx, arr.text[i])
	}
    }

    let txH = getTextHeight(ctx, arr.text[0]);
    let hgt = arr.text.length * 1.5 * txH;
    let xBorder = txH / 2;
    let yBorder = txH / 4;

    let xRT
    let yRT = arr.y0
    if (tJ == "center") {
	xRT = arr.x0 - maxW / 2 - xBorder;
    } else if (tJ == "left") {
	xRT = arr.x0 - xBorder;
    } else if (tJ == "right") {
	xRT = arr.x0 - maxW - xBorder;
    }
    //console.log(arr.text)

    arrR.xBorder = xBorder;
    arrR.yBorder = yBorder;
    
    if (typeof arr.label != "undefined") {
	//ctx.fillText(arr.text, arr.x0, arr.y0);
	let x0 = arr.x0
	let y0 = arr.y0

	ctx.fillStyle = bC;
	if (bC != "transparent") {
	    roundedRect(ctx, xRT, y0 - hgt / 2 - yBorder, maxW + xBorder * 2, hgt + yBorder * 2, 3)
	}

	ctx.fillStyle = arr.textColor;
	var yc = y0 +  1.10 * txH - 0.5 * (txH / 2) * (3 * arr.text.length + 1);
	for(let i = 0, len = arr.text.length; i < len; i++) {
	    let str = arr.text[i];
	    let txW = getTextWidth(ctx, str);
	    if (str.startsWith("luaS:") || str.startsWith("luaE:")) {
		str = "<lua script>";
	    }
	    if (tF != "None") {
		ctx.fillText(str, x0, yc + i * 1.5 * txH);
	    }
	} 
    }
    return arrR;
}

function chartRecorder(ctx, arr) {

    var arrR = {};

    const chartOffsetXL = 12;
    const chartOffsetYT = 18;
    const chartOffsetYB = 20;
    const chartOffsetXV = 34;
    const chartOffsetV = 13;

    let timeStamps = [
	["0:00", "0:05", "0:10", "0:15", "0:20", "0:25", "0:30"],
	["0:00", "0:10", "0:20", "0:30", "0:40", "0:50", "1:00"],
	["0:00", "0:20", "0:40", "1:00", "1:20", "1:40", "2:00"],
	["0:00", "0:40", "1:20", "2:00", "2:40", "3:20", "4:00"],
	["0:00", "1:20", "2:40", "4:00", "5:20", "6:40", "8:00"]
    ]

    let stampIndex = {"t30": 0, "t60": 1, "t120": 2, "t240": 3, "t480": 4}
    
    let maxTraces;
    if (typeof arr.maxTraces != "undefined") {
	maxTraces = arr.maxTraces;
    } else {
	maxTraces = 1;
    }
    maxTraces = Math.max(1, Math.min(4, maxTraces));
    //console.log("maxTraces", maxTraces)

    let barOffset;
    let barWidth = 21;
    arrR.barWidth = barWidth

    if (typeof arr.traceNumber != "undefined") {
	traceNumber = Math.min(maxTraces, arr.traceNumber);
	barOffset = (traceNumber - 1) *  (barWidth);
    } else {
	traceNumber = 1
	barOffset = barWidth
    }
    traceNumber = Math.max(1, traceNumber);
    
    //console.log("traceNumber, maxTraces", traceNumber, maxTraces)
    barOffset = Math.max(0, Math.min(3 * barWidth, barOffset));

    const chartOffsetXR = barWidth + maxTraces * barWidth;

    let timeSpan;
    if (typeof arr.timeSpan != "undefined") {
	timeSpan= stampIndex[arr.timeSpan];
    } else {
	timeSpan = stampIndex["0:30"]
    }

    arrR.boxW = 2 * (arr.width / 2 - chartOffsetXR / 2 - chartOffsetXL / 2) + 4;
    arrR.boxH = arr.height - (chartOffsetYT + chartOffsetYB);
    arrR.boxXL = arr.x0 - arr.width/2 + chartOffsetXL;
    arrR.boxYL = arr.y0 - arr.height/2 + chartOffsetYT;
    arrR.vertX = arrR.boxXL + arrR.boxW + chartOffsetXV;
    arrR.vertYB = arrR.boxYL + arrR.boxH
    arrR.vertYT = arrR.boxYL

    
    if (typeof arr.backColor != "undefined") {
	ctx.fillStyle = arr.backColor;
    } else {
	ctx.fillStyle = "black";
    }
    arrR.rgbBackColor = getRGB(ctx.fillStyle)

    let maxwid = Math.min(arr.width, 316);
    let maxhgt = Math.min(arr.height, 158);
    
    if (traceNumber == 1 && arr.backColor != "transparent" ) {
	ctx.fillRect(arr.x0 - arr.width/2, arr.y0 - arr.height/2,
		     maxwid, maxhgt);
    }

    ctx.lineWidth = 1;

    /*
    ctx.strokeStyle = "peachpuff";
    if (traceNumber == 1 && typeof arr.label != "undefined") {
	ctx.beginPath();
	ctx.rect(arr.x0 - arr.width/2, arr.y0 - arr.height/2, arr.width, arr.height);
	ctx.stroke();
    }
    */
    
    if (typeof arr.chartBackColor != "undefined") {
	ctx.fillStyle = arr.chartBackColor;
    } else {
	ctx.fillStyle = "black";
    }
    arrR.rgbChartBackColor = getRGB(ctx.fillStyle)

    if (traceNumber == 1) {
	ctx.fillRect(arrR.boxXL, arrR.boxYL, arrR.boxW, arrR.boxH);
    }
    
    ctx.strokeStyle = "white";
    if (traceNumber == 1) {
	ctx.beginPath();
	ctx.rect(arrR.boxXL, arrR.boxYL, arrR.boxW, arrR.boxH);
	ctx.stroke();
    }
    
    ctx.beginPath();
    ctx.moveTo(arrR.vertX + barOffset, arrR.vertYB);
    ctx.lineTo(arrR.vertX + barOffset, arrR.vertYT);
    ctx.stroke();
    
    ctx.beginPath();
    const ticL = 6;
    arrR.numberTicks = 10;    
    for (let i=0; i <= arrR.numberTicks; i++) {
	ctx.moveTo(arrR.vertX + barOffset, arrR.vertYB + i * (arrR.vertYT - arrR.vertYB) / arrR.numberTicks)
	let tl;
	if (i % (arrR.numberTicks / 2) == 0) { tl = ticL } else { tl = ticL / 2}
	ctx.lineTo(arrR.vertX - tl + barOffset,
		   arrR.vertYB + i * (arrR.vertYT - arrR.vertYB) / arrR.numberTicks);	
    }
    ctx.stroke();
    
    ctx.fillStyle = "white";
    ctx.font = jetiToCtx("Mini")
    
    let hh = getTextHeight(ctx, ":00") + 6

    ctx.textBaseline = "middle";
    ctx.textAlign = "center"; 
    ctx.fillText("" + arr.min, arrR.vertX - chartOffsetV + barOffset, arrR.vertYB + hh / 2)
    ctx.fillText("" + arr.max, arrR.vertX - chartOffsetV + barOffset, arrR.vertYT - hh / 2)

    ctx.align = "middle"
    let ss, xx

    if (traceNumber == 1 && typeof arr.value != "undefined" ) {
	for (let i=0; i<= 6; i++) {
	    ss = i * 5;
	    xx = arrR.boxXL + i * arrR.boxW / 6;
	    //console.log(timeSpan, i, timeStamps[timeSpan][i])
	    ctx.fillText(timeStamps[timeSpan][i], xx, arrR.vertYB + hh)
	    /*
	    if (i % 2 == 0) {
		ctx.fillText(":" + ("0" + ss).slice(-2), xx, arrR.vertYB + hh)
	    }
	    */
	    ctx.beginPath();
	    ctx.moveTo(xx, arrR.vertYB)
	    ctx.lineTo(xx, arrR.vertYB + ticL)
	    ctx.stroke();
	}
    }

    let xmin = 0;
    let xmax = 2;
    let ymin = -1;
    let ymax = 1;
    let x, xp, y, yp, fx, fy

    if (typeof arr.chartTraceColor != "undefined") {
	ctx.strokeStyle = arr.chartTraceColor;
    } else {
	ctx.strokeStyle = "blue";
    }
    arrR.rgbChartTraceColor = getRGB(ctx.strokeStyle)
    let traceColor = ctx.strokeStyle
    
    if (typeof arr.value != "undefined") {
	ctx.beginPath();
	for (let t = 0; t <= 2.0;t = t + 0.01) {
	    x = t;
	    y = 0.9 * Math.sin(2 * Math.PI * (t -  Math.PI / 4 * (traceNumber - 1)));
	    fx = (x - xmin) / (xmax - xmin);
	    xp = arrR.boxXL + fx * arrR.boxW
	    fy = (y - ymin) / (ymax - ymin)
	    yp = arrR.boxYL + (1 - fy) * arrR.boxH
	    ctx.lineTo(xp, yp);
	}
	ctx.stroke();
    }
    
    ymin = arr.min;
    ymax = arr.max;
    
    if (typeof arr.chartTraceColor != "undefined") {
	ctx.fillStyle = arr.chartTraceColor;
    } else {
	ctx.fillStyle = "blue";
    }

    fy = (arr.value - ymin) / (ymax - ymin);
    fy = Math.max(0, Math.min(fy, 1));
    if (typeof arr.value != "undefined") {
	ctx.fillRect(arrR.vertX - 3 * ticL + barOffset, arrR.vertYT + (1 - fy) * arrR.boxH,
		     2 * ticL, fy * arrR.boxH);
    }
    
    hh = getTextHeight(ctx, ":00") + 5;
    const labelStep = 3 + arrR.boxW / maxTraces;
    let labelOffset = (traceNumber - 1) * labelStep - hh / 2
    
    ctx.fillStyle = "white";
    arrR.xL = arrR.boxXL + hh + 2 + labelOffset;
    arrR.yL = arrR.boxYL - (hh + 3) / 2;
    if (typeof arr.label != "undefined") {
	roundedRect(ctx, arrR.boxXL + labelOffset, arrR.boxYL - (hh + 3), hh, hh, 3)
	ctx.font = jetiToCtx("Mini")
	ctx.textAlign = "left";
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
	ctx.fillStyle = traceColor;
	roundedRect(ctx, arrR.boxXL + 1 + labelOffset, arrR.boxYL - hh - 2, hh - 2, hh - 2, 2)
    }
    
    return arrR
}

function renderGauge(ctx, input) {
    const widgetFuncs = {sequencedTextBox:sequencedTextBox,
			 stackedTextBox:stackedTextBox,
			 horizontalBar:horizontalBar,
			 roundNeedleGauge:roundNeedleGauge,
			 roundArcGauge:roundArcGauge,
			 virtualGauge:virtualGauge,
			 panelLight:panelLight,
			 rawText:rawText,
			 artHorizon:artHorizon,
			 verticalTape:verticalTape,
			 chartRecorder:chartRecorder,
			 verticalBar:verticalBar}
    
    console.log("* Input.type", input.type)
    if (widgetFuncs[input.type]) {

	return widgetFuncs[input.type](ctx, input);
    } else {
	console.log("Attempt to dispatch unknown gauge type: ", input.type)
    }
}

function setupWidgets(){ 
    let radius = {key: "radius", label: "Radius", type: "plusminus"},
        min = {key: "min", label: "Minimum", type: "plusminus"},
        max = {key: "max", label: "Maximum", type: "plusminus"},
        width = {key: "width", label: "Width", type: "slider", props: {min: 10, max: 320}},
        height = {key: "height", label: "Height", type: "slider", props: {min: 10, max: 200}},
        majdivs = {key: "majdivs", label: "Major Divisions", type: "plusminus"},
        subdivs = {key: "subdivs", label: "Sub divisions", type: "plusminus"},
        arc_props = {min: -360, max: 360},
        arc_start = {key: "start", label: "Arc start", type: "slider", props: arc_props},
        arc_end = {key: "end", label: "Arc end", type: "slider", props: arc_props},
        textFont = {key: "textFont", label: "Font size (text)", type: "fontsize"},
        labelFont = {key: "labelFont", label: "Font size (label)", type: "fontsize"},
        tickFont = {key: "tickFont",  label: "Font size (ticks)", type: "fontsize"},
        valueFont = {key: "valueFont", label: "Font size (readout)", type: "fontsize"};

    return {
        roundNeedleGauge: "roundGauge",
        roundArcGauge: "roundGauge",
        roundGauge: [
            radius,
            min,
            max,
            majdivs,
            subdivs,
            tickFont,
	    {key: "tickSpace", label: "Tick to number spacing", type: "slider", props:{min:-200, max: 150}},
	    {key: "readoutPosX", label: "Readout Position L-R", type:"slider", props:{min: -100, max: 50}},
	    {key: "readoutPosY", label: "Readout Position U-D", type: "slider",props:{min: -100, max: 50}},
            valueFont,
	    {key: "labelColor", label: "Font color (label)", type: "color"},
	    {key: "labelBoxColor", label: "Back box color (label)", type: "color"},	    
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -100, max: 100}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -200, max: 200}},
	    labelFont,
	    {key: "arcWidth", label: "Arc Width % of radius", type: "slider", props: {min: 0, max: 50}},
            arc_start,
            arc_end,
            {type: "spectrum-or-colorvals"},
	    {key: "faceVis", 
	     label: "Face Visibility", 
	     type: "select",
	     props: {
		 def: "on", 
		 options: [
		     {value: "on", label: "On"},
		     {value: "off", label: "Off"}
		 ]
	     }
	    },
	    {key: "scaleVis", 
	     label: "Scale Visibility", 
	     type: "select",
	     props: {
		 def: "on", 
		 options: [
		     {value: "on", label: "On"},
		     {value: "off", label: "Off"}
		 ]
	     }
	    },
	    { key: "needleType", 
	      label: "Needle Style", 
	      type: "select",
	      props: {
		  def: "needle", 
		  options: [
		      {value: "needle", label: "Standard"},
		      {value: "needleAlt", label: "Straight"},
		      {value: "needleFat", label: "Wide"},
		      {value: "needleTrim", label: "Trimmable"},
		      {value: "none", label: "None"}
		  ]
	      }
	    },
	    {key: "needleColor", label: "Needle color", type: "color"},
	    {key: "needleTrim", label: "Needle trim", type: "slider"},	    
        ],

        stackedTextBox: "textBox",
        sequencedTextBox: "textBox",
        textBox: [
            width,
            height,
            textFont,
            labelFont,
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -50, max: 50}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -50, max: 25}},
            {key: "backColor", label: "Background Color", type: "color"},
	    {key: "bezelColor", label: "Bezel Color", type: "color"},
            {label: "Mode", type: "textbox-mode-switcher"},
            {label: "Text values", type: "multitext"}
        ],
        
        horizontalBar: [
            width,
            height,
            min,
            max,
            majdivs,
            subdivs,
            {key: "backColor", label: "Background Color", type: "color"},
	    {key: "bezelColor", label: "Bezel Color", type: "color"},
            {key: "tickFont", label: "Font size (numbers)", type: "fontsize"},
            {key: "labelFont", label: "Font size (label)", type: "fontsize"},
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -50, max: 50}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -75, max: 25}},
            {type: "spectrum-or-colorvals"}
        ],
	
        verticalBar: [
            width,
            height,
            min,
            max,
            majdivs,
            subdivs,
            {key: "backColor", label: "Background Color", type: "color"},
	    {key: "bezelColor", label: "Bezel Color", type: "color"},
            {key: "tickFont", label: "Font size (numbers)", type: "fontsize"},
	    { key: "labelside", 
	      label: "Tick label side", 
	      type: "select",
	      props: {
		  def: "left", 
		  options: [
		      {value: "left", label: "Left"},
		      {value: "right", label: "Right"}
		  ]
	      }
	    },
            {key: "labelFont", label: "Font size (label)", type: "fontsize"},
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -50, max: 50}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -75, max: 25}},
	    { key: "labeltopbot", 
	      label: "Label top or bottom", 
	      type: "select",
	      props: {
		  def: "bottom", 
		  options: [
		      {value: "bottom", label: "Bottom"},
		      {value: "top", label: "Top"}
		  ]
	      }
	    },
            {type: "spectrum-or-colorvals"}
        ],

        virtualGauge: [
            radius,
            min,
            max,
            textFont,
            arc_start,
            arc_end,
            {key: "needleClip", label: "Needle clipping", type: "slider"},
        ],
	
        rawText: [
            width,
            height,
            {label: "Text", type: "multitext"},
            textFont,
            {key: "textColor", label: "Font color (text)", type: "color"},
	    { key: "textJust", 
	      label: "Justification (text)", 
	      type: "select",
	      props: {
		  def: "center", 
		  options: [
		      {value: "center", label: "Centered"},
		      {value: "left", label: "Left"},
		      {value: "right", label: "Right"}
		  ]
	      }
	    },
            {key: "backColor", label: "Background Box Color", type: "color"},	    
        ],
	
        panelLight: [
            radius,
            width,
            height,
            labelFont,
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -50, max: 50}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -50, max: 25}},
            {key: "lightColor", label: "Color", type: "color"},
	    {key: "backColor", label: "Background Color", type: "color"},
	    {key: "bezelColor", label: "Bezel Color", type: "color"}
        ],
	
	artHorizon: [
	    width,
	    height,
	    {key: "roll", label: "Roll (deg)", type: "slider", props: {min: -180, max: 180}},
	    {key: "pitch", label: "Pitch (deg)", type: "slider", props: {min: -180, max: 180}},	    
	    {key: "skyColor", label: "Sky Color", type: "color"},
            {key: "landColor", label:"Land Color", type: "color"},
	    {key: "labelPosX", label: "Label Position L-R", type: "slider", props: {min: -50, max: 50}},
	    {key: "labelPosY", label: "Label Position U-D", type: "slider", props: {min: -140, max: 10}},
	    labelFont
	],

	verticalTape: [
	    width,
	    height,
	    {key: "step", label: "Step", type: "slider", props: {min: 1, max: 100}},
            {key: "numbers", label: "Numbers shown", type: "plusminus"},
	    { key: "handed", 
	      label: "Left or Right handed", 
	      type: "select",
	      props: {
		  def: "left", 
		  options: [
		      {value: "left", label: "Left"},
		      {value: "right", label: "Right"}
		  ]
	      }
	    }, 
	    labelFont,
	    valueFont,
            {key: "tapeFont", label: "Font size (tape)", type: "fontsize"},	    
	    {key: "backColor", label: "Background Color", type: "color"}
	],

	chartRecorder: [
	    width,
	    height,
	    min,
	    max,
	    {key: "backColor", label: "Background Color", type: "color"},
	    {key: "chartBackColor", label: "Chart Background Color", type: "color"}	    ,
	    {key: "chartTraceColor", label: "Chart Trace Color", type: "color"},	    
	    {key: "traceNumber", label: "Trace number", type: "plusminus"},
	    {key: "maxTraces", label: "Max number of traces", type: "plusminus"},
	    {key: "timeSpan", 
	      label: "Chart time span (mm:ss)", 
	      type: "select",
	      props: {
		  def: "t30", 
		  options: [
		      {value: "t30",  label: "00:30"},
		      {value: "t60",  label: "01:00"},
		      {value: "t120", label :"02:00"},
		      {value: "t240", label :"04:00"},
		      {value: "t480", label :"08:00"}
		  ]
	      }
	    }
	]
	
    }
}

