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

function returnColorVals(spec, min, max) {
    var cval = [];
    
    const step = (max - min) / spec.length;
    //console.log("step", step);
    for (var i = 0; i < spec.length; i++) {
	//console.log(i, spec[i], step * (i + 1))
	cval[i] = {color: spec[i], val: step * (i + 1) };
    }
    return cval;
}

function drawNeedle(ctx, arr, type, f, angle) {
    needles = { needle: [ {x:-1,y:0}, {x:-2,y:1}, {x:-4,y:4}, {x:-1,y:58},
			   {x:1,y:58}, {x:4, y:4}, {x:2, y:1}, {x:1,y:0}],
		needleAlt: [ {x:-2,y:0}, {x:-2,y:50}, {x:0,y:58},
			      {x:2, y:50}, {x:2, y:0}, {x:0, y:-2}],
		needleFat: [ {x:-2,y:0}, {x:-4,y:30}, {x:0,y:45},
			      {x:4, y:30}, {x:2,y:0}, {x:0, y:-2} ]
	      }
    
    if (typeof needles[type] == "undefined") {
	//console.log("returning")
	return
    }
    //console.log(type, f, angle, needles[type].length);
    
    ctx.beginPath();
    for (let k = 0, len = needles[type].length; k < len; k++ ) {
	ctx.lineTo(arr.x0 + f * needles[type][k].x * Math.cos(angle) -
		   f * needles[type][k].y * Math.sin(angle),
		   arr.y0 + f * needles[type][k].x * Math.sin(angle) +
		   f * needles[type][k].y * Math.cos(angle))
    }
    ctx.fill();
    
}

function roundG(ctx, arr, x0, y0, ro, start, end, min, max, nseg, minmaj, specIn, colors, value, label, type) {
    const ri = ro * 0.85;
    const fontScale = 0.24;
    var arrR = {};
    
    var spec = specIn;

    if (typeof specIn == "object" && specIn != null) {
	if (specIn.length == 1) {
	    spec[1] = spec[0];
	}
    }
   
    arrR.ri = ri;
    
    needle = [ {x:-1,y:0}, {x:-2,y:1}, {x:-4,y:4}, {x:-1,y:58},
	       {x:1,y:58}, {x:4, y:4}, {x:2, y:1}, {x:1,y:0}]

    needleAlt = [ {x:-2,y:0}, {x:-2,y:50}, {x:0,y:58},
		  {x:2, y:50}, {x:2, y:0}, {x:0, y:-2}]
    
    needleFat = [ {x:-2,y:0}, {x:-4,y:30}, {x:0,y:45},
		  {x:4, y:30}, {x:2,y:0}, {x:0, y:-2} ]
    
    
    ctx.font="bold " + fontScale * ro + "px sans-serif"
    var fontoffset = fontScale * ro / 4;

    if (spec) {
	var rainbow = new Rainbow();
	rainbow.setSpectrumByArray(spec); 
	rainbow.setNumberRange(0,nseg-1)
    }

    if (colors) {
	// setup for colorvals if needed
    }

    //console.log("colors", colors, typeof colors, "spec", spec, typeof spec)

    const fudge = 1 / (100*nseg);
    for (let i = 0; i <= nseg; i++) {
	
	var delta = (end - start) / nseg;
	var a = start + i * delta

	if (type != "altimeter") {
	    ctx.fillStyle = "gray";
	    if (spec != null) {
		ctx.fillStyle = "#"+rainbow.colourAt(i);
	    } else if (colors != null) {
		const cl = colors.length - 1;
		var aFrac = (a - start) / (end - start)
		var val = (min + aFrac * (max - min))
		if (val != 0) {
		    val = val + fudge;
		}
		if (val <= colors[0].val) {
		    ctx.fillStyle = colors[0].color
		} else if (val >= colors[cl].val) {
		    ctx.fillStyle = colors[cl].color
		} else {
		    for (let j = 1; j <= cl; j++) {
			if (val >= colors[j-1].val && val < colors[j].val) {
			    ctx.fillStyle = colors[j].color;
			    break;
			}
		    }
		}
	    } else {
		ctx.fillStyle = "white";
	    }
	} else {
	    ctx.fillStyle = "#202020";
	}

	if (i < nseg) {
	    var a1 = start + i * delta - 0*delta
	    var a2 = start + i * delta + 1*delta;
	    arcsegment(ctx, x0, y0, ri, ro, a1, a2 )
	}

	ctx.lineWidth = ro / 46;	
	ctx.strokeStyle="white";

	ctx.beginPath();
	ctx.moveTo(x0 + ro * Math.cos(a), y0 + ro * Math.sin(a))
	ctx.lineTo(x0 + ri * Math.cos(a), y0 + ri * Math.sin(a))
	ctx.stroke();

	const label2C = 1.6

	//console.log(i, minmaj, i % minmaj, (min + i * (max - min) / nseg));
	
	if (minmaj > 0 && i % minmaj == 0) {
	    ctx.fillStyle = "white";
	    ctx.textAlign = "center";
	    var rt = ri - label2C * (ro - ri)
	    var val = (min + i * (max - min) / nseg)
	    if (val <=  max) {
		//console.log("&",val);
		if (type == "airspeed") {
		    ctx.font="bold " + 0.60 * fontScale * ro + "px sans-serif"
		    fontoffset = fontScale * ro / 4;		    
		}
		
		ctx.fillText(val.toString(),
			     x0 + rt * Math.cos(a),
			     y0 + rt * Math.sin(a) + fontoffset)
	    }
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

    if (label) {
	ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
	arrR.xL = x0;
	arrR.yL = y0 + 0.90 * ro;
	ctx.fillText(label, arrR.xL, arrR.yL);
    }

    if (type == "altimeter") {
	ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
	const xA = x0 + ro * 0.25;
	const yA = y0 - ro * 0.1;
	ctx.fillText("ALT", xA, yA);	
	const x10 = x0 - ro * 0.03;
	const y10 = y0 - ro * 0.40;
	ctx.font = "bold " + 0.60 * fontScale * ro + "px sans-serif"
	ctx.fillText("10 m", x10, y10);
    }
    
    if (typeof value == "number") {
	ctx.font = "bold " + 0.75* fontScale * ro + "px sans-serif"
	arrR.xV = x0;
	arrR.yV = y0 + 0.3 * ro;
	ctx.fillText(parseFloat(value).toFixed(2), arrR.xV, arrR.yV);
	//console.log(value, parseFloat(value).toFixed(2))
	if (type == "altimeter") {
	    var val1C = value / 100.0;
	    var valTC = Math.floor(value / 100.0)
	    var valT  = 10 * (val1C - valTC);
	    var frac = Math.max(Math.min( (val1C - min) / (max - min), 1), 0);
	    var angle = start + frac * (end - start) - Math.PI/2;
	    ctx.fillStyle = "white";
	    var f = 0.90 * ro / 58;
	    drawNeedle(ctx, arr, "needleFat", f)
	    /*
	    ctx.beginPath();
	    for (let k = 0, len = needleFat.length; k < len; k++ ) {
		ctx.lineTo(x0 + f * needleFat[k].x * Math.cos(angle) -
			   f * needleFat[k].y * Math.sin(angle),
			   y0 + f * needleFat[k].x * Math.sin(angle) +
			   f * needleFat[k].y * Math.cos(angle))
	    }
	    ctx.fill();
	    */
	    frac = Math.max(Math.min( (valT - min) / (max - min), 1), 0);
	    angle = start + frac * (end - start) - Math.PI/2;
	    ctx.fillStyle = "white";
	    f = 0.90 * ro / 58;
	    /*
	    ctx.beginPath();
	    for (let k = 0, len = needleAlt.length; k < len; k++ ) {
		ctx.lineTo(x0 + f * needleAlt[k].x * Math.cos(angle) -
			   f * needleAlt[k].y * Math.sin(angle),
			   y0 + f * needleAlt[k].x * Math.sin(angle) +
			   f * needleAlt[k].y * Math.cos(angle))
	    }
	    ctx.fill();
	    */
	    drawNeedle(ctx, arr, "needleAlt", f)
	} else {
	    var frac = Math.max(Math.min( (value - min) / (max - min), 1), 0);
	    var angle = start + frac * (end - start) - Math.PI/2;
	    ctx.fillStyle = "white";
	    let f = 0.90 * ro / 58;
	    drawNeedle(ctx, arr, "needle", f, angle);
	    /*
	    ctx.beginPath();
	    for (let k = 0, len = needle.length; k < len; k++ ) {
		ctx.lineTo(x0 + f * needle[k].x * Math.cos(angle) - f * needle[k].y * Math.sin(angle),
			   y0 + f * needle[k].x * Math.sin(angle) + f * needle[k].y * Math.cos(angle))
	    }
	    ctx.fill();
	    */
	}
    }
    return arrR
}

function roundGauge(ctx, arr) {

    var start = -1.25 * Math.PI;
    var end = 0.25 * Math.PI;
    const eTrim = 0.99;
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

    const bezel=4;
    const radius = arr.radius - 2*bezel; 
    //console.log(radius)
    const gradient = ctx.createRadialGradient(arr.x0, arr.y0, 0, arr.x0, arr.y0, radius) 
    gradient.addColorStop(0  , "black");
    gradient.addColorStop(0.6, "#202020");
    gradient.addColorStop(  1, "#303030");
    ctx.fillStyle = gradient;
    //ctx.fillStyle = "black";
    ctx.beginPath();
    ctx.ellipse(arr.x0, arr.y0, radius * eTrim, radius * eTrim, 0, 0, 2*Math.PI);
    ctx.fill();

    const b1gradient = ctx.createRadialGradient(arr.x0, arr.y0, radius, arr.x0, arr.y0, radius+bezel);
    b1gradient.addColorStop(0, "black");
    b1gradient.addColorStop(0.2, "#101010")
    b1gradient.addColorStop(1, "#303030");
    ctx.fillStyle = b1gradient;
    arcsegment(ctx, arr.x0, arr.y0, radius, radius+bezel, 0, 2*Math.PI);

    const b2gradient = ctx.createRadialGradient(arr.x0, arr.y0, radius+bezel,
						arr.x0, arr.y0, radius+2*bezel);
    b2gradient.addColorStop(1, "black");
    b2gradient.addColorStop(0.2, "#101010")
    b2gradient.addColorStop(0, "#303030");
    ctx.fillStyle = b2gradient;
    arcsegment(ctx, arr.x0, arr.y0, radius+bezel, radius+2*bezel, 0, 2*Math.PI);

    var max = arr.max;
    var min = arr.min;
    var divs = arr.divs;
    var subdivs = arr.subdivs;
    var clr = [];
    clr = arr.colorvals;
    if (arr.gaugetype == "altimeter") {
	console.log("altimeter")
	max = 10;
	min = 0;
	divs = 50;
	subdivs = 5;
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

    if (typeof spec == 'XXXobject') {
	//console.log("spec", spec)
	clr = returnColorVals(arr.spectrum, min, max);
	spec = arr.barfo;
    }
    
    return roundG(ctx, arr, arr.x0, arr.y0, radius, start, end, min, max,
		  divs, subdivs, spec, clr,
		  arr.value, arr.label, arr.gaugetype);

}

function virtualGauge(ctx, arr) {

    var start = -1.25 * Math.PI;
    var end = 0.25 * Math.PI;
    var rotate = arr.rotate;
    const fontScale = 0.24;
    var arrR = {};

    if (typeof arr.value != "number") {
	console.log("arr.value not number - returning - type:", typeof arr.value)
	return
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

    ctx.strokeStyle = "lightgray";

    const ro = arr.radius - 2;
    
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

    ctx.fillStyle = "white";
    let f = 0.90 * ro / 58;

    drawNeedle(ctx, arr, "needle", f, angle);

    ctx.textAlign = "center";
    
    if (arr.label) {
	ctx.font = "bold " + 0.90 * fontScale * ro + "px sans-serif"
	arrR.xL = arr.x0;
	arrR.yL = arr.y0 + 0.90 * ro;
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
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

function textBox(ctx, arr) { 

    var arrR = {}
    var h
    const hFrac = 0.6
    if (arr.height) {
	h = arr.height;
    } else {
	h = w/4;
    }

    const x0 = arr.x0;
    const y0 = arr.y0;
    
    const fontScale = 0.30;
    const fontoffset = fontScale * h / 4;
    h = h * hFrac;

    arrR.height = h;
    arrR.width = arr.width;

    ctx.font="bold " + fontScale * h + "px sans-serif"

    const bezel = 2;

    ctx.fillStyle = "#303030";
    roundedRect(ctx, x0 - arr.width/2, y0 - h/2, arr.width, h, h/10);

    if (arr.color) {
	ctx.fillStyle = arr.color;
    } else {
	ctx.fillStyle = "yellowgreen";
    }

    roundedRect(ctx, x0 - arr.width/2 + bezel, y0 - h/2 + bezel, arr.width - 2*bezel, h-2*bezel, h/10);
        
    ctx.textAlign = "center";

    if (arr.label) {
	if (arr.labelcolor) {
	    ctx.fillStyle = arr.labelcolor;
	} else {
	    ctx.fillStyle = "white";
	}
	ctx.font = "" + 0.9 * fontScale * h + "px sans-serif"
	arrR.xL = x0
	
	//console.log(y0, h/2, 0.85 * fontScale * h);

	arrR.yL = y0 + h/2 + 0.85 * fontScale * h;

	ctx.fillText(arr.label, arrR.xL, arrR.yL);
    }
    if (arr.textcolor) {
	ctx.fillStyle = arr.textcolor;
    } else {
	ctx.fillStyle = "black";	
    }
    if (arr.value) {
	ctx.font = "bold " + fontScale * arr.height + "px sans-serif"
	arrR.xV = x0;
	arrR.yV = y0;
	//console.log(typeof arr.value)
	var str;
	if (typeof arr.value == 'string') {
	    str = arr.value;
	} else {
	    str = arr.value[0];
	}
	ctx.fillText(str, arrR.xV, arrR.yV + fontoffset);
    }
    return arrR
}

function horizontalBar(ctx, arr) {

    const hPad = arr.height / 4;
    const vPad = arr.height / 8;
    const h = arr.height - 2 * vPad;
    const w = arr.width - 2 * hPad;
    const start = arr.x0 - w / 2 //arr.width / 2 + hPad;
    const end = arr.x0 + w / 2 //arr.width / 2 - hPad;

    var arrR = {};
    
    ctx.fillStyle = "black";
    //ctx.fillRect(arr.x0 - arr.width / 2, arr.y0 - arr.height / 2, arr.width, arr.height)

    const fontScale = 0.18;
    ctx.font = "bold " + fontScale * arr.height + "px sans-serif"
    const fontoffset = -4 //0.00 * arr.height
    
    var rainbow = new Rainbow();

    var spectrum = arr.spectrum;
    
    if (spectrum.length == 1) {
	spectrum[1] = spectrum[0];
    }
    
    rainbow.setSpectrumByArray(spectrum); 
    rainbow.setNumberRange(0,arr.divs-1)

    const cellMult = 0.4;
    const cellOff  = (1 - cellMult) / 2 * h;

    arrR.barW = w;
    arrR.barH = h * cellMult;

    console.log("width, height, w,h", arr.width, arr.height, arrR.barW, arrR.barH);

    const bezel = 3;

    ctx.fillStyle = "#303030";
    //roundedRect(ctx, arr.x0 - arrR.barW/2, arr.y0 - arrR.barH/2, arrR.barW, arrR.barH, arrR.barH/10);
    roundedRect(ctx, arr.x0 - arrR.barW/2 - bezel, arr.y0 - arrR.barH/2 - bezel,
		arrR.barW + 2*bezel, arrR.barH + 2 * bezel, arrR.barH/10);


    var a;
    
    for (var i = 0; i <= arr.divs; i++) {
	ctx.fillStyle = "#" + rainbow.colourAt(i);
	var delta = (arr.width - 2*hPad) / arr.divs;
	a = start + i * delta;
	
	if (i < arr.divs) {
	    //var a1 = start + i * delta - 0 * delta
	    //var a2 = start + i * delta + 1 * delta;
	    //ctx.fillRect(a1, arr.y0 - h / 2 + cellOff, delta, cellMult * h)
	    ctx.fillRect(a, arr.y0 - h / 2 + cellOff, delta, cellMult * h)
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
			 arr.y0 - h/2 - fontoffset)
	    ctx.lineWidth = h / 23;	
	    ctx.strokeStyle="white";
	    ctx.beginPath();
	    ctx.moveTo(a, arr.y0 - h / 2 + cellOff)
	    ctx.lineTo(a, arr.y0 + h / 2  - cellOff)
	    ctx.stroke();
	}
    }
    ctx.fillStyle = "white";
    ctx.textAlign = "center";
    if (arr.label) {
	ctx.font = "bold " + fontScale * arr.height + "px sans-serif"
	arrR.xL = arr.x0;
	arrR.yL = arr.y0 +  h / 2;
	ctx.fillText(arr.label, arrR.xL, arrR.yL);
    }
    return arrR;
}

function panelLight(ctx, x0, y0, radius, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.ellipse(x0, y0, radius, radius, 0, 0, Math.PI*2);
    ctx.fill();
}

function renderGauge(ctx, input) {
    const widgetFuncs = {textBox:textBox, horizontalBar:horizontalBar,
			 roundGauge:roundGauge, virtualGauge:virtualGauge}
    if (widgetFuncs[input.type]) {
	return widgetFuncs[input.type](ctx, input);
    } else {
	console.log("Attempt to dispatch unknown gauge type: ", input.type)
    }
}
