goog.provide('gauge');
gauge.static_input_data = cljs.core.PersistentVector.EMPTY;
if((typeof gauge !== 'undefined') && (typeof gauge.db !== 'undefined')){
} else {
gauge.db = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(cljs.core.PersistentArrayMap.EMPTY);
}
gauge.config_json = cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(JSON.parse("{\n    \n    \"examples\": {\n        \"Empty\":         {\"file\": \"Empty.json\"},\n        \"ElectricArc\":   {\"file\": \"ElectricArc.json\"},\t\n        \"FourUp\":        {\"file\": \"FourUp.json\"},\n        \"PreFlightArc\":  {\"file\": \"PreFlightArc.json\"},\n        \"PreFlightCBox\": {\"file\": \"PreFlightCBox.json\"},\t\t\n        \"Turbine\":       {\"file\": \"Turbine.json\"},\n        \"TurbineArc\":    {\"file\": \"TurbineArc.json\"},\n\t\"TwoLarge\":      {\"file\": \"TwoLarge.json\"},\n\t\"TwoLargeArc\":   {\"file\": \"TwoLargeArc.json\"},\t\n\t\"GlassCockpit\":  {\"file\": \"GlassCockpit.json\"},\n\t\"TwoNeedle\":     {\"file\": \"TwoNeedle.json\"},\n\t\"Concentric\":    {\"file\": \"Concentric.json\"},\n\t\"SplitLarge\":    {\"file\": \"SplitSpread.json\"},\n\t\"ChartRecorder\": {\"file\": \"ChartRecorder.json\"}\n    },\n\n    \"prototypes\": {\n\t\n        \"roundNeedleGauge\": {\n            \"type\": \"roundNeedleGauge\",\n            \"x0\": 160,\n            \"y0\": 80,\n            \"radius\": 80,\n            \"min\": 0,\n            \"max\": 100,\n\t    \"tickFont\":\"Bold\",\n\t    \"tickSpace\":100,\n            \"value\":85,\n\t    \"readoutPosX\":0,\n\t    \"readoutPosY\":0,\n\t    \"valueFont\":\"Mini\",\n\t    \"majdivs\":4,\n            \"subdivs\": 5,\n            \"label\":\"Label\",\n\t    \"labelFont\":\"Bold\",\n\t    \"labelBoxColor\":\"transparent\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n            \"spectrum\": [\n\t\t\"red\",\n\t\t\"orange\",\n\t\t\"yellow\",\n\t\t\"green\"\n            ],\n\t    \"faceVis\":\"on\",\n\t    \"scaleVis\":\"on\",\n\t    \"needleType\":\"needle\",\n\t    \"needleColor\":\"white\",\n\t    \"labelColor\":\"white\",\n\t    \"arcWidth\":15\n        },\n\n        \"roundArcGauge\": {\n            \"type\": \"roundArcGauge\",\n            \"x0\": 160,\n            \"y0\": 80,\n            \"radius\": 80,\n            \"min\": 0,\n            \"max\": 100,\n\t    \"tickFont\":\"Normal\",\n\t    \"tickSpace\":100,\n\t    \"valueFont\":\"Maxi\",\n\t    \"majdivs\": 0,\n            \"subdivs\": 0,\n            \"value\":85,\n\t    \"readoutPosX\":0,\n\t    \"readoutPosY\":0,\n            \"label\":\"Label\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n\t    \"labelFont\":\"Bold\",\n\t    \"labelColor\":\"white\",\n\t    \"labelBoxColor\":\"transparent\",\n            \"spectrum\": [\n\t\t\"red\",\n\t\t\"orange\",\n\t\t\"yellow\",\n\t\t\"green\"\n            ],\n\t    \"arcWidth\":20,\n\t    \"faceVis\":\"on\",\n\t    \"scaleVis\":\"on\"\n        },\n\t\n        \"horizontalBar\": {\n            \"type\": \"horizontalBar\",\n            \"x0\": 160,\n            \"y0\": 80,\n            \"width\": 200,\n            \"height\": 70,\n            \"min\": 0,\n            \"max\": 100,\n\t    \"tickFont\":\"Mini\",\n\t    \"majdivs\":4,\n            \"subdivs\": 4,\n            \"label\":\"Value\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n\t    \"labelFont\":\"Mini\",\n\t    \"backColor\":\"black\",\n\t    \"bezelColor\":\"transparent\",\n\t    \"value\":50,\n            \"spectrum\": [\n                \"red\",\n                \"yellow\",\n                \"green\"\n            ] \n        },\n\n        \"sequencedTextBox\":  {\n            \"type\": \"sequencedTextBox\",\n\t    \"textFont\":\"Mini\",\n            \"x0\": 160,\n            \"y0\": 80,\n            \"width\": 100,\n            \"height\": 35,\n            \"value\": 0,\n\t    \"text\": [\n\t\t\"Ready\",\n\t\t\"Starting\",\n\t\t\"Running\"\n\t    ],\n\t    \"textcolor\": \"black\",\n\t    \"backColor\":\"yellowgreen\",\n\t    \"bezelColor\":\"transparent\",\n            \"label\":\"Status\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n\t    \"labelcolor\": \"white\",\n\t    \"labelFont\":\"Mini\"\n        },\n\n        \"stackedTextBox\":  {\n            \"type\": \"stackedTextBox\",\n\t    \"textFont\":\"Mini\",\n            \"x0\": 160,\n            \"y0\": 80,\n            \"width\": 120,\n            \"height\": 100,\n            \"value\": 0,\n\t    \"text\": [\n\t\t\"This is line 1\",\n\t\t\"And this is line 2\",\n\t\t\"Lastly this is line 3\"\n\t    ],\n\t    \"textcolor\": \"black\",\n\t    \"backColor\":\"yellowgreen\",\n\t    \"bezelColor\":\"transparent\",\n            \"label\":\"Info\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n\t    \"labelcolor\": \"white\",\n\t    \"labelFont\":\"Mini\"\n        },\n\n\t\"panelLight\": {\n\t    \"type\":\"panelLight\",\n\t    \"x0\":160,\n\t    \"y0\":80,\n\t    \"lightColor\":\"red\",\n\t    \"backColor\":\"black\",\n\t    \"bezelColor\":\"transparent\",\n\t    \"label\":\"Red Light\",\n\t    \"labelFont\":\"None\",\n\t    \"labelPosX\":0,\n\t    \"labelPosY\":0,\t    \n\t    \"radius\":10,\n\t    \"width\":50,\n\t    \"height\":50,\t    \n\t    \"min\":0,\n\t    \"max\":1,\n\t    \"value\":1\n\t},\n\t\n\t\"rawText\": {\n\t    \"type\":\"rawText\",\n\t    \"x0\": 160,\n\t    \"y0\": 80,\n\t    \"text\": [\n\t\t\"Some raw text\"\n\t    ],\n\t    \"label\":\"Label\",\n\t    \"textColor\":\"white\",\n\t    \"width\":200,\n\t    \"height\":40,\n\t    \"backColor\":\"transparent\"\n\t},\n\n\t\"virtualGauge\": {\n\t    \"type\": \"virtualGauge\",\n\t    \"x0\": 160,\n\t    \"y0\": 80,\n\t    \"min\": 0,\n\t    \"max\": 100,\n\t    \"radius\": 80,\n\t    \"value\": 0,\n\t    \"start\": -135,\n\t    \"end\": 135\n\t},\n\n\t\"artHorizon\": {\n\t    \"type\": \"artHorizon\",\n\t    \"x0\": 160,\n\t    \"y0\": 80,\n\t    \"roll\":0,\n\t    \"pitch\":0,\n\t    \"width\":150,\n\t    \"height\":150,\n\t    \"skyColor\":\"blue\",\n\t    \"landColor\":\"chocolate\",\n\t    \"label\":\"Artificial Horizon\",\n\t    \"labelFont\":\"None\",\n\t    \"labelPosX\": 0,\n\t    \"labelPosY\": 0,\t    \n\t    \"value\":0\n\t},\n\n\t\"verticalTape\": {\n\t    \"type\": \"verticalTape\",\n\t    \"x0\": 160,\n\t    \"y0\": 80,\n\t    \"height\": 160,\n\t    \"width\": 150,\n\t    \"step\":10,\n\t    \"value\":50,\n\t    \"numbers\":6,\n\t    \"label\":\"Airspeed\",\n\t    \"labelFont\":\"Mini\",\n\t    \"valueFont\":\"Big\",\n\t    \"valuePos\": \"Side\",\n\t    \"tapeFont\": \"Mini\",\n\t    \"valueFont\": \"Normal\",\n\t    \"backColor\": \"black\",\n\t    \"handed\":\"left\"\n\t},\n\t\"chartRecorder\": {\n\t    \"type\": \"chartRecorder\",\n\t    \"x0\":160,\n\t    \"y0\":80,\n\t    \"height\": 160,\n\t    \"width\":320,\n\t    \"value\":50,\n\t    \"min\":0,\n\t    \"max\":100,\n\t    \"backColor\":\"black\",\n\t    \"chartBackColor\":\"grey\",\n\t    \"chartTraceColor\":\"blue\",\n\t    \"traceNumber\":1,\n\t    \"label\":\"Trace\",\n\t    \"timeSpan\":\"t60\",\n\t    \"maxTraces\":1,\n\t    \"timeFont\":\"Mini\"\n\t}\t\n    }\n}\n"));
gauge.draw_scale = (2);
gauge.disp_scale = ((((((2000) < window.innerWidth)) && (((600) < window.innerHeight))))?(2):(1));
gauge.screen_width = (318);
gauge.screen_height = (159);
gauge.shape__GT_bbox = (function gauge$shape__GT_bbox(p__45586){
var map__45587 = p__45586;
var map__45587__$1 = cljs.core.__destructure_map(map__45587);
var sh = map__45587__$1;
var radius = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45587__$1,"radius");
var x0 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45587__$1,"x0");
var y0 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45587__$1,"y0");
var width = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45587__$1,"width");
var height = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45587__$1,"height");
if(cljs.core.truth_((function (){var and__4149__auto__ = width;
if(cljs.core.truth_(and__4149__auto__)){
var and__4149__auto____$1 = height;
if(cljs.core.truth_(and__4149__auto____$1)){
var and__4149__auto____$2 = x0;
if(cljs.core.truth_(and__4149__auto____$2)){
return y0;
} else {
return and__4149__auto____$2;
}
} else {
return and__4149__auto____$1;
}
} else {
return and__4149__auto__;
}
})())){
var halfw = (0.5 * width);
var halfh = (0.5 * height);
return new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [(x0 - halfw),(y0 - halfh),width,height], null);
} else {
if(cljs.core.truth_((function (){var and__4149__auto__ = radius;
if(cljs.core.truth_(and__4149__auto__)){
var and__4149__auto____$1 = x0;
if(cljs.core.truth_(and__4149__auto____$1)){
return y0;
} else {
return and__4149__auto____$1;
}
} else {
return and__4149__auto__;
}
})())){
var d = ((2) * radius);
return new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [(x0 - radius),(y0 - radius),d,d], null);
} else {
return console.error("Cannot determine bounding box",sh);

}
}
});
gauge.bitmap_canvas_drag = rum.core.lazy_build(rum.core.build_defc,(function (bmap,ix,iy,k){
var cref = rum.core.create_ref();
var vec__45588 = rum.core.use_state(cljs.core.PersistentArrayMap.EMPTY);
var map__45591 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45588,(0),null);
var map__45591__$1 = cljs.core.__destructure_map(map__45591);
var drag_state = map__45591__$1;
var x = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45591__$1,new cljs.core.Keyword(null,"x","x",2099068185));
var y = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45591__$1,new cljs.core.Keyword(null,"y","y",-1757859776));
var mousedown = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45591__$1,new cljs.core.Keyword(null,"mousedown","mousedown",1391242074));
var set_drag_state_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45588,(1),null);
var pos_top = [cljs.core.str.cljs$core$IFn$_invoke$arity$1((function (){var or__4160__auto__ = y;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return iy;
}
})()),"px"].join('');
var pos_left = [cljs.core.str.cljs$core$IFn$_invoke$arity$1((function (){var or__4160__auto__ = x;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return ix;
}
})()),"px"].join('');
var scaled_x = Math.round(((((function (){var or__4160__auto__ = x;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return ix;
}
})() / gauge.disp_scale) + (0.5 * bmap.width)) / gauge.draw_scale));
var scaled_y = Math.round(((((function (){var or__4160__auto__ = y;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return iy;
}
})() / gauge.disp_scale) + (0.5 * bmap.height)) / gauge.draw_scale));
rum.core.use_effect_BANG_.cljs$core$IFn$_invoke$arity$2((function (){
var cvs = rum.core.deref(cref);
var ctx = cvs.getContext("2d");
ctx.clearRect((0),(0),bmap.width,bmap.height);

return ctx.drawImage(bmap,(0),(0));
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [bmap], null));

return React.createElement(React.Fragment,null,(cljs.core.truth_(mousedown)?daiquiri.core.create_element("div",{'style':{'position':"absolute",'top':pos_top,'left':pos_left}},[[cljs.core.str.cljs$core$IFn$_invoke$arity$1(scaled_x),",",cljs.core.str.cljs$core$IFn$_invoke$arity$1(scaled_y)].join('')]):null),daiquiri.core.create_element("canvas",{'ref':cref,'width':bmap.width,'height':bmap.height,'style':{'position':"absolute",'width':(gauge.disp_scale * bmap.width),'height':(gauge.disp_scale * bmap.height),'outline':((cljs.core.not(mousedown))?"none":"1px solid #fff"),'top':pos_top,'left':pos_left,'zIndex':(cljs.core.truth_(mousedown)?(998):(0)),'userSelect':(cljs.core.truth_(mousedown)?"none":"auto")},'onMouseDown':(function (ev){
var ox = ev.nativeEvent.offsetX;
var oy = ev.nativeEvent.offsetY;
var cx = ev.clientX;
var cy = ev.clientY;
var G__45595 = cljs.core.assoc.cljs$core$IFn$_invoke$arity$variadic(drag_state,new cljs.core.Keyword(null,"mousedown","mousedown",1391242074),true,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"xinit","xinit",-1753302739),cx,new cljs.core.Keyword(null,"yinit","yinit",-1295274386),cy], 0));
return (set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1(G__45595) : set_drag_state_BANG_.call(null,G__45595));
}),'onMouseMove':(function (ev){
if(cljs.core.truth_(mousedown)){
var dx = (new cljs.core.Keyword(null,"xinit","xinit",-1753302739).cljs$core$IFn$_invoke$arity$1(drag_state) - ev.clientX);
var dy = (new cljs.core.Keyword(null,"yinit","yinit",-1295274386).cljs$core$IFn$_invoke$arity$1(drag_state) - ev.clientY);
var G__45596 = cljs.core.assoc.cljs$core$IFn$_invoke$arity$variadic(drag_state,new cljs.core.Keyword(null,"x","x",2099068185),(ev.target.offsetLeft - dx),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"y","y",-1757859776),(ev.target.offsetTop - dy),new cljs.core.Keyword(null,"xinit","xinit",-1753302739),ev.clientX,new cljs.core.Keyword(null,"yinit","yinit",-1295274386),ev.clientY], 0));
return (set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1(G__45596) : set_drag_state_BANG_.call(null,G__45596));
} else {
return null;
}
}),'onMouseUp':(function (ev){
var G__45597_45910 = cljs.core.assoc.cljs$core$IFn$_invoke$arity$variadic(drag_state,new cljs.core.Keyword(null,"mousedown","mousedown",1391242074),null,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"x","x",2099068185),null,new cljs.core.Keyword(null,"y","y",-1757859776),null], 0));
(set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_drag_state_BANG_.cljs$core$IFn$_invoke$arity$1(G__45597_45910) : set_drag_state_BANG_.call(null,G__45597_45910));

if(cljs.core.truth_((function (){var and__4149__auto__ = x;
if(cljs.core.truth_(and__4149__auto__)){
return y;
} else {
return and__4149__auto__;
}
})())){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$variadic(gauge.db,cljs.core.update_in,k,cljs.core.update,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"params","params",710516235),cljs.core.assoc,"x0",scaled_x,"y0",scaled_y], 0));
} else {
return null;
}
})},[]));
}),null,"gauge/bitmap-canvas-drag");
gauge.render_gauge_STAR_ = (function gauge$render_gauge_STAR_(var_args){
var G__45599 = arguments.length;
switch (G__45599) {
case 1:
return gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1 = (function (i){
return gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$2(i,gauge.draw_scale);
}));

(gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$2 = (function (i,scl){
var vec__45600 = gauge.shape__GT_bbox(i);
var x = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45600,(0),null);
var y = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45600,(1),null);
var w = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45600,(2),null);
var h = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45600,(3),null);
var bbox = vec__45600;
var c = (function (){var G__45603 = document.createElement("canvas");
(G__45603["width"] = (w * scl));

(G__45603["height"] = (h * scl));

return G__45603;
})();
var ctx = (function (){var G__45604 = c.getContext("2d");
G__45604.scale(scl,scl);

G__45604.translate((- x),(- y));

return G__45604;
})();
try{renderGauge(ctx,cljs.core.clj__GT_js(i));
}catch (e45605){var ex_45912 = e45605;
console.log("Render exception",ex_45912);
}
return new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926),c,new cljs.core.Keyword(null,"params","params",710516235),i], null);
}));

(gauge.render_gauge_STAR_.cljs$lang$maxFixedArity = 2);

gauge.static_bitmap_canvas = rum.core.lazy_build(rum.core.build_defc,(function (bmap){
var cref = rum.core.create_ref();
rum.core.use_effect_BANG_.cljs$core$IFn$_invoke$arity$2((function (){
if(cljs.core.truth_(rum.core.deref(cref))){
var cvs = rum.core.deref(cref);
var ctx = cvs.getContext("2d");
ctx.clearRect((0),(0),bmap.width,bmap.height);

return ctx.drawImage(bmap,(0),(0));
} else {
return null;
}
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [bmap], null));

return daiquiri.core.create_element("canvas",{'ref':cref,'width':bmap.width,'height':bmap.height},[]);
}),null,"gauge/static-bitmap-canvas");
gauge.update_gauge_STAR_ = (function gauge$update_gauge_STAR_(var_args){
var G__45612 = arguments.length;
switch (G__45612) {
case 2:
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 4:
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
var args_arr__4792__auto__ = [];
var len__4771__auto___45914 = arguments.length;
var i__4772__auto___45915 = (0);
while(true){
if((i__4772__auto___45915 < len__4771__auto___45914)){
args_arr__4792__auto__.push((arguments[i__4772__auto___45915]));

var G__45916 = (i__4772__auto___45915 + (1));
i__4772__auto___45915 = G__45916;
continue;
} else {
}
break;
}

var argseq__4793__auto__ = (new cljs.core.IndexedSeq(args_arr__4792__auto__.slice((4)),(0),null));
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]),argseq__4793__auto__);

}
});

(gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$2 = (function (a,f){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(a,(function (av){
return cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([av,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1((function (){var G__45613 = new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(av);
return (f.cljs$core$IFn$_invoke$arity$1 ? f.cljs$core$IFn$_invoke$arity$1(G__45613) : f.call(null,G__45613));
})())], 0));
}));
}));

(gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4 = (function (a,f,k,v){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(a,(function (av){
return cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([av,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1((function (){var G__45614 = new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(av);
var G__45615 = k;
var G__45616 = v;
return (f.cljs$core$IFn$_invoke$arity$3 ? f.cljs$core$IFn$_invoke$arity$3(G__45614,G__45615,G__45616) : f.call(null,G__45614,G__45615,G__45616));
})())], 0));
}));
}));

(gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$variadic = (function (a,f,k,v,more){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(a,(function (av){
return cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([av,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(cljs.core.apply.cljs$core$IFn$_invoke$arity$3(f,new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(av),cljs.core.list_STAR_.cljs$core$IFn$_invoke$arity$3(k,v,more)))], 0));
}));
}));

/** @this {Function} */
(gauge.update_gauge_STAR_.cljs$lang$applyTo = (function (seq45607){
var G__45608 = cljs.core.first(seq45607);
var seq45607__$1 = cljs.core.next(seq45607);
var G__45609 = cljs.core.first(seq45607__$1);
var seq45607__$2 = cljs.core.next(seq45607__$1);
var G__45610 = cljs.core.first(seq45607__$2);
var seq45607__$3 = cljs.core.next(seq45607__$2);
var G__45611 = cljs.core.first(seq45607__$3);
var seq45607__$4 = cljs.core.next(seq45607__$3);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__45608,G__45609,G__45610,G__45611,seq45607__$4);
}));

(gauge.update_gauge_STAR_.cljs$lang$maxFixedArity = (4));

gauge.gaugeparam_slider = rum.core.lazy_build(rum.core.build_defc,(function (da,k,props){
var map__45617 = rum.core.react(da);
var map__45617__$1 = cljs.core.__destructure_map(map__45617);
var d = map__45617__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45617__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("span",{'style':{'display':"inline-grid",'gridTemplateColumns':"1fr 5fr",'columnGap':"1ch",'alignItems':"center",'justifyContent':"space-between",'width':"100%"}},[daiquiri.core.create_element("span",null,[cljs.core.str.cljs$core$IFn$_invoke$arity$1(v)]),(function (){var attrs45618 = cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.PersistentArrayMap(null, 5, [new cljs.core.Keyword(null,"type","type",1174270348),"range",new cljs.core.Keyword(null,"min","min",444991522),(0),new cljs.core.Keyword(null,"max","max",61366548),(100),new cljs.core.Keyword(null,"value","value",305978217),(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (0);
}
})(),new cljs.core.Keyword(null,"onChange","onChange",-312891301),(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,parseFloat(ev.target.value));
})], null),props], 0));
return daiquiri.core.create_element("input",((cljs.core.map_QMARK_(attrs45618))?daiquiri.interpreter.element_attributes(attrs45618):null),((cljs.core.map_QMARK_(attrs45618))?null:[daiquiri.interpreter.interpret(attrs45618)]));
})()]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-slider");
gauge.gaugeparam_text = rum.core.lazy_build(rum.core.build_defc,(function (da,k){
var map__45619 = rum.core.react(da);
var map__45619__$1 = cljs.core.__destructure_map(map__45619);
var d = map__45619__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45619__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("input",{'type':"text",'value':(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "";
}
})(),'onChange':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,ev.target.value);
})},[]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-text");
gauge.font_size_options = new cljs.core.PersistentVector(null, 6, 5, cljs.core.PersistentVector.EMPTY_NODE, ["Mini","Normal","Bold","Big","Maxi","None"], null);
gauge.gaugeparam_fontsize = rum.core.lazy_build(rum.core.build_defc,(function (da,k){
var map__45620 = rum.core.react(da);
var map__45620__$1 = cljs.core.__destructure_map(map__45620);
var d = map__45620__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45620__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("select",{'value':(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "Mini";
}
})(),'style':{'width':"8em",'justifySelf':"end"},'onChange':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,ev.target.value);
})},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45621(s__45622){
return (new cljs.core.LazySeq(null,(function (){
var s__45622__$1 = s__45622;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45622__$1);
if(temp__5804__auto__){
var s__45622__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45622__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45622__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45624 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45623 = (0);
while(true){
if((i__45623 < size__4563__auto__)){
var fs = cljs.core._nth(c__4562__auto__,i__45623);
cljs.core.chunk_append(b__45624,daiquiri.core.create_element("option",{'key':fs,'value':fs},[daiquiri.interpreter.interpret(fs)]));

var G__45917 = (i__45623 + (1));
i__45623 = G__45917;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45624),gauge$iter__45621(cljs.core.chunk_rest(s__45622__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45624),null);
}
} else {
var fs = cljs.core.first(s__45622__$2);
return cljs.core.cons(daiquiri.core.create_element("option",{'key':fs,'value':fs},[daiquiri.interpreter.interpret(fs)]),gauge$iter__45621(cljs.core.rest(s__45622__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gauge.font_size_options);
})())]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-fontsize");
gauge.gaugeparam_select = rum.core.lazy_build(rum.core.build_defc,(function (da,k,p__45625){
var map__45626 = p__45625;
var map__45626__$1 = cljs.core.__destructure_map(map__45626);
var options = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45626__$1,"options");
var def = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45626__$1,"def");
var map__45627 = rum.core.react(da);
var map__45627__$1 = cljs.core.__destructure_map(map__45627);
var d = map__45627__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45627__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("select",{'value':(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return def;
}
})(),'style':{'width':"12em",'justifySelf':"end"},'onChange':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,ev.target.value);
})},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45628(s__45629){
return (new cljs.core.LazySeq(null,(function (){
var s__45629__$1 = s__45629;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45629__$1);
if(temp__5804__auto__){
var s__45629__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45629__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45629__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45631 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45630 = (0);
while(true){
if((i__45630 < size__4563__auto__)){
var o = cljs.core._nth(c__4562__auto__,i__45630);
cljs.core.chunk_append(b__45631,((typeof o === 'string')?daiquiri.core.create_element("option",{'key':o,'value':o},[o]):(function (){var map__45632 = o;
var map__45632__$1 = cljs.core.__destructure_map(map__45632);
var value = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45632__$1,"value");
var label = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45632__$1,"label");
return daiquiri.core.create_element("option",{'key':value,'value':value},[daiquiri.interpreter.interpret(label)]);
})()));

var G__45918 = (i__45630 + (1));
i__45630 = G__45918;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45631),gauge$iter__45628(cljs.core.chunk_rest(s__45629__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45631),null);
}
} else {
var o = cljs.core.first(s__45629__$2);
return cljs.core.cons(((typeof o === 'string')?daiquiri.core.create_element("option",{'key':o,'value':o},[o]):(function (){var map__45633 = o;
var map__45633__$1 = cljs.core.__destructure_map(map__45633);
var value = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45633__$1,"value");
var label = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45633__$1,"label");
return daiquiri.core.create_element("option",{'key':value,'value':value},[daiquiri.interpreter.interpret(label)]);
})()),gauge$iter__45628(cljs.core.rest(s__45629__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(options);
})())]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-select");
gauge.float_input = rum.core.lazy_build(rum.core.build_defc,(function (p__45634){
var map__45635 = p__45634;
var map__45635__$1 = cljs.core.__destructure_map(map__45635);
var value = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45635__$1,new cljs.core.Keyword(null,"value","value",305978217));
var on_change = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45635__$1,new cljs.core.Keyword(null,"on-change","on-change",-732046149));
var decimal_places = cljs.core.get.cljs$core$IFn$_invoke$arity$3(map__45635__$1,new cljs.core.Keyword(null,"decimal-places","decimal-places",1888767501),(2));
var vec__45636 = rum.core.use_state(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"text","text",-1790561697),value,new cljs.core.Keyword(null,"valid","valid",155614240),true], null));
var map__45639 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45636,(0),null);
var map__45639__$1 = cljs.core.__destructure_map(map__45639);
var st = map__45639__$1;
var text = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45639__$1,new cljs.core.Keyword(null,"text","text",-1790561697));
var valid = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45639__$1,new cljs.core.Keyword(null,"valid","valid",155614240));
var set_st_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45636,(1),null);
rum.core.use_effect_BANG_.cljs$core$IFn$_invoke$arity$2((function (){
var fx_45919 = value.toFixed(decimal_places);
var nv_45920 = parseFloat(fx_45919);
var d_45921 = (nv_45920 - parseFloat(text));
if(cljs.core.truth_((function (){var or__4160__auto__ = isNaN(d_45921);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (Math.abs(d_45921) > (1.0 / Math.pow((10),decimal_places)));
}
})())){
var G__45640_45922 = new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"valid","valid",155614240),true,new cljs.core.Keyword(null,"text","text",-1790561697),clojure.string.replace(clojure.string.replace(fx_45919,/\.0+$/,""),/00+$/,"")], null);
(set_st_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_st_BANG_.cljs$core$IFn$_invoke$arity$1(G__45640_45922) : set_st_BANG_.call(null,G__45640_45922));
} else {
}

return null;
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [value], null));

return daiquiri.core.create_element("input",{'type':"text",'value':text,'style':{'outline':(cljs.core.truth_(valid)?"unset":"2px solid tomato")},'onChange':(function (ev){
var n = parseFloat(ev.target.value);
var v_QMARK_ = cljs.core.not(isNaN(n));
var G__45641_45923 = new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"text","text",-1790561697),ev.target.value,new cljs.core.Keyword(null,"valid","valid",155614240),v_QMARK_], null);
(set_st_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_st_BANG_.cljs$core$IFn$_invoke$arity$1(G__45641_45923) : set_st_BANG_.call(null,G__45641_45923));

if(v_QMARK_){
return (on_change.cljs$core$IFn$_invoke$arity$1 ? on_change.cljs$core$IFn$_invoke$arity$1(n) : on_change.call(null,n));
} else {
return null;
}
})},[]);
}),null,"gauge/float-input");
gauge.gaugeparam_plusminus = rum.core.lazy_build(rum.core.build_defc,(function (da,k,p__45643){
var map__45644 = p__45643;
var map__45644__$1 = cljs.core.__destructure_map(map__45644);
var opts = map__45644__$1;
var d = cljs.core.get.cljs$core$IFn$_invoke$arity$3(map__45644__$1,new cljs.core.Keyword(null,"d","d",1972142424),(1));
var map__45645 = rum.core.react(da);
var map__45645__$1 = cljs.core.__destructure_map(map__45645);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45645__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("span",{'className':"plusminus"},[daiquiri.core.create_element("input",{'type':"button",'value':"-",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update_in,k,cljs.core.dec);
})},[]),gauge.float_input(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"value","value",305978217),(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (0);
}
})(),new cljs.core.Keyword(null,"on-change","on-change",-732046149),(function (p1__45642_SHARP_){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,k,p1__45642_SHARP_);
})], null)),daiquiri.core.create_element("input",{'type':"button",'value':"+",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update_in,k,cljs.core.inc);
})},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-plusminus");
gauge.gaugeparam_plusminus_fixed = rum.core.lazy_build(rum.core.build_defc,(function (da,k,p__45647){
var map__45648 = p__45647;
var map__45648__$1 = cljs.core.__destructure_map(map__45648);
var opts = map__45648__$1;
var d = cljs.core.get.cljs$core$IFn$_invoke$arity$3(map__45648__$1,new cljs.core.Keyword(null,"d","d",1972142424),(1));
var map__45649 = rum.core.react(da);
var map__45649__$1 = cljs.core.__destructure_map(map__45649);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45649__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("span",{'className':"plusminus"},[daiquiri.core.create_element("input",{'type':"button",'value':"-",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,k,cljs.core.dec);
})},[]),gauge.float_input(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"value","value",305978217),(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (0);
}
})(),new cljs.core.Keyword(null,"on-change","on-change",-732046149),(function (p1__45646_SHARP_){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,p1__45646_SHARP_);
})], null)),daiquiri.core.create_element("input",{'type':"button",'value':"+",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,k,cljs.core.inc);
})},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-plusminus-fixed");
gauge.gaugeparam_color = rum.core.lazy_build(rum.core.build_defc,(function (da,k){
var map__45650 = rum.core.react(da);
var map__45650__$1 = cljs.core.__destructure_map(map__45650);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45650__$1,new cljs.core.Keyword(null,"params","params",710516235));
var v = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,k);
return daiquiri.core.create_element("div",{'style':{'justifySelf':"end",'display':"grid",'alignItems':"center",'columnGap':"2ex",'gridTemplateColumns':"1.5em 8em"}},[((clojure.string.starts_with_QMARK_(k,"#"))?daiquiri.core.create_element("input",{'type':"color",'value':k,'onChange':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,ev.target.value);
})},[]):daiquiri.core.create_element("div",{'style':{'height':"2ex",'width':"4ex",'backgroundColor':v}},[])),daiquiri.core.create_element("input",{'type':"text",'value':(function (){var or__4160__auto__ = v;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "transparent";
}
})(),'onChange':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,k,ev.target.value);
})},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/gaugeparam-color");
gauge.edit_spectrum = rum.core.lazy_build(rum.core.build_defc,(function (da){
var map__45651 = rum.core.react(da);
var map__45651__$1 = cljs.core.__destructure_map(map__45651);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45651__$1,new cljs.core.Keyword(null,"params","params",710516235));
var map__45652 = params;
var map__45652__$1 = cljs.core.__destructure_map(map__45652);
var spectrum = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45652__$1,"spectrum");
var n = cljs.core.count(spectrum);
return daiquiri.core.create_element("div",{'className':"edit-spectrum"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45653(s__45654){
return (new cljs.core.LazySeq(null,(function (){
var s__45654__$1 = s__45654;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45654__$1);
if(temp__5804__auto__){
var xs__6360__auto__ = temp__5804__auto__;
var i = cljs.core.first(xs__6360__auto__);
var iterys__4560__auto__ = ((function (s__45654__$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function gauge$iter__45653_$_iter__45655(s__45656){
return (new cljs.core.LazySeq(null,((function (s__45654__$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (){
var s__45656__$1 = s__45656;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__45656__$1);
if(temp__5804__auto____$1){
var s__45656__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__45656__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45656__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45658 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45657 = (0);
while(true){
if((i__45657 < size__4563__auto__)){
var t = cljs.core._nth(c__4562__auto__,i__45657);
var color = cljs.core.nth.cljs$core$IFn$_invoke$arity$2(spectrum,i);
cljs.core.chunk_append(b__45658,(function (){var G__45659 = t;
var G__45659__$1 = (((G__45659 instanceof cljs.core.Keyword))?G__45659.fqn:null);
switch (G__45659__$1) {
case "swatch":
if(clojure.string.starts_with_QMARK_(color,"#")){
return daiquiri.core.create_element("input",{'type':"color",'value':color,'key':["cc",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'onChange':((function (i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, ["spectrum",i], null),ev.target.value);
});})(i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
},[]);
} else {
return daiquiri.core.create_element("span",{'key':["w",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'style':{'height':"2ex",'alignSelf':"center",'width':"4ex",'backgroundColor':color}},[]);
}

break;
case "label":
return daiquiri.core.create_element("input",{'type':"text",'key':["c",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':color,'onChange':((function (i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, ["spectrum",i], null),ev.target.value);
});})(i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
},[]);

break;
case "delete":
return daiquiri.core.create_element("input",{'type':"button",'value':"-",'key':["d",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'disabled':(n < (2)),'onClick':((function (i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,"spectrum",((function (i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (v){
if((n < (2))){
return v;
} else {
return cljs.core.vec(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(cljs.core.take.cljs$core$IFn$_invoke$arity$2(i,v),cljs.core.drop.cljs$core$IFn$_invoke$arity$2((i + (1)),v)));
}
});})(i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
);
});})(i__45657,s__45654__$1,G__45659,G__45659__$1,color,t,c__4562__auto__,size__4563__auto__,b__45658,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
,'className':"delete-button"},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45659__$1)].join('')));

}
})());

var G__45925 = (i__45657 + (1));
i__45657 = G__45925;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45658),gauge$iter__45653_$_iter__45655(cljs.core.chunk_rest(s__45656__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45658),null);
}
} else {
var t = cljs.core.first(s__45656__$2);
var color = cljs.core.nth.cljs$core$IFn$_invoke$arity$2(spectrum,i);
return cljs.core.cons((function (){var G__45660 = t;
var G__45660__$1 = (((G__45660 instanceof cljs.core.Keyword))?G__45660.fqn:null);
switch (G__45660__$1) {
case "swatch":
if(clojure.string.starts_with_QMARK_(color,"#")){
return daiquiri.core.create_element("input",{'type':"color",'value':color,'key':["cc",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'onChange':((function (s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, ["spectrum",i], null),ev.target.value);
});})(s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
},[]);
} else {
return daiquiri.core.create_element("span",{'key':["w",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'style':{'height':"2ex",'alignSelf':"center",'width':"4ex",'backgroundColor':color}},[]);
}

break;
case "label":
return daiquiri.core.create_element("input",{'type':"text",'key':["c",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':color,'onChange':((function (s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, ["spectrum",i], null),ev.target.value);
});})(s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
},[]);

break;
case "delete":
return daiquiri.core.create_element("input",{'type':"button",'value':"-",'key':["d",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'disabled':(n < (2)),'onClick':((function (s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,"spectrum",((function (s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n){
return (function (v){
if((n < (2))){
return v;
} else {
return cljs.core.vec(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(cljs.core.take.cljs$core$IFn$_invoke$arity$2(i,v),cljs.core.drop.cljs$core$IFn$_invoke$arity$2((i + (1)),v)));
}
});})(s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
);
});})(s__45654__$1,G__45660,G__45660__$1,color,t,s__45656__$2,temp__5804__auto____$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
,'className':"delete-button"},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45660__$1)].join('')));

}
})(),gauge$iter__45653_$_iter__45655(cljs.core.rest(s__45656__$2)));
}
} else {
return null;
}
break;
}
});})(s__45654__$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
,null,null));
});})(s__45654__$1,i,xs__6360__auto__,temp__5804__auto__,map__45651,map__45651__$1,params,map__45652,map__45652__$1,spectrum,n))
;
var fs__4561__auto__ = cljs.core.seq(iterys__4560__auto__(new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"label","label",1718410804),new cljs.core.Keyword(null,"swatch","swatch",120712170),new cljs.core.Keyword(null,"delete","delete",-1768633620)], null)));
if(fs__4561__auto__){
return cljs.core.concat.cljs$core$IFn$_invoke$arity$2(fs__4561__auto__,gauge$iter__45653(cljs.core.rest(s__45654__$1)));
} else {
var G__45927 = cljs.core.rest(s__45654__$1);
s__45654__$1 = G__45927;
continue;
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$1(n));
})()),daiquiri.core.create_element("input",{'type':"button",'value':"+",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$variadic(da,cljs.core.update,"spectrum",cljs.core.conj,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["red"], 0));
})},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/edit-spectrum");
gauge.edit_colorvals = rum.core.lazy_build(rum.core.build_defc,(function (da){
var map__45661 = rum.core.react(da);
var map__45661__$1 = cljs.core.__destructure_map(map__45661);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45661__$1,new cljs.core.Keyword(null,"params","params",710516235));
var cvs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"colorvals");
var n = cljs.core.count(cvs);
return daiquiri.core.create_element("div",{'className':"colorvals"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45662(s__45663){
return (new cljs.core.LazySeq(null,(function (){
var s__45663__$1 = s__45663;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45663__$1);
if(temp__5804__auto__){
var xs__6360__auto__ = temp__5804__auto__;
var i = cljs.core.first(xs__6360__auto__);
var map__45668 = cljs.core.nth.cljs$core$IFn$_invoke$arity$2(cvs,i);
var map__45668__$1 = cljs.core.__destructure_map(map__45668);
var val = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45668__$1,"val");
var color = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45668__$1,"color");
var minv = ((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(i,(0)))?cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"min"):cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(cvs,(i - (1))),"val"));
var maxv = ((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(i,(n - (1))))?cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"max"):cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(cvs,(i + (1))),"val"));
var iterys__4560__auto__ = ((function (s__45663__$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function gauge$iter__45662_$_iter__45664(s__45665){
return (new cljs.core.LazySeq(null,((function (s__45663__$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (){
var s__45665__$1 = s__45665;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__45665__$1);
if(temp__5804__auto____$1){
var s__45665__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__45665__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45665__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45667 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45666 = (0);
while(true){
if((i__45666 < size__4563__auto__)){
var t = cljs.core._nth(c__4562__auto__,i__45666);
cljs.core.chunk_append(b__45667,(function (){var G__45669 = t;
var G__45669__$1 = (((G__45669 instanceof cljs.core.Keyword))?G__45669.fqn:null);
switch (G__45669__$1) {
case "delete":
return daiquiri.core.create_element("input",{'type':"button",'key':["b",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':"-",'disabled':(n < (2)),'onClick':((function (i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,"colorvals",((function (i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (v){
if((n < (2))){
return v;
} else {
return cljs.core.vec(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(cljs.core.take.cljs$core$IFn$_invoke$arity$2(i,v),cljs.core.drop.cljs$core$IFn$_invoke$arity$2((i + (1)),v)));
}
});})(i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
);
});})(i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
,'className':"delete-button"},[]);

break;
case "range":
return daiquiri.core.create_element("div",{'key':["l",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join('')},[clojure.string.replace(clojure.string.replace(val.toFixed((3)),/\.0+$/,""),/0+$/,"")]);

break;
case "swatch":
return daiquiri.core.create_element("span",{'key':["w",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'style':{'height':"2ex",'width':"4ex",'backgroundColor':color}},[]);

break;
case "label":
return daiquiri.core.create_element("input",{'type':"text",'key':["c",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':color,'onChange':((function (i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, ["colorvals",i,"color"], null),ev.target.value);
});})(i__45666,s__45663__$1,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
},[]);

break;
case "slider":
var map__45670 = params;
var map__45670__$1 = cljs.core.__destructure_map(map__45670);
var max = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45670__$1,"max");
var min = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45670__$1,"min");
var majdivs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45670__$1,"majdivs");
var subdivs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45670__$1,"subdivs");
var step = ((max - min) / (majdivs * subdivs));
return daiquiri.core.create_element("input",{'type':"range",'key':["s",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'min':minv,'max':maxv,'step':step,'value':val,'onChange':((function (i__45666,s__45663__$1,map__45670,map__45670__$1,max,min,majdivs,subdivs,step,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, ["colorvals",i,"val"], null),parseFloat(ev.target.value));
});})(i__45666,s__45663__$1,map__45670,map__45670__$1,max,min,majdivs,subdivs,step,G__45669,G__45669__$1,t,c__4562__auto__,size__4563__auto__,b__45667,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45669__$1)].join('')));

}
})());

var G__45929 = (i__45666 + (1));
i__45666 = G__45929;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45667),gauge$iter__45662_$_iter__45664(cljs.core.chunk_rest(s__45665__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45667),null);
}
} else {
var t = cljs.core.first(s__45665__$2);
return cljs.core.cons((function (){var G__45671 = t;
var G__45671__$1 = (((G__45671 instanceof cljs.core.Keyword))?G__45671.fqn:null);
switch (G__45671__$1) {
case "delete":
return daiquiri.core.create_element("input",{'type':"button",'key':["b",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':"-",'disabled':(n < (2)),'onClick':((function (s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,"colorvals",((function (s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (v){
if((n < (2))){
return v;
} else {
return cljs.core.vec(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(cljs.core.take.cljs$core$IFn$_invoke$arity$2(i,v),cljs.core.drop.cljs$core$IFn$_invoke$arity$2((i + (1)),v)));
}
});})(s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
);
});})(s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
,'className':"delete-button"},[]);

break;
case "range":
return daiquiri.core.create_element("div",{'key':["l",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join('')},[clojure.string.replace(clojure.string.replace(val.toFixed((3)),/\.0+$/,""),/0+$/,"")]);

break;
case "swatch":
return daiquiri.core.create_element("span",{'key':["w",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'style':{'height':"2ex",'width':"4ex",'backgroundColor':color}},[]);

break;
case "label":
return daiquiri.core.create_element("input",{'type':"text",'key':["c",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'value':color,'onChange':((function (s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, ["colorvals",i,"color"], null),ev.target.value);
});})(s__45663__$1,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
},[]);

break;
case "slider":
var map__45672 = params;
var map__45672__$1 = cljs.core.__destructure_map(map__45672);
var max = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45672__$1,"max");
var min = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45672__$1,"min");
var majdivs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45672__$1,"majdivs");
var subdivs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45672__$1,"subdivs");
var step = ((max - min) / (majdivs * subdivs));
return daiquiri.core.create_element("input",{'type':"range",'key':["s",cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)].join(''),'min':minv,'max':maxv,'step':step,'value':val,'onChange':((function (s__45663__$1,map__45672,map__45672__$1,max,min,majdivs,subdivs,step,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n){
return (function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, ["colorvals",i,"val"], null),parseFloat(ev.target.value));
});})(s__45663__$1,map__45672,map__45672__$1,max,min,majdivs,subdivs,step,G__45671,G__45671__$1,t,s__45665__$2,temp__5804__auto____$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45671__$1)].join('')));

}
})(),gauge$iter__45662_$_iter__45664(cljs.core.rest(s__45665__$2)));
}
} else {
return null;
}
break;
}
});})(s__45663__$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
,null,null));
});})(s__45663__$1,map__45668,map__45668__$1,val,color,minv,maxv,i,xs__6360__auto__,temp__5804__auto__,map__45661,map__45661__$1,params,cvs,n))
;
var fs__4561__auto__ = cljs.core.seq(iterys__4560__auto__(new cljs.core.PersistentVector(null, 5, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"label","label",1718410804),new cljs.core.Keyword(null,"swatch","swatch",120712170),new cljs.core.Keyword(null,"range","range",1639692286),new cljs.core.Keyword(null,"slider","slider",-472668865),new cljs.core.Keyword(null,"delete","delete",-1768633620)], null)));
if(fs__4561__auto__){
return cljs.core.concat.cljs$core$IFn$_invoke$arity$2(fs__4561__auto__,gauge$iter__45662(cljs.core.rest(s__45663__$1)));
} else {
var G__45931 = cljs.core.rest(s__45663__$1);
s__45663__$1 = G__45931;
continue;
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$1(n));
})()),daiquiri.core.create_element("input",{'type':"button",'value':"+",'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$variadic(da,cljs.core.update,"colorvals",cljs.core.conj,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.PersistentArrayMap(null, 2, ["color","red","val",cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"max")], null)], 0));
}),'className':"add-arc"},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/edit-colorvals");
gauge.spectrum_or_colorvals = rum.core.lazy_build(rum.core.build_defc,(function (da){
var map__45675 = rum.core.react(da);
var map__45675__$1 = cljs.core.__destructure_map(map__45675);
var d = map__45675__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45675__$1,new cljs.core.Keyword(null,"params","params",710516235));
var map__45676 = params;
var map__45676__$1 = cljs.core.__destructure_map(map__45676);
var kq = map__45676__$1;
var colorvals = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45676__$1,"colorvals");
var spectrum = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45676__$1,"spectrum");
var min = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45676__$1,"min");
var max = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45676__$1,"max");
if(cljs.core.truth_(colorvals)){
return React.createElement(React.Fragment,null,daiquiri.core.create_element("div",{'className':"edit-spectrum-label"},["Manual colors",daiquiri.core.create_element("input",{'type':"button",'value':"Auto",'onClick':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$2(da,(function (p1__45673_SHARP_){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(p1__45673_SHARP_,"colorvals"),"spectrum",(function (){var G__45682 = (function (){var iter__4564__auto__ = (function gauge$iter__45683(s__45684){
return (new cljs.core.LazySeq(null,(function (){
var s__45684__$1 = s__45684;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45684__$1);
if(temp__5804__auto__){
var s__45684__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45684__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45684__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45686 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45685 = (0);
while(true){
if((i__45685 < size__4563__auto__)){
var c = cljs.core._nth(c__4562__auto__,i__45685);
cljs.core.chunk_append(b__45686,cljs.core.get.cljs$core$IFn$_invoke$arity$2(c,"color"));

var G__45932 = (i__45685 + (1));
i__45685 = G__45932;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45686),gauge$iter__45683(cljs.core.chunk_rest(s__45684__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45686),null);
}
} else {
var c = cljs.core.first(s__45684__$2);
return cljs.core.cons(cljs.core.get.cljs$core$IFn$_invoke$arity$2(c,"color"),gauge$iter__45683(cljs.core.rest(s__45684__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(colorvals);
})();
var G__45682__$1 = cljs.core.vec(G__45682)
;
if((max < min)){
return cljs.core.reverse(G__45682__$1);
} else {
return G__45682__$1;
}
})());
}));
})},[])]),gauge.edit_colorvals(da));
} else {
if(cljs.core.truth_(spectrum)){
return React.createElement(React.Fragment,null,daiquiri.core.create_element("div",{'className':"edit-spectrum-label"},["Auto spectrum",daiquiri.core.create_element("input",{'type':"button",'value':"Manual",'onClick':(function (ev){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$2(da,(function (p1__45674_SHARP_){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(p1__45674_SHARP_,"spectrum"),"colorvals",cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(returnColorVals(cljs.core.clj__GT_js(spectrum),cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"min"),cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"max"))));
}));
}),'style':{'marginLeft':"2ex"}},[])]),gauge.edit_spectrum(da));
} else {
return "Malformed gauge";

}
}
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/spectrum-or-colorvals");
gauge.edit_multitext = rum.core.lazy_build(rum.core.build_defcs,(function (p__45687,da){
var map__45688 = p__45687;
var map__45688__$1 = cljs.core.__destructure_map(map__45688);
var cls = map__45688__$1;
var value = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45688__$1,new cljs.core.Keyword("gauge","value","gauge/value",421218936));
var map__45689 = rum.core.react(da);
var map__45689__$1 = cljs.core.__destructure_map(map__45689);
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45689__$1,new cljs.core.Keyword(null,"params","params",710516235));
var map__45690 = params;
var map__45690__$1 = cljs.core.__destructure_map(map__45690);
var text = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45690__$1,"text");
return daiquiri.core.create_element("textarea",{'rows':cljs.core.count(text),'value':(function (){var or__4160__auto__ = cljs.core.not_empty((function (){var G__45692 = value;
if((G__45692 == null)){
return null;
} else {
return cljs.core.deref(G__45692);
}
})());
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return clojure.string.join.cljs$core$IFn$_invoke$arity$2("\n",text);
}
})(),'onChange':(function (ev){
var v = ev.target.value;
var G__45693_45933 = value;
if((G__45693_45933 == null)){
} else {
cljs.core.reset_BANG_(G__45693_45933,v);
}

return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,"text",clojure.string.split.cljs$core$IFn$_invoke$arity$2(v,/\n/));
})},[]);
}),new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive,rum.core.local.cljs$core$IFn$_invoke$arity$2(null,new cljs.core.Keyword("gauge","value","gauge/value",421218936))], null),"gauge/edit-multitext");
gauge.textbox_mode_switcher = rum.core.lazy_build(rum.core.build_defc,(function (da){
var map__45694 = rum.core.react(da);
var map__45694__$1 = cljs.core.__destructure_map(map__45694);
var d = map__45694__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45694__$1,new cljs.core.Keyword(null,"params","params",710516235));
return daiquiri.core.create_element("div",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Line chosen by value",'disabled':cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("sequencedTextBox",cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"type")),'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,"type","sequencedTextBox");
})},[]),daiquiri.core.create_element("input",{'type':"button",'value':"Multi-line",'disabled':((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("stackedTextBox",cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"type")))?true:false),'onClick':(function (){
return gauge.update_gauge_STAR_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,"type","stackedTextBox");
})},[])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/textbox-mode-switcher");
gauge.gauge_editor_map = cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(setupWidgets());
gauge.type__GT_fields = (function gauge$type__GT_fields(t){
var fs_QMARK_ = cljs.core.get.cljs$core$IFn$_invoke$arity$2(gauge.gauge_editor_map,t);
var fs = (((!(typeof fs_QMARK_ === 'string')))?fs_QMARK_:cljs.core.get.cljs$core$IFn$_invoke$arity$2(gauge.gauge_editor_map,fs_QMARK_));
if(cljs.core.truth_(fs)){
} else {
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2(["Don't know about ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(fs_QMARK_)].join(''),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"t","t",-1397832519),t], null));
}

return fs;
});
gauge.gauge_field = rum.core.lazy_build(rum.core.build_defc,(function (da,p__45695){
var map__45696 = p__45695;
var map__45696__$1 = cljs.core.__destructure_map(map__45696);
var key = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45696__$1,"key");
var label = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45696__$1,"label");
var type = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45696__$1,"type");
var props = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45696__$1,"props");
return React.createElement(React.Fragment,null,(cljs.core.truth_(label)?daiquiri.core.create_element("span",null,[daiquiri.interpreter.interpret(label)]):null),(function (){var G__45698 = type;
switch (G__45698) {
case "plusminus":
return gauge.gaugeparam_plusminus_fixed(da,key);

break;
case "fontsize":
return gauge.gaugeparam_fontsize(da,key);

break;
case "slider":
return gauge.gaugeparam_slider(da,key,props);

break;
case "color":
return gauge.gaugeparam_color(da,key);

break;
case "select":
return gauge.gaugeparam_select(da,key,props);

break;
case "multitext":
return gauge.edit_multitext(da);

break;
case "textbox-mode-switcher":
return gauge.textbox_mode_switcher(da);

break;
case "spectrum-or-colorvals":
return gauge.spectrum_or_colorvals(da);

break;
default:
console.error("No gauge type:",type);

return null;

}
})());
}),null,"gauge/gauge-field");
gauge.generic_gauge = rum.core.lazy_build(rum.core.build_defc,(function (da){
var map__45699 = rum.core.react(da);
var map__45699__$1 = cljs.core.__destructure_map(map__45699);
var d = map__45699__$1;
var params = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45699__$1,new cljs.core.Keyword(null,"params","params",710516235));
var ty = cljs.core.get.cljs$core$IFn$_invoke$arity$2(params,"type");
var fs = gauge.type__GT_fields(ty);
if(cljs.core.seq(fs)){
} else {
console.error("Cannot get field list",params);
}

return React.createElement(React.Fragment,null,cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45704(s__45705){
return (new cljs.core.LazySeq(null,(function (){
var s__45705__$1 = s__45705;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45705__$1);
if(temp__5804__auto__){
var s__45705__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45705__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45705__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45707 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45706 = (0);
while(true){
if((i__45706 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__45706);
cljs.core.chunk_append(b__45707,rum.core.with_key(gauge.gauge_field(da,cljs.core.nth.cljs$core$IFn$_invoke$arity$2(fs,i)),i));

var G__45935 = (i__45706 + (1));
i__45706 = G__45935;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45707),gauge$iter__45704(cljs.core.chunk_rest(s__45705__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45707),null);
}
} else {
var i = cljs.core.first(s__45705__$2);
return cljs.core.cons(rum.core.with_key(gauge.gauge_field(da,cljs.core.nth.cljs$core$IFn$_invoke$arity$2(fs,i)),i),gauge$iter__45704(cljs.core.rest(s__45705__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$1(cljs.core.count(fs)));
})()));
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/generic-gauge");
gauge.onegauge_editor = rum.core.lazy_build(rum.core.build_defc,(function (da,i){
var d = rum.core.react(da);
var x0 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),"x0");
var y0 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),"y0");
var val = cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),"value");
return daiquiri.core.create_element("div",{'className':"onegauge"},[daiquiri.interpreter.interpret((function (){var temp__5804__auto__ = new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926).cljs$core$IFn$_invoke$arity$1(d);
if(cljs.core.truth_(temp__5804__auto__)){
var bmap = temp__5804__auto__;
return gauge.static_bitmap_canvas(bmap);
} else {
return null;
}
})()),daiquiri.core.create_element("div",{'className':"sliders"},[daiquiri.core.create_element("span",{'className':"slider-label"},["Label"]),gauge.gaugeparam_text(da,"label"),daiquiri.core.create_element("span",{'className':"slider-label"},["X"]),gauge.gaugeparam_slider(da,"x0",new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"min","min",444991522),(0),new cljs.core.Keyword(null,"max","max",61366548),gauge.screen_width], null)),daiquiri.core.create_element("span",{'className':"slider-label"},["Y"]),gauge.gaugeparam_slider(da,"y0",new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"min","min",444991522),(0),new cljs.core.Keyword(null,"max","max",61366548),gauge.screen_height], null)),(cljs.core.truth_(val)?daiquiri.core.create_element("span",{'className':"slider-label"},["Value"]):null),(cljs.core.truth_(val)?(function (){var map__45716 = new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d);
var map__45716__$1 = cljs.core.__destructure_map(map__45716);
var type = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45716__$1,"type");
var min = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45716__$1,"min");
var max = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45716__$1,"max");
var G__45717 = type;
switch (G__45717) {
case "textBox":
case "rawText":
case "sequencedTextBox":
case "stackedTextBox":
return gauge.gaugeparam_plusminus(da,new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, ["value"], null));

break;
default:
var real_min = (function (){var x__4252__auto__ = min;
var y__4253__auto__ = max;
return ((x__4252__auto__ < y__4253__auto__) ? x__4252__auto__ : y__4253__auto__);
})();
var real_max = (function (){var x__4249__auto__ = min;
var y__4250__auto__ = max;
return ((x__4249__auto__ > y__4250__auto__) ? x__4249__auto__ : y__4250__auto__);
})();
return gauge.gaugeparam_slider(da,"value",new cljs.core.PersistentArrayMap(null, 3, [new cljs.core.Keyword(null,"min","min",444991522),real_min,new cljs.core.Keyword(null,"max","max",61366548),real_max,new cljs.core.Keyword(null,"step","step",1288888124),(0.01 * (real_max - real_min))], null));

}
})():null)]),daiquiri.core.create_element("div",{'className':"controls"},[daiquiri.core.create_element("input",{'type':"button",'value':((cljs.core.not(new cljs.core.Keyword(null,"editing","editing",1365491601).cljs$core$IFn$_invoke$arity$1(d)))?"Edit":"Finish"),'onClick':(function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.update,new cljs.core.Keyword(null,"editing","editing",1365491601),cljs.core.not);
})},[]),daiquiri.core.create_element("input",{'type':"button",'value':"Duplicate",'onClick':(function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.update_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)),new cljs.core.Keyword(null,"gauges","gauges",-962432914)], null),(function (gs){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(gs,cljs.core.count(gs),d);
}));
})},[]),daiquiri.core.create_element("input",{'type':"button",'value':"Delete",'onClick':(function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(da,cljs.core.assoc,new cljs.core.Keyword(null,"deleted","deleted",-510100639),true);
})},[])]),daiquiri.core.create_element("div",{'style':{'gridColumn':"1/4",'width':"100%",'justifyContent':"space-between"},'className':"sliders"},[(cljs.core.truth_(new cljs.core.Keyword(null,"editing","editing",1365491601).cljs$core$IFn$_invoke$arity$1(d))?gauge.generic_gauge(da):null)])]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/onegauge-editor");
gauge.ask_download_file = (function gauge$ask_download_file(path,contents){
var b = (new Blob([contents]));
var u = URL.createObjectURL(b);
var a = document.createElement("a");
(a.href = u);

(a.download = path);

return a.click();
});
gauge.render_panel = (function gauge$render_panel(pdb,w,h){
var c = (function (){var G__45719 = document.createElement("canvas");
(G__45719["width"] = w);

(G__45719["height"] = h);

return G__45719;
})();
var ctx = c.getContext("2d");
var map__45718 = pdb;
var map__45718__$1 = cljs.core.__destructure_map(map__45718);
var gauges = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45718__$1,new cljs.core.Keyword(null,"gauges","gauges",-962432914));
var background_image = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45718__$1,new cljs.core.Keyword(null,"background-image","background-image",-1142314704));
var bg = (cljs.core.truth_(background_image)?(function (){var G__45720 = document.createElement("img");
(G__45720["src"] = background_image);

return G__45720;
})():null);
var _ = (cljs.core.truth_(bg)?ctx.drawImage(bg,(0),(0),w,h):null);
var _PLUS_calc = cljs.core.vec((function (){var iter__4564__auto__ = (function gauge$render_panel_$_iter__45721(s__45722){
return (new cljs.core.LazySeq(null,(function (){
var s__45722__$1 = s__45722;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45722__$1);
if(temp__5804__auto__){
var s__45722__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45722__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45722__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45724 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45723 = (0);
while(true){
if((i__45723 < size__4563__auto__)){
var vec__45725 = cljs.core._nth(c__4562__auto__,i__45723);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45725,(0),null);
var map__45728 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45725,(1),null);
var map__45728__$1 = cljs.core.__destructure_map(map__45728);
var d = map__45728__$1;
var deleted = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45728__$1,new cljs.core.Keyword(null,"deleted","deleted",-510100639));
if(cljs.core.not(deleted)){
cljs.core.chunk_append(b__45724,cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(renderGauge(ctx,cljs.core.clj__GT_js(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$variadic(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),"value",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["label"], 0)))))], 0)));

var G__45937 = (i__45723 + (1));
i__45723 = G__45937;
continue;
} else {
var G__45938 = (i__45723 + (1));
i__45723 = G__45938;
continue;
}
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45724),gauge$render_panel_$_iter__45721(cljs.core.chunk_rest(s__45722__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45724),null);
}
} else {
var vec__45729 = cljs.core.first(s__45722__$2);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45729,(0),null);
var map__45732 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45729,(1),null);
var map__45732__$1 = cljs.core.__destructure_map(map__45732);
var d = map__45732__$1;
var deleted = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45732__$1,new cljs.core.Keyword(null,"deleted","deleted",-510100639));
if(cljs.core.not(deleted)){
return cljs.core.cons(cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(renderGauge(ctx,cljs.core.clj__GT_js(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$variadic(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d),"value",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["label"], 0)))))], 0)),gauge$render_panel_$_iter__45721(cljs.core.rest(s__45722__$2)));
} else {
var G__45939 = cljs.core.rest(s__45722__$2);
s__45722__$1 = G__45939;
continue;
}
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gauges);
})());
return (new Promise((function (resolve,reject){
return c.toBlob((function (b){
var G__45733 = new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"image","image",-58725096),b,new cljs.core.Keyword(null,"data","data",-232669377),_PLUS_calc], null);
return (resolve.cljs$core$IFn$_invoke$arity$1 ? resolve.cljs$core$IFn$_invoke$arity$1(G__45733) : resolve.call(null,G__45733));
}),"png");
})));
});
gauge.download_json_BANG_ = (function gauge$download_json_BANG_(w,h){
return gauge.render_panel(cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"panels","panels",801034044).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)),cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(gauge.db),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866))),w,h).then((function (p__45734){
var map__45735 = p__45734;
var map__45735__$1 = cljs.core.__destructure_map(map__45735);
var data = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45735__$1,new cljs.core.Keyword(null,"data","data",-232669377));
gauge.ask_download_file("gauges.json",JSON.stringify(cljs.core.clj__GT_js(data),null,(2)));

return gauge.ask_download_file("gauges.new.json",JSON.stringify(cljs.core.clj__GT_js(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"panel","panel",-558637456),data,new cljs.core.Keyword(null,"timestamp","timestamp",579478971),(new Date()).toISOString()], null)),null,(2)));
}));
});
gauge.download_png_BANG_ = (function gauge$download_png_BANG_(w,h){
return gauge.render_panel(cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"panels","panels",801034044).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)),cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(gauge.db),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866))),w,h).then((function (p__45736){
var map__45737 = p__45736;
var map__45737__$1 = cljs.core.__destructure_map(map__45737);
var image = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45737__$1,new cljs.core.Keyword(null,"image","image",-58725096));
return gauge.ask_download_file("gauges.png",image);
}));
});
gauge.blob__GT_base64 = (function gauge$blob__GT_base64(v){
return (new Promise((function (resolve,reject){
var fr = (function (){var G__45738 = (new FileReader());
G__45738.readAsDataURL(v);

return G__45738;
})();
(fr.error = reject);

return (fr.onloadend = (function (){
var G__45739 = fr.result;
return (resolve.cljs$core$IFn$_invoke$arity$1 ? resolve.cljs$core$IFn$_invoke$arity$1(G__45739) : resolve.call(null,G__45739));
}));
})));
});
gauge.make_dynamic_repo_request_STAR_ = (function gauge$make_dynamic_repo_request_STAR_(w,h){
return Promise.all(cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$make_dynamic_repo_request_STAR__$_iter__45740(s__45741){
return (new cljs.core.LazySeq(null,(function (){
var s__45741__$1 = s__45741;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45741__$1);
if(temp__5804__auto__){
var s__45741__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45741__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45741__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45743 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45742 = (0);
while(true){
if((i__45742 < size__4563__auto__)){
var vec__45744 = cljs.core._nth(c__4562__auto__,i__45742);
var panel_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45744,(0),null);
var panel = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45744,(1),null);
cljs.core.chunk_append(b__45743,gauge.render_panel(panel,w,h).then(((function (i__45742,vec__45744,panel_name,panel,c__4562__auto__,size__4563__auto__,b__45743,s__45741__$2,temp__5804__auto__){
return (function (p__45747){
var map__45748 = p__45747;
var map__45748__$1 = cljs.core.__destructure_map(map__45748);
var image = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45748__$1,new cljs.core.Keyword(null,"image","image",-58725096));
var data = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45748__$1,new cljs.core.Keyword(null,"data","data",-232669377));
return gauge.blob__GT_base64(image).then(((function (i__45742,map__45748,map__45748__$1,image,data,vec__45744,panel_name,panel,c__4562__auto__,size__4563__auto__,b__45743,s__45741__$2,temp__5804__auto__){
return (function (base){
return [new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".json"].join(''),new cljs.core.Keyword(null,"json-data","json-data",1378482923),cljs.core.clj__GT_js(data)], null),new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".new.json"].join(''),new cljs.core.Keyword(null,"json-data","json-data",1378482923),cljs.core.clj__GT_js(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"panel","panel",-558637456),data,new cljs.core.Keyword(null,"timestamp","timestamp",579478971),(new Date()).toISOString()], null))], null),new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".png"].join(''),new cljs.core.Keyword(null,"data-base64","data-base64",-716212948),cljs.core.subs.cljs$core$IFn$_invoke$arity$2(base,(("data:image/png;base64,").length))], null)];
});})(i__45742,map__45748,map__45748__$1,image,data,vec__45744,panel_name,panel,c__4562__auto__,size__4563__auto__,b__45743,s__45741__$2,temp__5804__auto__))
);
});})(i__45742,vec__45744,panel_name,panel,c__4562__auto__,size__4563__auto__,b__45743,s__45741__$2,temp__5804__auto__))
));

var G__45940 = (i__45742 + (1));
i__45742 = G__45940;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45743),gauge$make_dynamic_repo_request_STAR__$_iter__45740(cljs.core.chunk_rest(s__45741__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45743),null);
}
} else {
var vec__45749 = cljs.core.first(s__45741__$2);
var panel_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45749,(0),null);
var panel = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45749,(1),null);
return cljs.core.cons(gauge.render_panel(panel,w,h).then(((function (vec__45749,panel_name,panel,s__45741__$2,temp__5804__auto__){
return (function (p__45752){
var map__45753 = p__45752;
var map__45753__$1 = cljs.core.__destructure_map(map__45753);
var image = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45753__$1,new cljs.core.Keyword(null,"image","image",-58725096));
var data = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45753__$1,new cljs.core.Keyword(null,"data","data",-232669377));
return gauge.blob__GT_base64(image).then((function (base){
return [new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".json"].join(''),new cljs.core.Keyword(null,"json-data","json-data",1378482923),cljs.core.clj__GT_js(data)], null),new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".new.json"].join(''),new cljs.core.Keyword(null,"json-data","json-data",1378482923),cljs.core.clj__GT_js(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"panel","panel",-558637456),data,new cljs.core.Keyword(null,"timestamp","timestamp",579478971),(new Date()).toISOString()], null))], null),new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"destination","destination",-253872483),["Apps/DFM-InsP/Panels/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name),".png"].join(''),new cljs.core.Keyword(null,"data-base64","data-base64",-716212948),cljs.core.subs.cljs$core$IFn$_invoke$arity$2(base,(("data:image/png;base64,").length))], null)];
}));
});})(vec__45749,panel_name,panel,s__45741__$2,temp__5804__auto__))
),gauge$make_dynamic_repo_request_STAR__$_iter__45740(cljs.core.rest(s__45741__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(new cljs.core.Keyword(null,"panels","panels",801034044).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)));
})()));
});
gauge.make_dynamic_repo_request = (function gauge$make_dynamic_repo_request(w,h){
return gauge.make_dynamic_repo_request_STAR_(w,h).then((function (filesets){
return cljs.core.clj__GT_js(new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"yoururl","yoururl",688425964),window.location.origin,new cljs.core.Keyword(null,"dynamic-files","dynamic-files",-858256203),new cljs.core.PersistentArrayMap(null, 1, ["Gauges",cljs.core.into.cljs$core$IFn$_invoke$arity$3(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"app","app",-560961707),"DFM-InsP"], null)], null),cljs.core.cat,filesets)], null)], null));
}));
});
gauge.localstorage_db_key = "gauges-db";
gauge.save_watch_key = new cljs.core.Keyword(null,"save-watch-key","save-watch-key",-598120563);
gauge.encode_edn_string = (function gauge$encode_edn_string(dbval){
return cljs.core.pr_str.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([clojure.walk.prewalk((function (j){
if((!(cljs.core.map_QMARK_(j)))){
return j;
} else {
return cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(j,new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926));
}
}),dbval)], 0));
});
gauge.save_to_localstorage_BANG_ = (function gauge$save_to_localstorage_BANG_(dbval){
return window.localStorage.setItem(gauge.localstorage_db_key,gauge.encode_edn_string(dbval));
});
gauge.restore_db_BANG_ = (function gauge$restore_db_BANG_(saved_db){
return cljs.core.reset_BANG_(gauge.db,cljs.core.update.cljs$core$IFn$_invoke$arity$3(saved_db,new cljs.core.Keyword(null,"panels","panels",801034044),(function (ps){
return cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,(function (){var iter__4564__auto__ = (function gauge$restore_db_BANG__$_iter__45754(s__45755){
return (new cljs.core.LazySeq(null,(function (){
var s__45755__$1 = s__45755;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45755__$1);
if(temp__5804__auto__){
var s__45755__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45755__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45755__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45757 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45756 = (0);
while(true){
if((i__45756 < size__4563__auto__)){
var vec__45758 = cljs.core._nth(c__4562__auto__,i__45756);
var pk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45758,(0),null);
var p = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45758,(1),null);
cljs.core.chunk_append(b__45757,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [pk,cljs.core.update.cljs$core$IFn$_invoke$arity$3(p,new cljs.core.Keyword(null,"gauges","gauges",-962432914),((function (i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__){
return (function (gs){
return cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,(function (){var iter__4564__auto__ = ((function (i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__){
return (function gauge$restore_db_BANG__$_iter__45754_$_iter__45761(s__45762){
return (new cljs.core.LazySeq(null,((function (i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__){
return (function (){
var s__45762__$1 = s__45762;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__45762__$1);
if(temp__5804__auto____$1){
var s__45762__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__45762__$2)){
var c__4562__auto____$1 = cljs.core.chunk_first(s__45762__$2);
var size__4563__auto____$1 = cljs.core.count(c__4562__auto____$1);
var b__45764 = cljs.core.chunk_buffer(size__4563__auto____$1);
if((function (){var i__45763 = (0);
while(true){
if((i__45763 < size__4563__auto____$1)){
var vec__45765 = cljs.core._nth(c__4562__auto____$1,i__45763);
var gk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45765,(0),null);
var g = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45765,(1),null);
cljs.core.chunk_append(b__45764,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [gk,cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([g,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(g))], 0))], null));

var G__45941 = (i__45763 + (1));
i__45763 = G__45941;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45764),gauge$restore_db_BANG__$_iter__45754_$_iter__45761(cljs.core.chunk_rest(s__45762__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45764),null);
}
} else {
var vec__45768 = cljs.core.first(s__45762__$2);
var gk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45768,(0),null);
var g = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45768,(1),null);
return cljs.core.cons(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [gk,cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([g,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(g))], 0))], null),gauge$restore_db_BANG__$_iter__45754_$_iter__45761(cljs.core.rest(s__45762__$2)));
}
} else {
return null;
}
break;
}
});})(i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__))
,null,null));
});})(i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__))
;
return iter__4564__auto__(gs);
})());
});})(i__45756,vec__45758,pk,p,c__4562__auto__,size__4563__auto__,b__45757,s__45755__$2,temp__5804__auto__))
)], null));

var G__45942 = (i__45756 + (1));
i__45756 = G__45942;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45757),gauge$restore_db_BANG__$_iter__45754(cljs.core.chunk_rest(s__45755__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45757),null);
}
} else {
var vec__45771 = cljs.core.first(s__45755__$2);
var pk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45771,(0),null);
var p = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45771,(1),null);
return cljs.core.cons(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [pk,cljs.core.update.cljs$core$IFn$_invoke$arity$3(p,new cljs.core.Keyword(null,"gauges","gauges",-962432914),((function (vec__45771,pk,p,s__45755__$2,temp__5804__auto__){
return (function (gs){
return cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,(function (){var iter__4564__auto__ = (function gauge$restore_db_BANG__$_iter__45754_$_iter__45774(s__45775){
return (new cljs.core.LazySeq(null,(function (){
var s__45775__$1 = s__45775;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__45775__$1);
if(temp__5804__auto____$1){
var s__45775__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__45775__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45775__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45777 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45776 = (0);
while(true){
if((i__45776 < size__4563__auto__)){
var vec__45778 = cljs.core._nth(c__4562__auto__,i__45776);
var gk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45778,(0),null);
var g = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45778,(1),null);
cljs.core.chunk_append(b__45777,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [gk,cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([g,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(g))], 0))], null));

var G__45943 = (i__45776 + (1));
i__45776 = G__45943;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45777),gauge$restore_db_BANG__$_iter__45754_$_iter__45774(cljs.core.chunk_rest(s__45775__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45777),null);
}
} else {
var vec__45781 = cljs.core.first(s__45775__$2);
var gk = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45781,(0),null);
var g = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45781,(1),null);
return cljs.core.cons(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [gk,cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([g,gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(g))], 0))], null),gauge$restore_db_BANG__$_iter__45754_$_iter__45774(cljs.core.rest(s__45775__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gs);
})());
});})(vec__45771,pk,p,s__45755__$2,temp__5804__auto__))
)], null),gauge$restore_db_BANG__$_iter__45754(cljs.core.rest(s__45755__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(ps);
})());
})));
});
gauge.load_from_localstorage_BANG_ = (function gauge$load_from_localstorage_BANG_(){
var temp__5804__auto__ = (function (){var G__45784 = window.localStorage;
var G__45784__$1 = (((G__45784 == null))?null:G__45784.getItem(gauge.localstorage_db_key));
if((G__45784__$1 == null)){
return null;
} else {
return clojure.edn.read_string.cljs$core$IFn$_invoke$arity$1(G__45784__$1);
}
})();
if(cljs.core.truth_(temp__5804__auto__)){
var saved_db = temp__5804__auto__;
return gauge.restore_db_BANG_(saved_db);
} else {
return null;
}
});
gauge.download_edn_BANG_ = (function gauge$download_edn_BANG_(){
return gauge.ask_download_file("panels.edn",gauge.encode_edn_string(cljs.core.deref(gauge.db)));
});
gauge.app_controls = rum.core.lazy_build(rum.core.build_defc,(function (w,h){
return daiquiri.core.create_element("div",null,[daiquiri.core.create_element("div",null,[daiquiri.core.create_element("h4",null,["Background image"]),daiquiri.core.create_element("ul",null,[daiquiri.core.create_element("li",null,[daiquiri.core.create_element("input",{'type':"file",'onChange':(function (ev){
var temp__5804__auto__ = cljs.core.first(ev.target.files);
if(cljs.core.truth_(temp__5804__auto__)){
var f = temp__5804__auto__;
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)),new cljs.core.Keyword(null,"background-image","background-image",-1142314704)], null),URL.createObjectURL(f));
} else {
return null;
}
})},[])]),daiquiri.core.create_element("li",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Clear",'onClick':(function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$variadic(gauge.db,cljs.core.update_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db))], null),cljs.core.dissoc,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"background-image","background-image",-1142314704)], 0));
})},[])])])]),daiquiri.core.create_element("div",null,[daiquiri.core.create_element("h4",null,["Download"]),daiquiri.core.create_element("p",null,["When you are ready to install the Lua app along with all your created panels, ","click here to get the URL to paste into Jeti studio: ",daiquiri.core.create_element("input",{'type':"button",'display':"inline",'value':"Create app source",'onClick':(function (ev){
return gauge.make_dynamic_repo_request(w,h).then(dynamic_repo.send_dynamic_repo_request_BANG_);
}),'className':"dynamic-repo-button"},[])]),daiquiri.core.create_element("p",null,["You can also manually download this panel's configuration data:"]),daiquiri.core.create_element("ul",null,[daiquiri.core.create_element("li",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Download JSON",'onClick':(function (){
return gauge.download_json_BANG_(w,h);
})},[])]),daiquiri.core.create_element("li",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Download PNG",'onClick':(function (){
return gauge.download_png_BANG_(w,h);
})},[])])])]),daiquiri.core.create_element("div",null,[daiquiri.core.create_element("h4",null,["Backup & restore"]),daiquiri.core.create_element("p",null,["Data for ALL panels can be saved to a file and reloaded.  ","Be careful - restoring replaces all your panels!"]),daiquiri.core.create_element("ul",null,[daiquiri.core.create_element("li",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Download EDN backup",'onClick':(function (){
return gauge.download_edn_BANG_();
})},[])]),daiquiri.core.create_element("li",null,[daiquiri.core.create_element("label",null,["Restore",daiquiri.core.create_element("input",{'type':"file",'style':{'marginLeft':"1ch"},'onChange':(function (ev){
var temp__5804__auto__ = cljs.core.first(ev.target.files);
if(cljs.core.truth_(temp__5804__auto__)){
var f = temp__5804__auto__;
var fr = (function (){var G__45795 = (new FileReader());
G__45795.readAsText(f,"utf-8");

return G__45795;
})();
return (fr.onloadend = (function (){
return gauge.restore_db_BANG_(clojure.edn.read_string.cljs$core$IFn$_invoke$arity$1(fr.result));
}));
} else {
return null;
}
}),'className':"delete-button"},[])])])])]),dynamic_repo.repo_result_modal()]);
}),null,"gauge/app-controls");
gauge.reload_json_BANG_ = (function gauge$reload_json_BANG_(panel_name,url){
return fetch(url).then((function (fr){
return fr.json();
})).then((function (jd){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(gauge.db,(function (p1__45796_SHARP_){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(cljs.core.assoc_in(p1__45796_SHARP_,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),panel_name], null),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"gauges","gauges",-962432914),cljs.core.zipmap(cljs.core.range.cljs$core$IFn$_invoke$arity$0(),cljs.core.map.cljs$core$IFn$_invoke$arity$2(gauge.render_gauge_STAR_,cljs.core.js__GT_clj.cljs$core$IFn$_invoke$arity$1(jd)))], null)),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),panel_name);
}));
}));
});
gauge.new_gauge_BANG_ = (function gauge$new_gauge_BANG_(new_gauge_type){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.update_in,new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(gauge.db)),new cljs.core.Keyword(null,"gauges","gauges",-962432914)], null),(function (gs){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(gs,cljs.core.count(gs),cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(gauge.render_gauge_STAR_.cljs$core$IFn$_invoke$arity$1(cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(gauge.config_json,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, ["prototypes",new_gauge_type], null))),new cljs.core.Keyword(null,"editing","editing",1365491601),true));
}));
});
gauge.gauge_list_controls = rum.core.lazy_build(rum.core.build_defc,(function (){
var gauge_types = cljs.core.keys(cljs.core.get.cljs$core$IFn$_invoke$arity$2(gauge.config_json,"prototypes"));
var vec__45797 = rum.core.use_state(cljs.core.first(gauge_types));
var new_gauge_type = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45797,(0),null);
var set_new_gauge_type_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45797,(1),null);
return daiquiri.core.create_element("div",null,[daiquiri.core.create_element("input",{'type':"button",'value':"New",'onClick':(function (){
return gauge.new_gauge_BANG_(new_gauge_type);
})},[]),daiquiri.core.create_element("select",{'value':new_gauge_type,'onChange':(function (ev){
var G__45800 = ev.target.value;
return (set_new_gauge_type_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_new_gauge_type_BANG_.cljs$core$IFn$_invoke$arity$1(G__45800) : set_new_gauge_type_BANG_.call(null,G__45800));
})},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45801(s__45802){
return (new cljs.core.LazySeq(null,(function (){
var s__45802__$1 = s__45802;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45802__$1);
if(temp__5804__auto__){
var s__45802__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45802__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45802__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45804 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45803 = (0);
while(true){
if((i__45803 < size__4563__auto__)){
var gt = cljs.core._nth(c__4562__auto__,i__45803);
cljs.core.chunk_append(b__45804,daiquiri.core.create_element("option",{'key':gt,'value':gt},[daiquiri.interpreter.interpret(gt)]));

var G__45944 = (i__45803 + (1));
i__45803 = G__45944;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45804),gauge$iter__45801(cljs.core.chunk_rest(s__45802__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45804),null);
}
} else {
var gt = cljs.core.first(s__45802__$2);
return cljs.core.cons(daiquiri.core.create_element("option",{'key':gt,'value':gt},[daiquiri.interpreter.interpret(gt)]),gauge$iter__45801(cljs.core.rest(s__45802__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gauge_types);
})())])]);
}),null,"gauge/gauge-list-controls");
gauge.gauge_list = rum.core.lazy_build(rum.core.build_defc,(function (which_panel,gauges){
return daiquiri.core.create_element("div",{'className':"gauge-list"},[gauge.gauge_list_controls(),daiquiri.core.create_element("div",null,[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45805(s__45806){
return (new cljs.core.LazySeq(null,(function (){
var s__45806__$1 = s__45806;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45806__$1);
if(temp__5804__auto__){
var s__45806__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45806__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45806__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45808 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45807 = (0);
while(true){
if((i__45807 < size__4563__auto__)){
var vec__45809 = cljs.core._nth(c__4562__auto__,i__45807);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45809,(0),null);
var map__45812 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45809,(1),null);
var map__45812__$1 = cljs.core.__destructure_map(map__45812);
var d = map__45812__$1;
var deleted = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45812__$1,new cljs.core.Keyword(null,"deleted","deleted",-510100639));
if(cljs.core.not(deleted)){
cljs.core.chunk_append(b__45808,rum.core.with_key(gauge.onegauge_editor(rum.core.cursor_in(gauge.db,new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),which_panel,new cljs.core.Keyword(null,"gauges","gauges",-962432914),i], null)),i),i));

var G__45945 = (i__45807 + (1));
i__45807 = G__45945;
continue;
} else {
var G__45946 = (i__45807 + (1));
i__45807 = G__45946;
continue;
}
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45808),gauge$iter__45805(cljs.core.chunk_rest(s__45806__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45808),null);
}
} else {
var vec__45813 = cljs.core.first(s__45806__$2);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45813,(0),null);
var map__45816 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45813,(1),null);
var map__45816__$1 = cljs.core.__destructure_map(map__45816);
var d = map__45816__$1;
var deleted = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45816__$1,new cljs.core.Keyword(null,"deleted","deleted",-510100639));
if(cljs.core.not(deleted)){
return cljs.core.cons(rum.core.with_key(gauge.onegauge_editor(rum.core.cursor_in(gauge.db,new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),which_panel,new cljs.core.Keyword(null,"gauges","gauges",-962432914),i], null)),i),i),gauge$iter__45805(cljs.core.rest(s__45806__$2)));
} else {
var G__45947 = cljs.core.rest(s__45806__$2);
s__45806__$1 = G__45947;
continue;
}
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gauges);
})())])]);
}),null,"gauge/gauge-list");
gauge.get_panel_unique_name = (function gauge$get_panel_unique_name(proposed){
return cljs.core.first(cljs.core.filter.cljs$core$IFn$_invoke$arity$2((function (){var or__4160__auto__ = (function (){var G__45818 = cljs.core.deref(gauge.db);
var G__45818__$1 = (((G__45818 == null))?null:new cljs.core.Keyword(null,"panels","panels",801034044).cljs$core$IFn$_invoke$arity$1(G__45818));
if((G__45818__$1 == null)){
return null;
} else {
return cljs.core.comp.cljs$core$IFn$_invoke$arity$2(cljs.core.not,G__45818__$1);
}
})();
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (function (){
return true;
});
}
})(),cljs.core.map.cljs$core$IFn$_invoke$arity$3(cljs.core.str,cljs.core.repeat.cljs$core$IFn$_invoke$arity$1(proposed),cljs.core.cons(null,(function (){var iter__4564__auto__ = (function gauge$get_panel_unique_name_$_iter__45819(s__45820){
return (new cljs.core.LazySeq(null,(function (){
var s__45820__$1 = s__45820;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45820__$1);
if(temp__5804__auto__){
var s__45820__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45820__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45820__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45822 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45821 = (0);
while(true){
if((i__45821 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__45821);
cljs.core.chunk_append(b__45822,[" (",cljs.core.str.cljs$core$IFn$_invoke$arity$1((i + (1))),")"].join(''));

var G__45948 = (i__45821 + (1));
i__45821 = G__45948;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45822),gauge$get_panel_unique_name_$_iter__45819(cljs.core.chunk_rest(s__45820__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45822),null);
}
} else {
var i = cljs.core.first(s__45820__$2);
return cljs.core.cons([" (",cljs.core.str.cljs$core$IFn$_invoke$arity$1((i + (1))),")"].join(''),gauge$get_panel_unique_name_$_iter__45819(cljs.core.rest(s__45820__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$0());
})()))));
});
gauge.panel_list_controls = rum.core.lazy_build(rum.core.build_defc,(function (sel,ps){
var vec__45824 = rum.core.use_state("New panel");
var panel_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45824,(0),null);
var set_panel_name_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45824,(1),null);
return daiquiri.core.create_element("div",null,[daiquiri.core.create_element("input",{'type':"button",'value':"Save this panel as:",'onClick':(function (){
var uname = gauge.get_panel_unique_name(panel_name);
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(gauge.db,(function (p1__45823_SHARP_){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(cljs.core.update.cljs$core$IFn$_invoke$arity$5(p1__45823_SHARP_,new cljs.core.Keyword(null,"panels","panels",801034044),cljs.core.assoc,uname,cljs.core.get.cljs$core$IFn$_invoke$arity$2(ps,sel)),new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),uname);
}));
}),'className':"save-panel-button"},[]),daiquiri.core.create_element("input",{'type':"text",'value':panel_name,'onChange':(function (ev){
var G__45827 = ev.target.value;
return (set_panel_name_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_panel_name_BANG_.cljs$core$IFn$_invoke$arity$1(G__45827) : set_panel_name_BANG_.call(null,G__45827));
})},[])]);
}),null,"gauge/panel-list-controls");
gauge.do_panel_rename = (function gauge$do_panel_rename(db,old_name,new_name){
var G__45828 = db;
var G__45828__$1 = cljs.core.update.cljs$core$IFn$_invoke$arity$4(G__45828,new cljs.core.Keyword(null,"panels","panels",801034044),cljs.core.dissoc,old_name)
;
var G__45828__$2 = cljs.core.update.cljs$core$IFn$_invoke$arity$5(G__45828__$1,new cljs.core.Keyword(null,"panels","panels",801034044),cljs.core.assoc,new_name,cljs.core.get.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"panels","panels",801034044).cljs$core$IFn$_invoke$arity$1(db),old_name))
;
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(old_name,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866).cljs$core$IFn$_invoke$arity$1(db))){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__45828__$2,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),new_name);
} else {
return G__45828__$2;
}
});
gauge.panel_renamer = rum.core.lazy_build(rum.core.build_defc,(function (ps,old_name){
var vec__45829 = rum.core.use_state(old_name);
var new_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45829,(0),null);
var set_new_name_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45829,(1),null);
var vec__45832 = rum.core.use_state(true);
var collapse = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45832,(0),null);
var set_collapse_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45832,(1),null);
var taken_QMARK_ = cljs.core.contains_QMARK_(ps,new_name);
if(cljs.core.truth_(collapse)){
return daiquiri.core.create_element("input",{'type':"button",'value':"Rename",'onClick':(function (){
return (set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(null) : set_collapse_BANG_.call(null,null));
}),'className':"panel-rename-button"},[]);
} else {
return daiquiri.core.create_element("div",{'className':"panel-rename"},[daiquiri.core.create_element("input",{'type':"text",'value':(function (){var or__4160__auto__ = new_name;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "";
}
})(),'placeholder':"New name",'onChange':(function (ev){
var G__45835 = ev.target.value;
return (set_new_name_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_new_name_BANG_.cljs$core$IFn$_invoke$arity$1(G__45835) : set_new_name_BANG_.call(null,G__45835));
})},[]),daiquiri.core.create_element("input",{'type':"button",'value':"OK",'disabled':taken_QMARK_,'onClick':(function (ev){
(set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(true) : set_collapse_BANG_.call(null,true));

return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,gauge.do_panel_rename,old_name,new_name);
})},[]),daiquiri.core.create_element("input",{'type':"button",'value':"Cancel",'onClick':(function (){
return (set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(true) : set_collapse_BANG_.call(null,true));
})},[])]);
}
}),null,"gauge/panel-renamer");
gauge.ensure_selected_panel = (function gauge$ensure_selected_panel(p__45836){
var map__45837 = p__45836;
var map__45837__$1 = cljs.core.__destructure_map(map__45837);
var db = map__45837__$1;
var panels = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45837__$1,new cljs.core.Keyword(null,"panels","panels",801034044));
var selected_panel = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45837__$1,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866));
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Ensure SelectedPanel",selected_panel,cljs.core.keys(panels)], 0));

if(cljs.core.contains_QMARK_(panels,selected_panel)){
return db;
} else {
if(cljs.core.empty_QMARK_(panels)){
return db;
} else {
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(db,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),cljs.core.ffirst(panels));

}
}
});
gauge.do_panel_delete = (function gauge$do_panel_delete(db,panel_name){
return gauge.ensure_selected_panel(cljs.core.update.cljs$core$IFn$_invoke$arity$4(db,new cljs.core.Keyword(null,"panels","panels",801034044),cljs.core.dissoc,panel_name));
});
gauge.panel_deleter = rum.core.lazy_build(rum.core.build_defc,(function (ps,panel_name){
var vec__45838 = rum.core.use_state(true);
var collapse = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45838,(0),null);
var set_collapse_BANG_ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45838,(1),null);
if(cljs.core.truth_(collapse)){
return daiquiri.core.create_element("input",{'type':"button",'value':"Delete",'style':{'width':"8ex",'justifySelf':"end"},'onClick':(function (){
return (set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(null) : set_collapse_BANG_.call(null,null));
}),'className':"delete-button"},[]);
} else {
return daiquiri.core.create_element("div",{'className':"panel-delete"},[daiquiri.core.create_element("input",{'type':"button",'value':"Really delete",'onClick':(function (ev){
(set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(true) : set_collapse_BANG_.call(null,true));

return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(gauge.db,gauge.do_panel_delete,panel_name);
}),'className':"delete-button"},[]),daiquiri.core.create_element("input",{'type':"button",'value':"Cancel",'onClick':(function (){
return (set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1 ? set_collapse_BANG_.cljs$core$IFn$_invoke$arity$1(true) : set_collapse_BANG_.call(null,true));
})},[])]);
}
}),null,"gauge/panel-deleter");
gauge.panel_list_STAR_ = rum.core.lazy_build(rum.core.build_defc,(function (sel,ps){
return daiquiri.core.create_element("div",null,[(cljs.core.truth_(cljs.core.not_empty(ps))?daiquiri.core.create_element("div",{'className':"panel-list"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45841(s__45842){
return (new cljs.core.LazySeq(null,(function (){
var s__45842__$1 = s__45842;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45842__$1);
if(temp__5804__auto__){
var xs__6360__auto__ = temp__5804__auto__;
var vec__45847 = cljs.core.first(xs__6360__auto__);
var panel_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45847,(0),null);
var panel = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45847,(1),null);
var iterys__4560__auto__ = ((function (s__45842__$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__){
return (function gauge$iter__45841_$_iter__45843(s__45844){
return (new cljs.core.LazySeq(null,((function (s__45842__$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__){
return (function (){
var s__45844__$1 = s__45844;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__45844__$1);
if(temp__5804__auto____$1){
var s__45844__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__45844__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45844__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45846 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45845 = (0);
while(true){
if((i__45845 < size__4563__auto__)){
var c = cljs.core._nth(c__4562__auto__,i__45845);
cljs.core.chunk_append(b__45846,(function (){var G__45850 = c;
var G__45850__$1 = (((G__45850 instanceof cljs.core.Keyword))?G__45850.fqn:null);
switch (G__45850__$1) {
case "rename":
return rum.core.with_key(gauge.panel_renamer(ps,panel_name),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''));

break;
case "delete":
return rum.core.with_key(gauge.panel_deleter(ps,panel_name),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''));

break;
case "spacer":
return daiquiri.core.create_element("div",{'key':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join('')},[((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(panel_name,sel))?"(editing)":null)]);

break;
case "select":
return daiquiri.core.create_element("input",{'key':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''),'type':"button",'value':panel_name,'disabled':cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(sel,panel_name),'onClick':((function (i__45845,s__45842__$1,G__45850,G__45850__$1,c,c__4562__auto__,size__4563__auto__,b__45846,s__45844__$2,temp__5804__auto____$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__){
return (function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.assoc,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),panel_name);
});})(i__45845,s__45842__$1,G__45850,G__45850__$1,c,c__4562__auto__,size__4563__auto__,b__45846,s__45844__$2,temp__5804__auto____$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__))
},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45850__$1)].join('')));

}
})());

var G__45950 = (i__45845 + (1));
i__45845 = G__45950;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45846),gauge$iter__45841_$_iter__45843(cljs.core.chunk_rest(s__45844__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45846),null);
}
} else {
var c = cljs.core.first(s__45844__$2);
return cljs.core.cons((function (){var G__45851 = c;
var G__45851__$1 = (((G__45851 instanceof cljs.core.Keyword))?G__45851.fqn:null);
switch (G__45851__$1) {
case "rename":
return rum.core.with_key(gauge.panel_renamer(ps,panel_name),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''));

break;
case "delete":
return rum.core.with_key(gauge.panel_deleter(ps,panel_name),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''));

break;
case "spacer":
return daiquiri.core.create_element("div",{'key':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join('')},[((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(panel_name,sel))?"(editing)":null)]);

break;
case "select":
return daiquiri.core.create_element("input",{'key':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(c),cljs.core.str.cljs$core$IFn$_invoke$arity$1(panel_name)].join(''),'type':"button",'value':panel_name,'disabled':cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(sel,panel_name),'onClick':((function (s__45842__$1,G__45851,G__45851__$1,c,s__45844__$2,temp__5804__auto____$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__){
return (function (){
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.assoc,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866),panel_name);
});})(s__45842__$1,G__45851,G__45851__$1,c,s__45844__$2,temp__5804__auto____$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__))
},[]);

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__45851__$1)].join('')));

}
})(),gauge$iter__45841_$_iter__45843(cljs.core.rest(s__45844__$2)));
}
} else {
return null;
}
break;
}
});})(s__45842__$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__))
,null,null));
});})(s__45842__$1,vec__45847,panel_name,panel,xs__6360__auto__,temp__5804__auto__))
;
var fs__4561__auto__ = cljs.core.seq(iterys__4560__auto__(new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"select","select",1147833503),new cljs.core.Keyword(null,"spacer","spacer",2067425139),new cljs.core.Keyword(null,"rename","rename",1508157613),new cljs.core.Keyword(null,"delete","delete",-1768633620)], null)));
if(fs__4561__auto__){
return cljs.core.concat.cljs$core$IFn$_invoke$arity$2(fs__4561__auto__,gauge$iter__45841(cljs.core.rest(s__45842__$1)));
} else {
var G__45952 = cljs.core.rest(s__45842__$1);
s__45842__$1 = G__45952;
continue;
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.sort_by.cljs$core$IFn$_invoke$arity$2(cljs.core.first,ps));
})())]):null),gauge.panel_list_controls(sel,ps)]);
}),null,"gauge/panel-list*");
gauge.alignment_grid = rum.core.lazy_build(rum.core.build_defc,(function (d,ww,hh){
if(cljs.core.truth_((function (){var and__4149__auto__ = d;
if(cljs.core.truth_(and__4149__auto__)){
var and__4149__auto____$1 = ww;
if(cljs.core.truth_(and__4149__auto____$1)){
return hh;
} else {
return and__4149__auto____$1;
}
} else {
return and__4149__auto__;
}
})())){
return daiquiri.core.create_element("svg",{'width':ww,'height':hh,'viewBox':["0 0 ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(ww)," ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(hh)].join(''),'style':{'position':"absolute",'pointerEvents':"none",'zIndex':(999),'top':(0),'left':(0),'width':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(ww),"px"].join(''),'height':[cljs.core.str.cljs$core$IFn$_invoke$arity$1(hh),"px"].join('')}},[daiquiri.core.create_element("g",{'stroke':"#fff",'strokeWidth':(1),'strokeDasharray':"8 5"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45852(s__45853){
return (new cljs.core.LazySeq(null,(function (){
var s__45853__$1 = s__45853;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45853__$1);
if(temp__5804__auto__){
var s__45853__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45853__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45853__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45855 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45854 = (0);
while(true){
if((i__45854 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__45854);
cljs.core.chunk_append(b__45855,daiquiri.core.create_element("line",{'key':i,'x1':(i * (ww / d)),'y1':(0),'x2':(i * (ww / d)),'y2':hh},[]));

var G__45953 = (i__45854 + (1));
i__45854 = G__45953;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45855),gauge$iter__45852(cljs.core.chunk_rest(s__45853__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45855),null);
}
} else {
var i = cljs.core.first(s__45853__$2);
return cljs.core.cons(daiquiri.core.create_element("line",{'key':i,'x1':(i * (ww / d)),'y1':(0),'x2':(i * (ww / d)),'y2':hh},[]),gauge$iter__45852(cljs.core.rest(s__45853__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$2((1),d));
})()),cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45856(s__45857){
return (new cljs.core.LazySeq(null,(function (){
var s__45857__$1 = s__45857;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45857__$1);
if(temp__5804__auto__){
var s__45857__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45857__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45857__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45859 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45858 = (0);
while(true){
if((i__45858 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__45858);
cljs.core.chunk_append(b__45859,daiquiri.core.create_element("line",{'key':i,'x1':(0),'y1':(i * (hh / d)),'x2':ww,'y2':(i * (hh / d))},[]));

var G__45954 = (i__45858 + (1));
i__45858 = G__45954;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45859),gauge$iter__45856(cljs.core.chunk_rest(s__45857__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45859),null);
}
} else {
var i = cljs.core.first(s__45857__$2);
return cljs.core.cons(daiquiri.core.create_element("line",{'key':i,'x1':(0),'y1':(i * (hh / d)),'x2':ww,'y2':(i * (hh / d))},[]),gauge$iter__45856(cljs.core.rest(s__45857__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$2((1),d));
})())])]);
} else {
return null;
}
}),null,"gauge/alignment-grid");
gauge.root = rum.core.lazy_build(rum.core.build_defc,(function (){
var cref = rum.core.create_ref();
var w = gauge.screen_width;
var h = gauge.screen_height;
var map__45860 = rum.core.react(gauge.db);
var map__45860__$1 = cljs.core.__destructure_map(map__45860);
var panels = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45860__$1,new cljs.core.Keyword(null,"panels","panels",801034044));
var selected_panel = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45860__$1,new cljs.core.Keyword(null,"selected-panel","selected-panel",243942866));
var align_divs = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45860__$1,new cljs.core.Keyword(null,"align-divs","align-divs",-449557909));
var map__45861 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(panels,selected_panel);
var map__45861__$1 = cljs.core.__destructure_map(map__45861);
var gauges = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45861__$1,new cljs.core.Keyword(null,"gauges","gauges",-962432914));
var background_image = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45861__$1,new cljs.core.Keyword(null,"background-image","background-image",-1142314704));
return daiquiri.core.create_element("div",{'className':"container"},[daiquiri.core.create_element("div",{'style':{'marginLeft':"2ex",'zIndex':(1000)}},[daiquiri.core.create_element("h2",null,["Instrument Panel creator"]),daiquiri.core.create_element("p",null,["This web app is for creating instrument panels for display on Jeti transmitters using a Jeti Lua app named DFM-InsP."]),daiquiri.core.create_element("p",null,["Once you have finished drawing your panels here, you will get a link to paste into Jeti studio that will install the Lua app and all of your panels using the Transmitter Wizard."]),daiquiri.core.create_element("p",null,["You assign telemetry sensors to the gauges in the Lua app menus to animate the gauges and text boxes. Fine tuning of labels and fonts can be done on the transmitter."]),daiquiri.core.create_element("h4",null,["Example panels"]),daiquiri.core.create_element("div",{'className':"example-panels"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45874(s__45875){
return (new cljs.core.LazySeq(null,(function (){
var s__45875__$1 = s__45875;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45875__$1);
if(temp__5804__auto__){
var s__45875__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45875__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45875__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45877 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45876 = (0);
while(true){
if((i__45876 < size__4563__auto__)){
var vec__45878 = cljs.core._nth(c__4562__auto__,i__45876);
var name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45878,(0),null);
var map__45881 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45878,(1),null);
var map__45881__$1 = cljs.core.__destructure_map(map__45881);
var file = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45881__$1,"file");
cljs.core.chunk_append(b__45877,daiquiri.core.create_element("div",{'key':cljs.core.str.cljs$core$IFn$_invoke$arity$1(name)},[daiquiri.core.create_element("input",{'type':"button",'value':name,'onClick':((function (i__45876,vec__45878,name,map__45881,map__45881__$1,file,c__4562__auto__,size__4563__auto__,b__45877,s__45875__$2,temp__5804__auto__,cref,w,h,map__45860,map__45860__$1,panels,selected_panel,align_divs,map__45861,map__45861__$1,gauges,background_image){
return (function (){
return gauge.reload_json_BANG_(name,file);
});})(i__45876,vec__45878,name,map__45881,map__45881__$1,file,c__4562__auto__,size__4563__auto__,b__45877,s__45875__$2,temp__5804__auto__,cref,w,h,map__45860,map__45860__$1,panels,selected_panel,align_divs,map__45861,map__45861__$1,gauges,background_image))
},[])]));

var G__45955 = (i__45876 + (1));
i__45876 = G__45955;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45877),gauge$iter__45874(cljs.core.chunk_rest(s__45875__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45877),null);
}
} else {
var vec__45882 = cljs.core.first(s__45875__$2);
var name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45882,(0),null);
var map__45885 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45882,(1),null);
var map__45885__$1 = cljs.core.__destructure_map(map__45885);
var file = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__45885__$1,"file");
return cljs.core.cons(daiquiri.core.create_element("div",{'key':cljs.core.str.cljs$core$IFn$_invoke$arity$1(name)},[daiquiri.core.create_element("input",{'type':"button",'value':name,'onClick':((function (vec__45882,name,map__45885,map__45885__$1,file,s__45875__$2,temp__5804__auto__,cref,w,h,map__45860,map__45860__$1,panels,selected_panel,align_divs,map__45861,map__45861__$1,gauges,background_image){
return (function (){
return gauge.reload_json_BANG_(name,file);
});})(vec__45882,name,map__45885,map__45885__$1,file,s__45875__$2,temp__5804__auto__,cref,w,h,map__45860,map__45860__$1,panels,selected_panel,align_divs,map__45861,map__45861__$1,gauges,background_image))
},[])]),gauge$iter__45874(cljs.core.rest(s__45875__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.get.cljs$core$IFn$_invoke$arity$2(gauge.config_json,"examples"));
})())]),daiquiri.core.create_element("h4",null,["My panels"]),gauge.panel_list_STAR_(selected_panel,panels),gauge.app_controls(w,h)]),daiquiri.core.create_element("div",null,[daiquiri.core.create_element("div",{'style':daiquiri.interpreter.element_attributes((function (){var G__45886 = new cljs.core.PersistentArrayMap(null, 3, [new cljs.core.Keyword(null,"width","width",-384071477),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(((w * gauge.draw_scale) * gauge.disp_scale)),"px"].join(''),new cljs.core.Keyword(null,"height","height",1025178622),[cljs.core.str.cljs$core$IFn$_invoke$arity$1(((h * gauge.draw_scale) * gauge.disp_scale)),"px"].join(''),new cljs.core.Keyword(null,"position","position",-2011731912),new cljs.core.Keyword(null,"relative","relative",22796862)], null);
if(cljs.core.truth_(background_image)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$variadic(G__45886,new cljs.core.Keyword(null,"background-image","background-image",-1142314704),["url(",cljs.core.str.cljs$core$IFn$_invoke$arity$1(background_image),")"].join(''),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"background-size","background-size",-1248630243),"cover"], 0));
} else {
return G__45886;
}
})()),'className':"composite"},[cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45887(s__45888){
return (new cljs.core.LazySeq(null,(function (){
var s__45888__$1 = s__45888;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45888__$1);
if(temp__5804__auto__){
var s__45888__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45888__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45888__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45890 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45889 = (0);
while(true){
if((i__45889 < size__4563__auto__)){
var vec__45891 = cljs.core._nth(c__4562__auto__,i__45889);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45891,(0),null);
var d = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45891,(1),null);
if(cljs.core.truth_((function (){var and__4149__auto__ = new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926).cljs$core$IFn$_invoke$arity$1(d);
if(cljs.core.truth_(and__4149__auto__)){
return cljs.core.not((function (){var or__4160__auto__ = new cljs.core.Keyword(null,"hidden","hidden",-312506092).cljs$core$IFn$_invoke$arity$1(d);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return new cljs.core.Keyword(null,"deleted","deleted",-510100639).cljs$core$IFn$_invoke$arity$1(d);
}
})());
} else {
return and__4149__auto__;
}
})())){
var vec__45894 = gauge.shape__GT_bbox(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d));
var x = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45894,(0),null);
var y = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45894,(1),null);
var w__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45894,(2),null);
var h__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45894,(3),null);
cljs.core.chunk_append(b__45890,rum.core.with_key(gauge.bitmap_canvas_drag(new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926).cljs$core$IFn$_invoke$arity$1(d),((x * gauge.draw_scale) * gauge.disp_scale),((y * gauge.draw_scale) * gauge.disp_scale),new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),selected_panel,new cljs.core.Keyword(null,"gauges","gauges",-962432914),i], null)),i));

var G__45956 = (i__45889 + (1));
i__45889 = G__45956;
continue;
} else {
var G__45957 = (i__45889 + (1));
i__45889 = G__45957;
continue;
}
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45890),gauge$iter__45887(cljs.core.chunk_rest(s__45888__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45890),null);
}
} else {
var vec__45897 = cljs.core.first(s__45888__$2);
var i = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45897,(0),null);
var d = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45897,(1),null);
if(cljs.core.truth_((function (){var and__4149__auto__ = new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926).cljs$core$IFn$_invoke$arity$1(d);
if(cljs.core.truth_(and__4149__auto__)){
return cljs.core.not((function (){var or__4160__auto__ = new cljs.core.Keyword(null,"hidden","hidden",-312506092).cljs$core$IFn$_invoke$arity$1(d);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return new cljs.core.Keyword(null,"deleted","deleted",-510100639).cljs$core$IFn$_invoke$arity$1(d);
}
})());
} else {
return and__4149__auto__;
}
})())){
var vec__45900 = gauge.shape__GT_bbox(new cljs.core.Keyword(null,"params","params",710516235).cljs$core$IFn$_invoke$arity$1(d));
var x = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45900,(0),null);
var y = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45900,(1),null);
var w__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45900,(2),null);
var h__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__45900,(3),null);
return cljs.core.cons(rum.core.with_key(gauge.bitmap_canvas_drag(new cljs.core.Keyword(null,"bitmap","bitmap",-1139196926).cljs$core$IFn$_invoke$arity$1(d),((x * gauge.draw_scale) * gauge.disp_scale),((y * gauge.draw_scale) * gauge.disp_scale),new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"panels","panels",801034044),selected_panel,new cljs.core.Keyword(null,"gauges","gauges",-962432914),i], null)),i),gauge$iter__45887(cljs.core.rest(s__45888__$2)));
} else {
var G__45958 = cljs.core.rest(s__45888__$2);
s__45888__$1 = G__45958;
continue;
}
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(gauges);
})()),(cljs.core.truth_(align_divs)?gauge.alignment_grid(align_divs,((w * gauge.draw_scale) * gauge.disp_scale),((h * gauge.draw_scale) * gauge.disp_scale)):null)]),daiquiri.core.create_element("label",{'style':{'zIndex':(1000)}},["Alignment grid:",daiquiri.core.create_element("select",{'value':(function (){var or__4160__auto__ = align_divs;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "none";
}
})(),'style':{'marginLeft':"2ex"},'onChange':(function (ev){
var s = ev.target.value;
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(gauge.db,cljs.core.assoc,new cljs.core.Keyword(null,"align-divs","align-divs",-449557909),(function (){var G__45903 = s;
switch (G__45903) {
case "none":
return null;

break;
default:
return s;

}
})());
})},[daiquiri.core.create_element("option",{'value':"none"},["none"]),cljs.core.into_array.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function gauge$iter__45906(s__45907){
return (new cljs.core.LazySeq(null,(function (){
var s__45907__$1 = s__45907;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__45907__$1);
if(temp__5804__auto__){
var s__45907__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__45907__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__45907__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__45909 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__45908 = (0);
while(true){
if((i__45908 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__45908);
cljs.core.chunk_append(b__45909,daiquiri.core.create_element("option",{'key':i,'value':cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)},[cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)]));

var G__45960 = (i__45908 + (1));
i__45908 = G__45960;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__45909),gauge$iter__45906(cljs.core.chunk_rest(s__45907__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__45909),null);
}
} else {
var i = cljs.core.first(s__45907__$2);
return cljs.core.cons(daiquiri.core.create_element("option",{'key':i,'value':cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)},[cljs.core.str.cljs$core$IFn$_invoke$arity$1(i)]),gauge$iter__45906(cljs.core.rest(s__45907__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(new cljs.core.PersistentVector(null, 7, 5, cljs.core.PersistentVector.EMPTY_NODE, [(2),(3),(4),(5),(6),(7),(8)], null));
})())])])]),gauge.gauge_list(selected_panel,gauges)]);
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"gauge/root");
gauge.stop = (function gauge$stop(){
return cljs.core.remove_watch(gauge.db,gauge.save_watch_key);
});
gauge.init = (function gauge$init(){
var el = document.getElementById("root");
cljs.core.add_watch(gauge.db,gauge.save_watch_key,goog.functions.throttle((function (_,___$1,___$2,new$){
return gauge.save_to_localstorage_BANG_(new$);
}),(5000)));

rum.core.mount(gauge.root(),el);

return setTimeout((function (){
var or__4160__auto__ = gauge.load_from_localstorage_BANG_();
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return gauge.reload_json_BANG_("Turbine","Turbine.json");
}
}),(0));
});

//# sourceMappingURL=gauge.js.map
