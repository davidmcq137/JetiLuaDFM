goog.provide('rum.derived_atom');
rum.derived_atom.derived_atom = (function rum$derived_atom$derived_atom(var_args){
var G__52149 = arguments.length;
switch (G__52149) {
case 3:
return rum.derived_atom.derived_atom.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return rum.derived_atom.derived_atom.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(rum.derived_atom.derived_atom.cljs$core$IFn$_invoke$arity$3 = (function (refs,key,f){
return rum.derived_atom.derived_atom.cljs$core$IFn$_invoke$arity$4(refs,key,f,cljs.core.PersistentArrayMap.EMPTY);
}));

(rum.derived_atom.derived_atom.cljs$core$IFn$_invoke$arity$4 = (function (refs,key,f,opts){
var map__52151 = opts;
var map__52151__$1 = cljs.core.__destructure_map(map__52151);
var ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__52151__$1,new cljs.core.Keyword(null,"ref","ref",1289896967));
var check_equals_QMARK_ = cljs.core.get.cljs$core$IFn$_invoke$arity$3(map__52151__$1,new cljs.core.Keyword(null,"check-equals?","check-equals?",-2005755315),true);
var recalc = (function (){var G__52154 = cljs.core.count(refs);
switch (G__52154) {
case (1):
var vec__52155 = refs;
var a = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52155,(0),null);
return (function (){
var G__52158 = cljs.core.deref(a);
return (f.cljs$core$IFn$_invoke$arity$1 ? f.cljs$core$IFn$_invoke$arity$1(G__52158) : f.call(null,G__52158));
});

break;
case (2):
var vec__52159 = refs;
var a = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52159,(0),null);
var b = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52159,(1),null);
return (function (){
var G__52162 = cljs.core.deref(a);
var G__52163 = cljs.core.deref(b);
return (f.cljs$core$IFn$_invoke$arity$2 ? f.cljs$core$IFn$_invoke$arity$2(G__52162,G__52163) : f.call(null,G__52162,G__52163));
});

break;
case (3):
var vec__52164 = refs;
var a = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52164,(0),null);
var b = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52164,(1),null);
var c = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__52164,(2),null);
return (function (){
var G__52167 = cljs.core.deref(a);
var G__52168 = cljs.core.deref(b);
var G__52169 = cljs.core.deref(c);
return (f.cljs$core$IFn$_invoke$arity$3 ? f.cljs$core$IFn$_invoke$arity$3(G__52167,G__52168,G__52169) : f.call(null,G__52167,G__52168,G__52169));
});

break;
default:
return (function (){
return cljs.core.apply.cljs$core$IFn$_invoke$arity$2(f,cljs.core.map.cljs$core$IFn$_invoke$arity$2(cljs.core.deref,refs));
});

}
})();
var sink = (cljs.core.truth_(ref)?(function (){var G__52170 = ref;
cljs.core.reset_BANG_(G__52170,(recalc.cljs$core$IFn$_invoke$arity$0 ? recalc.cljs$core$IFn$_invoke$arity$0() : recalc.call(null)));

return G__52170;
})():cljs.core.atom.cljs$core$IFn$_invoke$arity$1((recalc.cljs$core$IFn$_invoke$arity$0 ? recalc.cljs$core$IFn$_invoke$arity$0() : recalc.call(null))));
var watch = (cljs.core.truth_(check_equals_QMARK_)?(function (_,___$1,___$2,___$3){
var new_val = (recalc.cljs$core$IFn$_invoke$arity$0 ? recalc.cljs$core$IFn$_invoke$arity$0() : recalc.call(null));
if(cljs.core.not_EQ_.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(sink),new_val)){
return cljs.core.reset_BANG_(sink,new_val);
} else {
return null;
}
}):(function (_,___$1,___$2,___$3){
return cljs.core.reset_BANG_(sink,(recalc.cljs$core$IFn$_invoke$arity$0 ? recalc.cljs$core$IFn$_invoke$arity$0() : recalc.call(null)));
}));
var seq__52172_52180 = cljs.core.seq(refs);
var chunk__52173_52181 = null;
var count__52174_52182 = (0);
var i__52175_52183 = (0);
while(true){
if((i__52175_52183 < count__52174_52182)){
var ref_52184__$1 = chunk__52173_52181.cljs$core$IIndexed$_nth$arity$2(null,i__52175_52183);
cljs.core.add_watch(ref_52184__$1,key,watch);


var G__52185 = seq__52172_52180;
var G__52186 = chunk__52173_52181;
var G__52187 = count__52174_52182;
var G__52188 = (i__52175_52183 + (1));
seq__52172_52180 = G__52185;
chunk__52173_52181 = G__52186;
count__52174_52182 = G__52187;
i__52175_52183 = G__52188;
continue;
} else {
var temp__5804__auto___52189 = cljs.core.seq(seq__52172_52180);
if(temp__5804__auto___52189){
var seq__52172_52190__$1 = temp__5804__auto___52189;
if(cljs.core.chunked_seq_QMARK_(seq__52172_52190__$1)){
var c__4591__auto___52195 = cljs.core.chunk_first(seq__52172_52190__$1);
var G__52196 = cljs.core.chunk_rest(seq__52172_52190__$1);
var G__52197 = c__4591__auto___52195;
var G__52198 = cljs.core.count(c__4591__auto___52195);
var G__52199 = (0);
seq__52172_52180 = G__52196;
chunk__52173_52181 = G__52197;
count__52174_52182 = G__52198;
i__52175_52183 = G__52199;
continue;
} else {
var ref_52200__$1 = cljs.core.first(seq__52172_52190__$1);
cljs.core.add_watch(ref_52200__$1,key,watch);


var G__52201 = cljs.core.next(seq__52172_52190__$1);
var G__52202 = null;
var G__52203 = (0);
var G__52204 = (0);
seq__52172_52180 = G__52201;
chunk__52173_52181 = G__52202;
count__52174_52182 = G__52203;
i__52175_52183 = G__52204;
continue;
}
} else {
}
}
break;
}

return sink;
}));

(rum.derived_atom.derived_atom.cljs$lang$maxFixedArity = 4);


//# sourceMappingURL=rum.derived_atom.js.map
