goog.provide('shadow.cljs.devtools.client.browser');
shadow.cljs.devtools.client.browser.devtools_msg = (function shadow$cljs$devtools$client$browser$devtools_msg(var_args){
var args__4777__auto__ = [];
var len__4771__auto___51897 = arguments.length;
var i__4772__auto___51898 = (0);
while(true){
if((i__4772__auto___51898 < len__4771__auto___51897)){
args__4777__auto__.push((arguments[i__4772__auto___51898]));

var G__51899 = (i__4772__auto___51898 + (1));
i__4772__auto___51898 = G__51899;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((1) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((1)),(0),null)):null);
return shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),argseq__4778__auto__);
});

(shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic = (function (msg,args){
if(shadow.cljs.devtools.client.env.log){
if(cljs.core.seq(shadow.cljs.devtools.client.env.log_style)){
return console.log.apply(console,cljs.core.into_array.cljs$core$IFn$_invoke$arity$1(cljs.core.into.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [["%cshadow-cljs: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(msg)].join(''),shadow.cljs.devtools.client.env.log_style], null),args)));
} else {
return console.log.apply(console,cljs.core.into_array.cljs$core$IFn$_invoke$arity$1(cljs.core.into.cljs$core$IFn$_invoke$arity$2(new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [["shadow-cljs: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(msg)].join('')], null),args)));
}
} else {
return null;
}
}));

(shadow.cljs.devtools.client.browser.devtools_msg.cljs$lang$maxFixedArity = (1));

/** @this {Function} */
(shadow.cljs.devtools.client.browser.devtools_msg.cljs$lang$applyTo = (function (seq51585){
var G__51586 = cljs.core.first(seq51585);
var seq51585__$1 = cljs.core.next(seq51585);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__51586,seq51585__$1);
}));

shadow.cljs.devtools.client.browser.script_eval = (function shadow$cljs$devtools$client$browser$script_eval(code){
return goog.globalEval(code);
});
shadow.cljs.devtools.client.browser.do_js_load = (function shadow$cljs$devtools$client$browser$do_js_load(sources){
var seq__51594 = cljs.core.seq(sources);
var chunk__51595 = null;
var count__51596 = (0);
var i__51597 = (0);
while(true){
if((i__51597 < count__51596)){
var map__51602 = chunk__51595.cljs$core$IIndexed$_nth$arity$2(null,i__51597);
var map__51602__$1 = cljs.core.__destructure_map(map__51602);
var src = map__51602__$1;
var resource_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51602__$1,new cljs.core.Keyword(null,"resource-id","resource-id",-1308422582));
var output_name = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51602__$1,new cljs.core.Keyword(null,"output-name","output-name",-1769107767));
var resource_name = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51602__$1,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100));
var js = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51602__$1,new cljs.core.Keyword(null,"js","js",1768080579));
$CLJS.SHADOW_ENV.setLoaded(output_name);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load JS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([resource_name], 0));

shadow.cljs.devtools.client.env.before_load_src(src);

try{shadow.cljs.devtools.client.browser.script_eval([cljs.core.str.cljs$core$IFn$_invoke$arity$1(js),"\n//# sourceURL=",cljs.core.str.cljs$core$IFn$_invoke$arity$1($CLJS.SHADOW_ENV.scriptBase),cljs.core.str.cljs$core$IFn$_invoke$arity$1(output_name)].join(''));
}catch (e51612){var e_51900 = e51612;
if(shadow.cljs.devtools.client.env.log){
console.error(["Failed to load ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name)].join(''),e_51900);
} else {
}

throw (new Error(["Failed to load ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name),": ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(e_51900.message)].join('')));
}

var G__51902 = seq__51594;
var G__51903 = chunk__51595;
var G__51904 = count__51596;
var G__51905 = (i__51597 + (1));
seq__51594 = G__51902;
chunk__51595 = G__51903;
count__51596 = G__51904;
i__51597 = G__51905;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__51594);
if(temp__5804__auto__){
var seq__51594__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__51594__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__51594__$1);
var G__51906 = cljs.core.chunk_rest(seq__51594__$1);
var G__51907 = c__4591__auto__;
var G__51908 = cljs.core.count(c__4591__auto__);
var G__51909 = (0);
seq__51594 = G__51906;
chunk__51595 = G__51907;
count__51596 = G__51908;
i__51597 = G__51909;
continue;
} else {
var map__51620 = cljs.core.first(seq__51594__$1);
var map__51620__$1 = cljs.core.__destructure_map(map__51620);
var src = map__51620__$1;
var resource_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51620__$1,new cljs.core.Keyword(null,"resource-id","resource-id",-1308422582));
var output_name = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51620__$1,new cljs.core.Keyword(null,"output-name","output-name",-1769107767));
var resource_name = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51620__$1,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100));
var js = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51620__$1,new cljs.core.Keyword(null,"js","js",1768080579));
$CLJS.SHADOW_ENV.setLoaded(output_name);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load JS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([resource_name], 0));

shadow.cljs.devtools.client.env.before_load_src(src);

try{shadow.cljs.devtools.client.browser.script_eval([cljs.core.str.cljs$core$IFn$_invoke$arity$1(js),"\n//# sourceURL=",cljs.core.str.cljs$core$IFn$_invoke$arity$1($CLJS.SHADOW_ENV.scriptBase),cljs.core.str.cljs$core$IFn$_invoke$arity$1(output_name)].join(''));
}catch (e51621){var e_51911 = e51621;
if(shadow.cljs.devtools.client.env.log){
console.error(["Failed to load ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name)].join(''),e_51911);
} else {
}

throw (new Error(["Failed to load ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name),": ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(e_51911.message)].join('')));
}

var G__51912 = cljs.core.next(seq__51594__$1);
var G__51913 = null;
var G__51914 = (0);
var G__51915 = (0);
seq__51594 = G__51912;
chunk__51595 = G__51913;
count__51596 = G__51914;
i__51597 = G__51915;
continue;
}
} else {
return null;
}
}
break;
}
});
shadow.cljs.devtools.client.browser.do_js_reload = (function shadow$cljs$devtools$client$browser$do_js_reload(msg,sources,complete_fn,failure_fn){
return shadow.cljs.devtools.client.env.do_js_reload.cljs$core$IFn$_invoke$arity$4(cljs.core.assoc.cljs$core$IFn$_invoke$arity$variadic(msg,new cljs.core.Keyword(null,"log-missing-fn","log-missing-fn",732676765),(function (fn_sym){
return null;
}),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"log-call-async","log-call-async",183826192),(function (fn_sym){
return shadow.cljs.devtools.client.browser.devtools_msg(["call async ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(fn_sym)].join(''));
}),new cljs.core.Keyword(null,"log-call","log-call",412404391),(function (fn_sym){
return shadow.cljs.devtools.client.browser.devtools_msg(["call ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(fn_sym)].join(''));
})], 0)),(function (){
return shadow.cljs.devtools.client.browser.do_js_load(sources);
}),complete_fn,failure_fn);
});
/**
 * when (require '["some-str" :as x]) is done at the REPL we need to manually call the shadow.js.require for it
 * since the file only adds the shadow$provide. only need to do this for shadow-js.
 */
shadow.cljs.devtools.client.browser.do_js_requires = (function shadow$cljs$devtools$client$browser$do_js_requires(js_requires){
var seq__51662 = cljs.core.seq(js_requires);
var chunk__51663 = null;
var count__51664 = (0);
var i__51665 = (0);
while(true){
if((i__51665 < count__51664)){
var js_ns = chunk__51663.cljs$core$IIndexed$_nth$arity$2(null,i__51665);
var require_str_51916 = ["var ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(js_ns)," = shadow.js.require(\"",cljs.core.str.cljs$core$IFn$_invoke$arity$1(js_ns),"\");"].join('');
shadow.cljs.devtools.client.browser.script_eval(require_str_51916);


var G__51917 = seq__51662;
var G__51918 = chunk__51663;
var G__51919 = count__51664;
var G__51920 = (i__51665 + (1));
seq__51662 = G__51917;
chunk__51663 = G__51918;
count__51664 = G__51919;
i__51665 = G__51920;
continue;
} else {
var temp__5804__auto__ = cljs.core.seq(seq__51662);
if(temp__5804__auto__){
var seq__51662__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__51662__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__51662__$1);
var G__51921 = cljs.core.chunk_rest(seq__51662__$1);
var G__51922 = c__4591__auto__;
var G__51923 = cljs.core.count(c__4591__auto__);
var G__51924 = (0);
seq__51662 = G__51921;
chunk__51663 = G__51922;
count__51664 = G__51923;
i__51665 = G__51924;
continue;
} else {
var js_ns = cljs.core.first(seq__51662__$1);
var require_str_51925 = ["var ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(js_ns)," = shadow.js.require(\"",cljs.core.str.cljs$core$IFn$_invoke$arity$1(js_ns),"\");"].join('');
shadow.cljs.devtools.client.browser.script_eval(require_str_51925);


var G__51926 = cljs.core.next(seq__51662__$1);
var G__51927 = null;
var G__51928 = (0);
var G__51929 = (0);
seq__51662 = G__51926;
chunk__51663 = G__51927;
count__51664 = G__51928;
i__51665 = G__51929;
continue;
}
} else {
return null;
}
}
break;
}
});
shadow.cljs.devtools.client.browser.handle_build_complete = (function shadow$cljs$devtools$client$browser$handle_build_complete(runtime,p__51679){
var map__51680 = p__51679;
var map__51680__$1 = cljs.core.__destructure_map(map__51680);
var msg = map__51680__$1;
var info = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51680__$1,new cljs.core.Keyword(null,"info","info",-317069002));
var reload_info = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51680__$1,new cljs.core.Keyword(null,"reload-info","reload-info",1648088086));
var warnings = cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentVector.EMPTY,cljs.core.distinct.cljs$core$IFn$_invoke$arity$1((function (){var iter__4564__auto__ = (function shadow$cljs$devtools$client$browser$handle_build_complete_$_iter__51681(s__51682){
return (new cljs.core.LazySeq(null,(function (){
var s__51682__$1 = s__51682;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__51682__$1);
if(temp__5804__auto__){
var xs__6360__auto__ = temp__5804__auto__;
var map__51687 = cljs.core.first(xs__6360__auto__);
var map__51687__$1 = cljs.core.__destructure_map(map__51687);
var src = map__51687__$1;
var resource_name = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51687__$1,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100));
var warnings = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51687__$1,new cljs.core.Keyword(null,"warnings","warnings",-735437651));
if(cljs.core.not(new cljs.core.Keyword(null,"from-jar","from-jar",1050932827).cljs$core$IFn$_invoke$arity$1(src))){
var iterys__4560__auto__ = ((function (s__51682__$1,map__51687,map__51687__$1,src,resource_name,warnings,xs__6360__auto__,temp__5804__auto__,map__51680,map__51680__$1,msg,info,reload_info){
return (function shadow$cljs$devtools$client$browser$handle_build_complete_$_iter__51681_$_iter__51683(s__51684){
return (new cljs.core.LazySeq(null,((function (s__51682__$1,map__51687,map__51687__$1,src,resource_name,warnings,xs__6360__auto__,temp__5804__auto__,map__51680,map__51680__$1,msg,info,reload_info){
return (function (){
var s__51684__$1 = s__51684;
while(true){
var temp__5804__auto____$1 = cljs.core.seq(s__51684__$1);
if(temp__5804__auto____$1){
var s__51684__$2 = temp__5804__auto____$1;
if(cljs.core.chunked_seq_QMARK_(s__51684__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__51684__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__51686 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__51685 = (0);
while(true){
if((i__51685 < size__4563__auto__)){
var warning = cljs.core._nth(c__4562__auto__,i__51685);
cljs.core.chunk_append(b__51686,cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(warning,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100),resource_name));

var G__51930 = (i__51685 + (1));
i__51685 = G__51930;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__51686),shadow$cljs$devtools$client$browser$handle_build_complete_$_iter__51681_$_iter__51683(cljs.core.chunk_rest(s__51684__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__51686),null);
}
} else {
var warning = cljs.core.first(s__51684__$2);
return cljs.core.cons(cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(warning,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100),resource_name),shadow$cljs$devtools$client$browser$handle_build_complete_$_iter__51681_$_iter__51683(cljs.core.rest(s__51684__$2)));
}
} else {
return null;
}
break;
}
});})(s__51682__$1,map__51687,map__51687__$1,src,resource_name,warnings,xs__6360__auto__,temp__5804__auto__,map__51680,map__51680__$1,msg,info,reload_info))
,null,null));
});})(s__51682__$1,map__51687,map__51687__$1,src,resource_name,warnings,xs__6360__auto__,temp__5804__auto__,map__51680,map__51680__$1,msg,info,reload_info))
;
var fs__4561__auto__ = cljs.core.seq(iterys__4560__auto__(warnings));
if(fs__4561__auto__){
return cljs.core.concat.cljs$core$IFn$_invoke$arity$2(fs__4561__auto__,shadow$cljs$devtools$client$browser$handle_build_complete_$_iter__51681(cljs.core.rest(s__51682__$1)));
} else {
var G__51931 = cljs.core.rest(s__51682__$1);
s__51682__$1 = G__51931;
continue;
}
} else {
var G__51932 = cljs.core.rest(s__51682__$1);
s__51682__$1 = G__51932;
continue;
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(new cljs.core.Keyword(null,"sources","sources",-321166424).cljs$core$IFn$_invoke$arity$1(info));
})()));
if(shadow.cljs.devtools.client.env.log){
var seq__51695_51933 = cljs.core.seq(warnings);
var chunk__51696_51934 = null;
var count__51697_51935 = (0);
var i__51698_51936 = (0);
while(true){
if((i__51698_51936 < count__51697_51935)){
var map__51713_51937 = chunk__51696_51934.cljs$core$IIndexed$_nth$arity$2(null,i__51698_51936);
var map__51713_51938__$1 = cljs.core.__destructure_map(map__51713_51937);
var w_51939 = map__51713_51938__$1;
var msg_51940__$1 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51713_51938__$1,new cljs.core.Keyword(null,"msg","msg",-1386103444));
var line_51941 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51713_51938__$1,new cljs.core.Keyword(null,"line","line",212345235));
var column_51942 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51713_51938__$1,new cljs.core.Keyword(null,"column","column",2078222095));
var resource_name_51943 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51713_51938__$1,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100));
console.warn(["BUILD-WARNING in ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name_51943)," at [",cljs.core.str.cljs$core$IFn$_invoke$arity$1(line_51941),":",cljs.core.str.cljs$core$IFn$_invoke$arity$1(column_51942),"]\n\t",cljs.core.str.cljs$core$IFn$_invoke$arity$1(msg_51940__$1)].join(''));


var G__51944 = seq__51695_51933;
var G__51945 = chunk__51696_51934;
var G__51946 = count__51697_51935;
var G__51947 = (i__51698_51936 + (1));
seq__51695_51933 = G__51944;
chunk__51696_51934 = G__51945;
count__51697_51935 = G__51946;
i__51698_51936 = G__51947;
continue;
} else {
var temp__5804__auto___51948 = cljs.core.seq(seq__51695_51933);
if(temp__5804__auto___51948){
var seq__51695_51949__$1 = temp__5804__auto___51948;
if(cljs.core.chunked_seq_QMARK_(seq__51695_51949__$1)){
var c__4591__auto___51950 = cljs.core.chunk_first(seq__51695_51949__$1);
var G__51951 = cljs.core.chunk_rest(seq__51695_51949__$1);
var G__51952 = c__4591__auto___51950;
var G__51953 = cljs.core.count(c__4591__auto___51950);
var G__51954 = (0);
seq__51695_51933 = G__51951;
chunk__51696_51934 = G__51952;
count__51697_51935 = G__51953;
i__51698_51936 = G__51954;
continue;
} else {
var map__51717_51955 = cljs.core.first(seq__51695_51949__$1);
var map__51717_51956__$1 = cljs.core.__destructure_map(map__51717_51955);
var w_51957 = map__51717_51956__$1;
var msg_51958__$1 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51717_51956__$1,new cljs.core.Keyword(null,"msg","msg",-1386103444));
var line_51959 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51717_51956__$1,new cljs.core.Keyword(null,"line","line",212345235));
var column_51960 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51717_51956__$1,new cljs.core.Keyword(null,"column","column",2078222095));
var resource_name_51961 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51717_51956__$1,new cljs.core.Keyword(null,"resource-name","resource-name",2001617100));
console.warn(["BUILD-WARNING in ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(resource_name_51961)," at [",cljs.core.str.cljs$core$IFn$_invoke$arity$1(line_51959),":",cljs.core.str.cljs$core$IFn$_invoke$arity$1(column_51960),"]\n\t",cljs.core.str.cljs$core$IFn$_invoke$arity$1(msg_51958__$1)].join(''));


var G__51963 = cljs.core.next(seq__51695_51949__$1);
var G__51964 = null;
var G__51965 = (0);
var G__51966 = (0);
seq__51695_51933 = G__51963;
chunk__51696_51934 = G__51964;
count__51697_51935 = G__51965;
i__51698_51936 = G__51966;
continue;
}
} else {
}
}
break;
}
} else {
}

if((!(shadow.cljs.devtools.client.env.autoload))){
return shadow.cljs.devtools.client.hud.load_end_success();
} else {
if(((cljs.core.empty_QMARK_(warnings)) || (shadow.cljs.devtools.client.env.ignore_warnings))){
var sources_to_get = shadow.cljs.devtools.client.env.filter_reload_sources(info,reload_info);
if(cljs.core.not(cljs.core.seq(sources_to_get))){
return shadow.cljs.devtools.client.hud.load_end_success();
} else {
if(cljs.core.seq(cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(msg,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"reload-info","reload-info",1648088086),new cljs.core.Keyword(null,"after-load","after-load",-1278503285)], null)))){
} else {
shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("reloading code but no :after-load hooks are configured!",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2(["https://shadow-cljs.github.io/docs/UsersGuide.html#_lifecycle_hooks"], 0));
}

return shadow.cljs.devtools.client.shared.load_sources(runtime,sources_to_get,(function (p1__51678_SHARP_){
return shadow.cljs.devtools.client.browser.do_js_reload(msg,p1__51678_SHARP_,shadow.cljs.devtools.client.hud.load_end_success,shadow.cljs.devtools.client.hud.load_failure);
}));
}
} else {
return null;
}
}
});
shadow.cljs.devtools.client.browser.page_load_uri = (cljs.core.truth_(goog.global.document)?goog.Uri.parse(document.location.href):null);
shadow.cljs.devtools.client.browser.match_paths = (function shadow$cljs$devtools$client$browser$match_paths(old,new$){
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("file",shadow.cljs.devtools.client.browser.page_load_uri.getScheme())){
var rel_new = cljs.core.subs.cljs$core$IFn$_invoke$arity$2(new$,(1));
if(((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(old,rel_new)) || (clojure.string.starts_with_QMARK_(old,[rel_new,"?"].join(''))))){
return rel_new;
} else {
return null;
}
} else {
var node_uri = goog.Uri.parse(old);
var node_uri_resolved = shadow.cljs.devtools.client.browser.page_load_uri.resolve(node_uri);
var node_abs = node_uri_resolved.getPath();
if(((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$1(shadow.cljs.devtools.client.browser.page_load_uri.hasSameDomainAs(node_uri))) || (cljs.core.not(node_uri.hasDomain())))){
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(node_abs,new$)){
return new$;
} else {
return false;
}
} else {
return false;
}
}
});
shadow.cljs.devtools.client.browser.handle_asset_update = (function shadow$cljs$devtools$client$browser$handle_asset_update(p__51725){
var map__51726 = p__51725;
var map__51726__$1 = cljs.core.__destructure_map(map__51726);
var msg = map__51726__$1;
var updates = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51726__$1,new cljs.core.Keyword(null,"updates","updates",2013983452));
var seq__51727 = cljs.core.seq(updates);
var chunk__51729 = null;
var count__51730 = (0);
var i__51731 = (0);
while(true){
if((i__51731 < count__51730)){
var path = chunk__51729.cljs$core$IIndexed$_nth$arity$2(null,i__51731);
if(clojure.string.ends_with_QMARK_(path,"css")){
var seq__51836_51972 = cljs.core.seq(cljs.core.array_seq.cljs$core$IFn$_invoke$arity$1(document.querySelectorAll("link[rel=\"stylesheet\"]")));
var chunk__51840_51973 = null;
var count__51841_51974 = (0);
var i__51842_51975 = (0);
while(true){
if((i__51842_51975 < count__51841_51974)){
var node_51976 = chunk__51840_51973.cljs$core$IIndexed$_nth$arity$2(null,i__51842_51975);
if(cljs.core.not(node_51976.shadow$old)){
var path_match_51977 = shadow.cljs.devtools.client.browser.match_paths(node_51976.getAttribute("href"),path);
if(cljs.core.truth_(path_match_51977)){
var new_link_51978 = (function (){var G__51848 = node_51976.cloneNode(true);
G__51848.setAttribute("href",[cljs.core.str.cljs$core$IFn$_invoke$arity$1(path_match_51977),"?r=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.rand.cljs$core$IFn$_invoke$arity$0())].join(''));

return G__51848;
})();
(node_51976.shadow$old = true);

(new_link_51978.onload = ((function (seq__51836_51972,chunk__51840_51973,count__51841_51974,i__51842_51975,seq__51727,chunk__51729,count__51730,i__51731,new_link_51978,path_match_51977,node_51976,path,map__51726,map__51726__$1,msg,updates){
return (function (e){
return goog.dom.removeNode(node_51976);
});})(seq__51836_51972,chunk__51840_51973,count__51841_51974,i__51842_51975,seq__51727,chunk__51729,count__51730,i__51731,new_link_51978,path_match_51977,node_51976,path,map__51726,map__51726__$1,msg,updates))
);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load CSS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([path_match_51977], 0));

goog.dom.insertSiblingAfter(new_link_51978,node_51976);


var G__51979 = seq__51836_51972;
var G__51980 = chunk__51840_51973;
var G__51981 = count__51841_51974;
var G__51982 = (i__51842_51975 + (1));
seq__51836_51972 = G__51979;
chunk__51840_51973 = G__51980;
count__51841_51974 = G__51981;
i__51842_51975 = G__51982;
continue;
} else {
var G__51983 = seq__51836_51972;
var G__51984 = chunk__51840_51973;
var G__51985 = count__51841_51974;
var G__51986 = (i__51842_51975 + (1));
seq__51836_51972 = G__51983;
chunk__51840_51973 = G__51984;
count__51841_51974 = G__51985;
i__51842_51975 = G__51986;
continue;
}
} else {
var G__51987 = seq__51836_51972;
var G__51988 = chunk__51840_51973;
var G__51989 = count__51841_51974;
var G__51990 = (i__51842_51975 + (1));
seq__51836_51972 = G__51987;
chunk__51840_51973 = G__51988;
count__51841_51974 = G__51989;
i__51842_51975 = G__51990;
continue;
}
} else {
var temp__5804__auto___51991 = cljs.core.seq(seq__51836_51972);
if(temp__5804__auto___51991){
var seq__51836_51992__$1 = temp__5804__auto___51991;
if(cljs.core.chunked_seq_QMARK_(seq__51836_51992__$1)){
var c__4591__auto___51993 = cljs.core.chunk_first(seq__51836_51992__$1);
var G__51994 = cljs.core.chunk_rest(seq__51836_51992__$1);
var G__51995 = c__4591__auto___51993;
var G__51996 = cljs.core.count(c__4591__auto___51993);
var G__51997 = (0);
seq__51836_51972 = G__51994;
chunk__51840_51973 = G__51995;
count__51841_51974 = G__51996;
i__51842_51975 = G__51997;
continue;
} else {
var node_51998 = cljs.core.first(seq__51836_51992__$1);
if(cljs.core.not(node_51998.shadow$old)){
var path_match_51999 = shadow.cljs.devtools.client.browser.match_paths(node_51998.getAttribute("href"),path);
if(cljs.core.truth_(path_match_51999)){
var new_link_52000 = (function (){var G__51849 = node_51998.cloneNode(true);
G__51849.setAttribute("href",[cljs.core.str.cljs$core$IFn$_invoke$arity$1(path_match_51999),"?r=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.rand.cljs$core$IFn$_invoke$arity$0())].join(''));

return G__51849;
})();
(node_51998.shadow$old = true);

(new_link_52000.onload = ((function (seq__51836_51972,chunk__51840_51973,count__51841_51974,i__51842_51975,seq__51727,chunk__51729,count__51730,i__51731,new_link_52000,path_match_51999,node_51998,seq__51836_51992__$1,temp__5804__auto___51991,path,map__51726,map__51726__$1,msg,updates){
return (function (e){
return goog.dom.removeNode(node_51998);
});})(seq__51836_51972,chunk__51840_51973,count__51841_51974,i__51842_51975,seq__51727,chunk__51729,count__51730,i__51731,new_link_52000,path_match_51999,node_51998,seq__51836_51992__$1,temp__5804__auto___51991,path,map__51726,map__51726__$1,msg,updates))
);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load CSS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([path_match_51999], 0));

goog.dom.insertSiblingAfter(new_link_52000,node_51998);


var G__52002 = cljs.core.next(seq__51836_51992__$1);
var G__52003 = null;
var G__52004 = (0);
var G__52005 = (0);
seq__51836_51972 = G__52002;
chunk__51840_51973 = G__52003;
count__51841_51974 = G__52004;
i__51842_51975 = G__52005;
continue;
} else {
var G__52006 = cljs.core.next(seq__51836_51992__$1);
var G__52007 = null;
var G__52008 = (0);
var G__52009 = (0);
seq__51836_51972 = G__52006;
chunk__51840_51973 = G__52007;
count__51841_51974 = G__52008;
i__51842_51975 = G__52009;
continue;
}
} else {
var G__52010 = cljs.core.next(seq__51836_51992__$1);
var G__52011 = null;
var G__52012 = (0);
var G__52013 = (0);
seq__51836_51972 = G__52010;
chunk__51840_51973 = G__52011;
count__51841_51974 = G__52012;
i__51842_51975 = G__52013;
continue;
}
}
} else {
}
}
break;
}


var G__52014 = seq__51727;
var G__52015 = chunk__51729;
var G__52016 = count__51730;
var G__52017 = (i__51731 + (1));
seq__51727 = G__52014;
chunk__51729 = G__52015;
count__51730 = G__52016;
i__51731 = G__52017;
continue;
} else {
var G__52018 = seq__51727;
var G__52019 = chunk__51729;
var G__52020 = count__51730;
var G__52021 = (i__51731 + (1));
seq__51727 = G__52018;
chunk__51729 = G__52019;
count__51730 = G__52020;
i__51731 = G__52021;
continue;
}
} else {
var temp__5804__auto__ = cljs.core.seq(seq__51727);
if(temp__5804__auto__){
var seq__51727__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__51727__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__51727__$1);
var G__52022 = cljs.core.chunk_rest(seq__51727__$1);
var G__52023 = c__4591__auto__;
var G__52024 = cljs.core.count(c__4591__auto__);
var G__52025 = (0);
seq__51727 = G__52022;
chunk__51729 = G__52023;
count__51730 = G__52024;
i__51731 = G__52025;
continue;
} else {
var path = cljs.core.first(seq__51727__$1);
if(clojure.string.ends_with_QMARK_(path,"css")){
var seq__51850_52026 = cljs.core.seq(cljs.core.array_seq.cljs$core$IFn$_invoke$arity$1(document.querySelectorAll("link[rel=\"stylesheet\"]")));
var chunk__51854_52027 = null;
var count__51855_52028 = (0);
var i__51856_52029 = (0);
while(true){
if((i__51856_52029 < count__51855_52028)){
var node_52030 = chunk__51854_52027.cljs$core$IIndexed$_nth$arity$2(null,i__51856_52029);
if(cljs.core.not(node_52030.shadow$old)){
var path_match_52031 = shadow.cljs.devtools.client.browser.match_paths(node_52030.getAttribute("href"),path);
if(cljs.core.truth_(path_match_52031)){
var new_link_52032 = (function (){var G__51862 = node_52030.cloneNode(true);
G__51862.setAttribute("href",[cljs.core.str.cljs$core$IFn$_invoke$arity$1(path_match_52031),"?r=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.rand.cljs$core$IFn$_invoke$arity$0())].join(''));

return G__51862;
})();
(node_52030.shadow$old = true);

(new_link_52032.onload = ((function (seq__51850_52026,chunk__51854_52027,count__51855_52028,i__51856_52029,seq__51727,chunk__51729,count__51730,i__51731,new_link_52032,path_match_52031,node_52030,path,seq__51727__$1,temp__5804__auto__,map__51726,map__51726__$1,msg,updates){
return (function (e){
return goog.dom.removeNode(node_52030);
});})(seq__51850_52026,chunk__51854_52027,count__51855_52028,i__51856_52029,seq__51727,chunk__51729,count__51730,i__51731,new_link_52032,path_match_52031,node_52030,path,seq__51727__$1,temp__5804__auto__,map__51726,map__51726__$1,msg,updates))
);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load CSS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([path_match_52031], 0));

goog.dom.insertSiblingAfter(new_link_52032,node_52030);


var G__52037 = seq__51850_52026;
var G__52038 = chunk__51854_52027;
var G__52039 = count__51855_52028;
var G__52040 = (i__51856_52029 + (1));
seq__51850_52026 = G__52037;
chunk__51854_52027 = G__52038;
count__51855_52028 = G__52039;
i__51856_52029 = G__52040;
continue;
} else {
var G__52041 = seq__51850_52026;
var G__52042 = chunk__51854_52027;
var G__52043 = count__51855_52028;
var G__52044 = (i__51856_52029 + (1));
seq__51850_52026 = G__52041;
chunk__51854_52027 = G__52042;
count__51855_52028 = G__52043;
i__51856_52029 = G__52044;
continue;
}
} else {
var G__52045 = seq__51850_52026;
var G__52046 = chunk__51854_52027;
var G__52047 = count__51855_52028;
var G__52048 = (i__51856_52029 + (1));
seq__51850_52026 = G__52045;
chunk__51854_52027 = G__52046;
count__51855_52028 = G__52047;
i__51856_52029 = G__52048;
continue;
}
} else {
var temp__5804__auto___52049__$1 = cljs.core.seq(seq__51850_52026);
if(temp__5804__auto___52049__$1){
var seq__51850_52053__$1 = temp__5804__auto___52049__$1;
if(cljs.core.chunked_seq_QMARK_(seq__51850_52053__$1)){
var c__4591__auto___52054 = cljs.core.chunk_first(seq__51850_52053__$1);
var G__52055 = cljs.core.chunk_rest(seq__51850_52053__$1);
var G__52056 = c__4591__auto___52054;
var G__52057 = cljs.core.count(c__4591__auto___52054);
var G__52058 = (0);
seq__51850_52026 = G__52055;
chunk__51854_52027 = G__52056;
count__51855_52028 = G__52057;
i__51856_52029 = G__52058;
continue;
} else {
var node_52060 = cljs.core.first(seq__51850_52053__$1);
if(cljs.core.not(node_52060.shadow$old)){
var path_match_52061 = shadow.cljs.devtools.client.browser.match_paths(node_52060.getAttribute("href"),path);
if(cljs.core.truth_(path_match_52061)){
var new_link_52062 = (function (){var G__51863 = node_52060.cloneNode(true);
G__51863.setAttribute("href",[cljs.core.str.cljs$core$IFn$_invoke$arity$1(path_match_52061),"?r=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.rand.cljs$core$IFn$_invoke$arity$0())].join(''));

return G__51863;
})();
(node_52060.shadow$old = true);

(new_link_52062.onload = ((function (seq__51850_52026,chunk__51854_52027,count__51855_52028,i__51856_52029,seq__51727,chunk__51729,count__51730,i__51731,new_link_52062,path_match_52061,node_52060,seq__51850_52053__$1,temp__5804__auto___52049__$1,path,seq__51727__$1,temp__5804__auto__,map__51726,map__51726__$1,msg,updates){
return (function (e){
return goog.dom.removeNode(node_52060);
});})(seq__51850_52026,chunk__51854_52027,count__51855_52028,i__51856_52029,seq__51727,chunk__51729,count__51730,i__51731,new_link_52062,path_match_52061,node_52060,seq__51850_52053__$1,temp__5804__auto___52049__$1,path,seq__51727__$1,temp__5804__auto__,map__51726,map__51726__$1,msg,updates))
);

shadow.cljs.devtools.client.browser.devtools_msg.cljs$core$IFn$_invoke$arity$variadic("load CSS",cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([path_match_52061], 0));

goog.dom.insertSiblingAfter(new_link_52062,node_52060);


var G__52063 = cljs.core.next(seq__51850_52053__$1);
var G__52064 = null;
var G__52065 = (0);
var G__52066 = (0);
seq__51850_52026 = G__52063;
chunk__51854_52027 = G__52064;
count__51855_52028 = G__52065;
i__51856_52029 = G__52066;
continue;
} else {
var G__52067 = cljs.core.next(seq__51850_52053__$1);
var G__52068 = null;
var G__52069 = (0);
var G__52070 = (0);
seq__51850_52026 = G__52067;
chunk__51854_52027 = G__52068;
count__51855_52028 = G__52069;
i__51856_52029 = G__52070;
continue;
}
} else {
var G__52073 = cljs.core.next(seq__51850_52053__$1);
var G__52074 = null;
var G__52075 = (0);
var G__52076 = (0);
seq__51850_52026 = G__52073;
chunk__51854_52027 = G__52074;
count__51855_52028 = G__52075;
i__51856_52029 = G__52076;
continue;
}
}
} else {
}
}
break;
}


var G__52078 = cljs.core.next(seq__51727__$1);
var G__52079 = null;
var G__52080 = (0);
var G__52081 = (0);
seq__51727 = G__52078;
chunk__51729 = G__52079;
count__51730 = G__52080;
i__51731 = G__52081;
continue;
} else {
var G__52082 = cljs.core.next(seq__51727__$1);
var G__52083 = null;
var G__52084 = (0);
var G__52085 = (0);
seq__51727 = G__52082;
chunk__51729 = G__52083;
count__51730 = G__52084;
i__51731 = G__52085;
continue;
}
}
} else {
return null;
}
}
break;
}
});
shadow.cljs.devtools.client.browser.global_eval = (function shadow$cljs$devtools$client$browser$global_eval(js){
if(cljs.core.not_EQ_.cljs$core$IFn$_invoke$arity$2("undefined",typeof(module))){
return eval(js);
} else {
return (0,eval)(js);;
}
});
shadow.cljs.devtools.client.browser.repl_init = (function shadow$cljs$devtools$client$browser$repl_init(runtime,p__51864){
var map__51865 = p__51864;
var map__51865__$1 = cljs.core.__destructure_map(map__51865);
var repl_state = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51865__$1,new cljs.core.Keyword(null,"repl-state","repl-state",-1733780387));
return shadow.cljs.devtools.client.shared.load_sources(runtime,cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentVector.EMPTY,cljs.core.remove.cljs$core$IFn$_invoke$arity$2(shadow.cljs.devtools.client.env.src_is_loaded_QMARK_,new cljs.core.Keyword(null,"repl-sources","repl-sources",723867535).cljs$core$IFn$_invoke$arity$1(repl_state))),(function (sources){
shadow.cljs.devtools.client.browser.do_js_load(sources);

return shadow.cljs.devtools.client.browser.devtools_msg("ready!");
}));
});
shadow.cljs.devtools.client.browser.runtime_info = (((typeof SHADOW_CONFIG !== 'undefined'))?shadow.json.to_clj.cljs$core$IFn$_invoke$arity$1(SHADOW_CONFIG):null);
shadow.cljs.devtools.client.browser.client_info = cljs.core.merge.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([shadow.cljs.devtools.client.browser.runtime_info,new cljs.core.PersistentArrayMap(null, 3, [new cljs.core.Keyword(null,"host","host",-1558485167),(cljs.core.truth_(goog.global.document)?new cljs.core.Keyword(null,"browser","browser",828191719):new cljs.core.Keyword(null,"browser-worker","browser-worker",1638998282)),new cljs.core.Keyword(null,"user-agent","user-agent",1220426212),[(cljs.core.truth_(goog.userAgent.OPERA)?"Opera":(cljs.core.truth_(goog.userAgent.product.CHROME)?"Chrome":(cljs.core.truth_(goog.userAgent.IE)?"MSIE":(cljs.core.truth_(goog.userAgent.EDGE)?"Edge":(cljs.core.truth_(goog.userAgent.GECKO)?"Firefox":(cljs.core.truth_(goog.userAgent.SAFARI)?"Safari":(cljs.core.truth_(goog.userAgent.WEBKIT)?"Webkit":null)))))))," ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(goog.userAgent.VERSION)," [",cljs.core.str.cljs$core$IFn$_invoke$arity$1(goog.userAgent.PLATFORM),"]"].join(''),new cljs.core.Keyword(null,"dom","dom",-1236537922),(!((goog.global.document == null)))], null)], 0));
if((typeof shadow !== 'undefined') && (typeof shadow.cljs !== 'undefined') && (typeof shadow.cljs.devtools !== 'undefined') && (typeof shadow.cljs.devtools.client !== 'undefined') && (typeof shadow.cljs.devtools.client.browser !== 'undefined') && (typeof shadow.cljs.devtools.client.browser.ws_was_welcome_ref !== 'undefined')){
} else {
shadow.cljs.devtools.client.browser.ws_was_welcome_ref = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(false);
}
if(((shadow.cljs.devtools.client.env.enabled) && ((shadow.cljs.devtools.client.env.worker_client_id > (0))))){
(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$remote$runtime$api$IEvalJS$ = cljs.core.PROTOCOL_SENTINEL);

(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$remote$runtime$api$IEvalJS$_js_eval$arity$2 = (function (this$,code){
var this$__$1 = this;
return shadow.cljs.devtools.client.browser.global_eval(code);
}));

(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$cljs$devtools$client$shared$IHostSpecific$ = cljs.core.PROTOCOL_SENTINEL);

(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$cljs$devtools$client$shared$IHostSpecific$do_invoke$arity$2 = (function (this$,p__51872){
var map__51873 = p__51872;
var map__51873__$1 = cljs.core.__destructure_map(map__51873);
var _ = map__51873__$1;
var js = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51873__$1,new cljs.core.Keyword(null,"js","js",1768080579));
var this$__$1 = this;
return shadow.cljs.devtools.client.browser.global_eval(js);
}));

(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$cljs$devtools$client$shared$IHostSpecific$do_repl_init$arity$4 = (function (runtime,p__51877,done,error){
var map__51878 = p__51877;
var map__51878__$1 = cljs.core.__destructure_map(map__51878);
var repl_sources = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51878__$1,new cljs.core.Keyword(null,"repl-sources","repl-sources",723867535));
var runtime__$1 = this;
return shadow.cljs.devtools.client.shared.load_sources(runtime__$1,cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentVector.EMPTY,cljs.core.remove.cljs$core$IFn$_invoke$arity$2(shadow.cljs.devtools.client.env.src_is_loaded_QMARK_,repl_sources)),(function (sources){
shadow.cljs.devtools.client.browser.do_js_load(sources);

return (done.cljs$core$IFn$_invoke$arity$0 ? done.cljs$core$IFn$_invoke$arity$0() : done.call(null));
}));
}));

(shadow.cljs.devtools.client.shared.Runtime.prototype.shadow$cljs$devtools$client$shared$IHostSpecific$do_repl_require$arity$4 = (function (runtime,p__51880,done,error){
var map__51881 = p__51880;
var map__51881__$1 = cljs.core.__destructure_map(map__51881);
var msg = map__51881__$1;
var sources = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51881__$1,new cljs.core.Keyword(null,"sources","sources",-321166424));
var reload_namespaces = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51881__$1,new cljs.core.Keyword(null,"reload-namespaces","reload-namespaces",250210134));
var js_requires = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51881__$1,new cljs.core.Keyword(null,"js-requires","js-requires",-1311472051));
var runtime__$1 = this;
var sources_to_load = cljs.core.into.cljs$core$IFn$_invoke$arity$2(cljs.core.PersistentVector.EMPTY,cljs.core.remove.cljs$core$IFn$_invoke$arity$2((function (p__51882){
var map__51883 = p__51882;
var map__51883__$1 = cljs.core.__destructure_map(map__51883);
var src = map__51883__$1;
var provides = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51883__$1,new cljs.core.Keyword(null,"provides","provides",-1634397992));
var and__4149__auto__ = shadow.cljs.devtools.client.env.src_is_loaded_QMARK_(src);
if(cljs.core.truth_(and__4149__auto__)){
return cljs.core.not(cljs.core.some(reload_namespaces,provides));
} else {
return and__4149__auto__;
}
}),sources));
if(cljs.core.not(cljs.core.seq(sources_to_load))){
var G__51884 = cljs.core.PersistentVector.EMPTY;
return (done.cljs$core$IFn$_invoke$arity$1 ? done.cljs$core$IFn$_invoke$arity$1(G__51884) : done.call(null,G__51884));
} else {
return shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$3(runtime__$1,new cljs.core.PersistentArrayMap(null, 3, [new cljs.core.Keyword(null,"op","op",-1882987955),new cljs.core.Keyword(null,"cljs-load-sources","cljs-load-sources",-1458295962),new cljs.core.Keyword(null,"to","to",192099007),shadow.cljs.devtools.client.env.worker_client_id,new cljs.core.Keyword(null,"sources","sources",-321166424),cljs.core.into.cljs$core$IFn$_invoke$arity$3(cljs.core.PersistentVector.EMPTY,cljs.core.map.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"resource-id","resource-id",-1308422582)),sources_to_load)], null),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"cljs-sources","cljs-sources",31121610),(function (p__51885){
var map__51886 = p__51885;
var map__51886__$1 = cljs.core.__destructure_map(map__51886);
var msg__$1 = map__51886__$1;
var sources__$1 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51886__$1,new cljs.core.Keyword(null,"sources","sources",-321166424));
try{shadow.cljs.devtools.client.browser.do_js_load(sources__$1);

if(cljs.core.seq(js_requires)){
shadow.cljs.devtools.client.browser.do_js_requires(js_requires);
} else {
}

return (done.cljs$core$IFn$_invoke$arity$1 ? done.cljs$core$IFn$_invoke$arity$1(sources_to_load) : done.call(null,sources_to_load));
}catch (e51887){var ex = e51887;
return (error.cljs$core$IFn$_invoke$arity$1 ? error.cljs$core$IFn$_invoke$arity$1(ex) : error.call(null,ex));
}})], null));
}
}));

shadow.cljs.devtools.client.shared.add_plugin_BANG_(new cljs.core.Keyword("shadow.cljs.devtools.client.browser","client","shadow.cljs.devtools.client.browser/client",-1461019282),cljs.core.PersistentHashSet.EMPTY,(function (p__51888){
var map__51889 = p__51888;
var map__51889__$1 = cljs.core.__destructure_map(map__51889);
var env = map__51889__$1;
var runtime = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51889__$1,new cljs.core.Keyword(null,"runtime","runtime",-1331573996));
var svc = new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"runtime","runtime",-1331573996),runtime], null);
shadow.remote.runtime.api.add_extension(runtime,new cljs.core.Keyword("shadow.cljs.devtools.client.browser","client","shadow.cljs.devtools.client.browser/client",-1461019282),new cljs.core.PersistentArrayMap(null, 4, [new cljs.core.Keyword(null,"on-welcome","on-welcome",1895317125),(function (){
cljs.core.reset_BANG_(shadow.cljs.devtools.client.browser.ws_was_welcome_ref,true);

shadow.cljs.devtools.client.hud.connection_error_clear_BANG_();

shadow.cljs.devtools.client.env.patch_goog_BANG_();

return shadow.cljs.devtools.client.browser.devtools_msg(["#",cljs.core.str.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"client-id","client-id",-464622140).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(new cljs.core.Keyword(null,"state-ref","state-ref",2127874952).cljs$core$IFn$_invoke$arity$1(runtime))))," ready!"].join(''));
}),new cljs.core.Keyword(null,"on-disconnect","on-disconnect",-809021814),(function (e){
if(cljs.core.truth_(cljs.core.deref(shadow.cljs.devtools.client.browser.ws_was_welcome_ref))){
shadow.cljs.devtools.client.hud.connection_error("The Websocket connection was closed!");

return cljs.core.reset_BANG_(shadow.cljs.devtools.client.browser.ws_was_welcome_ref,false);
} else {
return null;
}
}),new cljs.core.Keyword(null,"on-reconnect","on-reconnect",1239988702),(function (e){
return shadow.cljs.devtools.client.hud.connection_error("Reconnecting ...");
}),new cljs.core.Keyword(null,"ops","ops",1237330063),new cljs.core.PersistentArrayMap(null, 8, [new cljs.core.Keyword(null,"access-denied","access-denied",959449406),(function (msg){
cljs.core.reset_BANG_(shadow.cljs.devtools.client.browser.ws_was_welcome_ref,false);

return shadow.cljs.devtools.client.hud.connection_error(["Stale Output! Your loaded JS was not produced by the running shadow-cljs instance."," Is the watch for this build running?"].join(''));
}),new cljs.core.Keyword(null,"cljs-runtime-init","cljs-runtime-init",1305890232),(function (msg){
return shadow.cljs.devtools.client.browser.repl_init(runtime,msg);
}),new cljs.core.Keyword(null,"cljs-asset-update","cljs-asset-update",1224093028),(function (p__51890){
var map__51891 = p__51890;
var map__51891__$1 = cljs.core.__destructure_map(map__51891);
var msg = map__51891__$1;
var updates = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51891__$1,new cljs.core.Keyword(null,"updates","updates",2013983452));
return shadow.cljs.devtools.client.browser.handle_asset_update(msg);
}),new cljs.core.Keyword(null,"cljs-build-configure","cljs-build-configure",-2089891268),(function (msg){
return null;
}),new cljs.core.Keyword(null,"cljs-build-start","cljs-build-start",-725781241),(function (msg){
shadow.cljs.devtools.client.hud.hud_hide();

shadow.cljs.devtools.client.hud.load_start();

return shadow.cljs.devtools.client.env.run_custom_notify_BANG_(cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(msg,new cljs.core.Keyword(null,"type","type",1174270348),new cljs.core.Keyword(null,"build-start","build-start",-959649480)));
}),new cljs.core.Keyword(null,"cljs-build-complete","cljs-build-complete",273626153),(function (msg){
var msg__$1 = shadow.cljs.devtools.client.env.add_warnings_to_info(msg);
shadow.cljs.devtools.client.hud.hud_warnings(msg__$1);

shadow.cljs.devtools.client.browser.handle_build_complete(runtime,msg__$1);

return shadow.cljs.devtools.client.env.run_custom_notify_BANG_(cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(msg__$1,new cljs.core.Keyword(null,"type","type",1174270348),new cljs.core.Keyword(null,"build-complete","build-complete",-501868472)));
}),new cljs.core.Keyword(null,"cljs-build-failure","cljs-build-failure",1718154990),(function (msg){
shadow.cljs.devtools.client.hud.load_end();

shadow.cljs.devtools.client.hud.hud_error(msg);

return shadow.cljs.devtools.client.env.run_custom_notify_BANG_(cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(msg,new cljs.core.Keyword(null,"type","type",1174270348),new cljs.core.Keyword(null,"build-failure","build-failure",-2107487466)));
}),new cljs.core.Keyword("shadow.cljs.devtools.client.env","worker-notify","shadow.cljs.devtools.client.env/worker-notify",-1456820670),(function (p__51892){
var map__51893 = p__51892;
var map__51893__$1 = cljs.core.__destructure_map(map__51893);
var event_op = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51893__$1,new cljs.core.Keyword(null,"event-op","event-op",200358057));
var client_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51893__$1,new cljs.core.Keyword(null,"client-id","client-id",-464622140));
if(((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"client-disconnect","client-disconnect",640227957),event_op)) && (cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(client_id,shadow.cljs.devtools.client.env.worker_client_id)))){
shadow.cljs.devtools.client.hud.connection_error_clear_BANG_();

return shadow.cljs.devtools.client.hud.connection_error("The watch for this build was stopped!");
} else {
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"client-connect","client-connect",-1113973888),event_op)){
shadow.cljs.devtools.client.hud.connection_error_clear_BANG_();

return shadow.cljs.devtools.client.hud.connection_error("The watch for this build was restarted. Reload required!");
} else {
return null;
}
}
})], null)], null));

return svc;
}),(function (p__51894){
var map__51895 = p__51894;
var map__51895__$1 = cljs.core.__destructure_map(map__51895);
var svc = map__51895__$1;
var runtime = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__51895__$1,new cljs.core.Keyword(null,"runtime","runtime",-1331573996));
return shadow.remote.runtime.api.del_extension(runtime,new cljs.core.Keyword("shadow.cljs.devtools.client.browser","client","shadow.cljs.devtools.client.browser/client",-1461019282));
}));

shadow.cljs.devtools.client.shared.init_runtime_BANG_(shadow.cljs.devtools.client.browser.client_info,shadow.cljs.devtools.client.websocket.start,shadow.cljs.devtools.client.websocket.send,shadow.cljs.devtools.client.websocket.stop);
} else {
}

//# sourceMappingURL=shadow.cljs.devtools.client.browser.js.map
