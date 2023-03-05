goog.provide('shadow.dom');
shadow.dom.transition_supported_QMARK_ = (((typeof window !== 'undefined'))?goog.style.transition.isSupported():null);

/**
 * @interface
 */
shadow.dom.IElement = function(){};

var shadow$dom$IElement$_to_dom$dyn_48940 = (function (this$){
var x__4463__auto__ = (((this$ == null))?null:this$);
var m__4464__auto__ = (shadow.dom._to_dom[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(this$) : m__4464__auto__.call(null,this$));
} else {
var m__4461__auto__ = (shadow.dom._to_dom["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(this$) : m__4461__auto__.call(null,this$));
} else {
throw cljs.core.missing_protocol("IElement.-to-dom",this$);
}
}
});
shadow.dom._to_dom = (function shadow$dom$_to_dom(this$){
if((((!((this$ == null)))) && ((!((this$.shadow$dom$IElement$_to_dom$arity$1 == null)))))){
return this$.shadow$dom$IElement$_to_dom$arity$1(this$);
} else {
return shadow$dom$IElement$_to_dom$dyn_48940(this$);
}
});


/**
 * @interface
 */
shadow.dom.SVGElement = function(){};

var shadow$dom$SVGElement$_to_svg$dyn_48941 = (function (this$){
var x__4463__auto__ = (((this$ == null))?null:this$);
var m__4464__auto__ = (shadow.dom._to_svg[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(this$) : m__4464__auto__.call(null,this$));
} else {
var m__4461__auto__ = (shadow.dom._to_svg["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(this$) : m__4461__auto__.call(null,this$));
} else {
throw cljs.core.missing_protocol("SVGElement.-to-svg",this$);
}
}
});
shadow.dom._to_svg = (function shadow$dom$_to_svg(this$){
if((((!((this$ == null)))) && ((!((this$.shadow$dom$SVGElement$_to_svg$arity$1 == null)))))){
return this$.shadow$dom$SVGElement$_to_svg$arity$1(this$);
} else {
return shadow$dom$SVGElement$_to_svg$dyn_48941(this$);
}
});

shadow.dom.lazy_native_coll_seq = (function shadow$dom$lazy_native_coll_seq(coll,idx){
if((idx < coll.length)){
return (new cljs.core.LazySeq(null,(function (){
return cljs.core.cons((coll[idx]),(function (){var G__48257 = coll;
var G__48258 = (idx + (1));
return (shadow.dom.lazy_native_coll_seq.cljs$core$IFn$_invoke$arity$2 ? shadow.dom.lazy_native_coll_seq.cljs$core$IFn$_invoke$arity$2(G__48257,G__48258) : shadow.dom.lazy_native_coll_seq.call(null,G__48257,G__48258));
})());
}),null,null));
} else {
return null;
}
});

/**
* @constructor
 * @implements {cljs.core.IIndexed}
 * @implements {cljs.core.ICounted}
 * @implements {cljs.core.ISeqable}
 * @implements {cljs.core.IDeref}
 * @implements {shadow.dom.IElement}
*/
shadow.dom.NativeColl = (function (coll){
this.coll = coll;
this.cljs$lang$protocol_mask$partition0$ = 8421394;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(shadow.dom.NativeColl.prototype.cljs$core$IDeref$_deref$arity$1 = (function (this$){
var self__ = this;
var this$__$1 = this;
return self__.coll;
}));

(shadow.dom.NativeColl.prototype.cljs$core$IIndexed$_nth$arity$2 = (function (this$,n){
var self__ = this;
var this$__$1 = this;
return (self__.coll[n]);
}));

(shadow.dom.NativeColl.prototype.cljs$core$IIndexed$_nth$arity$3 = (function (this$,n,not_found){
var self__ = this;
var this$__$1 = this;
var or__4160__auto__ = (self__.coll[n]);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return not_found;
}
}));

(shadow.dom.NativeColl.prototype.cljs$core$ICounted$_count$arity$1 = (function (this$){
var self__ = this;
var this$__$1 = this;
return self__.coll.length;
}));

(shadow.dom.NativeColl.prototype.cljs$core$ISeqable$_seq$arity$1 = (function (this$){
var self__ = this;
var this$__$1 = this;
return shadow.dom.lazy_native_coll_seq(self__.coll,(0));
}));

(shadow.dom.NativeColl.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(shadow.dom.NativeColl.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var self__ = this;
var this$__$1 = this;
return self__.coll;
}));

(shadow.dom.NativeColl.getBasis = (function (){
return new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"coll","coll",-1006698606,null)], null);
}));

(shadow.dom.NativeColl.cljs$lang$type = true);

(shadow.dom.NativeColl.cljs$lang$ctorStr = "shadow.dom/NativeColl");

(shadow.dom.NativeColl.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"shadow.dom/NativeColl");
}));

/**
 * Positional factory function for shadow.dom/NativeColl.
 */
shadow.dom.__GT_NativeColl = (function shadow$dom$__GT_NativeColl(coll){
return (new shadow.dom.NativeColl(coll));
});

shadow.dom.native_coll = (function shadow$dom$native_coll(coll){
return (new shadow.dom.NativeColl(coll));
});
shadow.dom.dom_node = (function shadow$dom$dom_node(el){
if((el == null)){
return null;
} else {
if((((!((el == null))))?((((false) || ((cljs.core.PROTOCOL_SENTINEL === el.shadow$dom$IElement$))))?true:false):false)){
return el.shadow$dom$IElement$_to_dom$arity$1(null);
} else {
if(typeof el === 'string'){
return document.createTextNode(el);
} else {
if(typeof el === 'number'){
return document.createTextNode(cljs.core.str.cljs$core$IFn$_invoke$arity$1(el));
} else {
return el;

}
}
}
}
});
shadow.dom.query_one = (function shadow$dom$query_one(var_args){
var G__48282 = arguments.length;
switch (G__48282) {
case 1:
return shadow.dom.query_one.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.query_one.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.query_one.cljs$core$IFn$_invoke$arity$1 = (function (sel){
return document.querySelector(sel);
}));

(shadow.dom.query_one.cljs$core$IFn$_invoke$arity$2 = (function (sel,root){
return shadow.dom.dom_node(root).querySelector(sel);
}));

(shadow.dom.query_one.cljs$lang$maxFixedArity = 2);

shadow.dom.query = (function shadow$dom$query(var_args){
var G__48287 = arguments.length;
switch (G__48287) {
case 1:
return shadow.dom.query.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.query.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.query.cljs$core$IFn$_invoke$arity$1 = (function (sel){
return (new shadow.dom.NativeColl(document.querySelectorAll(sel)));
}));

(shadow.dom.query.cljs$core$IFn$_invoke$arity$2 = (function (sel,root){
return (new shadow.dom.NativeColl(shadow.dom.dom_node(root).querySelectorAll(sel)));
}));

(shadow.dom.query.cljs$lang$maxFixedArity = 2);

shadow.dom.by_id = (function shadow$dom$by_id(var_args){
var G__48298 = arguments.length;
switch (G__48298) {
case 2:
return shadow.dom.by_id.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 1:
return shadow.dom.by_id.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.by_id.cljs$core$IFn$_invoke$arity$2 = (function (id,el){
return shadow.dom.dom_node(el).getElementById(id);
}));

(shadow.dom.by_id.cljs$core$IFn$_invoke$arity$1 = (function (id){
return document.getElementById(id);
}));

(shadow.dom.by_id.cljs$lang$maxFixedArity = 2);

shadow.dom.build = shadow.dom.dom_node;
shadow.dom.ev_stop = (function shadow$dom$ev_stop(var_args){
var G__48309 = arguments.length;
switch (G__48309) {
case 1:
return shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 4:
return shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$1 = (function (e){
if(cljs.core.truth_(e.stopPropagation)){
e.stopPropagation();

e.preventDefault();
} else {
(e.cancelBubble = true);

(e.returnValue = false);
}

return e;
}));

(shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$2 = (function (e,el){
shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$1(e);

return el;
}));

(shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$4 = (function (e,el,scope,owner){
shadow.dom.ev_stop.cljs$core$IFn$_invoke$arity$1(e);

return el;
}));

(shadow.dom.ev_stop.cljs$lang$maxFixedArity = 4);

/**
 * check wether a parent node (or the document) contains the child
 */
shadow.dom.contains_QMARK_ = (function shadow$dom$contains_QMARK_(var_args){
var G__48327 = arguments.length;
switch (G__48327) {
case 1:
return shadow.dom.contains_QMARK_.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.contains_QMARK_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.contains_QMARK_.cljs$core$IFn$_invoke$arity$1 = (function (el){
return goog.dom.contains(document,shadow.dom.dom_node(el));
}));

(shadow.dom.contains_QMARK_.cljs$core$IFn$_invoke$arity$2 = (function (parent,el){
return goog.dom.contains(shadow.dom.dom_node(parent),shadow.dom.dom_node(el));
}));

(shadow.dom.contains_QMARK_.cljs$lang$maxFixedArity = 2);

shadow.dom.add_class = (function shadow$dom$add_class(el,cls){
return goog.dom.classlist.add(shadow.dom.dom_node(el),cls);
});
shadow.dom.remove_class = (function shadow$dom$remove_class(el,cls){
return goog.dom.classlist.remove(shadow.dom.dom_node(el),cls);
});
shadow.dom.toggle_class = (function shadow$dom$toggle_class(var_args){
var G__48339 = arguments.length;
switch (G__48339) {
case 2:
return shadow.dom.toggle_class.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return shadow.dom.toggle_class.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.toggle_class.cljs$core$IFn$_invoke$arity$2 = (function (el,cls){
return goog.dom.classlist.toggle(shadow.dom.dom_node(el),cls);
}));

(shadow.dom.toggle_class.cljs$core$IFn$_invoke$arity$3 = (function (el,cls,v){
if(cljs.core.truth_(v)){
return shadow.dom.add_class(el,cls);
} else {
return shadow.dom.remove_class(el,cls);
}
}));

(shadow.dom.toggle_class.cljs$lang$maxFixedArity = 3);

shadow.dom.dom_listen = (cljs.core.truth_((function (){var or__4160__auto__ = (!((typeof document !== 'undefined')));
if(or__4160__auto__){
return or__4160__auto__;
} else {
return document.addEventListener;
}
})())?(function shadow$dom$dom_listen_good(el,ev,handler){
return el.addEventListener(ev,handler,false);
}):(function shadow$dom$dom_listen_ie(el,ev,handler){
try{return el.attachEvent(["on",cljs.core.str.cljs$core$IFn$_invoke$arity$1(ev)].join(''),(function (e){
return (handler.cljs$core$IFn$_invoke$arity$2 ? handler.cljs$core$IFn$_invoke$arity$2(e,el) : handler.call(null,e,el));
}));
}catch (e48354){if((e48354 instanceof Object)){
var e = e48354;
return console.log("didnt support attachEvent",el,e);
} else {
throw e48354;

}
}}));
shadow.dom.dom_listen_remove = (cljs.core.truth_((function (){var or__4160__auto__ = (!((typeof document !== 'undefined')));
if(or__4160__auto__){
return or__4160__auto__;
} else {
return document.removeEventListener;
}
})())?(function shadow$dom$dom_listen_remove_good(el,ev,handler){
return el.removeEventListener(ev,handler,false);
}):(function shadow$dom$dom_listen_remove_ie(el,ev,handler){
return el.detachEvent(["on",cljs.core.str.cljs$core$IFn$_invoke$arity$1(ev)].join(''),handler);
}));
shadow.dom.on_query = (function shadow$dom$on_query(root_el,ev,selector,handler){
var seq__48361 = cljs.core.seq(shadow.dom.query.cljs$core$IFn$_invoke$arity$2(selector,root_el));
var chunk__48362 = null;
var count__48363 = (0);
var i__48364 = (0);
while(true){
if((i__48364 < count__48363)){
var el = chunk__48362.cljs$core$IIndexed$_nth$arity$2(null,i__48364);
var handler_48948__$1 = ((function (seq__48361,chunk__48362,count__48363,i__48364,el){
return (function (e){
return (handler.cljs$core$IFn$_invoke$arity$2 ? handler.cljs$core$IFn$_invoke$arity$2(e,el) : handler.call(null,e,el));
});})(seq__48361,chunk__48362,count__48363,i__48364,el))
;
shadow.dom.dom_listen(el,cljs.core.name(ev),handler_48948__$1);


var G__48949 = seq__48361;
var G__48950 = chunk__48362;
var G__48951 = count__48363;
var G__48952 = (i__48364 + (1));
seq__48361 = G__48949;
chunk__48362 = G__48950;
count__48363 = G__48951;
i__48364 = G__48952;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__48361);
if(temp__5804__auto__){
var seq__48361__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__48361__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__48361__$1);
var G__48953 = cljs.core.chunk_rest(seq__48361__$1);
var G__48954 = c__4591__auto__;
var G__48955 = cljs.core.count(c__4591__auto__);
var G__48956 = (0);
seq__48361 = G__48953;
chunk__48362 = G__48954;
count__48363 = G__48955;
i__48364 = G__48956;
continue;
} else {
var el = cljs.core.first(seq__48361__$1);
var handler_48957__$1 = ((function (seq__48361,chunk__48362,count__48363,i__48364,el,seq__48361__$1,temp__5804__auto__){
return (function (e){
return (handler.cljs$core$IFn$_invoke$arity$2 ? handler.cljs$core$IFn$_invoke$arity$2(e,el) : handler.call(null,e,el));
});})(seq__48361,chunk__48362,count__48363,i__48364,el,seq__48361__$1,temp__5804__auto__))
;
shadow.dom.dom_listen(el,cljs.core.name(ev),handler_48957__$1);


var G__48958 = cljs.core.next(seq__48361__$1);
var G__48959 = null;
var G__48960 = (0);
var G__48961 = (0);
seq__48361 = G__48958;
chunk__48362 = G__48959;
count__48363 = G__48960;
i__48364 = G__48961;
continue;
}
} else {
return null;
}
}
break;
}
});
shadow.dom.on = (function shadow$dom$on(var_args){
var G__48380 = arguments.length;
switch (G__48380) {
case 3:
return shadow.dom.on.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return shadow.dom.on.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.on.cljs$core$IFn$_invoke$arity$3 = (function (el,ev,handler){
return shadow.dom.on.cljs$core$IFn$_invoke$arity$4(el,ev,handler,false);
}));

(shadow.dom.on.cljs$core$IFn$_invoke$arity$4 = (function (el,ev,handler,capture){
if(cljs.core.vector_QMARK_(ev)){
return shadow.dom.on_query(el,cljs.core.first(ev),cljs.core.second(ev),handler);
} else {
var handler__$1 = (function (e){
return (handler.cljs$core$IFn$_invoke$arity$2 ? handler.cljs$core$IFn$_invoke$arity$2(e,el) : handler.call(null,e,el));
});
return shadow.dom.dom_listen(shadow.dom.dom_node(el),cljs.core.name(ev),handler__$1);
}
}));

(shadow.dom.on.cljs$lang$maxFixedArity = 4);

shadow.dom.remove_event_handler = (function shadow$dom$remove_event_handler(el,ev,handler){
return shadow.dom.dom_listen_remove(shadow.dom.dom_node(el),cljs.core.name(ev),handler);
});
shadow.dom.add_event_listeners = (function shadow$dom$add_event_listeners(el,events){
var seq__48390 = cljs.core.seq(events);
var chunk__48391 = null;
var count__48392 = (0);
var i__48393 = (0);
while(true){
if((i__48393 < count__48392)){
var vec__48406 = chunk__48391.cljs$core$IIndexed$_nth$arity$2(null,i__48393);
var k = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48406,(0),null);
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48406,(1),null);
shadow.dom.on.cljs$core$IFn$_invoke$arity$3(el,k,v);


var G__48963 = seq__48390;
var G__48964 = chunk__48391;
var G__48965 = count__48392;
var G__48966 = (i__48393 + (1));
seq__48390 = G__48963;
chunk__48391 = G__48964;
count__48392 = G__48965;
i__48393 = G__48966;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__48390);
if(temp__5804__auto__){
var seq__48390__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__48390__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__48390__$1);
var G__48967 = cljs.core.chunk_rest(seq__48390__$1);
var G__48968 = c__4591__auto__;
var G__48969 = cljs.core.count(c__4591__auto__);
var G__48970 = (0);
seq__48390 = G__48967;
chunk__48391 = G__48968;
count__48392 = G__48969;
i__48393 = G__48970;
continue;
} else {
var vec__48413 = cljs.core.first(seq__48390__$1);
var k = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48413,(0),null);
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48413,(1),null);
shadow.dom.on.cljs$core$IFn$_invoke$arity$3(el,k,v);


var G__48971 = cljs.core.next(seq__48390__$1);
var G__48972 = null;
var G__48973 = (0);
var G__48974 = (0);
seq__48390 = G__48971;
chunk__48391 = G__48972;
count__48392 = G__48973;
i__48393 = G__48974;
continue;
}
} else {
return null;
}
}
break;
}
});
shadow.dom.set_style = (function shadow$dom$set_style(el,styles){
var dom = shadow.dom.dom_node(el);
var seq__48419 = cljs.core.seq(styles);
var chunk__48420 = null;
var count__48421 = (0);
var i__48422 = (0);
while(true){
if((i__48422 < count__48421)){
var vec__48438 = chunk__48420.cljs$core$IIndexed$_nth$arity$2(null,i__48422);
var k = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48438,(0),null);
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48438,(1),null);
goog.style.setStyle(dom,cljs.core.name(k),(((v == null))?"":v));


var G__48975 = seq__48419;
var G__48976 = chunk__48420;
var G__48977 = count__48421;
var G__48978 = (i__48422 + (1));
seq__48419 = G__48975;
chunk__48420 = G__48976;
count__48421 = G__48977;
i__48422 = G__48978;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__48419);
if(temp__5804__auto__){
var seq__48419__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__48419__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__48419__$1);
var G__48979 = cljs.core.chunk_rest(seq__48419__$1);
var G__48980 = c__4591__auto__;
var G__48981 = cljs.core.count(c__4591__auto__);
var G__48982 = (0);
seq__48419 = G__48979;
chunk__48420 = G__48980;
count__48421 = G__48981;
i__48422 = G__48982;
continue;
} else {
var vec__48445 = cljs.core.first(seq__48419__$1);
var k = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48445,(0),null);
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48445,(1),null);
goog.style.setStyle(dom,cljs.core.name(k),(((v == null))?"":v));


var G__48983 = cljs.core.next(seq__48419__$1);
var G__48984 = null;
var G__48985 = (0);
var G__48986 = (0);
seq__48419 = G__48983;
chunk__48420 = G__48984;
count__48421 = G__48985;
i__48422 = G__48986;
continue;
}
} else {
return null;
}
}
break;
}
});
shadow.dom.set_attr_STAR_ = (function shadow$dom$set_attr_STAR_(el,key,value){
var G__48451_48987 = key;
var G__48451_48988__$1 = (((G__48451_48987 instanceof cljs.core.Keyword))?G__48451_48987.fqn:null);
switch (G__48451_48988__$1) {
case "id":
(el.id = cljs.core.str.cljs$core$IFn$_invoke$arity$1(value));

break;
case "class":
(el.className = cljs.core.str.cljs$core$IFn$_invoke$arity$1(value));

break;
case "for":
(el.htmlFor = value);

break;
case "cellpadding":
el.setAttribute("cellPadding",value);

break;
case "cellspacing":
el.setAttribute("cellSpacing",value);

break;
case "colspan":
el.setAttribute("colSpan",value);

break;
case "frameborder":
el.setAttribute("frameBorder",value);

break;
case "height":
el.setAttribute("height",value);

break;
case "maxlength":
el.setAttribute("maxLength",value);

break;
case "role":
el.setAttribute("role",value);

break;
case "rowspan":
el.setAttribute("rowSpan",value);

break;
case "type":
el.setAttribute("type",value);

break;
case "usemap":
el.setAttribute("useMap",value);

break;
case "valign":
el.setAttribute("vAlign",value);

break;
case "width":
el.setAttribute("width",value);

break;
case "on":
shadow.dom.add_event_listeners(el,value);

break;
case "style":
if((value == null)){
} else {
if(typeof value === 'string'){
el.setAttribute("style",value);
} else {
if(cljs.core.map_QMARK_(value)){
shadow.dom.set_style(el,value);
} else {
goog.style.setStyle(el,value);

}
}
}

break;
default:
var ks_48991 = cljs.core.name(key);
if(cljs.core.truth_((function (){var or__4160__auto__ = goog.string.startsWith(ks_48991,"data-");
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return goog.string.startsWith(ks_48991,"aria-");
}
})())){
el.setAttribute(ks_48991,value);
} else {
(el[ks_48991] = value);
}

}

return el;
});
shadow.dom.set_attrs = (function shadow$dom$set_attrs(el,attrs){
return cljs.core.reduce_kv((function (el__$1,key,value){
shadow.dom.set_attr_STAR_(el__$1,key,value);

return el__$1;
}),shadow.dom.dom_node(el),attrs);
});
shadow.dom.set_attr = (function shadow$dom$set_attr(el,key,value){
return shadow.dom.set_attr_STAR_(shadow.dom.dom_node(el),key,value);
});
shadow.dom.has_class_QMARK_ = (function shadow$dom$has_class_QMARK_(el,cls){
return goog.dom.classlist.contains(shadow.dom.dom_node(el),cls);
});
shadow.dom.merge_class_string = (function shadow$dom$merge_class_string(current,extra_class){
if(cljs.core.seq(current)){
return [cljs.core.str.cljs$core$IFn$_invoke$arity$1(current)," ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(extra_class)].join('');
} else {
return extra_class;
}
});
shadow.dom.parse_tag = (function shadow$dom$parse_tag(spec){
var spec__$1 = cljs.core.name(spec);
var fdot = spec__$1.indexOf(".");
var fhash = spec__$1.indexOf("#");
if(((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2((-1),fdot)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2((-1),fhash)))){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [spec__$1,null,null], null);
} else {
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2((-1),fhash)){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [spec__$1.substring((0),fdot),null,clojure.string.replace(spec__$1.substring((fdot + (1))),/\./," ")], null);
} else {
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2((-1),fdot)){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [spec__$1.substring((0),fhash),spec__$1.substring((fhash + (1))),null], null);
} else {
if((fhash > fdot)){
throw ["cant have id after class?",spec__$1].join('');
} else {
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [spec__$1.substring((0),fhash),spec__$1.substring((fhash + (1)),fdot),clojure.string.replace(spec__$1.substring((fdot + (1))),/\./," ")], null);

}
}
}
}
});
shadow.dom.create_dom_node = (function shadow$dom$create_dom_node(tag_def,p__48458){
var map__48459 = p__48458;
var map__48459__$1 = cljs.core.__destructure_map(map__48459);
var props = map__48459__$1;
var class$ = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__48459__$1,new cljs.core.Keyword(null,"class","class",-2030961996));
var tag_props = ({});
var vec__48460 = shadow.dom.parse_tag(tag_def);
var tag_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48460,(0),null);
var tag_id = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48460,(1),null);
var tag_classes = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48460,(2),null);
if(cljs.core.truth_(tag_id)){
(tag_props["id"] = tag_id);
} else {
}

if(cljs.core.truth_(tag_classes)){
(tag_props["class"] = shadow.dom.merge_class_string(class$,tag_classes));
} else {
}

var G__48465 = goog.dom.createDom(tag_name,tag_props);
shadow.dom.set_attrs(G__48465,cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(props,new cljs.core.Keyword(null,"class","class",-2030961996)));

return G__48465;
});
shadow.dom.append = (function shadow$dom$append(var_args){
var G__48469 = arguments.length;
switch (G__48469) {
case 1:
return shadow.dom.append.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.append.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.append.cljs$core$IFn$_invoke$arity$1 = (function (node){
if(cljs.core.truth_(node)){
var temp__5804__auto__ = shadow.dom.dom_node(node);
if(cljs.core.truth_(temp__5804__auto__)){
var n = temp__5804__auto__;
document.body.appendChild(n);

return n;
} else {
return null;
}
} else {
return null;
}
}));

(shadow.dom.append.cljs$core$IFn$_invoke$arity$2 = (function (el,node){
if(cljs.core.truth_(node)){
var temp__5804__auto__ = shadow.dom.dom_node(node);
if(cljs.core.truth_(temp__5804__auto__)){
var n = temp__5804__auto__;
shadow.dom.dom_node(el).appendChild(n);

return n;
} else {
return null;
}
} else {
return null;
}
}));

(shadow.dom.append.cljs$lang$maxFixedArity = 2);

shadow.dom.destructure_node = (function shadow$dom$destructure_node(create_fn,p__48477){
var vec__48479 = p__48477;
var seq__48480 = cljs.core.seq(vec__48479);
var first__48481 = cljs.core.first(seq__48480);
var seq__48480__$1 = cljs.core.next(seq__48480);
var nn = first__48481;
var first__48481__$1 = cljs.core.first(seq__48480__$1);
var seq__48480__$2 = cljs.core.next(seq__48480__$1);
var np = first__48481__$1;
var nc = seq__48480__$2;
var node = vec__48479;
if((nn instanceof cljs.core.Keyword)){
} else {
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2("invalid dom node",new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"node","node",581201198),node], null));
}

if((((np == null)) && ((nc == null)))){
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(function (){var G__48484 = nn;
var G__48485 = cljs.core.PersistentArrayMap.EMPTY;
return (create_fn.cljs$core$IFn$_invoke$arity$2 ? create_fn.cljs$core$IFn$_invoke$arity$2(G__48484,G__48485) : create_fn.call(null,G__48484,G__48485));
})(),cljs.core.List.EMPTY], null);
} else {
if(cljs.core.map_QMARK_(np)){
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(create_fn.cljs$core$IFn$_invoke$arity$2 ? create_fn.cljs$core$IFn$_invoke$arity$2(nn,np) : create_fn.call(null,nn,np)),nc], null);
} else {
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(function (){var G__48486 = nn;
var G__48487 = cljs.core.PersistentArrayMap.EMPTY;
return (create_fn.cljs$core$IFn$_invoke$arity$2 ? create_fn.cljs$core$IFn$_invoke$arity$2(G__48486,G__48487) : create_fn.call(null,G__48486,G__48487));
})(),cljs.core.conj.cljs$core$IFn$_invoke$arity$2(nc,np)], null);

}
}
});
shadow.dom.make_dom_node = (function shadow$dom$make_dom_node(structure){
var vec__48491 = shadow.dom.destructure_node(shadow.dom.create_dom_node,structure);
var node = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48491,(0),null);
var node_children = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48491,(1),null);
var seq__48495_48994 = cljs.core.seq(node_children);
var chunk__48496_48995 = null;
var count__48497_48996 = (0);
var i__48498_48997 = (0);
while(true){
if((i__48498_48997 < count__48497_48996)){
var child_struct_48998 = chunk__48496_48995.cljs$core$IIndexed$_nth$arity$2(null,i__48498_48997);
var children_48999 = shadow.dom.dom_node(child_struct_48998);
if(cljs.core.seq_QMARK_(children_48999)){
var seq__48532_49000 = cljs.core.seq(cljs.core.map.cljs$core$IFn$_invoke$arity$2(shadow.dom.dom_node,children_48999));
var chunk__48534_49001 = null;
var count__48535_49002 = (0);
var i__48536_49003 = (0);
while(true){
if((i__48536_49003 < count__48535_49002)){
var child_49004 = chunk__48534_49001.cljs$core$IIndexed$_nth$arity$2(null,i__48536_49003);
if(cljs.core.truth_(child_49004)){
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,child_49004);


var G__49005 = seq__48532_49000;
var G__49006 = chunk__48534_49001;
var G__49007 = count__48535_49002;
var G__49008 = (i__48536_49003 + (1));
seq__48532_49000 = G__49005;
chunk__48534_49001 = G__49006;
count__48535_49002 = G__49007;
i__48536_49003 = G__49008;
continue;
} else {
var G__49009 = seq__48532_49000;
var G__49010 = chunk__48534_49001;
var G__49011 = count__48535_49002;
var G__49012 = (i__48536_49003 + (1));
seq__48532_49000 = G__49009;
chunk__48534_49001 = G__49010;
count__48535_49002 = G__49011;
i__48536_49003 = G__49012;
continue;
}
} else {
var temp__5804__auto___49013 = cljs.core.seq(seq__48532_49000);
if(temp__5804__auto___49013){
var seq__48532_49014__$1 = temp__5804__auto___49013;
if(cljs.core.chunked_seq_QMARK_(seq__48532_49014__$1)){
var c__4591__auto___49015 = cljs.core.chunk_first(seq__48532_49014__$1);
var G__49016 = cljs.core.chunk_rest(seq__48532_49014__$1);
var G__49017 = c__4591__auto___49015;
var G__49018 = cljs.core.count(c__4591__auto___49015);
var G__49019 = (0);
seq__48532_49000 = G__49016;
chunk__48534_49001 = G__49017;
count__48535_49002 = G__49018;
i__48536_49003 = G__49019;
continue;
} else {
var child_49020 = cljs.core.first(seq__48532_49014__$1);
if(cljs.core.truth_(child_49020)){
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,child_49020);


var G__49021 = cljs.core.next(seq__48532_49014__$1);
var G__49022 = null;
var G__49023 = (0);
var G__49024 = (0);
seq__48532_49000 = G__49021;
chunk__48534_49001 = G__49022;
count__48535_49002 = G__49023;
i__48536_49003 = G__49024;
continue;
} else {
var G__49025 = cljs.core.next(seq__48532_49014__$1);
var G__49026 = null;
var G__49027 = (0);
var G__49028 = (0);
seq__48532_49000 = G__49025;
chunk__48534_49001 = G__49026;
count__48535_49002 = G__49027;
i__48536_49003 = G__49028;
continue;
}
}
} else {
}
}
break;
}
} else {
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,children_48999);
}


var G__49029 = seq__48495_48994;
var G__49030 = chunk__48496_48995;
var G__49031 = count__48497_48996;
var G__49032 = (i__48498_48997 + (1));
seq__48495_48994 = G__49029;
chunk__48496_48995 = G__49030;
count__48497_48996 = G__49031;
i__48498_48997 = G__49032;
continue;
} else {
var temp__5804__auto___49033 = cljs.core.seq(seq__48495_48994);
if(temp__5804__auto___49033){
var seq__48495_49034__$1 = temp__5804__auto___49033;
if(cljs.core.chunked_seq_QMARK_(seq__48495_49034__$1)){
var c__4591__auto___49035 = cljs.core.chunk_first(seq__48495_49034__$1);
var G__49036 = cljs.core.chunk_rest(seq__48495_49034__$1);
var G__49037 = c__4591__auto___49035;
var G__49038 = cljs.core.count(c__4591__auto___49035);
var G__49039 = (0);
seq__48495_48994 = G__49036;
chunk__48496_48995 = G__49037;
count__48497_48996 = G__49038;
i__48498_48997 = G__49039;
continue;
} else {
var child_struct_49040 = cljs.core.first(seq__48495_49034__$1);
var children_49041 = shadow.dom.dom_node(child_struct_49040);
if(cljs.core.seq_QMARK_(children_49041)){
var seq__48550_49042 = cljs.core.seq(cljs.core.map.cljs$core$IFn$_invoke$arity$2(shadow.dom.dom_node,children_49041));
var chunk__48552_49043 = null;
var count__48553_49044 = (0);
var i__48554_49045 = (0);
while(true){
if((i__48554_49045 < count__48553_49044)){
var child_49046 = chunk__48552_49043.cljs$core$IIndexed$_nth$arity$2(null,i__48554_49045);
if(cljs.core.truth_(child_49046)){
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,child_49046);


var G__49047 = seq__48550_49042;
var G__49048 = chunk__48552_49043;
var G__49049 = count__48553_49044;
var G__49050 = (i__48554_49045 + (1));
seq__48550_49042 = G__49047;
chunk__48552_49043 = G__49048;
count__48553_49044 = G__49049;
i__48554_49045 = G__49050;
continue;
} else {
var G__49051 = seq__48550_49042;
var G__49052 = chunk__48552_49043;
var G__49053 = count__48553_49044;
var G__49054 = (i__48554_49045 + (1));
seq__48550_49042 = G__49051;
chunk__48552_49043 = G__49052;
count__48553_49044 = G__49053;
i__48554_49045 = G__49054;
continue;
}
} else {
var temp__5804__auto___49055__$1 = cljs.core.seq(seq__48550_49042);
if(temp__5804__auto___49055__$1){
var seq__48550_49056__$1 = temp__5804__auto___49055__$1;
if(cljs.core.chunked_seq_QMARK_(seq__48550_49056__$1)){
var c__4591__auto___49057 = cljs.core.chunk_first(seq__48550_49056__$1);
var G__49058 = cljs.core.chunk_rest(seq__48550_49056__$1);
var G__49059 = c__4591__auto___49057;
var G__49060 = cljs.core.count(c__4591__auto___49057);
var G__49061 = (0);
seq__48550_49042 = G__49058;
chunk__48552_49043 = G__49059;
count__48553_49044 = G__49060;
i__48554_49045 = G__49061;
continue;
} else {
var child_49062 = cljs.core.first(seq__48550_49056__$1);
if(cljs.core.truth_(child_49062)){
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,child_49062);


var G__49063 = cljs.core.next(seq__48550_49056__$1);
var G__49064 = null;
var G__49065 = (0);
var G__49066 = (0);
seq__48550_49042 = G__49063;
chunk__48552_49043 = G__49064;
count__48553_49044 = G__49065;
i__48554_49045 = G__49066;
continue;
} else {
var G__49067 = cljs.core.next(seq__48550_49056__$1);
var G__49068 = null;
var G__49069 = (0);
var G__49070 = (0);
seq__48550_49042 = G__49067;
chunk__48552_49043 = G__49068;
count__48553_49044 = G__49069;
i__48554_49045 = G__49070;
continue;
}
}
} else {
}
}
break;
}
} else {
shadow.dom.append.cljs$core$IFn$_invoke$arity$2(node,children_49041);
}


var G__49071 = cljs.core.next(seq__48495_49034__$1);
var G__49072 = null;
var G__49073 = (0);
var G__49074 = (0);
seq__48495_48994 = G__49071;
chunk__48496_48995 = G__49072;
count__48497_48996 = G__49073;
i__48498_48997 = G__49074;
continue;
}
} else {
}
}
break;
}

return node;
});
(cljs.core.Keyword.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.Keyword.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var this$__$1 = this;
return shadow.dom.make_dom_node(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [this$__$1], null));
}));

(cljs.core.PersistentVector.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.PersistentVector.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var this$__$1 = this;
return shadow.dom.make_dom_node(this$__$1);
}));

(cljs.core.LazySeq.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.LazySeq.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var this$__$1 = this;
return cljs.core.map.cljs$core$IFn$_invoke$arity$2(shadow.dom._to_dom,this$__$1);
}));
if(cljs.core.truth_(((typeof HTMLElement) != 'undefined'))){
(HTMLElement.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(HTMLElement.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var this$__$1 = this;
return this$__$1;
}));
} else {
}
if(cljs.core.truth_(((typeof DocumentFragment) != 'undefined'))){
(DocumentFragment.prototype.shadow$dom$IElement$ = cljs.core.PROTOCOL_SENTINEL);

(DocumentFragment.prototype.shadow$dom$IElement$_to_dom$arity$1 = (function (this$){
var this$__$1 = this;
return this$__$1;
}));
} else {
}
/**
 * clear node children
 */
shadow.dom.reset = (function shadow$dom$reset(node){
return goog.dom.removeChildren(shadow.dom.dom_node(node));
});
shadow.dom.remove = (function shadow$dom$remove(node){
if((((!((node == null))))?(((((node.cljs$lang$protocol_mask$partition0$ & (8388608))) || ((cljs.core.PROTOCOL_SENTINEL === node.cljs$core$ISeqable$))))?true:false):false)){
var seq__48570 = cljs.core.seq(node);
var chunk__48571 = null;
var count__48572 = (0);
var i__48573 = (0);
while(true){
if((i__48573 < count__48572)){
var n = chunk__48571.cljs$core$IIndexed$_nth$arity$2(null,i__48573);
(shadow.dom.remove.cljs$core$IFn$_invoke$arity$1 ? shadow.dom.remove.cljs$core$IFn$_invoke$arity$1(n) : shadow.dom.remove.call(null,n));


var G__49075 = seq__48570;
var G__49076 = chunk__48571;
var G__49077 = count__48572;
var G__49078 = (i__48573 + (1));
seq__48570 = G__49075;
chunk__48571 = G__49076;
count__48572 = G__49077;
i__48573 = G__49078;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__48570);
if(temp__5804__auto__){
var seq__48570__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__48570__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__48570__$1);
var G__49079 = cljs.core.chunk_rest(seq__48570__$1);
var G__49080 = c__4591__auto__;
var G__49081 = cljs.core.count(c__4591__auto__);
var G__49082 = (0);
seq__48570 = G__49079;
chunk__48571 = G__49080;
count__48572 = G__49081;
i__48573 = G__49082;
continue;
} else {
var n = cljs.core.first(seq__48570__$1);
(shadow.dom.remove.cljs$core$IFn$_invoke$arity$1 ? shadow.dom.remove.cljs$core$IFn$_invoke$arity$1(n) : shadow.dom.remove.call(null,n));


var G__49083 = cljs.core.next(seq__48570__$1);
var G__49084 = null;
var G__49085 = (0);
var G__49086 = (0);
seq__48570 = G__49083;
chunk__48571 = G__49084;
count__48572 = G__49085;
i__48573 = G__49086;
continue;
}
} else {
return null;
}
}
break;
}
} else {
return goog.dom.removeNode(node);
}
});
shadow.dom.replace_node = (function shadow$dom$replace_node(old,new$){
return goog.dom.replaceNode(shadow.dom.dom_node(new$),shadow.dom.dom_node(old));
});
shadow.dom.text = (function shadow$dom$text(var_args){
var G__48581 = arguments.length;
switch (G__48581) {
case 2:
return shadow.dom.text.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 1:
return shadow.dom.text.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.text.cljs$core$IFn$_invoke$arity$2 = (function (el,new_text){
return (shadow.dom.dom_node(el).innerText = new_text);
}));

(shadow.dom.text.cljs$core$IFn$_invoke$arity$1 = (function (el){
return shadow.dom.dom_node(el).innerText;
}));

(shadow.dom.text.cljs$lang$maxFixedArity = 2);

shadow.dom.check = (function shadow$dom$check(var_args){
var G__48583 = arguments.length;
switch (G__48583) {
case 1:
return shadow.dom.check.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.check.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.check.cljs$core$IFn$_invoke$arity$1 = (function (el){
return shadow.dom.check.cljs$core$IFn$_invoke$arity$2(el,true);
}));

(shadow.dom.check.cljs$core$IFn$_invoke$arity$2 = (function (el,checked){
return (shadow.dom.dom_node(el).checked = checked);
}));

(shadow.dom.check.cljs$lang$maxFixedArity = 2);

shadow.dom.checked_QMARK_ = (function shadow$dom$checked_QMARK_(el){
return shadow.dom.dom_node(el).checked;
});
shadow.dom.form_elements = (function shadow$dom$form_elements(el){
return (new shadow.dom.NativeColl(shadow.dom.dom_node(el).elements));
});
shadow.dom.children = (function shadow$dom$children(el){
return (new shadow.dom.NativeColl(shadow.dom.dom_node(el).children));
});
shadow.dom.child_nodes = (function shadow$dom$child_nodes(el){
return (new shadow.dom.NativeColl(shadow.dom.dom_node(el).childNodes));
});
shadow.dom.attr = (function shadow$dom$attr(var_args){
var G__48591 = arguments.length;
switch (G__48591) {
case 2:
return shadow.dom.attr.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return shadow.dom.attr.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.attr.cljs$core$IFn$_invoke$arity$2 = (function (el,key){
return shadow.dom.dom_node(el).getAttribute(cljs.core.name(key));
}));

(shadow.dom.attr.cljs$core$IFn$_invoke$arity$3 = (function (el,key,default$){
var or__4160__auto__ = shadow.dom.dom_node(el).getAttribute(cljs.core.name(key));
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return default$;
}
}));

(shadow.dom.attr.cljs$lang$maxFixedArity = 3);

shadow.dom.del_attr = (function shadow$dom$del_attr(el,key){
return shadow.dom.dom_node(el).removeAttribute(cljs.core.name(key));
});
shadow.dom.data = (function shadow$dom$data(el,key){
return shadow.dom.dom_node(el).getAttribute(["data-",cljs.core.name(key)].join(''));
});
shadow.dom.set_data = (function shadow$dom$set_data(el,key,value){
return shadow.dom.dom_node(el).setAttribute(["data-",cljs.core.name(key)].join(''),cljs.core.str.cljs$core$IFn$_invoke$arity$1(value));
});
shadow.dom.set_html = (function shadow$dom$set_html(node,text){
return (shadow.dom.dom_node(node).innerHTML = text);
});
shadow.dom.get_html = (function shadow$dom$get_html(node){
return shadow.dom.dom_node(node).innerHTML;
});
shadow.dom.fragment = (function shadow$dom$fragment(var_args){
var args__4777__auto__ = [];
var len__4771__auto___49094 = arguments.length;
var i__4772__auto___49095 = (0);
while(true){
if((i__4772__auto___49095 < len__4771__auto___49094)){
args__4777__auto__.push((arguments[i__4772__auto___49095]));

var G__49096 = (i__4772__auto___49095 + (1));
i__4772__auto___49095 = G__49096;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((0) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((0)),(0),null)):null);
return shadow.dom.fragment.cljs$core$IFn$_invoke$arity$variadic(argseq__4778__auto__);
});

(shadow.dom.fragment.cljs$core$IFn$_invoke$arity$variadic = (function (nodes){
var fragment = document.createDocumentFragment();
var seq__48610_49097 = cljs.core.seq(nodes);
var chunk__48611_49098 = null;
var count__48612_49099 = (0);
var i__48613_49100 = (0);
while(true){
if((i__48613_49100 < count__48612_49099)){
var node_49101 = chunk__48611_49098.cljs$core$IIndexed$_nth$arity$2(null,i__48613_49100);
fragment.appendChild(shadow.dom._to_dom(node_49101));


var G__49102 = seq__48610_49097;
var G__49103 = chunk__48611_49098;
var G__49104 = count__48612_49099;
var G__49105 = (i__48613_49100 + (1));
seq__48610_49097 = G__49102;
chunk__48611_49098 = G__49103;
count__48612_49099 = G__49104;
i__48613_49100 = G__49105;
continue;
} else {
var temp__5804__auto___49106 = cljs.core.seq(seq__48610_49097);
if(temp__5804__auto___49106){
var seq__48610_49107__$1 = temp__5804__auto___49106;
if(cljs.core.chunked_seq_QMARK_(seq__48610_49107__$1)){
var c__4591__auto___49108 = cljs.core.chunk_first(seq__48610_49107__$1);
var G__49109 = cljs.core.chunk_rest(seq__48610_49107__$1);
var G__49110 = c__4591__auto___49108;
var G__49111 = cljs.core.count(c__4591__auto___49108);
var G__49112 = (0);
seq__48610_49097 = G__49109;
chunk__48611_49098 = G__49110;
count__48612_49099 = G__49111;
i__48613_49100 = G__49112;
continue;
} else {
var node_49113 = cljs.core.first(seq__48610_49107__$1);
fragment.appendChild(shadow.dom._to_dom(node_49113));


var G__49114 = cljs.core.next(seq__48610_49107__$1);
var G__49115 = null;
var G__49116 = (0);
var G__49117 = (0);
seq__48610_49097 = G__49114;
chunk__48611_49098 = G__49115;
count__48612_49099 = G__49116;
i__48613_49100 = G__49117;
continue;
}
} else {
}
}
break;
}

return (new shadow.dom.NativeColl(fragment));
}));

(shadow.dom.fragment.cljs$lang$maxFixedArity = (0));

/** @this {Function} */
(shadow.dom.fragment.cljs$lang$applyTo = (function (seq48607){
var self__4759__auto__ = this;
return self__4759__auto__.cljs$core$IFn$_invoke$arity$variadic(cljs.core.seq(seq48607));
}));

/**
 * given a html string, eval all <script> tags and return the html without the scripts
 * don't do this for everything, only content you trust.
 */
shadow.dom.eval_scripts = (function shadow$dom$eval_scripts(s){
var scripts = cljs.core.re_seq(/<script[^>]*?>(.+?)<\/script>/,s);
var seq__48619_49118 = cljs.core.seq(scripts);
var chunk__48620_49119 = null;
var count__48621_49120 = (0);
var i__48622_49121 = (0);
while(true){
if((i__48622_49121 < count__48621_49120)){
var vec__48632_49123 = chunk__48620_49119.cljs$core$IIndexed$_nth$arity$2(null,i__48622_49121);
var script_tag_49124 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48632_49123,(0),null);
var script_body_49125 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48632_49123,(1),null);
eval(script_body_49125);


var G__49126 = seq__48619_49118;
var G__49127 = chunk__48620_49119;
var G__49128 = count__48621_49120;
var G__49129 = (i__48622_49121 + (1));
seq__48619_49118 = G__49126;
chunk__48620_49119 = G__49127;
count__48621_49120 = G__49128;
i__48622_49121 = G__49129;
continue;
} else {
var temp__5804__auto___49130 = cljs.core.seq(seq__48619_49118);
if(temp__5804__auto___49130){
var seq__48619_49131__$1 = temp__5804__auto___49130;
if(cljs.core.chunked_seq_QMARK_(seq__48619_49131__$1)){
var c__4591__auto___49132 = cljs.core.chunk_first(seq__48619_49131__$1);
var G__49133 = cljs.core.chunk_rest(seq__48619_49131__$1);
var G__49134 = c__4591__auto___49132;
var G__49135 = cljs.core.count(c__4591__auto___49132);
var G__49136 = (0);
seq__48619_49118 = G__49133;
chunk__48620_49119 = G__49134;
count__48621_49120 = G__49135;
i__48622_49121 = G__49136;
continue;
} else {
var vec__48636_49137 = cljs.core.first(seq__48619_49131__$1);
var script_tag_49138 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48636_49137,(0),null);
var script_body_49139 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48636_49137,(1),null);
eval(script_body_49139);


var G__49140 = cljs.core.next(seq__48619_49131__$1);
var G__49141 = null;
var G__49142 = (0);
var G__49143 = (0);
seq__48619_49118 = G__49140;
chunk__48620_49119 = G__49141;
count__48621_49120 = G__49142;
i__48622_49121 = G__49143;
continue;
}
} else {
}
}
break;
}

return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3((function (s__$1,p__48639){
var vec__48640 = p__48639;
var script_tag = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48640,(0),null);
var script_body = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48640,(1),null);
return clojure.string.replace(s__$1,script_tag,"");
}),s,scripts);
});
shadow.dom.str__GT_fragment = (function shadow$dom$str__GT_fragment(s){
var el = document.createElement("div");
(el.innerHTML = s);

return (new shadow.dom.NativeColl(goog.dom.childrenToNode_(document,el)));
});
shadow.dom.node_name = (function shadow$dom$node_name(el){
return shadow.dom.dom_node(el).nodeName;
});
shadow.dom.ancestor_by_class = (function shadow$dom$ancestor_by_class(el,cls){
return goog.dom.getAncestorByClass(shadow.dom.dom_node(el),cls);
});
shadow.dom.ancestor_by_tag = (function shadow$dom$ancestor_by_tag(var_args){
var G__48648 = arguments.length;
switch (G__48648) {
case 2:
return shadow.dom.ancestor_by_tag.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return shadow.dom.ancestor_by_tag.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.ancestor_by_tag.cljs$core$IFn$_invoke$arity$2 = (function (el,tag){
return goog.dom.getAncestorByTagNameAndClass(shadow.dom.dom_node(el),cljs.core.name(tag));
}));

(shadow.dom.ancestor_by_tag.cljs$core$IFn$_invoke$arity$3 = (function (el,tag,cls){
return goog.dom.getAncestorByTagNameAndClass(shadow.dom.dom_node(el),cljs.core.name(tag),cljs.core.name(cls));
}));

(shadow.dom.ancestor_by_tag.cljs$lang$maxFixedArity = 3);

shadow.dom.get_value = (function shadow$dom$get_value(dom){
return goog.dom.forms.getValue(shadow.dom.dom_node(dom));
});
shadow.dom.set_value = (function shadow$dom$set_value(dom,value){
return goog.dom.forms.setValue(shadow.dom.dom_node(dom),value);
});
shadow.dom.px = (function shadow$dom$px(value){
return [cljs.core.str.cljs$core$IFn$_invoke$arity$1((value | (0))),"px"].join('');
});
shadow.dom.pct = (function shadow$dom$pct(value){
return [cljs.core.str.cljs$core$IFn$_invoke$arity$1(value),"%"].join('');
});
shadow.dom.remove_style_STAR_ = (function shadow$dom$remove_style_STAR_(el,style){
return el.style.removeProperty(cljs.core.name(style));
});
shadow.dom.remove_style = (function shadow$dom$remove_style(el,style){
var el__$1 = shadow.dom.dom_node(el);
return shadow.dom.remove_style_STAR_(el__$1,style);
});
shadow.dom.remove_styles = (function shadow$dom$remove_styles(el,style_keys){
var el__$1 = shadow.dom.dom_node(el);
var seq__48666 = cljs.core.seq(style_keys);
var chunk__48667 = null;
var count__48668 = (0);
var i__48669 = (0);
while(true){
if((i__48669 < count__48668)){
var it = chunk__48667.cljs$core$IIndexed$_nth$arity$2(null,i__48669);
shadow.dom.remove_style_STAR_(el__$1,it);


var G__49146 = seq__48666;
var G__49147 = chunk__48667;
var G__49148 = count__48668;
var G__49149 = (i__48669 + (1));
seq__48666 = G__49146;
chunk__48667 = G__49147;
count__48668 = G__49148;
i__48669 = G__49149;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__48666);
if(temp__5804__auto__){
var seq__48666__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__48666__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__48666__$1);
var G__49150 = cljs.core.chunk_rest(seq__48666__$1);
var G__49151 = c__4591__auto__;
var G__49152 = cljs.core.count(c__4591__auto__);
var G__49153 = (0);
seq__48666 = G__49150;
chunk__48667 = G__49151;
count__48668 = G__49152;
i__48669 = G__49153;
continue;
} else {
var it = cljs.core.first(seq__48666__$1);
shadow.dom.remove_style_STAR_(el__$1,it);


var G__49154 = cljs.core.next(seq__48666__$1);
var G__49155 = null;
var G__49156 = (0);
var G__49157 = (0);
seq__48666 = G__49154;
chunk__48667 = G__49155;
count__48668 = G__49156;
i__48669 = G__49157;
continue;
}
} else {
return null;
}
}
break;
}
});

/**
* @constructor
 * @implements {cljs.core.IRecord}
 * @implements {cljs.core.IKVReduce}
 * @implements {cljs.core.IEquiv}
 * @implements {cljs.core.IHash}
 * @implements {cljs.core.ICollection}
 * @implements {cljs.core.ICounted}
 * @implements {cljs.core.ISeqable}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.ICloneable}
 * @implements {cljs.core.IPrintWithWriter}
 * @implements {cljs.core.IIterable}
 * @implements {cljs.core.IWithMeta}
 * @implements {cljs.core.IAssociative}
 * @implements {cljs.core.IMap}
 * @implements {cljs.core.ILookup}
*/
shadow.dom.Coordinate = (function (x,y,__meta,__extmap,__hash){
this.x = x;
this.y = y;
this.__meta = __meta;
this.__extmap = __extmap;
this.__hash = __hash;
this.cljs$lang$protocol_mask$partition0$ = 2230716170;
this.cljs$lang$protocol_mask$partition1$ = 139264;
});
(shadow.dom.Coordinate.prototype.cljs$core$ILookup$_lookup$arity$2 = (function (this__4415__auto__,k__4416__auto__){
var self__ = this;
var this__4415__auto____$1 = this;
return this__4415__auto____$1.cljs$core$ILookup$_lookup$arity$3(null,k__4416__auto__,null);
}));

(shadow.dom.Coordinate.prototype.cljs$core$ILookup$_lookup$arity$3 = (function (this__4417__auto__,k48675,else__4418__auto__){
var self__ = this;
var this__4417__auto____$1 = this;
var G__48683 = k48675;
var G__48683__$1 = (((G__48683 instanceof cljs.core.Keyword))?G__48683.fqn:null);
switch (G__48683__$1) {
case "x":
return self__.x;

break;
case "y":
return self__.y;

break;
default:
return cljs.core.get.cljs$core$IFn$_invoke$arity$3(self__.__extmap,k48675,else__4418__auto__);

}
}));

(shadow.dom.Coordinate.prototype.cljs$core$IKVReduce$_kv_reduce$arity$3 = (function (this__4434__auto__,f__4435__auto__,init__4436__auto__){
var self__ = this;
var this__4434__auto____$1 = this;
return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3((function (ret__4437__auto__,p__48687){
var vec__48689 = p__48687;
var k__4438__auto__ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48689,(0),null);
var v__4439__auto__ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48689,(1),null);
return (f__4435__auto__.cljs$core$IFn$_invoke$arity$3 ? f__4435__auto__.cljs$core$IFn$_invoke$arity$3(ret__4437__auto__,k__4438__auto__,v__4439__auto__) : f__4435__auto__.call(null,ret__4437__auto__,k__4438__auto__,v__4439__auto__));
}),init__4436__auto__,this__4434__auto____$1);
}));

(shadow.dom.Coordinate.prototype.cljs$core$IPrintWithWriter$_pr_writer$arity$3 = (function (this__4429__auto__,writer__4430__auto__,opts__4431__auto__){
var self__ = this;
var this__4429__auto____$1 = this;
var pr_pair__4432__auto__ = (function (keyval__4433__auto__){
return cljs.core.pr_sequential_writer(writer__4430__auto__,cljs.core.pr_writer,""," ","",opts__4431__auto__,keyval__4433__auto__);
});
return cljs.core.pr_sequential_writer(writer__4430__auto__,pr_pair__4432__auto__,"#shadow.dom.Coordinate{",", ","}",opts__4431__auto__,cljs.core.concat.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[new cljs.core.Keyword(null,"x","x",2099068185),self__.x],null)),(new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[new cljs.core.Keyword(null,"y","y",-1757859776),self__.y],null))], null),self__.__extmap));
}));

(shadow.dom.Coordinate.prototype.cljs$core$IIterable$_iterator$arity$1 = (function (G__48674){
var self__ = this;
var G__48674__$1 = this;
return (new cljs.core.RecordIter((0),G__48674__$1,2,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"x","x",2099068185),new cljs.core.Keyword(null,"y","y",-1757859776)], null),(cljs.core.truth_(self__.__extmap)?cljs.core._iterator(self__.__extmap):cljs.core.nil_iter())));
}));

(shadow.dom.Coordinate.prototype.cljs$core$IMeta$_meta$arity$1 = (function (this__4413__auto__){
var self__ = this;
var this__4413__auto____$1 = this;
return self__.__meta;
}));

(shadow.dom.Coordinate.prototype.cljs$core$ICloneable$_clone$arity$1 = (function (this__4410__auto__){
var self__ = this;
var this__4410__auto____$1 = this;
return (new shadow.dom.Coordinate(self__.x,self__.y,self__.__meta,self__.__extmap,self__.__hash));
}));

(shadow.dom.Coordinate.prototype.cljs$core$ICounted$_count$arity$1 = (function (this__4419__auto__){
var self__ = this;
var this__4419__auto____$1 = this;
return (2 + cljs.core.count(self__.__extmap));
}));

(shadow.dom.Coordinate.prototype.cljs$core$IHash$_hash$arity$1 = (function (this__4411__auto__){
var self__ = this;
var this__4411__auto____$1 = this;
var h__4273__auto__ = self__.__hash;
if((!((h__4273__auto__ == null)))){
return h__4273__auto__;
} else {
var h__4273__auto____$1 = (function (coll__4412__auto__){
return (145542109 ^ cljs.core.hash_unordered_coll(coll__4412__auto__));
})(this__4411__auto____$1);
(self__.__hash = h__4273__auto____$1);

return h__4273__auto____$1;
}
}));

(shadow.dom.Coordinate.prototype.cljs$core$IEquiv$_equiv$arity$2 = (function (this48676,other48677){
var self__ = this;
var this48676__$1 = this;
return (((!((other48677 == null)))) && ((this48676__$1.constructor === other48677.constructor)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48676__$1.x,other48677.x)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48676__$1.y,other48677.y)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48676__$1.__extmap,other48677.__extmap)));
}));

(shadow.dom.Coordinate.prototype.cljs$core$IMap$_dissoc$arity$2 = (function (this__4424__auto__,k__4425__auto__){
var self__ = this;
var this__4424__auto____$1 = this;
if(cljs.core.contains_QMARK_(new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"y","y",-1757859776),null,new cljs.core.Keyword(null,"x","x",2099068185),null], null), null),k__4425__auto__)){
return cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(cljs.core._with_meta(cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,this__4424__auto____$1),self__.__meta),k__4425__auto__);
} else {
return (new shadow.dom.Coordinate(self__.x,self__.y,self__.__meta,cljs.core.not_empty(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(self__.__extmap,k__4425__auto__)),null));
}
}));

(shadow.dom.Coordinate.prototype.cljs$core$IAssociative$_assoc$arity$3 = (function (this__4422__auto__,k__4423__auto__,G__48674){
var self__ = this;
var this__4422__auto____$1 = this;
var pred__48706 = cljs.core.keyword_identical_QMARK_;
var expr__48707 = k__4423__auto__;
if(cljs.core.truth_((pred__48706.cljs$core$IFn$_invoke$arity$2 ? pred__48706.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"x","x",2099068185),expr__48707) : pred__48706.call(null,new cljs.core.Keyword(null,"x","x",2099068185),expr__48707)))){
return (new shadow.dom.Coordinate(G__48674,self__.y,self__.__meta,self__.__extmap,null));
} else {
if(cljs.core.truth_((pred__48706.cljs$core$IFn$_invoke$arity$2 ? pred__48706.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"y","y",-1757859776),expr__48707) : pred__48706.call(null,new cljs.core.Keyword(null,"y","y",-1757859776),expr__48707)))){
return (new shadow.dom.Coordinate(self__.x,G__48674,self__.__meta,self__.__extmap,null));
} else {
return (new shadow.dom.Coordinate(self__.x,self__.y,self__.__meta,cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(self__.__extmap,k__4423__auto__,G__48674),null));
}
}
}));

(shadow.dom.Coordinate.prototype.cljs$core$ISeqable$_seq$arity$1 = (function (this__4427__auto__){
var self__ = this;
var this__4427__auto____$1 = this;
return cljs.core.seq(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(new cljs.core.MapEntry(new cljs.core.Keyword(null,"x","x",2099068185),self__.x,null)),(new cljs.core.MapEntry(new cljs.core.Keyword(null,"y","y",-1757859776),self__.y,null))], null),self__.__extmap));
}));

(shadow.dom.Coordinate.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (this__4414__auto__,G__48674){
var self__ = this;
var this__4414__auto____$1 = this;
return (new shadow.dom.Coordinate(self__.x,self__.y,G__48674,self__.__extmap,self__.__hash));
}));

(shadow.dom.Coordinate.prototype.cljs$core$ICollection$_conj$arity$2 = (function (this__4420__auto__,entry__4421__auto__){
var self__ = this;
var this__4420__auto____$1 = this;
if(cljs.core.vector_QMARK_(entry__4421__auto__)){
return this__4420__auto____$1.cljs$core$IAssociative$_assoc$arity$3(null,cljs.core._nth(entry__4421__auto__,(0)),cljs.core._nth(entry__4421__auto__,(1)));
} else {
return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3(cljs.core._conj,this__4420__auto____$1,entry__4421__auto__);
}
}));

(shadow.dom.Coordinate.getBasis = (function (){
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"x","x",-555367584,null),new cljs.core.Symbol(null,"y","y",-117328249,null)], null);
}));

(shadow.dom.Coordinate.cljs$lang$type = true);

(shadow.dom.Coordinate.cljs$lang$ctorPrSeq = (function (this__4458__auto__){
return (new cljs.core.List(null,"shadow.dom/Coordinate",null,(1),null));
}));

(shadow.dom.Coordinate.cljs$lang$ctorPrWriter = (function (this__4458__auto__,writer__4459__auto__){
return cljs.core._write(writer__4459__auto__,"shadow.dom/Coordinate");
}));

/**
 * Positional factory function for shadow.dom/Coordinate.
 */
shadow.dom.__GT_Coordinate = (function shadow$dom$__GT_Coordinate(x,y){
return (new shadow.dom.Coordinate(x,y,null,null,null));
});

/**
 * Factory function for shadow.dom/Coordinate, taking a map of keywords to field values.
 */
shadow.dom.map__GT_Coordinate = (function shadow$dom$map__GT_Coordinate(G__48678){
var extmap__4454__auto__ = (function (){var G__48715 = cljs.core.dissoc.cljs$core$IFn$_invoke$arity$variadic(G__48678,new cljs.core.Keyword(null,"x","x",2099068185),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"y","y",-1757859776)], 0));
if(cljs.core.record_QMARK_(G__48678)){
return cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,G__48715);
} else {
return G__48715;
}
})();
return (new shadow.dom.Coordinate(new cljs.core.Keyword(null,"x","x",2099068185).cljs$core$IFn$_invoke$arity$1(G__48678),new cljs.core.Keyword(null,"y","y",-1757859776).cljs$core$IFn$_invoke$arity$1(G__48678),null,cljs.core.not_empty(extmap__4454__auto__),null));
});

shadow.dom.get_position = (function shadow$dom$get_position(el){
var pos = goog.style.getPosition(shadow.dom.dom_node(el));
return shadow.dom.__GT_Coordinate(pos.x,pos.y);
});
shadow.dom.get_client_position = (function shadow$dom$get_client_position(el){
var pos = goog.style.getClientPosition(shadow.dom.dom_node(el));
return shadow.dom.__GT_Coordinate(pos.x,pos.y);
});
shadow.dom.get_page_offset = (function shadow$dom$get_page_offset(el){
var pos = goog.style.getPageOffset(shadow.dom.dom_node(el));
return shadow.dom.__GT_Coordinate(pos.x,pos.y);
});

/**
* @constructor
 * @implements {cljs.core.IRecord}
 * @implements {cljs.core.IKVReduce}
 * @implements {cljs.core.IEquiv}
 * @implements {cljs.core.IHash}
 * @implements {cljs.core.ICollection}
 * @implements {cljs.core.ICounted}
 * @implements {cljs.core.ISeqable}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.ICloneable}
 * @implements {cljs.core.IPrintWithWriter}
 * @implements {cljs.core.IIterable}
 * @implements {cljs.core.IWithMeta}
 * @implements {cljs.core.IAssociative}
 * @implements {cljs.core.IMap}
 * @implements {cljs.core.ILookup}
*/
shadow.dom.Size = (function (w,h,__meta,__extmap,__hash){
this.w = w;
this.h = h;
this.__meta = __meta;
this.__extmap = __extmap;
this.__hash = __hash;
this.cljs$lang$protocol_mask$partition0$ = 2230716170;
this.cljs$lang$protocol_mask$partition1$ = 139264;
});
(shadow.dom.Size.prototype.cljs$core$ILookup$_lookup$arity$2 = (function (this__4415__auto__,k__4416__auto__){
var self__ = this;
var this__4415__auto____$1 = this;
return this__4415__auto____$1.cljs$core$ILookup$_lookup$arity$3(null,k__4416__auto__,null);
}));

(shadow.dom.Size.prototype.cljs$core$ILookup$_lookup$arity$3 = (function (this__4417__auto__,k48724,else__4418__auto__){
var self__ = this;
var this__4417__auto____$1 = this;
var G__48733 = k48724;
var G__48733__$1 = (((G__48733 instanceof cljs.core.Keyword))?G__48733.fqn:null);
switch (G__48733__$1) {
case "w":
return self__.w;

break;
case "h":
return self__.h;

break;
default:
return cljs.core.get.cljs$core$IFn$_invoke$arity$3(self__.__extmap,k48724,else__4418__auto__);

}
}));

(shadow.dom.Size.prototype.cljs$core$IKVReduce$_kv_reduce$arity$3 = (function (this__4434__auto__,f__4435__auto__,init__4436__auto__){
var self__ = this;
var this__4434__auto____$1 = this;
return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3((function (ret__4437__auto__,p__48736){
var vec__48737 = p__48736;
var k__4438__auto__ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48737,(0),null);
var v__4439__auto__ = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48737,(1),null);
return (f__4435__auto__.cljs$core$IFn$_invoke$arity$3 ? f__4435__auto__.cljs$core$IFn$_invoke$arity$3(ret__4437__auto__,k__4438__auto__,v__4439__auto__) : f__4435__auto__.call(null,ret__4437__auto__,k__4438__auto__,v__4439__auto__));
}),init__4436__auto__,this__4434__auto____$1);
}));

(shadow.dom.Size.prototype.cljs$core$IPrintWithWriter$_pr_writer$arity$3 = (function (this__4429__auto__,writer__4430__auto__,opts__4431__auto__){
var self__ = this;
var this__4429__auto____$1 = this;
var pr_pair__4432__auto__ = (function (keyval__4433__auto__){
return cljs.core.pr_sequential_writer(writer__4430__auto__,cljs.core.pr_writer,""," ","",opts__4431__auto__,keyval__4433__auto__);
});
return cljs.core.pr_sequential_writer(writer__4430__auto__,pr_pair__4432__auto__,"#shadow.dom.Size{",", ","}",opts__4431__auto__,cljs.core.concat.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[new cljs.core.Keyword(null,"w","w",354169001),self__.w],null)),(new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[new cljs.core.Keyword(null,"h","h",1109658740),self__.h],null))], null),self__.__extmap));
}));

(shadow.dom.Size.prototype.cljs$core$IIterable$_iterator$arity$1 = (function (G__48723){
var self__ = this;
var G__48723__$1 = this;
return (new cljs.core.RecordIter((0),G__48723__$1,2,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"w","w",354169001),new cljs.core.Keyword(null,"h","h",1109658740)], null),(cljs.core.truth_(self__.__extmap)?cljs.core._iterator(self__.__extmap):cljs.core.nil_iter())));
}));

(shadow.dom.Size.prototype.cljs$core$IMeta$_meta$arity$1 = (function (this__4413__auto__){
var self__ = this;
var this__4413__auto____$1 = this;
return self__.__meta;
}));

(shadow.dom.Size.prototype.cljs$core$ICloneable$_clone$arity$1 = (function (this__4410__auto__){
var self__ = this;
var this__4410__auto____$1 = this;
return (new shadow.dom.Size(self__.w,self__.h,self__.__meta,self__.__extmap,self__.__hash));
}));

(shadow.dom.Size.prototype.cljs$core$ICounted$_count$arity$1 = (function (this__4419__auto__){
var self__ = this;
var this__4419__auto____$1 = this;
return (2 + cljs.core.count(self__.__extmap));
}));

(shadow.dom.Size.prototype.cljs$core$IHash$_hash$arity$1 = (function (this__4411__auto__){
var self__ = this;
var this__4411__auto____$1 = this;
var h__4273__auto__ = self__.__hash;
if((!((h__4273__auto__ == null)))){
return h__4273__auto__;
} else {
var h__4273__auto____$1 = (function (coll__4412__auto__){
return (-1228019642 ^ cljs.core.hash_unordered_coll(coll__4412__auto__));
})(this__4411__auto____$1);
(self__.__hash = h__4273__auto____$1);

return h__4273__auto____$1;
}
}));

(shadow.dom.Size.prototype.cljs$core$IEquiv$_equiv$arity$2 = (function (this48725,other48726){
var self__ = this;
var this48725__$1 = this;
return (((!((other48726 == null)))) && ((this48725__$1.constructor === other48726.constructor)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48725__$1.w,other48726.w)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48725__$1.h,other48726.h)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(this48725__$1.__extmap,other48726.__extmap)));
}));

(shadow.dom.Size.prototype.cljs$core$IMap$_dissoc$arity$2 = (function (this__4424__auto__,k__4425__auto__){
var self__ = this;
var this__4424__auto____$1 = this;
if(cljs.core.contains_QMARK_(new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"w","w",354169001),null,new cljs.core.Keyword(null,"h","h",1109658740),null], null), null),k__4425__auto__)){
return cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(cljs.core._with_meta(cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,this__4424__auto____$1),self__.__meta),k__4425__auto__);
} else {
return (new shadow.dom.Size(self__.w,self__.h,self__.__meta,cljs.core.not_empty(cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(self__.__extmap,k__4425__auto__)),null));
}
}));

(shadow.dom.Size.prototype.cljs$core$IAssociative$_assoc$arity$3 = (function (this__4422__auto__,k__4423__auto__,G__48723){
var self__ = this;
var this__4422__auto____$1 = this;
var pred__48752 = cljs.core.keyword_identical_QMARK_;
var expr__48753 = k__4423__auto__;
if(cljs.core.truth_((pred__48752.cljs$core$IFn$_invoke$arity$2 ? pred__48752.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"w","w",354169001),expr__48753) : pred__48752.call(null,new cljs.core.Keyword(null,"w","w",354169001),expr__48753)))){
return (new shadow.dom.Size(G__48723,self__.h,self__.__meta,self__.__extmap,null));
} else {
if(cljs.core.truth_((pred__48752.cljs$core$IFn$_invoke$arity$2 ? pred__48752.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"h","h",1109658740),expr__48753) : pred__48752.call(null,new cljs.core.Keyword(null,"h","h",1109658740),expr__48753)))){
return (new shadow.dom.Size(self__.w,G__48723,self__.__meta,self__.__extmap,null));
} else {
return (new shadow.dom.Size(self__.w,self__.h,self__.__meta,cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(self__.__extmap,k__4423__auto__,G__48723),null));
}
}
}));

(shadow.dom.Size.prototype.cljs$core$ISeqable$_seq$arity$1 = (function (this__4427__auto__){
var self__ = this;
var this__4427__auto____$1 = this;
return cljs.core.seq(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [(new cljs.core.MapEntry(new cljs.core.Keyword(null,"w","w",354169001),self__.w,null)),(new cljs.core.MapEntry(new cljs.core.Keyword(null,"h","h",1109658740),self__.h,null))], null),self__.__extmap));
}));

(shadow.dom.Size.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (this__4414__auto__,G__48723){
var self__ = this;
var this__4414__auto____$1 = this;
return (new shadow.dom.Size(self__.w,self__.h,G__48723,self__.__extmap,self__.__hash));
}));

(shadow.dom.Size.prototype.cljs$core$ICollection$_conj$arity$2 = (function (this__4420__auto__,entry__4421__auto__){
var self__ = this;
var this__4420__auto____$1 = this;
if(cljs.core.vector_QMARK_(entry__4421__auto__)){
return this__4420__auto____$1.cljs$core$IAssociative$_assoc$arity$3(null,cljs.core._nth(entry__4421__auto__,(0)),cljs.core._nth(entry__4421__auto__,(1)));
} else {
return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3(cljs.core._conj,this__4420__auto____$1,entry__4421__auto__);
}
}));

(shadow.dom.Size.getBasis = (function (){
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"w","w",1994700528,null),new cljs.core.Symbol(null,"h","h",-1544777029,null)], null);
}));

(shadow.dom.Size.cljs$lang$type = true);

(shadow.dom.Size.cljs$lang$ctorPrSeq = (function (this__4458__auto__){
return (new cljs.core.List(null,"shadow.dom/Size",null,(1),null));
}));

(shadow.dom.Size.cljs$lang$ctorPrWriter = (function (this__4458__auto__,writer__4459__auto__){
return cljs.core._write(writer__4459__auto__,"shadow.dom/Size");
}));

/**
 * Positional factory function for shadow.dom/Size.
 */
shadow.dom.__GT_Size = (function shadow$dom$__GT_Size(w,h){
return (new shadow.dom.Size(w,h,null,null,null));
});

/**
 * Factory function for shadow.dom/Size, taking a map of keywords to field values.
 */
shadow.dom.map__GT_Size = (function shadow$dom$map__GT_Size(G__48728){
var extmap__4454__auto__ = (function (){var G__48762 = cljs.core.dissoc.cljs$core$IFn$_invoke$arity$variadic(G__48728,new cljs.core.Keyword(null,"w","w",354169001),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"h","h",1109658740)], 0));
if(cljs.core.record_QMARK_(G__48728)){
return cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentArrayMap.EMPTY,G__48762);
} else {
return G__48762;
}
})();
return (new shadow.dom.Size(new cljs.core.Keyword(null,"w","w",354169001).cljs$core$IFn$_invoke$arity$1(G__48728),new cljs.core.Keyword(null,"h","h",1109658740).cljs$core$IFn$_invoke$arity$1(G__48728),null,cljs.core.not_empty(extmap__4454__auto__),null));
});

shadow.dom.size__GT_clj = (function shadow$dom$size__GT_clj(size){
return (new shadow.dom.Size(size.width,size.height,null,null,null));
});
shadow.dom.get_size = (function shadow$dom$get_size(el){
return shadow.dom.size__GT_clj(goog.style.getSize(shadow.dom.dom_node(el)));
});
shadow.dom.get_height = (function shadow$dom$get_height(el){
return shadow.dom.get_size(el).h;
});
shadow.dom.get_viewport_size = (function shadow$dom$get_viewport_size(){
return shadow.dom.size__GT_clj(goog.dom.getViewportSize());
});
shadow.dom.first_child = (function shadow$dom$first_child(el){
return (shadow.dom.dom_node(el).children[(0)]);
});
shadow.dom.select_option_values = (function shadow$dom$select_option_values(el){
var native$ = shadow.dom.dom_node(el);
var opts = (native$["options"]);
var a__4645__auto__ = opts;
var l__4646__auto__ = a__4645__auto__.length;
var i = (0);
var ret = cljs.core.PersistentVector.EMPTY;
while(true){
if((i < l__4646__auto__)){
var G__49167 = (i + (1));
var G__49168 = cljs.core.conj.cljs$core$IFn$_invoke$arity$2(ret,(opts[i]["value"]));
i = G__49167;
ret = G__49168;
continue;
} else {
return ret;
}
break;
}
});
shadow.dom.build_url = (function shadow$dom$build_url(path,query_params){
if(cljs.core.empty_QMARK_(query_params)){
return path;
} else {
return [cljs.core.str.cljs$core$IFn$_invoke$arity$1(path),"?",clojure.string.join.cljs$core$IFn$_invoke$arity$2("&",cljs.core.map.cljs$core$IFn$_invoke$arity$2((function (p__48767){
var vec__48768 = p__48767;
var k = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48768,(0),null);
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48768,(1),null);
return [cljs.core.name(k),"=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(encodeURIComponent(cljs.core.str.cljs$core$IFn$_invoke$arity$1(v)))].join('');
}),query_params))].join('');
}
});
shadow.dom.redirect = (function shadow$dom$redirect(var_args){
var G__48773 = arguments.length;
switch (G__48773) {
case 1:
return shadow.dom.redirect.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return shadow.dom.redirect.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.redirect.cljs$core$IFn$_invoke$arity$1 = (function (path){
return shadow.dom.redirect.cljs$core$IFn$_invoke$arity$2(path,cljs.core.PersistentArrayMap.EMPTY);
}));

(shadow.dom.redirect.cljs$core$IFn$_invoke$arity$2 = (function (path,query_params){
return (document["location"]["href"] = shadow.dom.build_url(path,query_params));
}));

(shadow.dom.redirect.cljs$lang$maxFixedArity = 2);

shadow.dom.reload_BANG_ = (function shadow$dom$reload_BANG_(){
return (document.location.href = document.location.href);
});
shadow.dom.tag_name = (function shadow$dom$tag_name(el){
var dom = shadow.dom.dom_node(el);
return dom.tagName;
});
shadow.dom.insert_after = (function shadow$dom$insert_after(ref,new$){
var new_node = shadow.dom.dom_node(new$);
goog.dom.insertSiblingAfter(new_node,shadow.dom.dom_node(ref));

return new_node;
});
shadow.dom.insert_before = (function shadow$dom$insert_before(ref,new$){
var new_node = shadow.dom.dom_node(new$);
goog.dom.insertSiblingBefore(new_node,shadow.dom.dom_node(ref));

return new_node;
});
shadow.dom.insert_first = (function shadow$dom$insert_first(ref,new$){
var temp__5802__auto__ = shadow.dom.dom_node(ref).firstChild;
if(cljs.core.truth_(temp__5802__auto__)){
var child = temp__5802__auto__;
return shadow.dom.insert_before(child,new$);
} else {
return shadow.dom.append.cljs$core$IFn$_invoke$arity$2(ref,new$);
}
});
shadow.dom.index_of = (function shadow$dom$index_of(el){
var el__$1 = shadow.dom.dom_node(el);
var i = (0);
while(true){
var ps = el__$1.previousSibling;
if((ps == null)){
return i;
} else {
var G__49173 = ps;
var G__49174 = (i + (1));
el__$1 = G__49173;
i = G__49174;
continue;
}
break;
}
});
shadow.dom.get_parent = (function shadow$dom$get_parent(el){
return goog.dom.getParentElement(shadow.dom.dom_node(el));
});
shadow.dom.parents = (function shadow$dom$parents(el){
var parent = shadow.dom.get_parent(el);
if(cljs.core.truth_(parent)){
return cljs.core.cons(parent,(new cljs.core.LazySeq(null,(function (){
return (shadow.dom.parents.cljs$core$IFn$_invoke$arity$1 ? shadow.dom.parents.cljs$core$IFn$_invoke$arity$1(parent) : shadow.dom.parents.call(null,parent));
}),null,null)));
} else {
return null;
}
});
shadow.dom.matches = (function shadow$dom$matches(el,sel){
return shadow.dom.dom_node(el).matches(sel);
});
shadow.dom.get_next_sibling = (function shadow$dom$get_next_sibling(el){
return goog.dom.getNextElementSibling(shadow.dom.dom_node(el));
});
shadow.dom.get_previous_sibling = (function shadow$dom$get_previous_sibling(el){
return goog.dom.getPreviousElementSibling(shadow.dom.dom_node(el));
});
shadow.dom.xmlns = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(new cljs.core.PersistentArrayMap(null, 2, ["svg","http://www.w3.org/2000/svg","xlink","http://www.w3.org/1999/xlink"], null));
shadow.dom.create_svg_node = (function shadow$dom$create_svg_node(tag_def,props){
var vec__48798 = shadow.dom.parse_tag(tag_def);
var tag_name = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48798,(0),null);
var tag_id = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48798,(1),null);
var tag_classes = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48798,(2),null);
var el = document.createElementNS("http://www.w3.org/2000/svg",tag_name);
if(cljs.core.truth_(tag_id)){
el.setAttribute("id",tag_id);
} else {
}

if(cljs.core.truth_(tag_classes)){
el.setAttribute("class",shadow.dom.merge_class_string(new cljs.core.Keyword(null,"class","class",-2030961996).cljs$core$IFn$_invoke$arity$1(props),tag_classes));
} else {
}

var seq__48802_49175 = cljs.core.seq(props);
var chunk__48803_49176 = null;
var count__48804_49177 = (0);
var i__48805_49178 = (0);
while(true){
if((i__48805_49178 < count__48804_49177)){
var vec__48820_49179 = chunk__48803_49176.cljs$core$IIndexed$_nth$arity$2(null,i__48805_49178);
var k_49180 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48820_49179,(0),null);
var v_49181 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48820_49179,(1),null);
el.setAttributeNS((function (){var temp__5804__auto__ = cljs.core.namespace(k_49180);
if(cljs.core.truth_(temp__5804__auto__)){
var ns = temp__5804__auto__;
return cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(shadow.dom.xmlns),ns);
} else {
return null;
}
})(),cljs.core.name(k_49180),v_49181);


var G__49182 = seq__48802_49175;
var G__49183 = chunk__48803_49176;
var G__49184 = count__48804_49177;
var G__49185 = (i__48805_49178 + (1));
seq__48802_49175 = G__49182;
chunk__48803_49176 = G__49183;
count__48804_49177 = G__49184;
i__48805_49178 = G__49185;
continue;
} else {
var temp__5804__auto___49186 = cljs.core.seq(seq__48802_49175);
if(temp__5804__auto___49186){
var seq__48802_49187__$1 = temp__5804__auto___49186;
if(cljs.core.chunked_seq_QMARK_(seq__48802_49187__$1)){
var c__4591__auto___49188 = cljs.core.chunk_first(seq__48802_49187__$1);
var G__49189 = cljs.core.chunk_rest(seq__48802_49187__$1);
var G__49190 = c__4591__auto___49188;
var G__49191 = cljs.core.count(c__4591__auto___49188);
var G__49192 = (0);
seq__48802_49175 = G__49189;
chunk__48803_49176 = G__49190;
count__48804_49177 = G__49191;
i__48805_49178 = G__49192;
continue;
} else {
var vec__48827_49197 = cljs.core.first(seq__48802_49187__$1);
var k_49198 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48827_49197,(0),null);
var v_49199 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48827_49197,(1),null);
el.setAttributeNS((function (){var temp__5804__auto____$1 = cljs.core.namespace(k_49198);
if(cljs.core.truth_(temp__5804__auto____$1)){
var ns = temp__5804__auto____$1;
return cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(shadow.dom.xmlns),ns);
} else {
return null;
}
})(),cljs.core.name(k_49198),v_49199);


var G__49200 = cljs.core.next(seq__48802_49187__$1);
var G__49201 = null;
var G__49202 = (0);
var G__49203 = (0);
seq__48802_49175 = G__49200;
chunk__48803_49176 = G__49201;
count__48804_49177 = G__49202;
i__48805_49178 = G__49203;
continue;
}
} else {
}
}
break;
}

return el;
});
shadow.dom.svg_node = (function shadow$dom$svg_node(el){
if((el == null)){
return null;
} else {
if((((!((el == null))))?((((false) || ((cljs.core.PROTOCOL_SENTINEL === el.shadow$dom$SVGElement$))))?true:false):false)){
return el.shadow$dom$SVGElement$_to_svg$arity$1(null);
} else {
return el;

}
}
});
shadow.dom.make_svg_node = (function shadow$dom$make_svg_node(structure){
var vec__48837 = shadow.dom.destructure_node(shadow.dom.create_svg_node,structure);
var node = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48837,(0),null);
var node_children = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__48837,(1),null);
var seq__48840_49204 = cljs.core.seq(node_children);
var chunk__48842_49205 = null;
var count__48843_49206 = (0);
var i__48844_49207 = (0);
while(true){
if((i__48844_49207 < count__48843_49206)){
var child_struct_49208 = chunk__48842_49205.cljs$core$IIndexed$_nth$arity$2(null,i__48844_49207);
if((!((child_struct_49208 == null)))){
if(typeof child_struct_49208 === 'string'){
var text_49209 = (node["textContent"]);
(node["textContent"] = [cljs.core.str.cljs$core$IFn$_invoke$arity$1(text_49209),child_struct_49208].join(''));
} else {
var children_49210 = shadow.dom.svg_node(child_struct_49208);
if(cljs.core.seq_QMARK_(children_49210)){
var seq__48877_49211 = cljs.core.seq(children_49210);
var chunk__48879_49212 = null;
var count__48880_49213 = (0);
var i__48881_49214 = (0);
while(true){
if((i__48881_49214 < count__48880_49213)){
var child_49219 = chunk__48879_49212.cljs$core$IIndexed$_nth$arity$2(null,i__48881_49214);
if(cljs.core.truth_(child_49219)){
node.appendChild(child_49219);


var G__49220 = seq__48877_49211;
var G__49221 = chunk__48879_49212;
var G__49222 = count__48880_49213;
var G__49223 = (i__48881_49214 + (1));
seq__48877_49211 = G__49220;
chunk__48879_49212 = G__49221;
count__48880_49213 = G__49222;
i__48881_49214 = G__49223;
continue;
} else {
var G__49224 = seq__48877_49211;
var G__49225 = chunk__48879_49212;
var G__49226 = count__48880_49213;
var G__49227 = (i__48881_49214 + (1));
seq__48877_49211 = G__49224;
chunk__48879_49212 = G__49225;
count__48880_49213 = G__49226;
i__48881_49214 = G__49227;
continue;
}
} else {
var temp__5804__auto___49228 = cljs.core.seq(seq__48877_49211);
if(temp__5804__auto___49228){
var seq__48877_49229__$1 = temp__5804__auto___49228;
if(cljs.core.chunked_seq_QMARK_(seq__48877_49229__$1)){
var c__4591__auto___49230 = cljs.core.chunk_first(seq__48877_49229__$1);
var G__49231 = cljs.core.chunk_rest(seq__48877_49229__$1);
var G__49232 = c__4591__auto___49230;
var G__49233 = cljs.core.count(c__4591__auto___49230);
var G__49234 = (0);
seq__48877_49211 = G__49231;
chunk__48879_49212 = G__49232;
count__48880_49213 = G__49233;
i__48881_49214 = G__49234;
continue;
} else {
var child_49235 = cljs.core.first(seq__48877_49229__$1);
if(cljs.core.truth_(child_49235)){
node.appendChild(child_49235);


var G__49236 = cljs.core.next(seq__48877_49229__$1);
var G__49237 = null;
var G__49238 = (0);
var G__49239 = (0);
seq__48877_49211 = G__49236;
chunk__48879_49212 = G__49237;
count__48880_49213 = G__49238;
i__48881_49214 = G__49239;
continue;
} else {
var G__49240 = cljs.core.next(seq__48877_49229__$1);
var G__49241 = null;
var G__49242 = (0);
var G__49243 = (0);
seq__48877_49211 = G__49240;
chunk__48879_49212 = G__49241;
count__48880_49213 = G__49242;
i__48881_49214 = G__49243;
continue;
}
}
} else {
}
}
break;
}
} else {
node.appendChild(children_49210);
}
}


var G__49244 = seq__48840_49204;
var G__49245 = chunk__48842_49205;
var G__49246 = count__48843_49206;
var G__49247 = (i__48844_49207 + (1));
seq__48840_49204 = G__49244;
chunk__48842_49205 = G__49245;
count__48843_49206 = G__49246;
i__48844_49207 = G__49247;
continue;
} else {
var G__49248 = seq__48840_49204;
var G__49249 = chunk__48842_49205;
var G__49250 = count__48843_49206;
var G__49251 = (i__48844_49207 + (1));
seq__48840_49204 = G__49248;
chunk__48842_49205 = G__49249;
count__48843_49206 = G__49250;
i__48844_49207 = G__49251;
continue;
}
} else {
var temp__5804__auto___49252 = cljs.core.seq(seq__48840_49204);
if(temp__5804__auto___49252){
var seq__48840_49253__$1 = temp__5804__auto___49252;
if(cljs.core.chunked_seq_QMARK_(seq__48840_49253__$1)){
var c__4591__auto___49254 = cljs.core.chunk_first(seq__48840_49253__$1);
var G__49255 = cljs.core.chunk_rest(seq__48840_49253__$1);
var G__49256 = c__4591__auto___49254;
var G__49257 = cljs.core.count(c__4591__auto___49254);
var G__49258 = (0);
seq__48840_49204 = G__49255;
chunk__48842_49205 = G__49256;
count__48843_49206 = G__49257;
i__48844_49207 = G__49258;
continue;
} else {
var child_struct_49259 = cljs.core.first(seq__48840_49253__$1);
if((!((child_struct_49259 == null)))){
if(typeof child_struct_49259 === 'string'){
var text_49260 = (node["textContent"]);
(node["textContent"] = [cljs.core.str.cljs$core$IFn$_invoke$arity$1(text_49260),child_struct_49259].join(''));
} else {
var children_49261 = shadow.dom.svg_node(child_struct_49259);
if(cljs.core.seq_QMARK_(children_49261)){
var seq__48891_49262 = cljs.core.seq(children_49261);
var chunk__48893_49263 = null;
var count__48894_49264 = (0);
var i__48895_49265 = (0);
while(true){
if((i__48895_49265 < count__48894_49264)){
var child_49266 = chunk__48893_49263.cljs$core$IIndexed$_nth$arity$2(null,i__48895_49265);
if(cljs.core.truth_(child_49266)){
node.appendChild(child_49266);


var G__49267 = seq__48891_49262;
var G__49268 = chunk__48893_49263;
var G__49269 = count__48894_49264;
var G__49270 = (i__48895_49265 + (1));
seq__48891_49262 = G__49267;
chunk__48893_49263 = G__49268;
count__48894_49264 = G__49269;
i__48895_49265 = G__49270;
continue;
} else {
var G__49271 = seq__48891_49262;
var G__49272 = chunk__48893_49263;
var G__49273 = count__48894_49264;
var G__49274 = (i__48895_49265 + (1));
seq__48891_49262 = G__49271;
chunk__48893_49263 = G__49272;
count__48894_49264 = G__49273;
i__48895_49265 = G__49274;
continue;
}
} else {
var temp__5804__auto___49278__$1 = cljs.core.seq(seq__48891_49262);
if(temp__5804__auto___49278__$1){
var seq__48891_49279__$1 = temp__5804__auto___49278__$1;
if(cljs.core.chunked_seq_QMARK_(seq__48891_49279__$1)){
var c__4591__auto___49280 = cljs.core.chunk_first(seq__48891_49279__$1);
var G__49281 = cljs.core.chunk_rest(seq__48891_49279__$1);
var G__49282 = c__4591__auto___49280;
var G__49283 = cljs.core.count(c__4591__auto___49280);
var G__49284 = (0);
seq__48891_49262 = G__49281;
chunk__48893_49263 = G__49282;
count__48894_49264 = G__49283;
i__48895_49265 = G__49284;
continue;
} else {
var child_49285 = cljs.core.first(seq__48891_49279__$1);
if(cljs.core.truth_(child_49285)){
node.appendChild(child_49285);


var G__49286 = cljs.core.next(seq__48891_49279__$1);
var G__49287 = null;
var G__49288 = (0);
var G__49289 = (0);
seq__48891_49262 = G__49286;
chunk__48893_49263 = G__49287;
count__48894_49264 = G__49288;
i__48895_49265 = G__49289;
continue;
} else {
var G__49290 = cljs.core.next(seq__48891_49279__$1);
var G__49291 = null;
var G__49292 = (0);
var G__49293 = (0);
seq__48891_49262 = G__49290;
chunk__48893_49263 = G__49291;
count__48894_49264 = G__49292;
i__48895_49265 = G__49293;
continue;
}
}
} else {
}
}
break;
}
} else {
node.appendChild(children_49261);
}
}


var G__49294 = cljs.core.next(seq__48840_49253__$1);
var G__49295 = null;
var G__49296 = (0);
var G__49297 = (0);
seq__48840_49204 = G__49294;
chunk__48842_49205 = G__49295;
count__48843_49206 = G__49296;
i__48844_49207 = G__49297;
continue;
} else {
var G__49298 = cljs.core.next(seq__48840_49253__$1);
var G__49299 = null;
var G__49300 = (0);
var G__49301 = (0);
seq__48840_49204 = G__49298;
chunk__48842_49205 = G__49299;
count__48843_49206 = G__49300;
i__48844_49207 = G__49301;
continue;
}
}
} else {
}
}
break;
}

return node;
});
goog.object.set(shadow.dom.SVGElement,"string",true);

goog.object.set(shadow.dom._to_svg,"string",(function (this$){
if((this$ instanceof cljs.core.Keyword)){
return shadow.dom.make_svg_node(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [this$], null));
} else {
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2("strings cannot be in svgs",new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"this","this",-611633625),this$], null));
}
}));

(cljs.core.PersistentVector.prototype.shadow$dom$SVGElement$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.PersistentVector.prototype.shadow$dom$SVGElement$_to_svg$arity$1 = (function (this$){
var this$__$1 = this;
return shadow.dom.make_svg_node(this$__$1);
}));

(cljs.core.LazySeq.prototype.shadow$dom$SVGElement$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.LazySeq.prototype.shadow$dom$SVGElement$_to_svg$arity$1 = (function (this$){
var this$__$1 = this;
return cljs.core.map.cljs$core$IFn$_invoke$arity$2(shadow.dom._to_svg,this$__$1);
}));

goog.object.set(shadow.dom.SVGElement,"null",true);

goog.object.set(shadow.dom._to_svg,"null",(function (_){
return null;
}));
shadow.dom.svg = (function shadow$dom$svg(var_args){
var args__4777__auto__ = [];
var len__4771__auto___49302 = arguments.length;
var i__4772__auto___49303 = (0);
while(true){
if((i__4772__auto___49303 < len__4771__auto___49302)){
args__4777__auto__.push((arguments[i__4772__auto___49303]));

var G__49304 = (i__4772__auto___49303 + (1));
i__4772__auto___49303 = G__49304;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((1) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((1)),(0),null)):null);
return shadow.dom.svg.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),argseq__4778__auto__);
});

(shadow.dom.svg.cljs$core$IFn$_invoke$arity$variadic = (function (attrs,children){
return shadow.dom._to_svg(cljs.core.vec(cljs.core.concat.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"svg","svg",856789142),attrs], null),children)));
}));

(shadow.dom.svg.cljs$lang$maxFixedArity = (1));

/** @this {Function} */
(shadow.dom.svg.cljs$lang$applyTo = (function (seq48915){
var G__48916 = cljs.core.first(seq48915);
var seq48915__$1 = cljs.core.next(seq48915);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__48916,seq48915__$1);
}));

/**
 * returns a channel for events on el
 * transform-fn should be a (fn [e el] some-val) where some-val will be put on the chan
 * once-or-cleanup handles the removal of the event handler
 * - true: remove after one event
 * - false: never removed
 * - chan: remove on msg/close
 */
shadow.dom.event_chan = (function shadow$dom$event_chan(var_args){
var G__48924 = arguments.length;
switch (G__48924) {
case 2:
return shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$2 = (function (el,event){
return shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$4(el,event,null,false);
}));

(shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$3 = (function (el,event,xf){
return shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$4(el,event,xf,false);
}));

(shadow.dom.event_chan.cljs$core$IFn$_invoke$arity$4 = (function (el,event,xf,once_or_cleanup){
var buf = cljs.core.async.sliding_buffer((1));
var chan = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$2(buf,xf);
var event_fn = (function shadow$dom$event_fn(e){
cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(chan,e);

if(once_or_cleanup === true){
shadow.dom.remove_event_handler(el,event,shadow$dom$event_fn);

return cljs.core.async.close_BANG_(chan);
} else {
return null;
}
});
shadow.dom.dom_listen(shadow.dom.dom_node(el),cljs.core.name(event),event_fn);

if(cljs.core.truth_((function (){var and__4149__auto__ = once_or_cleanup;
if(cljs.core.truth_(and__4149__auto__)){
return (!(once_or_cleanup === true));
} else {
return and__4149__auto__;
}
})())){
var c__46685__auto___49309 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_48932){
var state_val_48933 = (state_48932[(1)]);
if((state_val_48933 === (1))){
var state_48932__$1 = state_48932;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_48932__$1,(2),once_or_cleanup);
} else {
if((state_val_48933 === (2))){
var inst_48929 = (state_48932[(2)]);
var inst_48930 = shadow.dom.remove_event_handler(el,event,event_fn);
var state_48932__$1 = (function (){var statearr_48934 = state_48932;
(statearr_48934[(7)] = inst_48929);

return statearr_48934;
})();
return cljs.core.async.impl.ioc_helpers.return_chan(state_48932__$1,inst_48930);
} else {
return null;
}
}
});
return (function() {
var shadow$dom$state_machine__46650__auto__ = null;
var shadow$dom$state_machine__46650__auto____0 = (function (){
var statearr_48935 = [null,null,null,null,null,null,null,null];
(statearr_48935[(0)] = shadow$dom$state_machine__46650__auto__);

(statearr_48935[(1)] = (1));

return statearr_48935;
});
var shadow$dom$state_machine__46650__auto____1 = (function (state_48932){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_48932);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e48936){var ex__46653__auto__ = e48936;
var statearr_48937_49317 = state_48932;
(statearr_48937_49317[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_48932[(4)]))){
var statearr_48938_49318 = state_48932;
(statearr_48938_49318[(1)] = cljs.core.first((state_48932[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__49319 = state_48932;
state_48932 = G__49319;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
shadow$dom$state_machine__46650__auto__ = function(state_48932){
switch(arguments.length){
case 0:
return shadow$dom$state_machine__46650__auto____0.call(this);
case 1:
return shadow$dom$state_machine__46650__auto____1.call(this,state_48932);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
shadow$dom$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = shadow$dom$state_machine__46650__auto____0;
shadow$dom$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = shadow$dom$state_machine__46650__auto____1;
return shadow$dom$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_48939 = f__46686__auto__();
(statearr_48939[(6)] = c__46685__auto___49309);

return statearr_48939;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

} else {
}

return chan;
}));

(shadow.dom.event_chan.cljs$lang$maxFixedArity = 4);


//# sourceMappingURL=shadow.dom.js.map
