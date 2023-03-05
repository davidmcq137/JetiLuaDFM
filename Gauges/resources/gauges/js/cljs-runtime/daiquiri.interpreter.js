goog.provide('daiquiri.interpreter');
/**
 * Create a React element. Returns a JavaScript object when running
 *   under ClojureScript, and a om.dom.Element record in Clojure.
 */
daiquiri.interpreter.create_element = (function daiquiri$interpreter$create_element(type,attrs,children){
return React.createElement.apply(null,[type,attrs].concat(children));
});
daiquiri.interpreter.component_attributes = (function daiquiri$interpreter$component_attributes(attrs){
var x = daiquiri.util.camel_case_keys_STAR_(attrs);
var m = ({});
var seq__52088_52127 = cljs.core.seq(x);
var chunk__52089_52128 = null;
var count__52090_52129 = (0);
var i__52091_52130 = (0);
while(true){
if((i__52091_52130 < count__52090_52129)){
var vec__52098_52131 = chunk__52089_52128.cljs$core$IIndexed$_nth$arity$2(null,i__52091_52130);
var k_52132 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52098_52131,(0),null);
var v_52133 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52098_52131,(1),null);
goog.object.set(m,cljs.core.name(k_52132),v_52133);


var G__52134 = seq__52088_52127;
var G__52135 = chunk__52089_52128;
var G__52136 = count__52090_52129;
var G__52137 = (i__52091_52130 + (1));
seq__52088_52127 = G__52134;
chunk__52089_52128 = G__52135;
count__52090_52129 = G__52136;
i__52091_52130 = G__52137;
continue;
} else {
var temp__5804__auto___52138 = cljs.core.seq(seq__52088_52127);
if(temp__5804__auto___52138){
var seq__52088_52139__$1 = temp__5804__auto___52138;
if(cljs.core.chunked_seq_QMARK_(seq__52088_52139__$1)){
var c__4591__auto___52140 = cljs.core.chunk_first(seq__52088_52139__$1);
var G__52141 = cljs.core.chunk_rest(seq__52088_52139__$1);
var G__52142 = c__4591__auto___52140;
var G__52143 = cljs.core.count(c__4591__auto___52140);
var G__52144 = (0);
seq__52088_52127 = G__52141;
chunk__52089_52128 = G__52142;
count__52090_52129 = G__52143;
i__52091_52130 = G__52144;
continue;
} else {
var vec__52101_52145 = cljs.core.first(seq__52088_52139__$1);
var k_52146 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52101_52145,(0),null);
var v_52147 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52101_52145,(1),null);
goog.object.set(m,cljs.core.name(k_52146),v_52147);


var G__52191 = cljs.core.next(seq__52088_52139__$1);
var G__52192 = null;
var G__52193 = (0);
var G__52194 = (0);
seq__52088_52127 = G__52191;
chunk__52089_52128 = G__52192;
count__52090_52129 = G__52193;
i__52091_52130 = G__52194;
continue;
}
} else {
}
}
break;
}

return m;
});
daiquiri.interpreter.element_attributes = (function daiquiri$interpreter$element_attributes(attrs){
var temp__5804__auto__ = cljs.core.clj__GT_js(daiquiri.util.html_to_dom_attrs(attrs));
if(cljs.core.truth_(temp__5804__auto__)){
var js_attrs = temp__5804__auto__;
var class$ = js_attrs.className;
var class$__$1 = ((cljs.core.array_QMARK_(class$))?clojure.string.join.cljs$core$IFn$_invoke$arity$2(" ",class$):class$);
if(clojure.string.blank_QMARK_(class$__$1)){
delete js_attrs["className"];
} else {
(js_attrs.className = class$__$1);
}

return js_attrs;
} else {
return null;
}
});
/**
 * Eagerly interpret the seq `x` as HTML elements.
 */
daiquiri.interpreter.interpret_seq = (function daiquiri$interpreter$interpret_seq(x){
return cljs.core.reduce.cljs$core$IFn$_invoke$arity$3((function (ret,x__$1){
ret.push((daiquiri.interpreter.interpret.cljs$core$IFn$_invoke$arity$1 ? daiquiri.interpreter.interpret.cljs$core$IFn$_invoke$arity$1(x__$1) : daiquiri.interpreter.interpret.call(null,x__$1)));

return ret;
}),[],x);
});
/**
 * Render an element vector as a HTML element.
 */
daiquiri.interpreter.element = (function daiquiri$interpreter$element(element){
var vec__52104 = daiquiri.normalize.element(element);
var type = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52104,(0),null);
var attrs = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52104,(1),null);
var content = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52104,(2),null);
return daiquiri.interpreter.create_element(type,daiquiri.interpreter.element_attributes(attrs),daiquiri.interpreter.interpret_seq(content));
});
daiquiri.interpreter.fragment = (function daiquiri$interpreter$fragment(p__52107){
var vec__52108 = p__52107;
var seq__52109 = cljs.core.seq(vec__52108);
var first__52110 = cljs.core.first(seq__52109);
var seq__52109__$1 = cljs.core.next(seq__52109);
var _ = first__52110;
var first__52110__$1 = cljs.core.first(seq__52109__$1);
var seq__52109__$2 = cljs.core.next(seq__52109__$1);
var attrs = first__52110__$1;
var children = seq__52109__$2;
var vec__52111 = ((cljs.core.map_QMARK_(attrs))?new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [daiquiri.interpreter.component_attributes(attrs),daiquiri.interpreter.interpret_seq(children)], null):new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [null,daiquiri.interpreter.interpret_seq(cljs.core.into.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [attrs], null),children))], null));
var attrs__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52111,(0),null);
var children__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52111,(1),null);
return daiquiri.interpreter.create_element(React.Fragment,attrs__$1,children__$1);
});
daiquiri.interpreter.interop = (function daiquiri$interpreter$interop(p__52114){
var vec__52115 = p__52114;
var seq__52116 = cljs.core.seq(vec__52115);
var first__52117 = cljs.core.first(seq__52116);
var seq__52116__$1 = cljs.core.next(seq__52116);
var _ = first__52117;
var first__52117__$1 = cljs.core.first(seq__52116__$1);
var seq__52116__$2 = cljs.core.next(seq__52116__$1);
var component = first__52117__$1;
var first__52117__$2 = cljs.core.first(seq__52116__$2);
var seq__52116__$3 = cljs.core.next(seq__52116__$2);
var attrs = first__52117__$2;
var children = seq__52116__$3;
var vec__52119 = ((cljs.core.map_QMARK_(attrs))?new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [daiquiri.interpreter.component_attributes(attrs),daiquiri.interpreter.interpret_seq(children)], null):new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [null,daiquiri.interpreter.interpret_seq(cljs.core.into.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [attrs], null),children))], null));
var attrs__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52119,(0),null);
var children__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52119,(1),null);
return daiquiri.interpreter.create_element(component,attrs__$1,children__$1);
});
/**
 * Interpret the vector `x` as an HTML element or a the children of an
 *   element.
 */
daiquiri.interpreter.interpret_vec = (function daiquiri$interpreter$interpret_vec(x){
if(daiquiri.util.fragment_QMARK_(x)){
return daiquiri.interpreter.fragment(x);
} else {
if(cljs.core.keyword_identical_QMARK_(new cljs.core.Keyword(null,">",">",-555517146),cljs.core.nth.cljs$core$IFn$_invoke$arity$3(x,(0),null))){
return daiquiri.interpreter.interop(x);
} else {
if(daiquiri.util.element_QMARK_(x)){
return daiquiri.interpreter.element(x);
} else {
return daiquiri.interpreter.interpret_seq(x);

}
}
}
});
daiquiri.interpreter.interpret = (function daiquiri$interpreter$interpret(v){
if(cljs.core.vector_QMARK_(v)){
return daiquiri.interpreter.interpret_vec(v);
} else {
if(cljs.core.seq_QMARK_(v)){
return daiquiri.interpreter.interpret_seq(v);
} else {
return v;

}
}
});

//# sourceMappingURL=daiquiri.interpreter.js.map
