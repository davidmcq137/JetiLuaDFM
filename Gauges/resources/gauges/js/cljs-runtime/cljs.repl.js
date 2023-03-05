goog.provide('cljs.repl');
cljs.repl.print_doc = (function cljs$repl$print_doc(p__51050){
var map__51051 = p__51050;
var map__51051__$1 = cljs.core.__destructure_map(map__51051);
var m = map__51051__$1;
var n = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51051__$1,new cljs.core.Keyword(null,"ns","ns",441598760));
var nm = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51051__$1,new cljs.core.Keyword(null,"name","name",1843675177));
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["-------------------------"], 0));

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([(function (){var or__4160__auto__ = new cljs.core.Keyword(null,"spec","spec",347520401).cljs$core$IFn$_invoke$arity$1(m);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return [(function (){var temp__5804__auto__ = new cljs.core.Keyword(null,"ns","ns",441598760).cljs$core$IFn$_invoke$arity$1(m);
if(cljs.core.truth_(temp__5804__auto__)){
var ns = temp__5804__auto__;
return [cljs.core.str.cljs$core$IFn$_invoke$arity$1(ns),"/"].join('');
} else {
return null;
}
})(),cljs.core.str.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"name","name",1843675177).cljs$core$IFn$_invoke$arity$1(m))].join('');
}
})()], 0));

if(cljs.core.truth_(new cljs.core.Keyword(null,"protocol","protocol",652470118).cljs$core$IFn$_invoke$arity$1(m))){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Protocol"], 0));
} else {
}

if(cljs.core.truth_(new cljs.core.Keyword(null,"forms","forms",2045992350).cljs$core$IFn$_invoke$arity$1(m))){
var seq__51052_51156 = cljs.core.seq(new cljs.core.Keyword(null,"forms","forms",2045992350).cljs$core$IFn$_invoke$arity$1(m));
var chunk__51053_51157 = null;
var count__51054_51158 = (0);
var i__51055_51159 = (0);
while(true){
if((i__51055_51159 < count__51054_51158)){
var f_51160 = chunk__51053_51157.cljs$core$IIndexed$_nth$arity$2(null,i__51055_51159);
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["  ",f_51160], 0));


var G__51161 = seq__51052_51156;
var G__51162 = chunk__51053_51157;
var G__51163 = count__51054_51158;
var G__51164 = (i__51055_51159 + (1));
seq__51052_51156 = G__51161;
chunk__51053_51157 = G__51162;
count__51054_51158 = G__51163;
i__51055_51159 = G__51164;
continue;
} else {
var temp__5804__auto___51165 = cljs.core.seq(seq__51052_51156);
if(temp__5804__auto___51165){
var seq__51052_51166__$1 = temp__5804__auto___51165;
if(cljs.core.chunked_seq_QMARK_(seq__51052_51166__$1)){
var c__4591__auto___51167 = cljs.core.chunk_first(seq__51052_51166__$1);
var G__51168 = cljs.core.chunk_rest(seq__51052_51166__$1);
var G__51169 = c__4591__auto___51167;
var G__51170 = cljs.core.count(c__4591__auto___51167);
var G__51171 = (0);
seq__51052_51156 = G__51168;
chunk__51053_51157 = G__51169;
count__51054_51158 = G__51170;
i__51055_51159 = G__51171;
continue;
} else {
var f_51172 = cljs.core.first(seq__51052_51166__$1);
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["  ",f_51172], 0));


var G__51173 = cljs.core.next(seq__51052_51166__$1);
var G__51174 = null;
var G__51175 = (0);
var G__51176 = (0);
seq__51052_51156 = G__51173;
chunk__51053_51157 = G__51174;
count__51054_51158 = G__51175;
i__51055_51159 = G__51176;
continue;
}
} else {
}
}
break;
}
} else {
if(cljs.core.truth_(new cljs.core.Keyword(null,"arglists","arglists",1661989754).cljs$core$IFn$_invoke$arity$1(m))){
var arglists_51177 = new cljs.core.Keyword(null,"arglists","arglists",1661989754).cljs$core$IFn$_invoke$arity$1(m);
if(cljs.core.truth_((function (){var or__4160__auto__ = new cljs.core.Keyword(null,"macro","macro",-867863404).cljs$core$IFn$_invoke$arity$1(m);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return new cljs.core.Keyword(null,"repl-special-function","repl-special-function",1262603725).cljs$core$IFn$_invoke$arity$1(m);
}
})())){
cljs.core.prn.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([arglists_51177], 0));
} else {
cljs.core.prn.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(new cljs.core.Symbol(null,"quote","quote",1377916282,null),cljs.core.first(arglists_51177)))?cljs.core.second(arglists_51177):arglists_51177)], 0));
}
} else {
}
}

if(cljs.core.truth_(new cljs.core.Keyword(null,"special-form","special-form",-1326536374).cljs$core$IFn$_invoke$arity$1(m))){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Special Form"], 0));

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",new cljs.core.Keyword(null,"doc","doc",1913296891).cljs$core$IFn$_invoke$arity$1(m)], 0));

if(cljs.core.contains_QMARK_(m,new cljs.core.Keyword(null,"url","url",276297046))){
if(cljs.core.truth_(new cljs.core.Keyword(null,"url","url",276297046).cljs$core$IFn$_invoke$arity$1(m))){
return cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([["\n  Please see http://clojure.org/",cljs.core.str.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"url","url",276297046).cljs$core$IFn$_invoke$arity$1(m))].join('')], 0));
} else {
return null;
}
} else {
return cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([["\n  Please see http://clojure.org/special_forms#",cljs.core.str.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"name","name",1843675177).cljs$core$IFn$_invoke$arity$1(m))].join('')], 0));
}
} else {
if(cljs.core.truth_(new cljs.core.Keyword(null,"macro","macro",-867863404).cljs$core$IFn$_invoke$arity$1(m))){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Macro"], 0));
} else {
}

if(cljs.core.truth_(new cljs.core.Keyword(null,"spec","spec",347520401).cljs$core$IFn$_invoke$arity$1(m))){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Spec"], 0));
} else {
}

if(cljs.core.truth_(new cljs.core.Keyword(null,"repl-special-function","repl-special-function",1262603725).cljs$core$IFn$_invoke$arity$1(m))){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["REPL Special Function"], 0));
} else {
}

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",new cljs.core.Keyword(null,"doc","doc",1913296891).cljs$core$IFn$_invoke$arity$1(m)], 0));

if(cljs.core.truth_(new cljs.core.Keyword(null,"protocol","protocol",652470118).cljs$core$IFn$_invoke$arity$1(m))){
var seq__51056_51182 = cljs.core.seq(new cljs.core.Keyword(null,"methods","methods",453930866).cljs$core$IFn$_invoke$arity$1(m));
var chunk__51057_51183 = null;
var count__51058_51184 = (0);
var i__51059_51185 = (0);
while(true){
if((i__51059_51185 < count__51058_51184)){
var vec__51068_51186 = chunk__51057_51183.cljs$core$IIndexed$_nth$arity$2(null,i__51059_51185);
var name_51187 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51068_51186,(0),null);
var map__51071_51188 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51068_51186,(1),null);
var map__51071_51189__$1 = cljs.core.__destructure_map(map__51071_51188);
var doc_51190 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51071_51189__$1,new cljs.core.Keyword(null,"doc","doc",1913296891));
var arglists_51191 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51071_51189__$1,new cljs.core.Keyword(null,"arglists","arglists",1661989754));
cljs.core.println();

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",name_51187], 0));

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",arglists_51191], 0));

if(cljs.core.truth_(doc_51190)){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",doc_51190], 0));
} else {
}


var G__51202 = seq__51056_51182;
var G__51203 = chunk__51057_51183;
var G__51204 = count__51058_51184;
var G__51205 = (i__51059_51185 + (1));
seq__51056_51182 = G__51202;
chunk__51057_51183 = G__51203;
count__51058_51184 = G__51204;
i__51059_51185 = G__51205;
continue;
} else {
var temp__5804__auto___51206 = cljs.core.seq(seq__51056_51182);
if(temp__5804__auto___51206){
var seq__51056_51207__$1 = temp__5804__auto___51206;
if(cljs.core.chunked_seq_QMARK_(seq__51056_51207__$1)){
var c__4591__auto___51208 = cljs.core.chunk_first(seq__51056_51207__$1);
var G__51209 = cljs.core.chunk_rest(seq__51056_51207__$1);
var G__51210 = c__4591__auto___51208;
var G__51211 = cljs.core.count(c__4591__auto___51208);
var G__51212 = (0);
seq__51056_51182 = G__51209;
chunk__51057_51183 = G__51210;
count__51058_51184 = G__51211;
i__51059_51185 = G__51212;
continue;
} else {
var vec__51074_51213 = cljs.core.first(seq__51056_51207__$1);
var name_51214 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51074_51213,(0),null);
var map__51077_51215 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51074_51213,(1),null);
var map__51077_51216__$1 = cljs.core.__destructure_map(map__51077_51215);
var doc_51217 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51077_51216__$1,new cljs.core.Keyword(null,"doc","doc",1913296891));
var arglists_51218 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51077_51216__$1,new cljs.core.Keyword(null,"arglists","arglists",1661989754));
cljs.core.println();

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",name_51214], 0));

cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",arglists_51218], 0));

if(cljs.core.truth_(doc_51217)){
cljs.core.println.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([" ",doc_51217], 0));
} else {
}


var G__51222 = cljs.core.next(seq__51056_51207__$1);
var G__51223 = null;
var G__51224 = (0);
var G__51225 = (0);
seq__51056_51182 = G__51222;
chunk__51057_51183 = G__51223;
count__51058_51184 = G__51224;
i__51059_51185 = G__51225;
continue;
}
} else {
}
}
break;
}
} else {
}

if(cljs.core.truth_(n)){
var temp__5804__auto__ = cljs.spec.alpha.get_spec(cljs.core.symbol.cljs$core$IFn$_invoke$arity$2(cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.ns_name(n)),cljs.core.name(nm)));
if(cljs.core.truth_(temp__5804__auto__)){
var fnspec = temp__5804__auto__;
cljs.core.print.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["Spec"], 0));

var seq__51078 = cljs.core.seq(new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"args","args",1315556576),new cljs.core.Keyword(null,"ret","ret",-468222814),new cljs.core.Keyword(null,"fn","fn",-1175266204)], null));
var chunk__51079 = null;
var count__51080 = (0);
var i__51081 = (0);
while(true){
if((i__51081 < count__51080)){
var role = chunk__51079.cljs$core$IIndexed$_nth$arity$2(null,i__51081);
var temp__5804__auto___51226__$1 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(fnspec,role);
if(cljs.core.truth_(temp__5804__auto___51226__$1)){
var spec_51227 = temp__5804__auto___51226__$1;
cljs.core.print.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([["\n ",cljs.core.name(role),":"].join(''),cljs.spec.alpha.describe(spec_51227)], 0));
} else {
}


var G__51228 = seq__51078;
var G__51229 = chunk__51079;
var G__51230 = count__51080;
var G__51231 = (i__51081 + (1));
seq__51078 = G__51228;
chunk__51079 = G__51229;
count__51080 = G__51230;
i__51081 = G__51231;
continue;
} else {
var temp__5804__auto____$1 = cljs.core.seq(seq__51078);
if(temp__5804__auto____$1){
var seq__51078__$1 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(seq__51078__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__51078__$1);
var G__51232 = cljs.core.chunk_rest(seq__51078__$1);
var G__51233 = c__4591__auto__;
var G__51234 = cljs.core.count(c__4591__auto__);
var G__51235 = (0);
seq__51078 = G__51232;
chunk__51079 = G__51233;
count__51080 = G__51234;
i__51081 = G__51235;
continue;
} else {
var role = cljs.core.first(seq__51078__$1);
var temp__5804__auto___51236__$2 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(fnspec,role);
if(cljs.core.truth_(temp__5804__auto___51236__$2)){
var spec_51237 = temp__5804__auto___51236__$2;
cljs.core.print.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([["\n ",cljs.core.name(role),":"].join(''),cljs.spec.alpha.describe(spec_51237)], 0));
} else {
}


var G__51238 = cljs.core.next(seq__51078__$1);
var G__51239 = null;
var G__51240 = (0);
var G__51241 = (0);
seq__51078 = G__51238;
chunk__51079 = G__51239;
count__51080 = G__51240;
i__51081 = G__51241;
continue;
}
} else {
return null;
}
}
break;
}
} else {
return null;
}
} else {
return null;
}
}
});
/**
 * Constructs a data representation for a Error with keys:
 *  :cause - root cause message
 *  :phase - error phase
 *  :via - cause chain, with cause keys:
 *           :type - exception class symbol
 *           :message - exception message
 *           :data - ex-data
 *           :at - top stack element
 *  :trace - root cause stack elements
 */
cljs.repl.Error__GT_map = (function cljs$repl$Error__GT_map(o){
var base = (function (t){
return cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"type","type",1174270348),(((t instanceof cljs.core.ExceptionInfo))?new cljs.core.Symbol("cljs.core","ExceptionInfo","cljs.core/ExceptionInfo",701839050,null):(((t instanceof Error))?cljs.core.symbol.cljs$core$IFn$_invoke$arity$2("js",t.name):null
))], null),(function (){var temp__5804__auto__ = cljs.core.ex_message(t);
if(cljs.core.truth_(temp__5804__auto__)){
var msg = temp__5804__auto__;
return new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"message","message",-406056002),msg], null);
} else {
return null;
}
})(),(function (){var temp__5804__auto__ = cljs.core.ex_data(t);
if(cljs.core.truth_(temp__5804__auto__)){
var ed = temp__5804__auto__;
return new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"data","data",-232669377),ed], null);
} else {
return null;
}
})()], 0));
});
var via = (function (){var via = cljs.core.PersistentVector.EMPTY;
var t = o;
while(true){
if(cljs.core.truth_(t)){
var G__51242 = cljs.core.conj.cljs$core$IFn$_invoke$arity$2(via,t);
var G__51243 = cljs.core.ex_cause(t);
via = G__51242;
t = G__51243;
continue;
} else {
return via;
}
break;
}
})();
var root = cljs.core.peek(via);
return cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"via","via",-1904457336),cljs.core.vec(cljs.core.map.cljs$core$IFn$_invoke$arity$2(base,via)),new cljs.core.Keyword(null,"trace","trace",-1082747415),null], null),(function (){var temp__5804__auto__ = cljs.core.ex_message(root);
if(cljs.core.truth_(temp__5804__auto__)){
var root_msg = temp__5804__auto__;
return new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"cause","cause",231901252),root_msg], null);
} else {
return null;
}
})(),(function (){var temp__5804__auto__ = cljs.core.ex_data(root);
if(cljs.core.truth_(temp__5804__auto__)){
var data = temp__5804__auto__;
return new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"data","data",-232669377),data], null);
} else {
return null;
}
})(),(function (){var temp__5804__auto__ = new cljs.core.Keyword("clojure.error","phase","clojure.error/phase",275140358).cljs$core$IFn$_invoke$arity$1(cljs.core.ex_data(o));
if(cljs.core.truth_(temp__5804__auto__)){
var phase = temp__5804__auto__;
return new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"phase","phase",575722892),phase], null);
} else {
return null;
}
})()], 0));
});
/**
 * Returns an analysis of the phase, error, cause, and location of an error that occurred
 *   based on Throwable data, as returned by Throwable->map. All attributes other than phase
 *   are optional:
 *  :clojure.error/phase - keyword phase indicator, one of:
 *    :read-source :compile-syntax-check :compilation :macro-syntax-check :macroexpansion
 *    :execution :read-eval-result :print-eval-result
 *  :clojure.error/source - file name (no path)
 *  :clojure.error/line - integer line number
 *  :clojure.error/column - integer column number
 *  :clojure.error/symbol - symbol being expanded/compiled/invoked
 *  :clojure.error/class - cause exception class symbol
 *  :clojure.error/cause - cause exception message
 *  :clojure.error/spec - explain-data for spec error
 */
cljs.repl.ex_triage = (function cljs$repl$ex_triage(datafied_throwable){
var map__51087 = datafied_throwable;
var map__51087__$1 = cljs.core.__destructure_map(map__51087);
var via = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51087__$1,new cljs.core.Keyword(null,"via","via",-1904457336));
var trace = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51087__$1,new cljs.core.Keyword(null,"trace","trace",-1082747415));
var phase = cljs.core.get.cljs$core$IFn$_invoke$arity$3(map__51087__$1,new cljs.core.Keyword(null,"phase","phase",575722892),new cljs.core.Keyword(null,"execution","execution",253283524));
var map__51088 = cljs.core.last(via);
var map__51088__$1 = cljs.core.__destructure_map(map__51088);
var type = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51088__$1,new cljs.core.Keyword(null,"type","type",1174270348));
var message = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51088__$1,new cljs.core.Keyword(null,"message","message",-406056002));
var data = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51088__$1,new cljs.core.Keyword(null,"data","data",-232669377));
var map__51089 = data;
var map__51089__$1 = cljs.core.__destructure_map(map__51089);
var problems = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51089__$1,new cljs.core.Keyword("cljs.spec.alpha","problems","cljs.spec.alpha/problems",447400814));
var fn = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51089__$1,new cljs.core.Keyword("cljs.spec.alpha","fn","cljs.spec.alpha/fn",408600443));
var caller = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51089__$1,new cljs.core.Keyword("cljs.spec.test.alpha","caller","cljs.spec.test.alpha/caller",-398302390));
var map__51090 = new cljs.core.Keyword(null,"data","data",-232669377).cljs$core$IFn$_invoke$arity$1(cljs.core.first(via));
var map__51090__$1 = cljs.core.__destructure_map(map__51090);
var top_data = map__51090__$1;
var source = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51090__$1,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397));
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3((function (){var G__51091 = phase;
var G__51091__$1 = (((G__51091 instanceof cljs.core.Keyword))?G__51091.fqn:null);
switch (G__51091__$1) {
case "read-source":
var map__51092 = data;
var map__51092__$1 = cljs.core.__destructure_map(map__51092);
var line = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51092__$1,new cljs.core.Keyword("clojure.error","line","clojure.error/line",-1816287471));
var column = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51092__$1,new cljs.core.Keyword("clojure.error","column","clojure.error/column",304721553));
var G__51093 = cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"data","data",-232669377).cljs$core$IFn$_invoke$arity$1(cljs.core.second(via)),top_data], 0));
var G__51093__$1 = (cljs.core.truth_(source)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51093,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397),source):G__51093);
var G__51093__$2 = (cljs.core.truth_((function (){var fexpr__51094 = new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, ["NO_SOURCE_PATH",null,"NO_SOURCE_FILE",null], null), null);
return (fexpr__51094.cljs$core$IFn$_invoke$arity$1 ? fexpr__51094.cljs$core$IFn$_invoke$arity$1(source) : fexpr__51094.call(null,source));
})())?cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(G__51093__$1,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397)):G__51093__$1);
if(cljs.core.truth_(message)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51093__$2,new cljs.core.Keyword("clojure.error","cause","clojure.error/cause",-1879175742),message);
} else {
return G__51093__$2;
}

break;
case "compile-syntax-check":
case "compilation":
case "macro-syntax-check":
case "macroexpansion":
var G__51095 = top_data;
var G__51095__$1 = (cljs.core.truth_(source)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51095,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397),source):G__51095);
var G__51095__$2 = (cljs.core.truth_((function (){var fexpr__51096 = new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, ["NO_SOURCE_PATH",null,"NO_SOURCE_FILE",null], null), null);
return (fexpr__51096.cljs$core$IFn$_invoke$arity$1 ? fexpr__51096.cljs$core$IFn$_invoke$arity$1(source) : fexpr__51096.call(null,source));
})())?cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(G__51095__$1,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397)):G__51095__$1);
var G__51095__$3 = (cljs.core.truth_(type)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51095__$2,new cljs.core.Keyword("clojure.error","class","clojure.error/class",278435890),type):G__51095__$2);
var G__51095__$4 = (cljs.core.truth_(message)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51095__$3,new cljs.core.Keyword("clojure.error","cause","clojure.error/cause",-1879175742),message):G__51095__$3);
if(cljs.core.truth_(problems)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51095__$4,new cljs.core.Keyword("clojure.error","spec","clojure.error/spec",2055032595),data);
} else {
return G__51095__$4;
}

break;
case "read-eval-result":
case "print-eval-result":
var vec__51102 = cljs.core.first(trace);
var source__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51102,(0),null);
var method = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51102,(1),null);
var file = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51102,(2),null);
var line = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51102,(3),null);
var G__51105 = top_data;
var G__51105__$1 = (cljs.core.truth_(line)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51105,new cljs.core.Keyword("clojure.error","line","clojure.error/line",-1816287471),line):G__51105);
var G__51105__$2 = (cljs.core.truth_(file)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51105__$1,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397),file):G__51105__$1);
var G__51105__$3 = (cljs.core.truth_((function (){var and__4149__auto__ = source__$1;
if(cljs.core.truth_(and__4149__auto__)){
return method;
} else {
return and__4149__auto__;
}
})())?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51105__$2,new cljs.core.Keyword("clojure.error","symbol","clojure.error/symbol",1544821994),(new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[source__$1,method],null))):G__51105__$2);
var G__51105__$4 = (cljs.core.truth_(type)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51105__$3,new cljs.core.Keyword("clojure.error","class","clojure.error/class",278435890),type):G__51105__$3);
if(cljs.core.truth_(message)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51105__$4,new cljs.core.Keyword("clojure.error","cause","clojure.error/cause",-1879175742),message);
} else {
return G__51105__$4;
}

break;
case "execution":
var vec__51108 = cljs.core.first(trace);
var source__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51108,(0),null);
var method = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51108,(1),null);
var file = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51108,(2),null);
var line = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__51108,(3),null);
var file__$1 = cljs.core.first(cljs.core.remove.cljs$core$IFn$_invoke$arity$2((function (p1__51086_SHARP_){
var or__4160__auto__ = (p1__51086_SHARP_ == null);
if(or__4160__auto__){
return or__4160__auto__;
} else {
var fexpr__51112 = new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, ["NO_SOURCE_PATH",null,"NO_SOURCE_FILE",null], null), null);
return (fexpr__51112.cljs$core$IFn$_invoke$arity$1 ? fexpr__51112.cljs$core$IFn$_invoke$arity$1(p1__51086_SHARP_) : fexpr__51112.call(null,p1__51086_SHARP_));
}
}),new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"file","file",-1269645878).cljs$core$IFn$_invoke$arity$1(caller),file], null)));
var err_line = (function (){var or__4160__auto__ = new cljs.core.Keyword(null,"line","line",212345235).cljs$core$IFn$_invoke$arity$1(caller);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return line;
}
})();
var G__51113 = new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword("clojure.error","class","clojure.error/class",278435890),type], null);
var G__51113__$1 = (cljs.core.truth_(err_line)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51113,new cljs.core.Keyword("clojure.error","line","clojure.error/line",-1816287471),err_line):G__51113);
var G__51113__$2 = (cljs.core.truth_(message)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51113__$1,new cljs.core.Keyword("clojure.error","cause","clojure.error/cause",-1879175742),message):G__51113__$1);
var G__51113__$3 = (cljs.core.truth_((function (){var or__4160__auto__ = fn;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
var and__4149__auto__ = source__$1;
if(cljs.core.truth_(and__4149__auto__)){
return method;
} else {
return and__4149__auto__;
}
}
})())?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51113__$2,new cljs.core.Keyword("clojure.error","symbol","clojure.error/symbol",1544821994),(function (){var or__4160__auto__ = fn;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (new cljs.core.PersistentVector(null,2,(5),cljs.core.PersistentVector.EMPTY_NODE,[source__$1,method],null));
}
})()):G__51113__$2);
var G__51113__$4 = (cljs.core.truth_(file__$1)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51113__$3,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397),file__$1):G__51113__$3);
if(cljs.core.truth_(problems)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__51113__$4,new cljs.core.Keyword("clojure.error","spec","clojure.error/spec",2055032595),data);
} else {
return G__51113__$4;
}

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__51091__$1)].join('')));

}
})(),new cljs.core.Keyword("clojure.error","phase","clojure.error/phase",275140358),phase);
});
/**
 * Returns a string from exception data, as produced by ex-triage.
 *   The first line summarizes the exception phase and location.
 *   The subsequent lines describe the cause.
 */
cljs.repl.ex_str = (function cljs$repl$ex_str(p__51116){
var map__51117 = p__51116;
var map__51117__$1 = cljs.core.__destructure_map(map__51117);
var triage_data = map__51117__$1;
var phase = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","phase","clojure.error/phase",275140358));
var source = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","source","clojure.error/source",-2011936397));
var line = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","line","clojure.error/line",-1816287471));
var column = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","column","clojure.error/column",304721553));
var symbol = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","symbol","clojure.error/symbol",1544821994));
var class$ = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","class","clojure.error/class",278435890));
var cause = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","cause","clojure.error/cause",-1879175742));
var spec = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51117__$1,new cljs.core.Keyword("clojure.error","spec","clojure.error/spec",2055032595));
var loc = [cljs.core.str.cljs$core$IFn$_invoke$arity$1((function (){var or__4160__auto__ = source;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "<cljs repl>";
}
})()),":",cljs.core.str.cljs$core$IFn$_invoke$arity$1((function (){var or__4160__auto__ = line;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return (1);
}
})()),(cljs.core.truth_(column)?[":",cljs.core.str.cljs$core$IFn$_invoke$arity$1(column)].join(''):"")].join('');
var class_name = cljs.core.name((function (){var or__4160__auto__ = class$;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return "";
}
})());
var simple_class = class_name;
var cause_type = ((cljs.core.contains_QMARK_(new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, ["RuntimeException",null,"Exception",null], null), null),simple_class))?"":[" (",simple_class,")"].join(''));
var format = goog.string.format;
var G__51118 = phase;
var G__51118__$1 = (((G__51118 instanceof cljs.core.Keyword))?G__51118.fqn:null);
switch (G__51118__$1) {
case "read-source":
return (format.cljs$core$IFn$_invoke$arity$3 ? format.cljs$core$IFn$_invoke$arity$3("Syntax error reading source at (%s).\n%s\n",loc,cause) : format.call(null,"Syntax error reading source at (%s).\n%s\n",loc,cause));

break;
case "macro-syntax-check":
var G__51119 = "Syntax error macroexpanding %sat (%s).\n%s";
var G__51120 = (cljs.core.truth_(symbol)?[cljs.core.str.cljs$core$IFn$_invoke$arity$1(symbol)," "].join(''):"");
var G__51121 = loc;
var G__51122 = (cljs.core.truth_(spec)?(function (){var sb__4702__auto__ = (new goog.string.StringBuffer());
var _STAR_print_newline_STAR__orig_val__51123_51252 = cljs.core._STAR_print_newline_STAR_;
var _STAR_print_fn_STAR__orig_val__51124_51253 = cljs.core._STAR_print_fn_STAR_;
var _STAR_print_newline_STAR__temp_val__51125_51254 = true;
var _STAR_print_fn_STAR__temp_val__51126_51255 = (function (x__4703__auto__){
return sb__4702__auto__.append(x__4703__auto__);
});
(cljs.core._STAR_print_newline_STAR_ = _STAR_print_newline_STAR__temp_val__51125_51254);

(cljs.core._STAR_print_fn_STAR_ = _STAR_print_fn_STAR__temp_val__51126_51255);

try{cljs.spec.alpha.explain_out(cljs.core.update.cljs$core$IFn$_invoke$arity$3(spec,new cljs.core.Keyword("cljs.spec.alpha","problems","cljs.spec.alpha/problems",447400814),(function (probs){
return cljs.core.map.cljs$core$IFn$_invoke$arity$2((function (p1__51114_SHARP_){
return cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(p1__51114_SHARP_,new cljs.core.Keyword(null,"in","in",-1531184865));
}),probs);
}))
);
}finally {(cljs.core._STAR_print_fn_STAR_ = _STAR_print_fn_STAR__orig_val__51124_51253);

(cljs.core._STAR_print_newline_STAR_ = _STAR_print_newline_STAR__orig_val__51123_51252);
}
return cljs.core.str.cljs$core$IFn$_invoke$arity$1(sb__4702__auto__);
})():(format.cljs$core$IFn$_invoke$arity$2 ? format.cljs$core$IFn$_invoke$arity$2("%s\n",cause) : format.call(null,"%s\n",cause)));
return (format.cljs$core$IFn$_invoke$arity$4 ? format.cljs$core$IFn$_invoke$arity$4(G__51119,G__51120,G__51121,G__51122) : format.call(null,G__51119,G__51120,G__51121,G__51122));

break;
case "macroexpansion":
var G__51127 = "Unexpected error%s macroexpanding %sat (%s).\n%s\n";
var G__51128 = cause_type;
var G__51129 = (cljs.core.truth_(symbol)?[cljs.core.str.cljs$core$IFn$_invoke$arity$1(symbol)," "].join(''):"");
var G__51130 = loc;
var G__51131 = cause;
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5(G__51127,G__51128,G__51129,G__51130,G__51131) : format.call(null,G__51127,G__51128,G__51129,G__51130,G__51131));

break;
case "compile-syntax-check":
var G__51132 = "Syntax error%s compiling %sat (%s).\n%s\n";
var G__51133 = cause_type;
var G__51134 = (cljs.core.truth_(symbol)?[cljs.core.str.cljs$core$IFn$_invoke$arity$1(symbol)," "].join(''):"");
var G__51135 = loc;
var G__51136 = cause;
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5(G__51132,G__51133,G__51134,G__51135,G__51136) : format.call(null,G__51132,G__51133,G__51134,G__51135,G__51136));

break;
case "compilation":
var G__51137 = "Unexpected error%s compiling %sat (%s).\n%s\n";
var G__51138 = cause_type;
var G__51139 = (cljs.core.truth_(symbol)?[cljs.core.str.cljs$core$IFn$_invoke$arity$1(symbol)," "].join(''):"");
var G__51140 = loc;
var G__51141 = cause;
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5(G__51137,G__51138,G__51139,G__51140,G__51141) : format.call(null,G__51137,G__51138,G__51139,G__51140,G__51141));

break;
case "read-eval-result":
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5("Error reading eval result%s at %s (%s).\n%s\n",cause_type,symbol,loc,cause) : format.call(null,"Error reading eval result%s at %s (%s).\n%s\n",cause_type,symbol,loc,cause));

break;
case "print-eval-result":
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5("Error printing return value%s at %s (%s).\n%s\n",cause_type,symbol,loc,cause) : format.call(null,"Error printing return value%s at %s (%s).\n%s\n",cause_type,symbol,loc,cause));

break;
case "execution":
if(cljs.core.truth_(spec)){
var G__51142 = "Execution error - invalid arguments to %s at (%s).\n%s";
var G__51143 = symbol;
var G__51144 = loc;
var G__51145 = (function (){var sb__4702__auto__ = (new goog.string.StringBuffer());
var _STAR_print_newline_STAR__orig_val__51146_51256 = cljs.core._STAR_print_newline_STAR_;
var _STAR_print_fn_STAR__orig_val__51147_51257 = cljs.core._STAR_print_fn_STAR_;
var _STAR_print_newline_STAR__temp_val__51148_51258 = true;
var _STAR_print_fn_STAR__temp_val__51149_51259 = (function (x__4703__auto__){
return sb__4702__auto__.append(x__4703__auto__);
});
(cljs.core._STAR_print_newline_STAR_ = _STAR_print_newline_STAR__temp_val__51148_51258);

(cljs.core._STAR_print_fn_STAR_ = _STAR_print_fn_STAR__temp_val__51149_51259);

try{cljs.spec.alpha.explain_out(cljs.core.update.cljs$core$IFn$_invoke$arity$3(spec,new cljs.core.Keyword("cljs.spec.alpha","problems","cljs.spec.alpha/problems",447400814),(function (probs){
return cljs.core.map.cljs$core$IFn$_invoke$arity$2((function (p1__51115_SHARP_){
return cljs.core.dissoc.cljs$core$IFn$_invoke$arity$2(p1__51115_SHARP_,new cljs.core.Keyword(null,"in","in",-1531184865));
}),probs);
}))
);
}finally {(cljs.core._STAR_print_fn_STAR_ = _STAR_print_fn_STAR__orig_val__51147_51257);

(cljs.core._STAR_print_newline_STAR_ = _STAR_print_newline_STAR__orig_val__51146_51256);
}
return cljs.core.str.cljs$core$IFn$_invoke$arity$1(sb__4702__auto__);
})();
return (format.cljs$core$IFn$_invoke$arity$4 ? format.cljs$core$IFn$_invoke$arity$4(G__51142,G__51143,G__51144,G__51145) : format.call(null,G__51142,G__51143,G__51144,G__51145));
} else {
var G__51150 = "Execution error%s at %s(%s).\n%s\n";
var G__51151 = cause_type;
var G__51152 = (cljs.core.truth_(symbol)?[cljs.core.str.cljs$core$IFn$_invoke$arity$1(symbol)," "].join(''):"");
var G__51153 = loc;
var G__51154 = cause;
return (format.cljs$core$IFn$_invoke$arity$5 ? format.cljs$core$IFn$_invoke$arity$5(G__51150,G__51151,G__51152,G__51153,G__51154) : format.call(null,G__51150,G__51151,G__51152,G__51153,G__51154));
}

break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__51118__$1)].join('')));

}
});
cljs.repl.error__GT_str = (function cljs$repl$error__GT_str(error){
return cljs.repl.ex_str(cljs.repl.ex_triage(cljs.repl.Error__GT_map(error)));
});

//# sourceMappingURL=cljs.repl.js.map
