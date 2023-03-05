goog.provide('shadow.remote.runtime.shared');
shadow.remote.runtime.shared.init_state = (function shadow$remote$runtime$shared$init_state(client_info){
return new cljs.core.PersistentArrayMap(null, 5, [new cljs.core.Keyword(null,"extensions","extensions",-1103629196),cljs.core.PersistentArrayMap.EMPTY,new cljs.core.Keyword(null,"ops","ops",1237330063),cljs.core.PersistentArrayMap.EMPTY,new cljs.core.Keyword(null,"client-info","client-info",1958982504),client_info,new cljs.core.Keyword(null,"call-id-seq","call-id-seq",-1679248218),(0),new cljs.core.Keyword(null,"call-handlers","call-handlers",386605551),cljs.core.PersistentArrayMap.EMPTY], null);
});
shadow.remote.runtime.shared.now = (function shadow$remote$runtime$shared$now(){
return Date.now();
});
shadow.remote.runtime.shared.relay_msg = (function shadow$remote$runtime$shared$relay_msg(runtime,msg){
return shadow.remote.runtime.api.relay_msg(runtime,msg);
});
shadow.remote.runtime.shared.reply = (function shadow$remote$runtime$shared$reply(runtime,p__49437,res){
var map__49438 = p__49437;
var map__49438__$1 = cljs.core.__destructure_map(map__49438);
var call_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49438__$1,new cljs.core.Keyword(null,"call-id","call-id",1043012968));
var from = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49438__$1,new cljs.core.Keyword(null,"from","from",1815293044));
var res__$1 = (function (){var G__49439 = res;
var G__49439__$1 = (cljs.core.truth_(call_id)?cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__49439,new cljs.core.Keyword(null,"call-id","call-id",1043012968),call_id):G__49439);
if(cljs.core.truth_(from)){
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(G__49439__$1,new cljs.core.Keyword(null,"to","to",192099007),from);
} else {
return G__49439__$1;
}
})();
return shadow.remote.runtime.api.relay_msg(runtime,res__$1);
});
shadow.remote.runtime.shared.call = (function shadow$remote$runtime$shared$call(var_args){
var G__49441 = arguments.length;
switch (G__49441) {
case 3:
return shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$3 = (function (runtime,msg,handlers){
return shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$4(runtime,msg,handlers,(0));
}));

(shadow.remote.runtime.shared.call.cljs$core$IFn$_invoke$arity$4 = (function (p__49442,msg,handlers,timeout_after_ms){
var map__49443 = p__49442;
var map__49443__$1 = cljs.core.__destructure_map(map__49443);
var runtime = map__49443__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49443__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
var call_id = new cljs.core.Keyword(null,"call-id-seq","call-id-seq",-1679248218).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(state_ref));
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(state_ref,cljs.core.update,new cljs.core.Keyword(null,"call-id-seq","call-id-seq",-1679248218),cljs.core.inc);

cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(state_ref,cljs.core.assoc_in,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"call-handlers","call-handlers",386605551),call_id], null),new cljs.core.PersistentArrayMap(null, 4, [new cljs.core.Keyword(null,"handlers","handlers",79528781),handlers,new cljs.core.Keyword(null,"called-at","called-at",607081160),shadow.remote.runtime.shared.now(),new cljs.core.Keyword(null,"msg","msg",-1386103444),msg,new cljs.core.Keyword(null,"timeout","timeout",-318625318),timeout_after_ms], null));

return shadow.remote.runtime.api.relay_msg(runtime,cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(msg,new cljs.core.Keyword(null,"call-id","call-id",1043012968),call_id));
}));

(shadow.remote.runtime.shared.call.cljs$lang$maxFixedArity = 4);

shadow.remote.runtime.shared.trigger_BANG_ = (function shadow$remote$runtime$shared$trigger_BANG_(var_args){
var args__4777__auto__ = [];
var len__4771__auto___49606 = arguments.length;
var i__4772__auto___49607 = (0);
while(true){
if((i__4772__auto___49607 < len__4771__auto___49606)){
args__4777__auto__.push((arguments[i__4772__auto___49607]));

var G__49608 = (i__4772__auto___49607 + (1));
i__4772__auto___49607 = G__49608;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((2) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((2)),(0),null)):null);
return shadow.remote.runtime.shared.trigger_BANG_.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),(arguments[(1)]),argseq__4778__auto__);
});

(shadow.remote.runtime.shared.trigger_BANG_.cljs$core$IFn$_invoke$arity$variadic = (function (p__49453,ev,args){
var map__49454 = p__49453;
var map__49454__$1 = cljs.core.__destructure_map(map__49454);
var runtime = map__49454__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49454__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
var seq__49455 = cljs.core.seq(cljs.core.vals(new cljs.core.Keyword(null,"extensions","extensions",-1103629196).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(state_ref))));
var chunk__49458 = null;
var count__49459 = (0);
var i__49460 = (0);
while(true){
if((i__49460 < count__49459)){
var ext = chunk__49458.cljs$core$IIndexed$_nth$arity$2(null,i__49460);
var ev_fn = cljs.core.get.cljs$core$IFn$_invoke$arity$2(ext,ev);
if(cljs.core.truth_(ev_fn)){
cljs.core.apply.cljs$core$IFn$_invoke$arity$2(ev_fn,args);


var G__49614 = seq__49455;
var G__49615 = chunk__49458;
var G__49616 = count__49459;
var G__49617 = (i__49460 + (1));
seq__49455 = G__49614;
chunk__49458 = G__49615;
count__49459 = G__49616;
i__49460 = G__49617;
continue;
} else {
var G__49618 = seq__49455;
var G__49619 = chunk__49458;
var G__49620 = count__49459;
var G__49621 = (i__49460 + (1));
seq__49455 = G__49618;
chunk__49458 = G__49619;
count__49459 = G__49620;
i__49460 = G__49621;
continue;
}
} else {
var temp__5804__auto__ = cljs.core.seq(seq__49455);
if(temp__5804__auto__){
var seq__49455__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__49455__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__49455__$1);
var G__49622 = cljs.core.chunk_rest(seq__49455__$1);
var G__49623 = c__4591__auto__;
var G__49624 = cljs.core.count(c__4591__auto__);
var G__49625 = (0);
seq__49455 = G__49622;
chunk__49458 = G__49623;
count__49459 = G__49624;
i__49460 = G__49625;
continue;
} else {
var ext = cljs.core.first(seq__49455__$1);
var ev_fn = cljs.core.get.cljs$core$IFn$_invoke$arity$2(ext,ev);
if(cljs.core.truth_(ev_fn)){
cljs.core.apply.cljs$core$IFn$_invoke$arity$2(ev_fn,args);


var G__49626 = cljs.core.next(seq__49455__$1);
var G__49627 = null;
var G__49628 = (0);
var G__49629 = (0);
seq__49455 = G__49626;
chunk__49458 = G__49627;
count__49459 = G__49628;
i__49460 = G__49629;
continue;
} else {
var G__49630 = cljs.core.next(seq__49455__$1);
var G__49631 = null;
var G__49632 = (0);
var G__49633 = (0);
seq__49455 = G__49630;
chunk__49458 = G__49631;
count__49459 = G__49632;
i__49460 = G__49633;
continue;
}
}
} else {
return null;
}
}
break;
}
}));

(shadow.remote.runtime.shared.trigger_BANG_.cljs$lang$maxFixedArity = (2));

/** @this {Function} */
(shadow.remote.runtime.shared.trigger_BANG_.cljs$lang$applyTo = (function (seq49450){
var G__49451 = cljs.core.first(seq49450);
var seq49450__$1 = cljs.core.next(seq49450);
var G__49452 = cljs.core.first(seq49450__$1);
var seq49450__$2 = cljs.core.next(seq49450__$1);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__49451,G__49452,seq49450__$2);
}));

shadow.remote.runtime.shared.welcome = (function shadow$remote$runtime$shared$welcome(p__49491,p__49492){
var map__49493 = p__49491;
var map__49493__$1 = cljs.core.__destructure_map(map__49493);
var runtime = map__49493__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49493__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
var map__49494 = p__49492;
var map__49494__$1 = cljs.core.__destructure_map(map__49494);
var msg = map__49494__$1;
var client_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49494__$1,new cljs.core.Keyword(null,"client-id","client-id",-464622140));
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(state_ref,cljs.core.assoc,new cljs.core.Keyword(null,"client-id","client-id",-464622140),client_id);

var map__49495 = cljs.core.deref(state_ref);
var map__49495__$1 = cljs.core.__destructure_map(map__49495);
var client_info = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49495__$1,new cljs.core.Keyword(null,"client-info","client-info",1958982504));
var extensions = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49495__$1,new cljs.core.Keyword(null,"extensions","extensions",-1103629196));
shadow.remote.runtime.shared.relay_msg(runtime,new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"op","op",-1882987955),new cljs.core.Keyword(null,"hello","hello",-245025397),new cljs.core.Keyword(null,"client-info","client-info",1958982504),client_info], null));

return shadow.remote.runtime.shared.trigger_BANG_(runtime,new cljs.core.Keyword(null,"on-welcome","on-welcome",1895317125));
});
shadow.remote.runtime.shared.ping = (function shadow$remote$runtime$shared$ping(runtime,msg){
return shadow.remote.runtime.shared.reply(runtime,msg,new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"op","op",-1882987955),new cljs.core.Keyword(null,"pong","pong",-172484958)], null));
});
shadow.remote.runtime.shared.get_client_id = (function shadow$remote$runtime$shared$get_client_id(p__49497){
var map__49498 = p__49497;
var map__49498__$1 = cljs.core.__destructure_map(map__49498);
var runtime = map__49498__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49498__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
var or__4160__auto__ = new cljs.core.Keyword(null,"client-id","client-id",-464622140).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(state_ref));
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2("runtime has no assigned runtime-id",new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"runtime","runtime",-1331573996),runtime], null));
}
});
shadow.remote.runtime.shared.request_supported_ops = (function shadow$remote$runtime$shared$request_supported_ops(p__49501,msg){
var map__49502 = p__49501;
var map__49502__$1 = cljs.core.__destructure_map(map__49502);
var runtime = map__49502__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49502__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
return shadow.remote.runtime.shared.reply(runtime,msg,new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"op","op",-1882987955),new cljs.core.Keyword(null,"supported-ops","supported-ops",337914702),new cljs.core.Keyword(null,"ops","ops",1237330063),cljs.core.disj.cljs$core$IFn$_invoke$arity$variadic(cljs.core.set(cljs.core.keys(new cljs.core.Keyword(null,"ops","ops",1237330063).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(state_ref)))),new cljs.core.Keyword(null,"welcome","welcome",-578152123),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([new cljs.core.Keyword(null,"unknown-relay-op","unknown-relay-op",170832753),new cljs.core.Keyword(null,"unknown-op","unknown-op",1900385996),new cljs.core.Keyword(null,"request-supported-ops","request-supported-ops",-1034994502),new cljs.core.Keyword(null,"tool-disconnect","tool-disconnect",189103996)], 0))], null));
});
shadow.remote.runtime.shared.unknown_relay_op = (function shadow$remote$runtime$shared$unknown_relay_op(msg){
return console.warn("unknown-relay-op",msg);
});
shadow.remote.runtime.shared.unknown_op = (function shadow$remote$runtime$shared$unknown_op(msg){
return console.warn("unknown-op",msg);
});
shadow.remote.runtime.shared.add_extension_STAR_ = (function shadow$remote$runtime$shared$add_extension_STAR_(p__49506,key,p__49507){
var map__49508 = p__49506;
var map__49508__$1 = cljs.core.__destructure_map(map__49508);
var state = map__49508__$1;
var extensions = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49508__$1,new cljs.core.Keyword(null,"extensions","extensions",-1103629196));
var map__49509 = p__49507;
var map__49509__$1 = cljs.core.__destructure_map(map__49509);
var spec = map__49509__$1;
var ops = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49509__$1,new cljs.core.Keyword(null,"ops","ops",1237330063));
if(cljs.core.contains_QMARK_(extensions,key)){
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2("extension already registered",new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"key","key",-1516042587),key,new cljs.core.Keyword(null,"spec","spec",347520401),spec], null));
} else {
}

return cljs.core.reduce_kv((function (state__$1,op_kw,op_handler){
if(cljs.core.truth_(cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(state__$1,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"ops","ops",1237330063),op_kw], null)))){
throw cljs.core.ex_info.cljs$core$IFn$_invoke$arity$2("op already registered",new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"key","key",-1516042587),key,new cljs.core.Keyword(null,"op","op",-1882987955),op_kw], null));
} else {
}

return cljs.core.assoc_in(state__$1,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"ops","ops",1237330063),op_kw], null),op_handler);
}),cljs.core.assoc_in(state,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"extensions","extensions",-1103629196),key], null),spec),ops);
});
shadow.remote.runtime.shared.add_extension = (function shadow$remote$runtime$shared$add_extension(p__49514,key,spec){
var map__49516 = p__49514;
var map__49516__$1 = cljs.core.__destructure_map(map__49516);
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49516__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(state_ref,shadow.remote.runtime.shared.add_extension_STAR_,key,spec);
});
shadow.remote.runtime.shared.add_defaults = (function shadow$remote$runtime$shared$add_defaults(runtime){
return shadow.remote.runtime.shared.add_extension(runtime,new cljs.core.Keyword("shadow.remote.runtime.shared","defaults","shadow.remote.runtime.shared/defaults",-1821257543),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"ops","ops",1237330063),new cljs.core.PersistentArrayMap(null, 5, [new cljs.core.Keyword(null,"welcome","welcome",-578152123),(function (p1__49518_SHARP_){
return shadow.remote.runtime.shared.welcome(runtime,p1__49518_SHARP_);
}),new cljs.core.Keyword(null,"unknown-relay-op","unknown-relay-op",170832753),(function (p1__49519_SHARP_){
return shadow.remote.runtime.shared.unknown_relay_op(p1__49519_SHARP_);
}),new cljs.core.Keyword(null,"unknown-op","unknown-op",1900385996),(function (p1__49520_SHARP_){
return shadow.remote.runtime.shared.unknown_op(p1__49520_SHARP_);
}),new cljs.core.Keyword(null,"ping","ping",-1670114784),(function (p1__49521_SHARP_){
return shadow.remote.runtime.shared.ping(runtime,p1__49521_SHARP_);
}),new cljs.core.Keyword(null,"request-supported-ops","request-supported-ops",-1034994502),(function (p1__49522_SHARP_){
return shadow.remote.runtime.shared.request_supported_ops(runtime,p1__49522_SHARP_);
})], null)], null));
});
shadow.remote.runtime.shared.del_extension_STAR_ = (function shadow$remote$runtime$shared$del_extension_STAR_(state,key){
var ext = cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(state,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"extensions","extensions",-1103629196),key], null));
if(cljs.core.not(ext)){
return state;
} else {
return cljs.core.reduce_kv((function (state__$1,op_kw,op_handler){
return cljs.core.update_in.cljs$core$IFn$_invoke$arity$4(state__$1,new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"ops","ops",1237330063)], null),cljs.core.dissoc,op_kw);
}),cljs.core.update.cljs$core$IFn$_invoke$arity$4(state,new cljs.core.Keyword(null,"extensions","extensions",-1103629196),cljs.core.dissoc,key),new cljs.core.Keyword(null,"ops","ops",1237330063).cljs$core$IFn$_invoke$arity$1(ext));
}
});
shadow.remote.runtime.shared.del_extension = (function shadow$remote$runtime$shared$del_extension(p__49524,key){
var map__49525 = p__49524;
var map__49525__$1 = cljs.core.__destructure_map(map__49525);
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49525__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(state_ref,shadow.remote.runtime.shared.del_extension_STAR_,key);
});
shadow.remote.runtime.shared.unhandled_call_result = (function shadow$remote$runtime$shared$unhandled_call_result(call_config,msg){
return console.warn("unhandled call result",msg,call_config);
});
shadow.remote.runtime.shared.unhandled_client_not_found = (function shadow$remote$runtime$shared$unhandled_client_not_found(p__49526,msg){
var map__49527 = p__49526;
var map__49527__$1 = cljs.core.__destructure_map(map__49527);
var runtime = map__49527__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49527__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
return shadow.remote.runtime.shared.trigger_BANG_.cljs$core$IFn$_invoke$arity$variadic(runtime,new cljs.core.Keyword(null,"on-client-not-found","on-client-not-found",-642452849),cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([msg], 0));
});
shadow.remote.runtime.shared.reply_unknown_op = (function shadow$remote$runtime$shared$reply_unknown_op(runtime,msg){
return shadow.remote.runtime.shared.reply(runtime,msg,new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"op","op",-1882987955),new cljs.core.Keyword(null,"unknown-op","unknown-op",1900385996),new cljs.core.Keyword(null,"msg","msg",-1386103444),msg], null));
});
shadow.remote.runtime.shared.process = (function shadow$remote$runtime$shared$process(p__49545,p__49546){
var map__49551 = p__49545;
var map__49551__$1 = cljs.core.__destructure_map(map__49551);
var runtime = map__49551__$1;
var state_ref = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49551__$1,new cljs.core.Keyword(null,"state-ref","state-ref",2127874952));
var map__49552 = p__49546;
var map__49552__$1 = cljs.core.__destructure_map(map__49552);
var msg = map__49552__$1;
var op = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49552__$1,new cljs.core.Keyword(null,"op","op",-1882987955));
var call_id = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49552__$1,new cljs.core.Keyword(null,"call-id","call-id",1043012968));
var state = cljs.core.deref(state_ref);
var op_handler = cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(state,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"ops","ops",1237330063),op], null));
if(cljs.core.truth_(call_id)){
var cfg = cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(state,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"call-handlers","call-handlers",386605551),call_id], null));
var call_handler = cljs.core.get_in.cljs$core$IFn$_invoke$arity$2(cfg,new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"handlers","handlers",79528781),op], null));
if(cljs.core.truth_(call_handler)){
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$variadic(state_ref,cljs.core.update,new cljs.core.Keyword(null,"call-handlers","call-handlers",386605551),cljs.core.dissoc,cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([call_id], 0));

return (call_handler.cljs$core$IFn$_invoke$arity$1 ? call_handler.cljs$core$IFn$_invoke$arity$1(msg) : call_handler.call(null,msg));
} else {
if(cljs.core.truth_(op_handler)){
return (op_handler.cljs$core$IFn$_invoke$arity$1 ? op_handler.cljs$core$IFn$_invoke$arity$1(msg) : op_handler.call(null,msg));
} else {
return shadow.remote.runtime.shared.unhandled_call_result(cfg,msg);

}
}
} else {
if(cljs.core.truth_(op_handler)){
return (op_handler.cljs$core$IFn$_invoke$arity$1 ? op_handler.cljs$core$IFn$_invoke$arity$1(msg) : op_handler.call(null,msg));
} else {
if(cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null,"client-not-found","client-not-found",-1754042614),op)){
return shadow.remote.runtime.shared.unhandled_client_not_found(runtime,msg);
} else {
return shadow.remote.runtime.shared.reply_unknown_op(runtime,msg);

}
}
}
});
shadow.remote.runtime.shared.run_on_idle = (function shadow$remote$runtime$shared$run_on_idle(state_ref){
var seq__49557 = cljs.core.seq(cljs.core.vals(new cljs.core.Keyword(null,"extensions","extensions",-1103629196).cljs$core$IFn$_invoke$arity$1(cljs.core.deref(state_ref))));
var chunk__49559 = null;
var count__49560 = (0);
var i__49561 = (0);
while(true){
if((i__49561 < count__49560)){
var map__49586 = chunk__49559.cljs$core$IIndexed$_nth$arity$2(null,i__49561);
var map__49586__$1 = cljs.core.__destructure_map(map__49586);
var on_idle = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49586__$1,new cljs.core.Keyword(null,"on-idle","on-idle",2044706602));
if(cljs.core.truth_(on_idle)){
(on_idle.cljs$core$IFn$_invoke$arity$0 ? on_idle.cljs$core$IFn$_invoke$arity$0() : on_idle.call(null));


var G__49647 = seq__49557;
var G__49648 = chunk__49559;
var G__49649 = count__49560;
var G__49650 = (i__49561 + (1));
seq__49557 = G__49647;
chunk__49559 = G__49648;
count__49560 = G__49649;
i__49561 = G__49650;
continue;
} else {
var G__49651 = seq__49557;
var G__49652 = chunk__49559;
var G__49653 = count__49560;
var G__49654 = (i__49561 + (1));
seq__49557 = G__49651;
chunk__49559 = G__49652;
count__49560 = G__49653;
i__49561 = G__49654;
continue;
}
} else {
var temp__5804__auto__ = cljs.core.seq(seq__49557);
if(temp__5804__auto__){
var seq__49557__$1 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(seq__49557__$1)){
var c__4591__auto__ = cljs.core.chunk_first(seq__49557__$1);
var G__49655 = cljs.core.chunk_rest(seq__49557__$1);
var G__49656 = c__4591__auto__;
var G__49657 = cljs.core.count(c__4591__auto__);
var G__49658 = (0);
seq__49557 = G__49655;
chunk__49559 = G__49656;
count__49560 = G__49657;
i__49561 = G__49658;
continue;
} else {
var map__49599 = cljs.core.first(seq__49557__$1);
var map__49599__$1 = cljs.core.__destructure_map(map__49599);
var on_idle = cljs.core.get.cljs$core$IFn$_invoke$arity$2(map__49599__$1,new cljs.core.Keyword(null,"on-idle","on-idle",2044706602));
if(cljs.core.truth_(on_idle)){
(on_idle.cljs$core$IFn$_invoke$arity$0 ? on_idle.cljs$core$IFn$_invoke$arity$0() : on_idle.call(null));


var G__49659 = cljs.core.next(seq__49557__$1);
var G__49660 = null;
var G__49661 = (0);
var G__49662 = (0);
seq__49557 = G__49659;
chunk__49559 = G__49660;
count__49560 = G__49661;
i__49561 = G__49662;
continue;
} else {
var G__49663 = cljs.core.next(seq__49557__$1);
var G__49664 = null;
var G__49665 = (0);
var G__49666 = (0);
seq__49557 = G__49663;
chunk__49559 = G__49664;
count__49560 = G__49665;
i__49561 = G__49666;
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

//# sourceMappingURL=shadow.remote.runtime.shared.js.map
