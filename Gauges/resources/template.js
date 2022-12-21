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

function roundG(ctx, x0, y0, ro, start, end, min, max, nseg, minmaj, spec, value, label) {
    const ri = ro * 0.85;
    const fontScale = 0.24;
    needle = [ {x:-1,y:0}, {x:-2,y:1}, {x:-4,y:4}, {x:-1,y:58},
	       {x:1,y:58}, {x:4, y:4}, {x:2, y:1}, {x:1,y:0} ]
    
    ctx.font="bold " + fontScale * ro + "px sans-serif"
    const fontoffset = fontScale * ro / 4;
    
    var rainbow = new Rainbow();
    rainbow.setSpectrumByArray(spec); 
    rainbow.setNumberRange(0,nseg-1)

    for (let i = 0; i <= nseg; i++) {

	ctx.fillStyle = "#"+rainbow.colourAt(i);
	
	var delta = (end - start) / nseg;
	
	if (i < nseg) {
	    var a1 = start + i * delta - 0*delta
	    var a2 = start + i * delta + 1*delta;
	    arcsegment(ctx, x0, y0, ri, ro, a1, a2 )
	}

	var a = start + i * delta

	ctx.lineWidth = ro / 46;	
	ctx.strokeStyle="white";

	ctx.beginPath();
	ctx.moveTo(x0 + ro * Math.cos(a), y0 + ro * Math.sin(a))
	ctx.lineTo(x0 + ri * Math.cos(a), y0 + ri * Math.sin(a))
	ctx.stroke();

	const label2C = 1.6
	
	if (minmaj > 0 && i % minmaj == 0) {
	    ctx.fillStyle = "white";
	    ctx.textAlign = "center";
	    var rt = ri - label2C * (ro - ri)
	    var val = Math.floor(min + i * (max - min) / nseg)
	    ctx.fillText(val.toString(),
			 x0 + rt * Math.cos(a),
			 y0 + rt * Math.sin(a) + fontoffset)
	    ctx.lineWidth=ro/23;	
	    ctx.strokeStyle="white";
	    ctx.beginPath();
	    var rr = ri - (ro - ri) / 2;
	    ctx.moveTo(x0 + ro * Math.cos(a), y0 + ro * Math.sin(a))
	    ctx.lineTo(x0 + rr * Math.cos(a), y0 + rr * Math.sin(a))
	    ctx.stroke();
	}
    }
    ctx.fillStyle = "white";
    ctx.textAlign = "center";

    ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"

    if (label) {
	ctx.fillText(label, x0, y0 + 0.90 * ro);
    }

    if (value) {
	ctx.font = "bold " + 0.75* fontScale * ro + "px sans-serif"
	ctx.fillText(parseFloat(value).toFixed(1), x0, y0 + 0.3 * ro);
	
	var angle = Math.PI / 2.0;
	
	ctx.fillStyle = "white";
	ctx.beginPath();
	let f = 0.90 * ro / 58;
	for (let k = 0, len = needle.length; k < len; k++ ) {
	    ctx.lineTo(x0 + f * needle[k].x * Math.cos(angle) - f * needle[k].y * Math.sin(angle),
		       y0 + f * needle[k].x * Math.sin(angle) + f * needle[k].y * Math.cos(angle))
	    
	}
	ctx.fill();
    }
}

function roundGauge(ctx, arr) {

    const start = -1.25 * Math.PI;
    const end = 0.25 * Math.PI;
    const eTrim = 0.99;
    
    ctx.fillStyle = "black";
    ctx.beginPath();
    ctx.ellipse(arr.x0, arr.y0, arr.radius * eTrim, arr.radius * eTrim, 0, 0, 2*Math.PI);
    ctx.fill();

    roundG(ctx, arr.x0, arr.y0, arr.radius, start, end, arr.min, arr.max,
	   arr.divs, arr.subdivs, arr.spectrum, arr.value, arr.label);
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
    ctx.fill()
    
}

function textBox(ctx, arr) { 
    var h
    if (arr.height) {
	h = arr.height;
    } else {
	h = w/4;
    }
    const fontScale = 0.22
    ctx.font="bold " + fontScale * h + "px sans-serif"
    ctx.fillStyle = "yellowgreen";
    roundedRect(ctx, arr.x0 - arr.width/2, arr.y0 - h/2, arr.width, h, h/10);
}

function horizontalBar(ctx, arr) {

    const hPad = arr.height / 4;
    const vPad = arr.height / 8;
    const start = arr.x0 - arr.width / 2 + hPad;
    const end = arr.x0 + arr.width / 2 - hPad;

    const h = arr.height - 2 * vPad;
    const w = arr.width - 2 * hPad;

    arr.barwidth = start;
    arr.barheight = end;
    
    ctx.fillStyle = "black";
    ctx.fillRect(arr.x0 - arr.width / 2, arr.y0 - arr.height / 2, arr.width, arr.height)

    const fontScale = 0.25;
    ctx.font = "bold " + fontScale * arr.height + "px sans-serif"
    const fontOffset = 0.16 * arr.height
    
    var rainbow = new Rainbow();
    rainbow.setSpectrumByArray(arr.spectrum); 
    rainbow.setNumberRange(0,arr.divs-1)

    const cellMult = 0.4;
    const cellOff  = (1 - cellMult) / 2 * h;
    
    for (var i = 0; i <= arr.divs; i++) {
	ctx.fillStyle = "#" + rainbow.colourAt(i);
	var delta = (arr.width - 2*hPad) / arr.divs;
	const a = start + i * delta;
	
	if (i < arr.divs) {
	    var a1 = start + i * delta - 0 * delta
	    var a2 = start + i * delta + 1 * delta;
	    ctx.fillRect(a1, arr.y0 - h / 2 + cellOff, delta, cellMult * h)
	    ctx.lineWidth = h / 60;	
	    ctx.strokeStyle="white";
	    ctx.beginPath();
	    ctx.moveTo(a, arr.y0 - h / 2 + cellOff)
	    ctx.lineTo(a, arr.y0 + h / 2 - cellOff)
	    ctx.stroke();
	}

	if (arr.subdivs > 0 && i % arr.subdivs == 0) {
	    ctx.fillStyle = "white";	
	    ctx.textAlign = "center";
	    var val = Math.floor(arr.min + i * (arr.max - arr.min) / arr.divs)
	    ctx.fillText(val.toString(),
			 a,
			 arr.y0 - h/2 + fontOffset)
	    ctx.lineWidth = h / 23;	
	    ctx.strokeStyle="white";
	    ctx.beginPath();
	    ctx.moveTo(a, arr.y0 - h / 2 + cellOff)
	    ctx.lineTo(a, arr.y0 + h / 2  - cellOff)
	    ctx.stroke();
	}
    }
}

function panelLight(ctx, x0, y0, radius, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.ellipse(x0, y0, radius, radius, 0, 0, Math.PI*2);
    ctx.fill();
}

function draw(input) {
    let cvs = document.getElementById("output-canvas");
    let ctx = cvs.getContext("2d");

    renderGauges(ctx, input);
}

function renderGauges(ctx, input) {
    const widgetFuncs = {textBox:textBox, horizontalBar:horizontalBar, roundGauge:roundGauge}
    
    for (const inp of input) {
	if (widgetFuncs[inp.type]) {
	    widgetFuncs[inp.type](ctx, inp)
	}
    }
}
