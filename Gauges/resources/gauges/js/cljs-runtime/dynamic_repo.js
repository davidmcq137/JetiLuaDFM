goog.provide('dynamic_repo');
dynamic_repo.new_random_token = (function dynamic_repo$new_random_token(n_random_bytes){
var alphabet = "234679CDFGHJRTWX";
var bs = (function (){var G__53299 = (new Uint8Array(n_random_bytes));
window.crypto.getRandomValues(G__53299);

return G__53299;
})();
return cljs.core.apply.cljs$core$IFn$_invoke$arity$2(cljs.core.str,(function (){var iter__4564__auto__ = (function dynamic_repo$new_random_token_$_iter__53300(s__53301){
return (new cljs.core.LazySeq(null,(function (){
var s__53301__$1 = s__53301;
while(true){
var temp__5804__auto__ = cljs.core.seq(s__53301__$1);
if(temp__5804__auto__){
var s__53301__$2 = temp__5804__auto__;
if(cljs.core.chunked_seq_QMARK_(s__53301__$2)){
var c__4562__auto__ = cljs.core.chunk_first(s__53301__$2);
var size__4563__auto__ = cljs.core.count(c__4562__auto__);
var b__53303 = cljs.core.chunk_buffer(size__4563__auto__);
if((function (){var i__53302 = (0);
while(true){
if((i__53302 < size__4563__auto__)){
var i = cljs.core._nth(c__4562__auto__,i__53302);
cljs.core.chunk_append(b__53303,[cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(alphabet,(((bs[i]) & (15)) >> (0)))),cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(alphabet,(((bs[i]) & (240)) >> (4))))].join(''));

var G__53341 = (i__53302 + (1));
i__53302 = G__53341;
continue;
} else {
return true;
}
break;
}
})()){
return cljs.core.chunk_cons(cljs.core.chunk(b__53303),dynamic_repo$new_random_token_$_iter__53300(cljs.core.chunk_rest(s__53301__$2)));
} else {
return cljs.core.chunk_cons(cljs.core.chunk(b__53303),null);
}
} else {
var i = cljs.core.first(s__53301__$2);
return cljs.core.cons([cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(alphabet,(((bs[i]) & (15)) >> (0)))),cljs.core.str.cljs$core$IFn$_invoke$arity$1(cljs.core.nth.cljs$core$IFn$_invoke$arity$2(alphabet,(((bs[i]) & (240)) >> (4))))].join(''),dynamic_repo$new_random_token_$_iter__53300(cljs.core.rest(s__53301__$2)));
}
} else {
return null;
}
break;
}
}),null,null));
});
return iter__4564__auto__(cljs.core.range.cljs$core$IFn$_invoke$arity$1(bs.length));
})());
});
dynamic_repo.get_or_create_token_BANG_ = (function dynamic_repo$get_or_create_token_BANG_(){
var key = "user-id-token";
var or__4160__auto__ = window.localStorage.getItem(key);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
var t = dynamic_repo.new_random_token((4));
window.localStorage.setItem(key,t);

return t;
}
});
dynamic_repo.apps_request_result = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(null);
dynamic_repo.modal_state = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(null);
dynamic_repo.send_dynamic_repo_request_BANG_ = (function dynamic_repo$send_dynamic_repo_request_BANG_(json_data){
cljs.core.reset_BANG_(dynamic_repo.modal_state,new cljs.core.Keyword(null,"repo-request","repo-request",1627250361));

var xhr = (new goog.net.XhrIo());
xhr.listen(goog.net.EventType.COMPLETE,(function (_){
return cljs.core.reset_BANG_(dynamic_repo.apps_request_result,xhr.getResponseJson());
}));

return xhr.send(["/dynamic-repo-v2?token=",cljs.core.str.cljs$core$IFn$_invoke$arity$1(dynamic_repo.get_or_create_token_BANG_())].join(''),"POST",JSON.stringify(json_data,null,(2)),({"Content-Type": "application/json;charset=UTF-8"}));
});
dynamic_repo.repo_result_modal = rum.core.lazy_build(rum.core.build_defc,(function (){
return daiquiri.interpreter.interpret((function (){var temp__5804__auto__ = rum.core.react(dynamic_repo.modal_state);
if(cljs.core.truth_(temp__5804__auto__)){
var st = temp__5804__auto__;
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"div.modal","div.modal",-610985484),new cljs.core.PersistentVector(null, 4, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"div.modal-content","div.modal-content",-83470844),new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"span.close","span.close",-217177185),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"on-click","on-click",1632826543),(function (){
return cljs.core.reset_BANG_(dynamic_repo.modal_state,null);
})], null),"\u00D7"], null),(function (){var G__53321 = st;
var G__53321__$1 = (((G__53321 instanceof cljs.core.Keyword))?G__53321.fqn:null);
switch (G__53321__$1) {
case "repo-request":
var res = rum.core.react(dynamic_repo.apps_request_result);
var repo_url = (function (){var G__53322 = res;
if((G__53322 == null)){
return null;
} else {
return (G__53322["repo_url"]);
}
})();
var error = (function (){var G__53323 = res;
if((G__53323 == null)){
return null;
} else {
return (G__53323["error"]);
}
})();
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"div","div",1057191632),"Dynamic repo request",(((res == null))?new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"span","span",1394872991),"Waiting for server..."], null):(cljs.core.truth_(error)?new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"p","p",151049309),"Server error."], null):(cljs.core.truth_(repo_url)?new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"code","code",1586293142),new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"pre","pre",2118456869),repo_url], null)], null):null)))], null);

break;
default:
return ["Weird modal state:",cljs.core.pr_str.cljs$core$IFn$_invoke$arity$variadic(cljs.core.prim_seq.cljs$core$IFn$_invoke$arity$2([st], 0))].join('');

}
})(),new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"div","div",1057191632),new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"button","button",1456579943),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"on-click","on-click",1632826543),(function (){
return cljs.core.reset_BANG_(dynamic_repo.modal_state,null);
})], null),"Close"], null)], null)], null)], null);
} else {
return null;
}
})());
}),new cljs.core.PersistentVector(null, 1, 5, cljs.core.PersistentVector.EMPTY_NODE, [rum.core.reactive], null),"dynamic-repo/repo-result-modal");

//# sourceMappingURL=dynamic_repo.js.map
