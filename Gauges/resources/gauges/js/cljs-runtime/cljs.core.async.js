goog.provide('cljs.core.async');
cljs.core.async.fn_handler = (function cljs$core$async$fn_handler(var_args){
var G__46743 = arguments.length;
switch (G__46743) {
case 1:
return cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$1 = (function (f){
return cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$2(f,true);
}));

(cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$2 = (function (f,blockable){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async46744 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Handler}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async46744 = (function (f,blockable,meta46745){
this.f = f;
this.blockable = blockable;
this.meta46745 = meta46745;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_46746,meta46745__$1){
var self__ = this;
var _46746__$1 = this;
return (new cljs.core.async.t_cljs$core$async46744(self__.f,self__.blockable,meta46745__$1));
}));

(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_46746){
var self__ = this;
var _46746__$1 = this;
return self__.meta46745;
}));

(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$async$impl$protocols$Handler$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$async$impl$protocols$Handler$active_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return true;
}));

(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$async$impl$protocols$Handler$blockable_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return self__.blockable;
}));

(cljs.core.async.t_cljs$core$async46744.prototype.cljs$core$async$impl$protocols$Handler$commit$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return self__.f;
}));

(cljs.core.async.t_cljs$core$async46744.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"f","f",43394975,null),new cljs.core.Symbol(null,"blockable","blockable",-28395259,null),new cljs.core.Symbol(null,"meta46745","meta46745",-291030754,null)], null);
}));

(cljs.core.async.t_cljs$core$async46744.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async46744.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async46744");

(cljs.core.async.t_cljs$core$async46744.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async46744");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async46744.
 */
cljs.core.async.__GT_t_cljs$core$async46744 = (function cljs$core$async$__GT_t_cljs$core$async46744(f__$1,blockable__$1,meta46745){
return (new cljs.core.async.t_cljs$core$async46744(f__$1,blockable__$1,meta46745));
});

}

return (new cljs.core.async.t_cljs$core$async46744(f,blockable,cljs.core.PersistentArrayMap.EMPTY));
}));

(cljs.core.async.fn_handler.cljs$lang$maxFixedArity = 2);

/**
 * Returns a fixed buffer of size n. When full, puts will block/park.
 */
cljs.core.async.buffer = (function cljs$core$async$buffer(n){
return cljs.core.async.impl.buffers.fixed_buffer(n);
});
/**
 * Returns a buffer of size n. When full, puts will complete but
 *   val will be dropped (no transfer).
 */
cljs.core.async.dropping_buffer = (function cljs$core$async$dropping_buffer(n){
return cljs.core.async.impl.buffers.dropping_buffer(n);
});
/**
 * Returns a buffer of size n. When full, puts will complete, and be
 *   buffered, but oldest elements in buffer will be dropped (not
 *   transferred).
 */
cljs.core.async.sliding_buffer = (function cljs$core$async$sliding_buffer(n){
return cljs.core.async.impl.buffers.sliding_buffer(n);
});
/**
 * Returns true if a channel created with buff will never block. That is to say,
 * puts into this buffer will never cause the buffer to be full. 
 */
cljs.core.async.unblocking_buffer_QMARK_ = (function cljs$core$async$unblocking_buffer_QMARK_(buff){
if((!((buff == null)))){
if(((false) || ((cljs.core.PROTOCOL_SENTINEL === buff.cljs$core$async$impl$protocols$UnblockingBuffer$)))){
return true;
} else {
if((!buff.cljs$lang$protocol_mask$partition$)){
return cljs.core.native_satisfies_QMARK_(cljs.core.async.impl.protocols.UnblockingBuffer,buff);
} else {
return false;
}
}
} else {
return cljs.core.native_satisfies_QMARK_(cljs.core.async.impl.protocols.UnblockingBuffer,buff);
}
});
/**
 * Creates a channel with an optional buffer, an optional transducer (like (map f),
 *   (filter p) etc or a composition thereof), and an optional exception handler.
 *   If buf-or-n is a number, will create and use a fixed buffer of that size. If a
 *   transducer is supplied a buffer must be specified. ex-handler must be a
 *   fn of one argument - if an exception occurs during transformation it will be called
 *   with the thrown value as an argument, and any non-nil return value will be placed
 *   in the channel.
 */
cljs.core.async.chan = (function cljs$core$async$chan(var_args){
var G__46758 = arguments.length;
switch (G__46758) {
case 0:
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$0();

break;
case 1:
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.chan.cljs$core$IFn$_invoke$arity$0 = (function (){
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(null);
}));

(cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1 = (function (buf_or_n){
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3(buf_or_n,null,null);
}));

(cljs.core.async.chan.cljs$core$IFn$_invoke$arity$2 = (function (buf_or_n,xform){
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3(buf_or_n,xform,null);
}));

(cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3 = (function (buf_or_n,xform,ex_handler){
var buf_or_n__$1 = ((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(buf_or_n,(0)))?null:buf_or_n);
if(cljs.core.truth_(xform)){
if(cljs.core.truth_(buf_or_n__$1)){
} else {
throw (new Error(["Assert failed: ","buffer must be supplied when transducer is","\n","buf-or-n"].join('')));
}
} else {
}

return cljs.core.async.impl.channels.chan.cljs$core$IFn$_invoke$arity$3(((typeof buf_or_n__$1 === 'number')?cljs.core.async.buffer(buf_or_n__$1):buf_or_n__$1),xform,ex_handler);
}));

(cljs.core.async.chan.cljs$lang$maxFixedArity = 3);

/**
 * Creates a promise channel with an optional transducer, and an optional
 *   exception-handler. A promise channel can take exactly one value that consumers
 *   will receive. Once full, puts complete but val is dropped (no transfer).
 *   Consumers will block until either a value is placed in the channel or the
 *   channel is closed. See chan for the semantics of xform and ex-handler.
 */
cljs.core.async.promise_chan = (function cljs$core$async$promise_chan(var_args){
var G__46760 = arguments.length;
switch (G__46760) {
case 0:
return cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$0();

break;
case 1:
return cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$0 = (function (){
return cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$1(null);
}));

(cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$1 = (function (xform){
return cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$2(xform,null);
}));

(cljs.core.async.promise_chan.cljs$core$IFn$_invoke$arity$2 = (function (xform,ex_handler){
return cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3(cljs.core.async.impl.buffers.promise_buffer(),xform,ex_handler);
}));

(cljs.core.async.promise_chan.cljs$lang$maxFixedArity = 2);

/**
 * Returns a channel that will close after msecs
 */
cljs.core.async.timeout = (function cljs$core$async$timeout(msecs){
return cljs.core.async.impl.timers.timeout(msecs);
});
/**
 * takes a val from port. Must be called inside a (go ...) block. Will
 *   return nil if closed. Will park if nothing is available.
 *   Returns true unless port is already closed
 */
cljs.core.async._LT__BANG_ = (function cljs$core$async$_LT__BANG_(port){
throw (new Error("<! used not in (go ...) block"));
});
/**
 * Asynchronously takes a val from port, passing to fn1. Will pass nil
 * if closed. If on-caller? (default true) is true, and value is
 * immediately available, will call fn1 on calling thread.
 * Returns nil.
 */
cljs.core.async.take_BANG_ = (function cljs$core$async$take_BANG_(var_args){
var G__46762 = arguments.length;
switch (G__46762) {
case 2:
return cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$2 = (function (port,fn1){
return cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$3(port,fn1,true);
}));

(cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$3 = (function (port,fn1,on_caller_QMARK_){
var ret = cljs.core.async.impl.protocols.take_BANG_(port,cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$1(fn1));
if(cljs.core.truth_(ret)){
var val_48252 = cljs.core.deref(ret);
if(cljs.core.truth_(on_caller_QMARK_)){
(fn1.cljs$core$IFn$_invoke$arity$1 ? fn1.cljs$core$IFn$_invoke$arity$1(val_48252) : fn1.call(null,val_48252));
} else {
cljs.core.async.impl.dispatch.run((function (){
return (fn1.cljs$core$IFn$_invoke$arity$1 ? fn1.cljs$core$IFn$_invoke$arity$1(val_48252) : fn1.call(null,val_48252));
}));
}
} else {
}

return null;
}));

(cljs.core.async.take_BANG_.cljs$lang$maxFixedArity = 3);

cljs.core.async.nop = (function cljs$core$async$nop(_){
return null;
});
cljs.core.async.fhnop = cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$1(cljs.core.async.nop);
/**
 * puts a val into port. nil values are not allowed. Must be called
 *   inside a (go ...) block. Will park if no buffer space is available.
 *   Returns true unless port is already closed.
 */
cljs.core.async._GT__BANG_ = (function cljs$core$async$_GT__BANG_(port,val){
throw (new Error(">! used not in (go ...) block"));
});
/**
 * Asynchronously puts a val into port, calling fn1 (if supplied) when
 * complete. nil values are not allowed. Will throw if closed. If
 * on-caller? (default true) is true, and the put is immediately
 * accepted, will call fn1 on calling thread.  Returns nil.
 */
cljs.core.async.put_BANG_ = (function cljs$core$async$put_BANG_(var_args){
var G__46768 = arguments.length;
switch (G__46768) {
case 2:
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2 = (function (port,val){
var temp__5802__auto__ = cljs.core.async.impl.protocols.put_BANG_(port,val,cljs.core.async.fhnop);
if(cljs.core.truth_(temp__5802__auto__)){
var ret = temp__5802__auto__;
return cljs.core.deref(ret);
} else {
return true;
}
}));

(cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$3 = (function (port,val,fn1){
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$4(port,val,fn1,true);
}));

(cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$4 = (function (port,val,fn1,on_caller_QMARK_){
var temp__5802__auto__ = cljs.core.async.impl.protocols.put_BANG_(port,val,cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$1(fn1));
if(cljs.core.truth_(temp__5802__auto__)){
var retb = temp__5802__auto__;
var ret = cljs.core.deref(retb);
if(cljs.core.truth_(on_caller_QMARK_)){
(fn1.cljs$core$IFn$_invoke$arity$1 ? fn1.cljs$core$IFn$_invoke$arity$1(ret) : fn1.call(null,ret));
} else {
cljs.core.async.impl.dispatch.run((function (){
return (fn1.cljs$core$IFn$_invoke$arity$1 ? fn1.cljs$core$IFn$_invoke$arity$1(ret) : fn1.call(null,ret));
}));
}

return ret;
} else {
return true;
}
}));

(cljs.core.async.put_BANG_.cljs$lang$maxFixedArity = 4);

cljs.core.async.close_BANG_ = (function cljs$core$async$close_BANG_(port){
return cljs.core.async.impl.protocols.close_BANG_(port);
});
cljs.core.async.random_array = (function cljs$core$async$random_array(n){
var a = (new Array(n));
var n__4648__auto___48254 = n;
var x_48255 = (0);
while(true){
if((x_48255 < n__4648__auto___48254)){
(a[x_48255] = x_48255);

var G__48256 = (x_48255 + (1));
x_48255 = G__48256;
continue;
} else {
}
break;
}

goog.array.shuffle(a);

return a;
});
cljs.core.async.alt_flag = (function cljs$core$async$alt_flag(){
var flag = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(true);
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async46772 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Handler}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async46772 = (function (flag,meta46773){
this.flag = flag;
this.meta46773 = meta46773;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_46774,meta46773__$1){
var self__ = this;
var _46774__$1 = this;
return (new cljs.core.async.t_cljs$core$async46772(self__.flag,meta46773__$1));
}));

(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_46774){
var self__ = this;
var _46774__$1 = this;
return self__.meta46773;
}));

(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$async$impl$protocols$Handler$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$async$impl$protocols$Handler$active_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.deref(self__.flag);
}));

(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$async$impl$protocols$Handler$blockable_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return true;
}));

(cljs.core.async.t_cljs$core$async46772.prototype.cljs$core$async$impl$protocols$Handler$commit$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
cljs.core.reset_BANG_(self__.flag,null);

return true;
}));

(cljs.core.async.t_cljs$core$async46772.getBasis = (function (){
return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"flag","flag",-1565787888,null),new cljs.core.Symbol(null,"meta46773","meta46773",678749074,null)], null);
}));

(cljs.core.async.t_cljs$core$async46772.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async46772.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async46772");

(cljs.core.async.t_cljs$core$async46772.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async46772");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async46772.
 */
cljs.core.async.__GT_t_cljs$core$async46772 = (function cljs$core$async$alt_flag_$___GT_t_cljs$core$async46772(flag__$1,meta46773){
return (new cljs.core.async.t_cljs$core$async46772(flag__$1,meta46773));
});

}

return (new cljs.core.async.t_cljs$core$async46772(flag,cljs.core.PersistentArrayMap.EMPTY));
});
cljs.core.async.alt_handler = (function cljs$core$async$alt_handler(flag,cb){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async46778 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Handler}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async46778 = (function (flag,cb,meta46779){
this.flag = flag;
this.cb = cb;
this.meta46779 = meta46779;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_46780,meta46779__$1){
var self__ = this;
var _46780__$1 = this;
return (new cljs.core.async.t_cljs$core$async46778(self__.flag,self__.cb,meta46779__$1));
}));

(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_46780){
var self__ = this;
var _46780__$1 = this;
return self__.meta46779;
}));

(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$async$impl$protocols$Handler$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$async$impl$protocols$Handler$active_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.active_QMARK_(self__.flag);
}));

(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$async$impl$protocols$Handler$blockable_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return true;
}));

(cljs.core.async.t_cljs$core$async46778.prototype.cljs$core$async$impl$protocols$Handler$commit$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
cljs.core.async.impl.protocols.commit(self__.flag);

return self__.cb;
}));

(cljs.core.async.t_cljs$core$async46778.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"flag","flag",-1565787888,null),new cljs.core.Symbol(null,"cb","cb",-2064487928,null),new cljs.core.Symbol(null,"meta46779","meta46779",162004883,null)], null);
}));

(cljs.core.async.t_cljs$core$async46778.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async46778.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async46778");

(cljs.core.async.t_cljs$core$async46778.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async46778");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async46778.
 */
cljs.core.async.__GT_t_cljs$core$async46778 = (function cljs$core$async$alt_handler_$___GT_t_cljs$core$async46778(flag__$1,cb__$1,meta46779){
return (new cljs.core.async.t_cljs$core$async46778(flag__$1,cb__$1,meta46779));
});

}

return (new cljs.core.async.t_cljs$core$async46778(flag,cb,cljs.core.PersistentArrayMap.EMPTY));
});
/**
 * returns derefable [val port] if immediate, nil if enqueued
 */
cljs.core.async.do_alts = (function cljs$core$async$do_alts(fret,ports,opts){
if((cljs.core.count(ports) > (0))){
} else {
throw (new Error(["Assert failed: ","alts must have at least one channel operation","\n","(pos? (count ports))"].join('')));
}

var flag = cljs.core.async.alt_flag();
var ports__$1 = cljs.core.vec(ports);
var n = cljs.core.count(ports__$1);
var idxs = cljs.core.async.random_array(n);
var priority = new cljs.core.Keyword(null,"priority","priority",1431093715).cljs$core$IFn$_invoke$arity$1(opts);
var ret = (function (){var i = (0);
while(true){
if((i < n)){
var idx = (cljs.core.truth_(priority)?i:(idxs[i]));
var port = cljs.core.nth.cljs$core$IFn$_invoke$arity$2(ports__$1,idx);
var wport = ((cljs.core.vector_QMARK_(port))?(port.cljs$core$IFn$_invoke$arity$1 ? port.cljs$core$IFn$_invoke$arity$1((0)) : port.call(null,(0))):null);
var vbox = (cljs.core.truth_(wport)?(function (){var val = (port.cljs$core$IFn$_invoke$arity$1 ? port.cljs$core$IFn$_invoke$arity$1((1)) : port.call(null,(1)));
return cljs.core.async.impl.protocols.put_BANG_(wport,val,cljs.core.async.alt_handler(flag,((function (i,val,idx,port,wport,flag,ports__$1,n,idxs,priority){
return (function (p1__46781_SHARP_){
var G__46783 = new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [p1__46781_SHARP_,wport], null);
return (fret.cljs$core$IFn$_invoke$arity$1 ? fret.cljs$core$IFn$_invoke$arity$1(G__46783) : fret.call(null,G__46783));
});})(i,val,idx,port,wport,flag,ports__$1,n,idxs,priority))
));
})():cljs.core.async.impl.protocols.take_BANG_(port,cljs.core.async.alt_handler(flag,((function (i,idx,port,wport,flag,ports__$1,n,idxs,priority){
return (function (p1__46782_SHARP_){
var G__46784 = new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [p1__46782_SHARP_,port], null);
return (fret.cljs$core$IFn$_invoke$arity$1 ? fret.cljs$core$IFn$_invoke$arity$1(G__46784) : fret.call(null,G__46784));
});})(i,idx,port,wport,flag,ports__$1,n,idxs,priority))
)));
if(cljs.core.truth_(vbox)){
return cljs.core.async.impl.channels.box(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [cljs.core.deref(vbox),(function (){var or__4160__auto__ = wport;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return port;
}
})()], null));
} else {
var G__48259 = (i + (1));
i = G__48259;
continue;
}
} else {
return null;
}
break;
}
})();
var or__4160__auto__ = ret;
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
if(cljs.core.contains_QMARK_(opts,new cljs.core.Keyword(null,"default","default",-1987822328))){
var temp__5804__auto__ = (function (){var and__4149__auto__ = flag.cljs$core$async$impl$protocols$Handler$active_QMARK_$arity$1(null);
if(cljs.core.truth_(and__4149__auto__)){
return flag.cljs$core$async$impl$protocols$Handler$commit$arity$1(null);
} else {
return and__4149__auto__;
}
})();
if(cljs.core.truth_(temp__5804__auto__)){
var got = temp__5804__auto__;
return cljs.core.async.impl.channels.box(new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Keyword(null,"default","default",-1987822328).cljs$core$IFn$_invoke$arity$1(opts),new cljs.core.Keyword(null,"default","default",-1987822328)], null));
} else {
return null;
}
} else {
return null;
}
}
});
/**
 * Completes at most one of several channel operations. Must be called
 * inside a (go ...) block. ports is a vector of channel endpoints,
 * which can be either a channel to take from or a vector of
 *   [channel-to-put-to val-to-put], in any combination. Takes will be
 *   made as if by <!, and puts will be made as if by >!. Unless
 *   the :priority option is true, if more than one port operation is
 *   ready a non-deterministic choice will be made. If no operation is
 *   ready and a :default value is supplied, [default-val :default] will
 *   be returned, otherwise alts! will park until the first operation to
 *   become ready completes. Returns [val port] of the completed
 *   operation, where val is the value taken for takes, and a
 *   boolean (true unless already closed, as per put!) for puts.
 * 
 *   opts are passed as :key val ... Supported options:
 * 
 *   :default val - the value to use if none of the operations are immediately ready
 *   :priority true - (default nil) when true, the operations will be tried in order.
 * 
 *   Note: there is no guarantee that the port exps or val exprs will be
 *   used, nor in what order should they be, so they should not be
 *   depended upon for side effects.
 */
cljs.core.async.alts_BANG_ = (function cljs$core$async$alts_BANG_(var_args){
var args__4777__auto__ = [];
var len__4771__auto___48260 = arguments.length;
var i__4772__auto___48261 = (0);
while(true){
if((i__4772__auto___48261 < len__4771__auto___48260)){
args__4777__auto__.push((arguments[i__4772__auto___48261]));

var G__48262 = (i__4772__auto___48261 + (1));
i__4772__auto___48261 = G__48262;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((1) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((1)),(0),null)):null);
return cljs.core.async.alts_BANG_.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),argseq__4778__auto__);
});

(cljs.core.async.alts_BANG_.cljs$core$IFn$_invoke$arity$variadic = (function (ports,p__46787){
var map__46788 = p__46787;
var map__46788__$1 = cljs.core.__destructure_map(map__46788);
var opts = map__46788__$1;
throw (new Error("alts! used not in (go ...) block"));
}));

(cljs.core.async.alts_BANG_.cljs$lang$maxFixedArity = (1));

/** @this {Function} */
(cljs.core.async.alts_BANG_.cljs$lang$applyTo = (function (seq46785){
var G__46786 = cljs.core.first(seq46785);
var seq46785__$1 = cljs.core.next(seq46785);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__46786,seq46785__$1);
}));

/**
 * Puts a val into port if it's possible to do so immediately.
 *   nil values are not allowed. Never blocks. Returns true if offer succeeds.
 */
cljs.core.async.offer_BANG_ = (function cljs$core$async$offer_BANG_(port,val){
var ret = cljs.core.async.impl.protocols.put_BANG_(port,val,cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$2(cljs.core.async.nop,false));
if(cljs.core.truth_(ret)){
return cljs.core.deref(ret);
} else {
return null;
}
});
/**
 * Takes a val from port if it's possible to do so immediately.
 *   Never blocks. Returns value if successful, nil otherwise.
 */
cljs.core.async.poll_BANG_ = (function cljs$core$async$poll_BANG_(port){
var ret = cljs.core.async.impl.protocols.take_BANG_(port,cljs.core.async.fn_handler.cljs$core$IFn$_invoke$arity$2(cljs.core.async.nop,false));
if(cljs.core.truth_(ret)){
return cljs.core.deref(ret);
} else {
return null;
}
});
/**
 * Takes elements from the from channel and supplies them to the to
 * channel. By default, the to channel will be closed when the from
 * channel closes, but can be determined by the close?  parameter. Will
 * stop consuming the from channel if the to channel closes
 */
cljs.core.async.pipe = (function cljs$core$async$pipe(var_args){
var G__46790 = arguments.length;
switch (G__46790) {
case 2:
return cljs.core.async.pipe.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.pipe.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.pipe.cljs$core$IFn$_invoke$arity$2 = (function (from,to){
return cljs.core.async.pipe.cljs$core$IFn$_invoke$arity$3(from,to,true);
}));

(cljs.core.async.pipe.cljs$core$IFn$_invoke$arity$3 = (function (from,to,close_QMARK_){
var c__46685__auto___48264 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_46814){
var state_val_46815 = (state_46814[(1)]);
if((state_val_46815 === (7))){
var inst_46810 = (state_46814[(2)]);
var state_46814__$1 = state_46814;
var statearr_46816_48265 = state_46814__$1;
(statearr_46816_48265[(2)] = inst_46810);

(statearr_46816_48265[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (1))){
var state_46814__$1 = state_46814;
var statearr_46819_48266 = state_46814__$1;
(statearr_46819_48266[(2)] = null);

(statearr_46819_48266[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (4))){
var inst_46793 = (state_46814[(7)]);
var inst_46793__$1 = (state_46814[(2)]);
var inst_46794 = (inst_46793__$1 == null);
var state_46814__$1 = (function (){var statearr_46823 = state_46814;
(statearr_46823[(7)] = inst_46793__$1);

return statearr_46823;
})();
if(cljs.core.truth_(inst_46794)){
var statearr_46825_48267 = state_46814__$1;
(statearr_46825_48267[(1)] = (5));

} else {
var statearr_46826_48268 = state_46814__$1;
(statearr_46826_48268[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (13))){
var state_46814__$1 = state_46814;
var statearr_46827_48269 = state_46814__$1;
(statearr_46827_48269[(2)] = null);

(statearr_46827_48269[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (6))){
var inst_46793 = (state_46814[(7)]);
var state_46814__$1 = state_46814;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_46814__$1,(11),to,inst_46793);
} else {
if((state_val_46815 === (3))){
var inst_46812 = (state_46814[(2)]);
var state_46814__$1 = state_46814;
return cljs.core.async.impl.ioc_helpers.return_chan(state_46814__$1,inst_46812);
} else {
if((state_val_46815 === (12))){
var state_46814__$1 = state_46814;
var statearr_46833_48270 = state_46814__$1;
(statearr_46833_48270[(2)] = null);

(statearr_46833_48270[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (2))){
var state_46814__$1 = state_46814;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_46814__$1,(4),from);
} else {
if((state_val_46815 === (11))){
var inst_46803 = (state_46814[(2)]);
var state_46814__$1 = state_46814;
if(cljs.core.truth_(inst_46803)){
var statearr_46840_48271 = state_46814__$1;
(statearr_46840_48271[(1)] = (12));

} else {
var statearr_46841_48272 = state_46814__$1;
(statearr_46841_48272[(1)] = (13));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (9))){
var state_46814__$1 = state_46814;
var statearr_46843_48273 = state_46814__$1;
(statearr_46843_48273[(2)] = null);

(statearr_46843_48273[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (5))){
var state_46814__$1 = state_46814;
if(cljs.core.truth_(close_QMARK_)){
var statearr_46845_48274 = state_46814__$1;
(statearr_46845_48274[(1)] = (8));

} else {
var statearr_46846_48275 = state_46814__$1;
(statearr_46846_48275[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (14))){
var inst_46808 = (state_46814[(2)]);
var state_46814__$1 = state_46814;
var statearr_46847_48277 = state_46814__$1;
(statearr_46847_48277[(2)] = inst_46808);

(statearr_46847_48277[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (10))){
var inst_46800 = (state_46814[(2)]);
var state_46814__$1 = state_46814;
var statearr_46848_48278 = state_46814__$1;
(statearr_46848_48278[(2)] = inst_46800);

(statearr_46848_48278[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46815 === (8))){
var inst_46797 = cljs.core.async.close_BANG_(to);
var state_46814__$1 = state_46814;
var statearr_46849_48279 = state_46814__$1;
(statearr_46849_48279[(2)] = inst_46797);

(statearr_46849_48279[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_46850 = [null,null,null,null,null,null,null,null];
(statearr_46850[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_46850[(1)] = (1));

return statearr_46850;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_46814){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_46814);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e46851){var ex__46653__auto__ = e46851;
var statearr_46852_48281 = state_46814;
(statearr_46852_48281[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_46814[(4)]))){
var statearr_46853_48283 = state_46814;
(statearr_46853_48283[(1)] = cljs.core.first((state_46814[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48284 = state_46814;
state_46814 = G__48284;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_46814){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_46814);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_46854 = f__46686__auto__();
(statearr_46854[(6)] = c__46685__auto___48264);

return statearr_46854;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return to;
}));

(cljs.core.async.pipe.cljs$lang$maxFixedArity = 3);

cljs.core.async.pipeline_STAR_ = (function cljs$core$async$pipeline_STAR_(n,to,xf,from,close_QMARK_,ex_handler,type){
if((n > (0))){
} else {
throw (new Error("Assert failed: (pos? n)"));
}

var jobs = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(n);
var results = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(n);
var process = (function (p__46864){
var vec__46866 = p__46864;
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__46866,(0),null);
var p = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__46866,(1),null);
var job = vec__46866;
if((job == null)){
cljs.core.async.close_BANG_(results);

return null;
} else {
var res = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$3((1),xf,ex_handler);
var c__46685__auto___48285 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_46876){
var state_val_46877 = (state_46876[(1)]);
if((state_val_46877 === (1))){
var state_46876__$1 = state_46876;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_46876__$1,(2),res,v);
} else {
if((state_val_46877 === (2))){
var inst_46873 = (state_46876[(2)]);
var inst_46874 = cljs.core.async.close_BANG_(res);
var state_46876__$1 = (function (){var statearr_46880 = state_46876;
(statearr_46880[(7)] = inst_46873);

return statearr_46880;
})();
return cljs.core.async.impl.ioc_helpers.return_chan(state_46876__$1,inst_46874);
} else {
return null;
}
}
});
return (function() {
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_46881 = [null,null,null,null,null,null,null,null];
(statearr_46881[(0)] = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__);

(statearr_46881[(1)] = (1));

return statearr_46881;
});
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1 = (function (state_46876){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_46876);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e46882){var ex__46653__auto__ = e46882;
var statearr_46883_48288 = state_46876;
(statearr_46883_48288[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_46876[(4)]))){
var statearr_46884_48289 = state_46876;
(statearr_46884_48289[(1)] = cljs.core.first((state_46876[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48290 = state_46876;
state_46876 = G__48290;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = function(state_46876){
switch(arguments.length){
case 0:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1.call(this,state_46876);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0;
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_46885 = f__46686__auto__();
(statearr_46885[(6)] = c__46685__auto___48285);

return statearr_46885;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(p,res);

return true;
}
});
var async = (function (p__46886){
var vec__46887 = p__46886;
var v = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__46887,(0),null);
var p = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(vec__46887,(1),null);
var job = vec__46887;
if((job == null)){
cljs.core.async.close_BANG_(results);

return null;
} else {
var res = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
(xf.cljs$core$IFn$_invoke$arity$2 ? xf.cljs$core$IFn$_invoke$arity$2(v,res) : xf.call(null,v,res));

cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(p,res);

return true;
}
});
var n__4648__auto___48291 = n;
var __48292 = (0);
while(true){
if((__48292 < n__4648__auto___48291)){
var G__46890_48293 = type;
var G__46890_48294__$1 = (((G__46890_48293 instanceof cljs.core.Keyword))?G__46890_48293.fqn:null);
switch (G__46890_48294__$1) {
case "compute":
var c__46685__auto___48297 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run(((function (__48292,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = ((function (__48292,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function (state_46906){
var state_val_46907 = (state_46906[(1)]);
if((state_val_46907 === (1))){
var state_46906__$1 = state_46906;
var statearr_46910_48299 = state_46906__$1;
(statearr_46910_48299[(2)] = null);

(statearr_46910_48299[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46907 === (2))){
var state_46906__$1 = state_46906;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_46906__$1,(4),jobs);
} else {
if((state_val_46907 === (3))){
var inst_46903 = (state_46906[(2)]);
var state_46906__$1 = state_46906;
return cljs.core.async.impl.ioc_helpers.return_chan(state_46906__$1,inst_46903);
} else {
if((state_val_46907 === (4))){
var inst_46894 = (state_46906[(2)]);
var inst_46895 = process(inst_46894);
var state_46906__$1 = state_46906;
if(cljs.core.truth_(inst_46895)){
var statearr_46915_48300 = state_46906__$1;
(statearr_46915_48300[(1)] = (5));

} else {
var statearr_46916_48301 = state_46906__$1;
(statearr_46916_48301[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46907 === (5))){
var state_46906__$1 = state_46906;
var statearr_46919_48302 = state_46906__$1;
(statearr_46919_48302[(2)] = null);

(statearr_46919_48302[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46907 === (6))){
var state_46906__$1 = state_46906;
var statearr_46922_48303 = state_46906__$1;
(statearr_46922_48303[(2)] = null);

(statearr_46922_48303[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46907 === (7))){
var inst_46900 = (state_46906[(2)]);
var state_46906__$1 = state_46906;
var statearr_46923_48304 = state_46906__$1;
(statearr_46923_48304[(2)] = inst_46900);

(statearr_46923_48304[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
});})(__48292,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
;
return ((function (__48292,switch__46649__auto__,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function() {
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_46924 = [null,null,null,null,null,null,null];
(statearr_46924[(0)] = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__);

(statearr_46924[(1)] = (1));

return statearr_46924;
});
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1 = (function (state_46906){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_46906);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e46925){var ex__46653__auto__ = e46925;
var statearr_46927_48305 = state_46906;
(statearr_46927_48305[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_46906[(4)]))){
var statearr_46928_48307 = state_46906;
(statearr_46928_48307[(1)] = cljs.core.first((state_46906[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48308 = state_46906;
state_46906 = G__48308;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = function(state_46906){
switch(arguments.length){
case 0:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1.call(this,state_46906);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0;
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__;
})()
;})(__48292,switch__46649__auto__,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
})();
var state__46687__auto__ = (function (){var statearr_46929 = f__46686__auto__();
(statearr_46929[(6)] = c__46685__auto___48297);

return statearr_46929;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
});})(__48292,c__46685__auto___48297,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
);


break;
case "async":
var c__46685__auto___48310 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run(((function (__48292,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = ((function (__48292,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function (state_46942){
var state_val_46943 = (state_46942[(1)]);
if((state_val_46943 === (1))){
var state_46942__$1 = state_46942;
var statearr_46944_48311 = state_46942__$1;
(statearr_46944_48311[(2)] = null);

(statearr_46944_48311[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46943 === (2))){
var state_46942__$1 = state_46942;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_46942__$1,(4),jobs);
} else {
if((state_val_46943 === (3))){
var inst_46940 = (state_46942[(2)]);
var state_46942__$1 = state_46942;
return cljs.core.async.impl.ioc_helpers.return_chan(state_46942__$1,inst_46940);
} else {
if((state_val_46943 === (4))){
var inst_46932 = (state_46942[(2)]);
var inst_46933 = async(inst_46932);
var state_46942__$1 = state_46942;
if(cljs.core.truth_(inst_46933)){
var statearr_46945_48312 = state_46942__$1;
(statearr_46945_48312[(1)] = (5));

} else {
var statearr_46946_48313 = state_46942__$1;
(statearr_46946_48313[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46943 === (5))){
var state_46942__$1 = state_46942;
var statearr_46947_48314 = state_46942__$1;
(statearr_46947_48314[(2)] = null);

(statearr_46947_48314[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46943 === (6))){
var state_46942__$1 = state_46942;
var statearr_46948_48315 = state_46942__$1;
(statearr_46948_48315[(2)] = null);

(statearr_46948_48315[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46943 === (7))){
var inst_46938 = (state_46942[(2)]);
var state_46942__$1 = state_46942;
var statearr_46949_48316 = state_46942__$1;
(statearr_46949_48316[(2)] = inst_46938);

(statearr_46949_48316[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
});})(__48292,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
;
return ((function (__48292,switch__46649__auto__,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async){
return (function() {
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_46950 = [null,null,null,null,null,null,null];
(statearr_46950[(0)] = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__);

(statearr_46950[(1)] = (1));

return statearr_46950;
});
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1 = (function (state_46942){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_46942);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e46951){var ex__46653__auto__ = e46951;
var statearr_46952_48317 = state_46942;
(statearr_46952_48317[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_46942[(4)]))){
var statearr_46953_48318 = state_46942;
(statearr_46953_48318[(1)] = cljs.core.first((state_46942[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48319 = state_46942;
state_46942 = G__48319;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = function(state_46942){
switch(arguments.length){
case 0:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1.call(this,state_46942);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0;
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__;
})()
;})(__48292,switch__46649__auto__,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
})();
var state__46687__auto__ = (function (){var statearr_46954 = f__46686__auto__();
(statearr_46954[(6)] = c__46685__auto___48310);

return statearr_46954;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
});})(__48292,c__46685__auto___48310,G__46890_48293,G__46890_48294__$1,n__4648__auto___48291,jobs,results,process,async))
);


break;
default:
throw (new Error(["No matching clause: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(G__46890_48294__$1)].join('')));

}

var G__48320 = (__48292 + (1));
__48292 = G__48320;
continue;
} else {
}
break;
}

var c__46685__auto___48321 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_46985){
var state_val_46986 = (state_46985[(1)]);
if((state_val_46986 === (7))){
var inst_46981 = (state_46985[(2)]);
var state_46985__$1 = state_46985;
var statearr_46987_48322 = state_46985__$1;
(statearr_46987_48322[(2)] = inst_46981);

(statearr_46987_48322[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46986 === (1))){
var state_46985__$1 = state_46985;
var statearr_46988_48323 = state_46985__$1;
(statearr_46988_48323[(2)] = null);

(statearr_46988_48323[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46986 === (4))){
var inst_46957 = (state_46985[(7)]);
var inst_46957__$1 = (state_46985[(2)]);
var inst_46958 = (inst_46957__$1 == null);
var state_46985__$1 = (function (){var statearr_46989 = state_46985;
(statearr_46989[(7)] = inst_46957__$1);

return statearr_46989;
})();
if(cljs.core.truth_(inst_46958)){
var statearr_46990_48325 = state_46985__$1;
(statearr_46990_48325[(1)] = (5));

} else {
var statearr_46991_48326 = state_46985__$1;
(statearr_46991_48326[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46986 === (6))){
var inst_46957 = (state_46985[(7)]);
var inst_46963 = (state_46985[(8)]);
var inst_46963__$1 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
var inst_46972 = cljs.core.PersistentVector.EMPTY_NODE;
var inst_46973 = [inst_46957,inst_46963__$1];
var inst_46974 = (new cljs.core.PersistentVector(null,2,(5),inst_46972,inst_46973,null));
var state_46985__$1 = (function (){var statearr_46992 = state_46985;
(statearr_46992[(8)] = inst_46963__$1);

return statearr_46992;
})();
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_46985__$1,(8),jobs,inst_46974);
} else {
if((state_val_46986 === (3))){
var inst_46983 = (state_46985[(2)]);
var state_46985__$1 = state_46985;
return cljs.core.async.impl.ioc_helpers.return_chan(state_46985__$1,inst_46983);
} else {
if((state_val_46986 === (2))){
var state_46985__$1 = state_46985;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_46985__$1,(4),from);
} else {
if((state_val_46986 === (9))){
var inst_46978 = (state_46985[(2)]);
var state_46985__$1 = (function (){var statearr_46993 = state_46985;
(statearr_46993[(9)] = inst_46978);

return statearr_46993;
})();
var statearr_46994_48328 = state_46985__$1;
(statearr_46994_48328[(2)] = null);

(statearr_46994_48328[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46986 === (5))){
var inst_46960 = cljs.core.async.close_BANG_(jobs);
var state_46985__$1 = state_46985;
var statearr_46995_48329 = state_46985__$1;
(statearr_46995_48329[(2)] = inst_46960);

(statearr_46995_48329[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_46986 === (8))){
var inst_46963 = (state_46985[(8)]);
var inst_46976 = (state_46985[(2)]);
var state_46985__$1 = (function (){var statearr_46996 = state_46985;
(statearr_46996[(10)] = inst_46976);

return statearr_46996;
})();
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_46985__$1,(9),results,inst_46963);
} else {
return null;
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_46997 = [null,null,null,null,null,null,null,null,null,null,null];
(statearr_46997[(0)] = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__);

(statearr_46997[(1)] = (1));

return statearr_46997;
});
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1 = (function (state_46985){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_46985);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e46998){var ex__46653__auto__ = e46998;
var statearr_46999_48330 = state_46985;
(statearr_46999_48330[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_46985[(4)]))){
var statearr_47000_48331 = state_46985;
(statearr_47000_48331[(1)] = cljs.core.first((state_46985[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48332 = state_46985;
state_46985 = G__48332;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = function(state_46985){
switch(arguments.length){
case 0:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1.call(this,state_46985);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0;
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47001 = f__46686__auto__();
(statearr_47001[(6)] = c__46685__auto___48321);

return statearr_47001;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


var c__46685__auto__ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47039){
var state_val_47040 = (state_47039[(1)]);
if((state_val_47040 === (7))){
var inst_47035 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
var statearr_47045_48333 = state_47039__$1;
(statearr_47045_48333[(2)] = inst_47035);

(statearr_47045_48333[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (20))){
var state_47039__$1 = state_47039;
var statearr_47046_48334 = state_47039__$1;
(statearr_47046_48334[(2)] = null);

(statearr_47046_48334[(1)] = (21));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (1))){
var state_47039__$1 = state_47039;
var statearr_47047_48335 = state_47039__$1;
(statearr_47047_48335[(2)] = null);

(statearr_47047_48335[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (4))){
var inst_47004 = (state_47039[(7)]);
var inst_47004__$1 = (state_47039[(2)]);
var inst_47005 = (inst_47004__$1 == null);
var state_47039__$1 = (function (){var statearr_47048 = state_47039;
(statearr_47048[(7)] = inst_47004__$1);

return statearr_47048;
})();
if(cljs.core.truth_(inst_47005)){
var statearr_47049_48337 = state_47039__$1;
(statearr_47049_48337[(1)] = (5));

} else {
var statearr_47050_48338 = state_47039__$1;
(statearr_47050_48338[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (15))){
var inst_47017 = (state_47039[(8)]);
var state_47039__$1 = state_47039;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47039__$1,(18),to,inst_47017);
} else {
if((state_val_47040 === (21))){
var inst_47030 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
var statearr_47051_48340 = state_47039__$1;
(statearr_47051_48340[(2)] = inst_47030);

(statearr_47051_48340[(1)] = (13));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (13))){
var inst_47032 = (state_47039[(2)]);
var state_47039__$1 = (function (){var statearr_47052 = state_47039;
(statearr_47052[(9)] = inst_47032);

return statearr_47052;
})();
var statearr_47053_48341 = state_47039__$1;
(statearr_47053_48341[(2)] = null);

(statearr_47053_48341[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (6))){
var inst_47004 = (state_47039[(7)]);
var state_47039__$1 = state_47039;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47039__$1,(11),inst_47004);
} else {
if((state_val_47040 === (17))){
var inst_47025 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
if(cljs.core.truth_(inst_47025)){
var statearr_47054_48342 = state_47039__$1;
(statearr_47054_48342[(1)] = (19));

} else {
var statearr_47055_48343 = state_47039__$1;
(statearr_47055_48343[(1)] = (20));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (3))){
var inst_47037 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47039__$1,inst_47037);
} else {
if((state_val_47040 === (12))){
var inst_47014 = (state_47039[(10)]);
var state_47039__$1 = state_47039;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47039__$1,(14),inst_47014);
} else {
if((state_val_47040 === (2))){
var state_47039__$1 = state_47039;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47039__$1,(4),results);
} else {
if((state_val_47040 === (19))){
var state_47039__$1 = state_47039;
var statearr_47057_48344 = state_47039__$1;
(statearr_47057_48344[(2)] = null);

(statearr_47057_48344[(1)] = (12));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (11))){
var inst_47014 = (state_47039[(2)]);
var state_47039__$1 = (function (){var statearr_47058 = state_47039;
(statearr_47058[(10)] = inst_47014);

return statearr_47058;
})();
var statearr_47060_48345 = state_47039__$1;
(statearr_47060_48345[(2)] = null);

(statearr_47060_48345[(1)] = (12));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (9))){
var state_47039__$1 = state_47039;
var statearr_47061_48346 = state_47039__$1;
(statearr_47061_48346[(2)] = null);

(statearr_47061_48346[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (5))){
var state_47039__$1 = state_47039;
if(cljs.core.truth_(close_QMARK_)){
var statearr_47063_48347 = state_47039__$1;
(statearr_47063_48347[(1)] = (8));

} else {
var statearr_47064_48348 = state_47039__$1;
(statearr_47064_48348[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (14))){
var inst_47017 = (state_47039[(8)]);
var inst_47017__$1 = (state_47039[(2)]);
var inst_47018 = (inst_47017__$1 == null);
var inst_47019 = cljs.core.not(inst_47018);
var state_47039__$1 = (function (){var statearr_47065 = state_47039;
(statearr_47065[(8)] = inst_47017__$1);

return statearr_47065;
})();
if(inst_47019){
var statearr_47066_48349 = state_47039__$1;
(statearr_47066_48349[(1)] = (15));

} else {
var statearr_47067_48350 = state_47039__$1;
(statearr_47067_48350[(1)] = (16));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (16))){
var state_47039__$1 = state_47039;
var statearr_47068_48351 = state_47039__$1;
(statearr_47068_48351[(2)] = false);

(statearr_47068_48351[(1)] = (17));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (10))){
var inst_47011 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
var statearr_47069_48352 = state_47039__$1;
(statearr_47069_48352[(2)] = inst_47011);

(statearr_47069_48352[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (18))){
var inst_47022 = (state_47039[(2)]);
var state_47039__$1 = state_47039;
var statearr_47070_48353 = state_47039__$1;
(statearr_47070_48353[(2)] = inst_47022);

(statearr_47070_48353[(1)] = (17));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47040 === (8))){
var inst_47008 = cljs.core.async.close_BANG_(to);
var state_47039__$1 = state_47039;
var statearr_47071_48355 = state_47039__$1;
(statearr_47071_48355[(2)] = inst_47008);

(statearr_47071_48355[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_47073 = [null,null,null,null,null,null,null,null,null,null,null];
(statearr_47073[(0)] = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__);

(statearr_47073[(1)] = (1));

return statearr_47073;
});
var cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1 = (function (state_47039){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47039);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47076){var ex__46653__auto__ = e47076;
var statearr_47077_48356 = state_47039;
(statearr_47077_48356[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47039[(4)]))){
var statearr_47078_48357 = state_47039;
(statearr_47078_48357[(1)] = cljs.core.first((state_47039[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48358 = state_47039;
state_47039 = G__48358;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__ = function(state_47039){
switch(arguments.length){
case 0:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1.call(this,state_47039);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____0;
cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$pipeline_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$pipeline_STAR__$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47079 = f__46686__auto__();
(statearr_47079[(6)] = c__46685__auto__);

return statearr_47079;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

return c__46685__auto__;
});
/**
 * Takes elements from the from channel and supplies them to the to
 *   channel, subject to the async function af, with parallelism n. af
 *   must be a function of two arguments, the first an input value and
 *   the second a channel on which to place the result(s). The
 *   presumption is that af will return immediately, having launched some
 *   asynchronous operation whose completion/callback will put results on
 *   the channel, then close! it. Outputs will be returned in order
 *   relative to the inputs. By default, the to channel will be closed
 *   when the from channel closes, but can be determined by the close?
 *   parameter. Will stop consuming the from channel if the to channel
 *   closes. See also pipeline, pipeline-blocking.
 */
cljs.core.async.pipeline_async = (function cljs$core$async$pipeline_async(var_args){
var G__47081 = arguments.length;
switch (G__47081) {
case 4:
return cljs.core.async.pipeline_async.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
case 5:
return cljs.core.async.pipeline_async.cljs$core$IFn$_invoke$arity$5((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]),(arguments[(4)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.pipeline_async.cljs$core$IFn$_invoke$arity$4 = (function (n,to,af,from){
return cljs.core.async.pipeline_async.cljs$core$IFn$_invoke$arity$5(n,to,af,from,true);
}));

(cljs.core.async.pipeline_async.cljs$core$IFn$_invoke$arity$5 = (function (n,to,af,from,close_QMARK_){
return cljs.core.async.pipeline_STAR_(n,to,af,from,close_QMARK_,null,new cljs.core.Keyword(null,"async","async",1050769601));
}));

(cljs.core.async.pipeline_async.cljs$lang$maxFixedArity = 5);

/**
 * Takes elements from the from channel and supplies them to the to
 *   channel, subject to the transducer xf, with parallelism n. Because
 *   it is parallel, the transducer will be applied independently to each
 *   element, not across elements, and may produce zero or more outputs
 *   per input.  Outputs will be returned in order relative to the
 *   inputs. By default, the to channel will be closed when the from
 *   channel closes, but can be determined by the close?  parameter. Will
 *   stop consuming the from channel if the to channel closes.
 * 
 *   Note this is supplied for API compatibility with the Clojure version.
 *   Values of N > 1 will not result in actual concurrency in a
 *   single-threaded runtime.
 */
cljs.core.async.pipeline = (function cljs$core$async$pipeline(var_args){
var G__47084 = arguments.length;
switch (G__47084) {
case 4:
return cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
case 5:
return cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$5((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]),(arguments[(4)]));

break;
case 6:
return cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$6((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]),(arguments[(4)]),(arguments[(5)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$4 = (function (n,to,xf,from){
return cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$5(n,to,xf,from,true);
}));

(cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$5 = (function (n,to,xf,from,close_QMARK_){
return cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$6(n,to,xf,from,close_QMARK_,null);
}));

(cljs.core.async.pipeline.cljs$core$IFn$_invoke$arity$6 = (function (n,to,xf,from,close_QMARK_,ex_handler){
return cljs.core.async.pipeline_STAR_(n,to,xf,from,close_QMARK_,ex_handler,new cljs.core.Keyword(null,"compute","compute",1555393130));
}));

(cljs.core.async.pipeline.cljs$lang$maxFixedArity = 6);

/**
 * Takes a predicate and a source channel and returns a vector of two
 *   channels, the first of which will contain the values for which the
 *   predicate returned true, the second those for which it returned
 *   false.
 * 
 *   The out channels will be unbuffered by default, or two buf-or-ns can
 *   be supplied. The channels will close after the source channel has
 *   closed.
 */
cljs.core.async.split = (function cljs$core$async$split(var_args){
var G__47086 = arguments.length;
switch (G__47086) {
case 2:
return cljs.core.async.split.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 4:
return cljs.core.async.split.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.split.cljs$core$IFn$_invoke$arity$2 = (function (p,ch){
return cljs.core.async.split.cljs$core$IFn$_invoke$arity$4(p,ch,null,null);
}));

(cljs.core.async.split.cljs$core$IFn$_invoke$arity$4 = (function (p,ch,t_buf_or_n,f_buf_or_n){
var tc = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(t_buf_or_n);
var fc = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(f_buf_or_n);
var c__46685__auto___48366 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47112){
var state_val_47113 = (state_47112[(1)]);
if((state_val_47113 === (7))){
var inst_47108 = (state_47112[(2)]);
var state_47112__$1 = state_47112;
var statearr_47114_48367 = state_47112__$1;
(statearr_47114_48367[(2)] = inst_47108);

(statearr_47114_48367[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (1))){
var state_47112__$1 = state_47112;
var statearr_47115_48368 = state_47112__$1;
(statearr_47115_48368[(2)] = null);

(statearr_47115_48368[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (4))){
var inst_47089 = (state_47112[(7)]);
var inst_47089__$1 = (state_47112[(2)]);
var inst_47090 = (inst_47089__$1 == null);
var state_47112__$1 = (function (){var statearr_47116 = state_47112;
(statearr_47116[(7)] = inst_47089__$1);

return statearr_47116;
})();
if(cljs.core.truth_(inst_47090)){
var statearr_47117_48369 = state_47112__$1;
(statearr_47117_48369[(1)] = (5));

} else {
var statearr_47118_48370 = state_47112__$1;
(statearr_47118_48370[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (13))){
var state_47112__$1 = state_47112;
var statearr_47119_48371 = state_47112__$1;
(statearr_47119_48371[(2)] = null);

(statearr_47119_48371[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (6))){
var inst_47089 = (state_47112[(7)]);
var inst_47095 = (p.cljs$core$IFn$_invoke$arity$1 ? p.cljs$core$IFn$_invoke$arity$1(inst_47089) : p.call(null,inst_47089));
var state_47112__$1 = state_47112;
if(cljs.core.truth_(inst_47095)){
var statearr_47120_48372 = state_47112__$1;
(statearr_47120_48372[(1)] = (9));

} else {
var statearr_47121_48373 = state_47112__$1;
(statearr_47121_48373[(1)] = (10));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (3))){
var inst_47110 = (state_47112[(2)]);
var state_47112__$1 = state_47112;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47112__$1,inst_47110);
} else {
if((state_val_47113 === (12))){
var state_47112__$1 = state_47112;
var statearr_47122_48374 = state_47112__$1;
(statearr_47122_48374[(2)] = null);

(statearr_47122_48374[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (2))){
var state_47112__$1 = state_47112;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47112__$1,(4),ch);
} else {
if((state_val_47113 === (11))){
var inst_47089 = (state_47112[(7)]);
var inst_47099 = (state_47112[(2)]);
var state_47112__$1 = state_47112;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47112__$1,(8),inst_47099,inst_47089);
} else {
if((state_val_47113 === (9))){
var state_47112__$1 = state_47112;
var statearr_47123_48375 = state_47112__$1;
(statearr_47123_48375[(2)] = tc);

(statearr_47123_48375[(1)] = (11));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (5))){
var inst_47092 = cljs.core.async.close_BANG_(tc);
var inst_47093 = cljs.core.async.close_BANG_(fc);
var state_47112__$1 = (function (){var statearr_47124 = state_47112;
(statearr_47124[(8)] = inst_47092);

return statearr_47124;
})();
var statearr_47125_48376 = state_47112__$1;
(statearr_47125_48376[(2)] = inst_47093);

(statearr_47125_48376[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (14))){
var inst_47106 = (state_47112[(2)]);
var state_47112__$1 = state_47112;
var statearr_47126_48377 = state_47112__$1;
(statearr_47126_48377[(2)] = inst_47106);

(statearr_47126_48377[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (10))){
var state_47112__$1 = state_47112;
var statearr_47127_48379 = state_47112__$1;
(statearr_47127_48379[(2)] = fc);

(statearr_47127_48379[(1)] = (11));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47113 === (8))){
var inst_47101 = (state_47112[(2)]);
var state_47112__$1 = state_47112;
if(cljs.core.truth_(inst_47101)){
var statearr_47128_48381 = state_47112__$1;
(statearr_47128_48381[(1)] = (12));

} else {
var statearr_47129_48382 = state_47112__$1;
(statearr_47129_48382[(1)] = (13));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47130 = [null,null,null,null,null,null,null,null,null];
(statearr_47130[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47130[(1)] = (1));

return statearr_47130;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47112){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47112);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47131){var ex__46653__auto__ = e47131;
var statearr_47132_48383 = state_47112;
(statearr_47132_48383[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47112[(4)]))){
var statearr_47133_48384 = state_47112;
(statearr_47133_48384[(1)] = cljs.core.first((state_47112[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48385 = state_47112;
state_47112 = G__48385;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47112){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47112);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47134 = f__46686__auto__();
(statearr_47134[(6)] = c__46685__auto___48366);

return statearr_47134;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return new cljs.core.PersistentVector(null, 2, 5, cljs.core.PersistentVector.EMPTY_NODE, [tc,fc], null);
}));

(cljs.core.async.split.cljs$lang$maxFixedArity = 4);

/**
 * f should be a function of 2 arguments. Returns a channel containing
 *   the single result of applying f to init and the first item from the
 *   channel, then applying f to that result and the 2nd item, etc. If
 *   the channel closes without yielding items, returns init and f is not
 *   called. ch must close before reduce produces a result.
 */
cljs.core.async.reduce = (function cljs$core$async$reduce(f,init,ch){
var c__46685__auto__ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47156){
var state_val_47157 = (state_47156[(1)]);
if((state_val_47157 === (7))){
var inst_47152 = (state_47156[(2)]);
var state_47156__$1 = state_47156;
var statearr_47158_48386 = state_47156__$1;
(statearr_47158_48386[(2)] = inst_47152);

(statearr_47158_48386[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (1))){
var inst_47135 = init;
var inst_47136 = inst_47135;
var state_47156__$1 = (function (){var statearr_47159 = state_47156;
(statearr_47159[(7)] = inst_47136);

return statearr_47159;
})();
var statearr_47160_48387 = state_47156__$1;
(statearr_47160_48387[(2)] = null);

(statearr_47160_48387[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (4))){
var inst_47139 = (state_47156[(8)]);
var inst_47139__$1 = (state_47156[(2)]);
var inst_47140 = (inst_47139__$1 == null);
var state_47156__$1 = (function (){var statearr_47161 = state_47156;
(statearr_47161[(8)] = inst_47139__$1);

return statearr_47161;
})();
if(cljs.core.truth_(inst_47140)){
var statearr_47162_48388 = state_47156__$1;
(statearr_47162_48388[(1)] = (5));

} else {
var statearr_47163_48389 = state_47156__$1;
(statearr_47163_48389[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (6))){
var inst_47136 = (state_47156[(7)]);
var inst_47139 = (state_47156[(8)]);
var inst_47143 = (state_47156[(9)]);
var inst_47143__$1 = (f.cljs$core$IFn$_invoke$arity$2 ? f.cljs$core$IFn$_invoke$arity$2(inst_47136,inst_47139) : f.call(null,inst_47136,inst_47139));
var inst_47144 = cljs.core.reduced_QMARK_(inst_47143__$1);
var state_47156__$1 = (function (){var statearr_47164 = state_47156;
(statearr_47164[(9)] = inst_47143__$1);

return statearr_47164;
})();
if(inst_47144){
var statearr_47165_48394 = state_47156__$1;
(statearr_47165_48394[(1)] = (8));

} else {
var statearr_47166_48395 = state_47156__$1;
(statearr_47166_48395[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (3))){
var inst_47154 = (state_47156[(2)]);
var state_47156__$1 = state_47156;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47156__$1,inst_47154);
} else {
if((state_val_47157 === (2))){
var state_47156__$1 = state_47156;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47156__$1,(4),ch);
} else {
if((state_val_47157 === (9))){
var inst_47143 = (state_47156[(9)]);
var inst_47136 = inst_47143;
var state_47156__$1 = (function (){var statearr_47167 = state_47156;
(statearr_47167[(7)] = inst_47136);

return statearr_47167;
})();
var statearr_47168_48399 = state_47156__$1;
(statearr_47168_48399[(2)] = null);

(statearr_47168_48399[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (5))){
var inst_47136 = (state_47156[(7)]);
var state_47156__$1 = state_47156;
var statearr_47169_48400 = state_47156__$1;
(statearr_47169_48400[(2)] = inst_47136);

(statearr_47169_48400[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (10))){
var inst_47150 = (state_47156[(2)]);
var state_47156__$1 = state_47156;
var statearr_47170_48404 = state_47156__$1;
(statearr_47170_48404[(2)] = inst_47150);

(statearr_47170_48404[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47157 === (8))){
var inst_47143 = (state_47156[(9)]);
var inst_47146 = cljs.core.deref(inst_47143);
var state_47156__$1 = state_47156;
var statearr_47171_48405 = state_47156__$1;
(statearr_47171_48405[(2)] = inst_47146);

(statearr_47171_48405[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$reduce_$_state_machine__46650__auto__ = null;
var cljs$core$async$reduce_$_state_machine__46650__auto____0 = (function (){
var statearr_47172 = [null,null,null,null,null,null,null,null,null,null];
(statearr_47172[(0)] = cljs$core$async$reduce_$_state_machine__46650__auto__);

(statearr_47172[(1)] = (1));

return statearr_47172;
});
var cljs$core$async$reduce_$_state_machine__46650__auto____1 = (function (state_47156){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47156);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47173){var ex__46653__auto__ = e47173;
var statearr_47174_48409 = state_47156;
(statearr_47174_48409[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47156[(4)]))){
var statearr_47175_48410 = state_47156;
(statearr_47175_48410[(1)] = cljs.core.first((state_47156[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48411 = state_47156;
state_47156 = G__48411;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$reduce_$_state_machine__46650__auto__ = function(state_47156){
switch(arguments.length){
case 0:
return cljs$core$async$reduce_$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$reduce_$_state_machine__46650__auto____1.call(this,state_47156);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$reduce_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$reduce_$_state_machine__46650__auto____0;
cljs$core$async$reduce_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$reduce_$_state_machine__46650__auto____1;
return cljs$core$async$reduce_$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47176 = f__46686__auto__();
(statearr_47176[(6)] = c__46685__auto__);

return statearr_47176;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

return c__46685__auto__;
});
/**
 * async/reduces a channel with a transformation (xform f).
 *   Returns a channel containing the result.  ch must close before
 *   transduce produces a result.
 */
cljs.core.async.transduce = (function cljs$core$async$transduce(xform,f,init,ch){
var f__$1 = (xform.cljs$core$IFn$_invoke$arity$1 ? xform.cljs$core$IFn$_invoke$arity$1(f) : xform.call(null,f));
var c__46685__auto__ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47182){
var state_val_47183 = (state_47182[(1)]);
if((state_val_47183 === (1))){
var inst_47177 = cljs.core.async.reduce(f__$1,init,ch);
var state_47182__$1 = state_47182;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47182__$1,(2),inst_47177);
} else {
if((state_val_47183 === (2))){
var inst_47179 = (state_47182[(2)]);
var inst_47180 = (f__$1.cljs$core$IFn$_invoke$arity$1 ? f__$1.cljs$core$IFn$_invoke$arity$1(inst_47179) : f__$1.call(null,inst_47179));
var state_47182__$1 = state_47182;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47182__$1,inst_47180);
} else {
return null;
}
}
});
return (function() {
var cljs$core$async$transduce_$_state_machine__46650__auto__ = null;
var cljs$core$async$transduce_$_state_machine__46650__auto____0 = (function (){
var statearr_47184 = [null,null,null,null,null,null,null];
(statearr_47184[(0)] = cljs$core$async$transduce_$_state_machine__46650__auto__);

(statearr_47184[(1)] = (1));

return statearr_47184;
});
var cljs$core$async$transduce_$_state_machine__46650__auto____1 = (function (state_47182){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47182);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47185){var ex__46653__auto__ = e47185;
var statearr_47186_48412 = state_47182;
(statearr_47186_48412[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47182[(4)]))){
var statearr_47187_48416 = state_47182;
(statearr_47187_48416[(1)] = cljs.core.first((state_47182[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48417 = state_47182;
state_47182 = G__48417;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$transduce_$_state_machine__46650__auto__ = function(state_47182){
switch(arguments.length){
case 0:
return cljs$core$async$transduce_$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$transduce_$_state_machine__46650__auto____1.call(this,state_47182);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$transduce_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$transduce_$_state_machine__46650__auto____0;
cljs$core$async$transduce_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$transduce_$_state_machine__46650__auto____1;
return cljs$core$async$transduce_$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47188 = f__46686__auto__();
(statearr_47188[(6)] = c__46685__auto__);

return statearr_47188;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

return c__46685__auto__;
});
/**
 * Puts the contents of coll into the supplied channel.
 * 
 *   By default the channel will be closed after the items are copied,
 *   but can be determined by the close? parameter.
 * 
 *   Returns a channel which will close after the items are copied.
 */
cljs.core.async.onto_chan_BANG_ = (function cljs$core$async$onto_chan_BANG_(var_args){
var G__47190 = arguments.length;
switch (G__47190) {
case 2:
return cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$2 = (function (ch,coll){
return cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$3(ch,coll,true);
}));

(cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$3 = (function (ch,coll,close_QMARK_){
var c__46685__auto__ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47215){
var state_val_47216 = (state_47215[(1)]);
if((state_val_47216 === (7))){
var inst_47197 = (state_47215[(2)]);
var state_47215__$1 = state_47215;
var statearr_47217_48426 = state_47215__$1;
(statearr_47217_48426[(2)] = inst_47197);

(statearr_47217_48426[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (1))){
var inst_47191 = cljs.core.seq(coll);
var inst_47192 = inst_47191;
var state_47215__$1 = (function (){var statearr_47218 = state_47215;
(statearr_47218[(7)] = inst_47192);

return statearr_47218;
})();
var statearr_47219_48427 = state_47215__$1;
(statearr_47219_48427[(2)] = null);

(statearr_47219_48427[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (4))){
var inst_47192 = (state_47215[(7)]);
var inst_47195 = cljs.core.first(inst_47192);
var state_47215__$1 = state_47215;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47215__$1,(7),ch,inst_47195);
} else {
if((state_val_47216 === (13))){
var inst_47209 = (state_47215[(2)]);
var state_47215__$1 = state_47215;
var statearr_47220_48428 = state_47215__$1;
(statearr_47220_48428[(2)] = inst_47209);

(statearr_47220_48428[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (6))){
var inst_47200 = (state_47215[(2)]);
var state_47215__$1 = state_47215;
if(cljs.core.truth_(inst_47200)){
var statearr_47221_48429 = state_47215__$1;
(statearr_47221_48429[(1)] = (8));

} else {
var statearr_47222_48430 = state_47215__$1;
(statearr_47222_48430[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (3))){
var inst_47213 = (state_47215[(2)]);
var state_47215__$1 = state_47215;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47215__$1,inst_47213);
} else {
if((state_val_47216 === (12))){
var state_47215__$1 = state_47215;
var statearr_47223_48434 = state_47215__$1;
(statearr_47223_48434[(2)] = null);

(statearr_47223_48434[(1)] = (13));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (2))){
var inst_47192 = (state_47215[(7)]);
var state_47215__$1 = state_47215;
if(cljs.core.truth_(inst_47192)){
var statearr_47224_48435 = state_47215__$1;
(statearr_47224_48435[(1)] = (4));

} else {
var statearr_47225_48436 = state_47215__$1;
(statearr_47225_48436[(1)] = (5));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (11))){
var inst_47206 = cljs.core.async.close_BANG_(ch);
var state_47215__$1 = state_47215;
var statearr_47226_48437 = state_47215__$1;
(statearr_47226_48437[(2)] = inst_47206);

(statearr_47226_48437[(1)] = (13));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (9))){
var state_47215__$1 = state_47215;
if(cljs.core.truth_(close_QMARK_)){
var statearr_47227_48441 = state_47215__$1;
(statearr_47227_48441[(1)] = (11));

} else {
var statearr_47228_48442 = state_47215__$1;
(statearr_47228_48442[(1)] = (12));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (5))){
var inst_47192 = (state_47215[(7)]);
var state_47215__$1 = state_47215;
var statearr_47229_48443 = state_47215__$1;
(statearr_47229_48443[(2)] = inst_47192);

(statearr_47229_48443[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (10))){
var inst_47211 = (state_47215[(2)]);
var state_47215__$1 = state_47215;
var statearr_47230_48444 = state_47215__$1;
(statearr_47230_48444[(2)] = inst_47211);

(statearr_47230_48444[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47216 === (8))){
var inst_47192 = (state_47215[(7)]);
var inst_47202 = cljs.core.next(inst_47192);
var inst_47192__$1 = inst_47202;
var state_47215__$1 = (function (){var statearr_47231 = state_47215;
(statearr_47231[(7)] = inst_47192__$1);

return statearr_47231;
})();
var statearr_47232_48448 = state_47215__$1;
(statearr_47232_48448[(2)] = null);

(statearr_47232_48448[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47233 = [null,null,null,null,null,null,null,null];
(statearr_47233[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47233[(1)] = (1));

return statearr_47233;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47215){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47215);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47234){var ex__46653__auto__ = e47234;
var statearr_47235_48449 = state_47215;
(statearr_47235_48449[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47215[(4)]))){
var statearr_47236_48450 = state_47215;
(statearr_47236_48450[(1)] = cljs.core.first((state_47215[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48452 = state_47215;
state_47215 = G__48452;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47215){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47215);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47237 = f__46686__auto__();
(statearr_47237[(6)] = c__46685__auto__);

return statearr_47237;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

return c__46685__auto__;
}));

(cljs.core.async.onto_chan_BANG_.cljs$lang$maxFixedArity = 3);

/**
 * Creates and returns a channel which contains the contents of coll,
 *   closing when exhausted.
 */
cljs.core.async.to_chan_BANG_ = (function cljs$core$async$to_chan_BANG_(coll){
var ch = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(cljs.core.bounded_count((100),coll));
cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$2(ch,coll);

return ch;
});
/**
 * Deprecated - use onto-chan!
 */
cljs.core.async.onto_chan = (function cljs$core$async$onto_chan(var_args){
var G__47239 = arguments.length;
switch (G__47239) {
case 2:
return cljs.core.async.onto_chan.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.onto_chan.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.onto_chan.cljs$core$IFn$_invoke$arity$2 = (function (ch,coll){
return cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$3(ch,coll,true);
}));

(cljs.core.async.onto_chan.cljs$core$IFn$_invoke$arity$3 = (function (ch,coll,close_QMARK_){
return cljs.core.async.onto_chan_BANG_.cljs$core$IFn$_invoke$arity$3(ch,coll,close_QMARK_);
}));

(cljs.core.async.onto_chan.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - use to-chan!
 */
cljs.core.async.to_chan = (function cljs$core$async$to_chan(coll){
return cljs.core.async.to_chan_BANG_(coll);
});

/**
 * @interface
 */
cljs.core.async.Mux = function(){};

var cljs$core$async$Mux$muxch_STAR_$dyn_48454 = (function (_){
var x__4463__auto__ = (((_ == null))?null:_);
var m__4464__auto__ = (cljs.core.async.muxch_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(_) : m__4464__auto__.call(null,_));
} else {
var m__4461__auto__ = (cljs.core.async.muxch_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(_) : m__4461__auto__.call(null,_));
} else {
throw cljs.core.missing_protocol("Mux.muxch*",_);
}
}
});
cljs.core.async.muxch_STAR_ = (function cljs$core$async$muxch_STAR_(_){
if((((!((_ == null)))) && ((!((_.cljs$core$async$Mux$muxch_STAR_$arity$1 == null)))))){
return _.cljs$core$async$Mux$muxch_STAR_$arity$1(_);
} else {
return cljs$core$async$Mux$muxch_STAR_$dyn_48454(_);
}
});


/**
 * @interface
 */
cljs.core.async.Mult = function(){};

var cljs$core$async$Mult$tap_STAR_$dyn_48455 = (function (m,ch,close_QMARK_){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.tap_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$3 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$3(m,ch,close_QMARK_) : m__4464__auto__.call(null,m,ch,close_QMARK_));
} else {
var m__4461__auto__ = (cljs.core.async.tap_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$3 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$3(m,ch,close_QMARK_) : m__4461__auto__.call(null,m,ch,close_QMARK_));
} else {
throw cljs.core.missing_protocol("Mult.tap*",m);
}
}
});
cljs.core.async.tap_STAR_ = (function cljs$core$async$tap_STAR_(m,ch,close_QMARK_){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mult$tap_STAR_$arity$3 == null)))))){
return m.cljs$core$async$Mult$tap_STAR_$arity$3(m,ch,close_QMARK_);
} else {
return cljs$core$async$Mult$tap_STAR_$dyn_48455(m,ch,close_QMARK_);
}
});

var cljs$core$async$Mult$untap_STAR_$dyn_48456 = (function (m,ch){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.untap_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4464__auto__.call(null,m,ch));
} else {
var m__4461__auto__ = (cljs.core.async.untap_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4461__auto__.call(null,m,ch));
} else {
throw cljs.core.missing_protocol("Mult.untap*",m);
}
}
});
cljs.core.async.untap_STAR_ = (function cljs$core$async$untap_STAR_(m,ch){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mult$untap_STAR_$arity$2 == null)))))){
return m.cljs$core$async$Mult$untap_STAR_$arity$2(m,ch);
} else {
return cljs$core$async$Mult$untap_STAR_$dyn_48456(m,ch);
}
});

var cljs$core$async$Mult$untap_all_STAR_$dyn_48457 = (function (m){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.untap_all_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(m) : m__4464__auto__.call(null,m));
} else {
var m__4461__auto__ = (cljs.core.async.untap_all_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(m) : m__4461__auto__.call(null,m));
} else {
throw cljs.core.missing_protocol("Mult.untap-all*",m);
}
}
});
cljs.core.async.untap_all_STAR_ = (function cljs$core$async$untap_all_STAR_(m){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mult$untap_all_STAR_$arity$1 == null)))))){
return m.cljs$core$async$Mult$untap_all_STAR_$arity$1(m);
} else {
return cljs$core$async$Mult$untap_all_STAR_$dyn_48457(m);
}
});

/**
 * Creates and returns a mult(iple) of the supplied channel. Channels
 *   containing copies of the channel can be created with 'tap', and
 *   detached with 'untap'.
 * 
 *   Each item is distributed to all taps in parallel and synchronously,
 *   i.e. each tap must accept before the next item is distributed. Use
 *   buffering/windowing to prevent slow taps from holding up the mult.
 * 
 *   Items received when there are no taps get dropped.
 * 
 *   If a tap puts to a closed channel, it will be removed from the mult.
 */
cljs.core.async.mult = (function cljs$core$async$mult(ch){
var cs = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(cljs.core.PersistentArrayMap.EMPTY);
var m = (function (){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47240 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.Mult}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.async.Mux}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47240 = (function (ch,cs,meta47241){
this.ch = ch;
this.cs = cs;
this.meta47241 = meta47241;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47242,meta47241__$1){
var self__ = this;
var _47242__$1 = this;
return (new cljs.core.async.t_cljs$core$async47240(self__.ch,self__.cs,meta47241__$1));
}));

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47242){
var self__ = this;
var _47242__$1 = this;
return self__.meta47241;
}));

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mux$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mux$muxch_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return self__.ch;
}));

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mult$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mult$tap_STAR_$arity$3 = (function (_,ch__$1,close_QMARK_){
var self__ = this;
var ___$1 = this;
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(self__.cs,cljs.core.assoc,ch__$1,close_QMARK_);

return null;
}));

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mult$untap_STAR_$arity$2 = (function (_,ch__$1){
var self__ = this;
var ___$1 = this;
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(self__.cs,cljs.core.dissoc,ch__$1);

return null;
}));

(cljs.core.async.t_cljs$core$async47240.prototype.cljs$core$async$Mult$untap_all_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
cljs.core.reset_BANG_(self__.cs,cljs.core.PersistentArrayMap.EMPTY);

return null;
}));

(cljs.core.async.t_cljs$core$async47240.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"cs","cs",-117024463,null),new cljs.core.Symbol(null,"meta47241","meta47241",2124486724,null)], null);
}));

(cljs.core.async.t_cljs$core$async47240.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47240.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47240");

(cljs.core.async.t_cljs$core$async47240.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47240");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47240.
 */
cljs.core.async.__GT_t_cljs$core$async47240 = (function cljs$core$async$mult_$___GT_t_cljs$core$async47240(ch__$1,cs__$1,meta47241){
return (new cljs.core.async.t_cljs$core$async47240(ch__$1,cs__$1,meta47241));
});

}

return (new cljs.core.async.t_cljs$core$async47240(ch,cs,cljs.core.PersistentArrayMap.EMPTY));
})()
;
var dchan = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
var dctr = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(null);
var done = (function (_){
if((cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(dctr,cljs.core.dec) === (0))){
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(dchan,true);
} else {
return null;
}
});
var c__46685__auto___48463 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47375){
var state_val_47376 = (state_47375[(1)]);
if((state_val_47376 === (7))){
var inst_47371 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47377_48464 = state_47375__$1;
(statearr_47377_48464[(2)] = inst_47371);

(statearr_47377_48464[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (20))){
var inst_47276 = (state_47375[(7)]);
var inst_47288 = cljs.core.first(inst_47276);
var inst_47289 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47288,(0),null);
var inst_47290 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47288,(1),null);
var state_47375__$1 = (function (){var statearr_47378 = state_47375;
(statearr_47378[(8)] = inst_47289);

return statearr_47378;
})();
if(cljs.core.truth_(inst_47290)){
var statearr_47379_48466 = state_47375__$1;
(statearr_47379_48466[(1)] = (22));

} else {
var statearr_47380_48467 = state_47375__$1;
(statearr_47380_48467[(1)] = (23));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (27))){
var inst_47318 = (state_47375[(9)]);
var inst_47320 = (state_47375[(10)]);
var inst_47325 = (state_47375[(11)]);
var inst_47245 = (state_47375[(12)]);
var inst_47325__$1 = cljs.core._nth(inst_47318,inst_47320);
var inst_47326 = cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$3(inst_47325__$1,inst_47245,done);
var state_47375__$1 = (function (){var statearr_47381 = state_47375;
(statearr_47381[(11)] = inst_47325__$1);

return statearr_47381;
})();
if(cljs.core.truth_(inst_47326)){
var statearr_47382_48470 = state_47375__$1;
(statearr_47382_48470[(1)] = (30));

} else {
var statearr_47383_48471 = state_47375__$1;
(statearr_47383_48471[(1)] = (31));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (1))){
var state_47375__$1 = state_47375;
var statearr_47384_48472 = state_47375__$1;
(statearr_47384_48472[(2)] = null);

(statearr_47384_48472[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (24))){
var inst_47276 = (state_47375[(7)]);
var inst_47295 = (state_47375[(2)]);
var inst_47296 = cljs.core.next(inst_47276);
var inst_47254 = inst_47296;
var inst_47255 = null;
var inst_47256 = (0);
var inst_47257 = (0);
var state_47375__$1 = (function (){var statearr_47385 = state_47375;
(statearr_47385[(13)] = inst_47295);

(statearr_47385[(14)] = inst_47254);

(statearr_47385[(15)] = inst_47255);

(statearr_47385[(16)] = inst_47256);

(statearr_47385[(17)] = inst_47257);

return statearr_47385;
})();
var statearr_47386_48473 = state_47375__$1;
(statearr_47386_48473[(2)] = null);

(statearr_47386_48473[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (39))){
var state_47375__$1 = state_47375;
var statearr_47390_48474 = state_47375__$1;
(statearr_47390_48474[(2)] = null);

(statearr_47390_48474[(1)] = (41));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (4))){
var inst_47245 = (state_47375[(12)]);
var inst_47245__$1 = (state_47375[(2)]);
var inst_47246 = (inst_47245__$1 == null);
var state_47375__$1 = (function (){var statearr_47391 = state_47375;
(statearr_47391[(12)] = inst_47245__$1);

return statearr_47391;
})();
if(cljs.core.truth_(inst_47246)){
var statearr_47392_48475 = state_47375__$1;
(statearr_47392_48475[(1)] = (5));

} else {
var statearr_47393_48476 = state_47375__$1;
(statearr_47393_48476[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (15))){
var inst_47257 = (state_47375[(17)]);
var inst_47254 = (state_47375[(14)]);
var inst_47255 = (state_47375[(15)]);
var inst_47256 = (state_47375[(16)]);
var inst_47272 = (state_47375[(2)]);
var inst_47273 = (inst_47257 + (1));
var tmp47387 = inst_47254;
var tmp47388 = inst_47256;
var tmp47389 = inst_47255;
var inst_47254__$1 = tmp47387;
var inst_47255__$1 = tmp47389;
var inst_47256__$1 = tmp47388;
var inst_47257__$1 = inst_47273;
var state_47375__$1 = (function (){var statearr_47394 = state_47375;
(statearr_47394[(18)] = inst_47272);

(statearr_47394[(14)] = inst_47254__$1);

(statearr_47394[(15)] = inst_47255__$1);

(statearr_47394[(16)] = inst_47256__$1);

(statearr_47394[(17)] = inst_47257__$1);

return statearr_47394;
})();
var statearr_47395_48478 = state_47375__$1;
(statearr_47395_48478[(2)] = null);

(statearr_47395_48478[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (21))){
var inst_47299 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47399_48482 = state_47375__$1;
(statearr_47399_48482[(2)] = inst_47299);

(statearr_47399_48482[(1)] = (18));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (31))){
var inst_47325 = (state_47375[(11)]);
var inst_47329 = m.cljs$core$async$Mult$untap_STAR_$arity$2(null,inst_47325);
var state_47375__$1 = state_47375;
var statearr_47400_48483 = state_47375__$1;
(statearr_47400_48483[(2)] = inst_47329);

(statearr_47400_48483[(1)] = (32));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (32))){
var inst_47320 = (state_47375[(10)]);
var inst_47317 = (state_47375[(19)]);
var inst_47318 = (state_47375[(9)]);
var inst_47319 = (state_47375[(20)]);
var inst_47331 = (state_47375[(2)]);
var inst_47332 = (inst_47320 + (1));
var tmp47396 = inst_47317;
var tmp47397 = inst_47319;
var tmp47398 = inst_47318;
var inst_47317__$1 = tmp47396;
var inst_47318__$1 = tmp47398;
var inst_47319__$1 = tmp47397;
var inst_47320__$1 = inst_47332;
var state_47375__$1 = (function (){var statearr_47401 = state_47375;
(statearr_47401[(21)] = inst_47331);

(statearr_47401[(19)] = inst_47317__$1);

(statearr_47401[(9)] = inst_47318__$1);

(statearr_47401[(20)] = inst_47319__$1);

(statearr_47401[(10)] = inst_47320__$1);

return statearr_47401;
})();
var statearr_47402_48488 = state_47375__$1;
(statearr_47402_48488[(2)] = null);

(statearr_47402_48488[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (40))){
var inst_47344 = (state_47375[(22)]);
var inst_47348 = m.cljs$core$async$Mult$untap_STAR_$arity$2(null,inst_47344);
var state_47375__$1 = state_47375;
var statearr_47403_48489 = state_47375__$1;
(statearr_47403_48489[(2)] = inst_47348);

(statearr_47403_48489[(1)] = (41));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (33))){
var inst_47335 = (state_47375[(23)]);
var inst_47337 = cljs.core.chunked_seq_QMARK_(inst_47335);
var state_47375__$1 = state_47375;
if(inst_47337){
var statearr_47404_48490 = state_47375__$1;
(statearr_47404_48490[(1)] = (36));

} else {
var statearr_47405_48494 = state_47375__$1;
(statearr_47405_48494[(1)] = (37));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (13))){
var inst_47266 = (state_47375[(24)]);
var inst_47269 = cljs.core.async.close_BANG_(inst_47266);
var state_47375__$1 = state_47375;
var statearr_47406_48499 = state_47375__$1;
(statearr_47406_48499[(2)] = inst_47269);

(statearr_47406_48499[(1)] = (15));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (22))){
var inst_47289 = (state_47375[(8)]);
var inst_47292 = cljs.core.async.close_BANG_(inst_47289);
var state_47375__$1 = state_47375;
var statearr_47407_48500 = state_47375__$1;
(statearr_47407_48500[(2)] = inst_47292);

(statearr_47407_48500[(1)] = (24));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (36))){
var inst_47335 = (state_47375[(23)]);
var inst_47339 = cljs.core.chunk_first(inst_47335);
var inst_47340 = cljs.core.chunk_rest(inst_47335);
var inst_47341 = cljs.core.count(inst_47339);
var inst_47317 = inst_47340;
var inst_47318 = inst_47339;
var inst_47319 = inst_47341;
var inst_47320 = (0);
var state_47375__$1 = (function (){var statearr_47408 = state_47375;
(statearr_47408[(19)] = inst_47317);

(statearr_47408[(9)] = inst_47318);

(statearr_47408[(20)] = inst_47319);

(statearr_47408[(10)] = inst_47320);

return statearr_47408;
})();
var statearr_47409_48507 = state_47375__$1;
(statearr_47409_48507[(2)] = null);

(statearr_47409_48507[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (41))){
var inst_47335 = (state_47375[(23)]);
var inst_47350 = (state_47375[(2)]);
var inst_47351 = cljs.core.next(inst_47335);
var inst_47317 = inst_47351;
var inst_47318 = null;
var inst_47319 = (0);
var inst_47320 = (0);
var state_47375__$1 = (function (){var statearr_47410 = state_47375;
(statearr_47410[(25)] = inst_47350);

(statearr_47410[(19)] = inst_47317);

(statearr_47410[(9)] = inst_47318);

(statearr_47410[(20)] = inst_47319);

(statearr_47410[(10)] = inst_47320);

return statearr_47410;
})();
var statearr_47411_48508 = state_47375__$1;
(statearr_47411_48508[(2)] = null);

(statearr_47411_48508[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (43))){
var state_47375__$1 = state_47375;
var statearr_47412_48509 = state_47375__$1;
(statearr_47412_48509[(2)] = null);

(statearr_47412_48509[(1)] = (44));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (29))){
var inst_47359 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47413_48510 = state_47375__$1;
(statearr_47413_48510[(2)] = inst_47359);

(statearr_47413_48510[(1)] = (26));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (44))){
var inst_47368 = (state_47375[(2)]);
var state_47375__$1 = (function (){var statearr_47414 = state_47375;
(statearr_47414[(26)] = inst_47368);

return statearr_47414;
})();
var statearr_47415_48511 = state_47375__$1;
(statearr_47415_48511[(2)] = null);

(statearr_47415_48511[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (6))){
var inst_47309 = (state_47375[(27)]);
var inst_47308 = cljs.core.deref(cs);
var inst_47309__$1 = cljs.core.keys(inst_47308);
var inst_47310 = cljs.core.count(inst_47309__$1);
var inst_47311 = cljs.core.reset_BANG_(dctr,inst_47310);
var inst_47316 = cljs.core.seq(inst_47309__$1);
var inst_47317 = inst_47316;
var inst_47318 = null;
var inst_47319 = (0);
var inst_47320 = (0);
var state_47375__$1 = (function (){var statearr_47416 = state_47375;
(statearr_47416[(27)] = inst_47309__$1);

(statearr_47416[(28)] = inst_47311);

(statearr_47416[(19)] = inst_47317);

(statearr_47416[(9)] = inst_47318);

(statearr_47416[(20)] = inst_47319);

(statearr_47416[(10)] = inst_47320);

return statearr_47416;
})();
var statearr_47417_48512 = state_47375__$1;
(statearr_47417_48512[(2)] = null);

(statearr_47417_48512[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (28))){
var inst_47317 = (state_47375[(19)]);
var inst_47335 = (state_47375[(23)]);
var inst_47335__$1 = cljs.core.seq(inst_47317);
var state_47375__$1 = (function (){var statearr_47418 = state_47375;
(statearr_47418[(23)] = inst_47335__$1);

return statearr_47418;
})();
if(inst_47335__$1){
var statearr_47419_48513 = state_47375__$1;
(statearr_47419_48513[(1)] = (33));

} else {
var statearr_47420_48514 = state_47375__$1;
(statearr_47420_48514[(1)] = (34));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (25))){
var inst_47320 = (state_47375[(10)]);
var inst_47319 = (state_47375[(20)]);
var inst_47322 = (inst_47320 < inst_47319);
var inst_47323 = inst_47322;
var state_47375__$1 = state_47375;
if(cljs.core.truth_(inst_47323)){
var statearr_47421_48521 = state_47375__$1;
(statearr_47421_48521[(1)] = (27));

} else {
var statearr_47422_48522 = state_47375__$1;
(statearr_47422_48522[(1)] = (28));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (34))){
var state_47375__$1 = state_47375;
var statearr_47423_48523 = state_47375__$1;
(statearr_47423_48523[(2)] = null);

(statearr_47423_48523[(1)] = (35));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (17))){
var state_47375__$1 = state_47375;
var statearr_47424_48524 = state_47375__$1;
(statearr_47424_48524[(2)] = null);

(statearr_47424_48524[(1)] = (18));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (3))){
var inst_47373 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47375__$1,inst_47373);
} else {
if((state_val_47376 === (12))){
var inst_47304 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47425_48525 = state_47375__$1;
(statearr_47425_48525[(2)] = inst_47304);

(statearr_47425_48525[(1)] = (9));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (2))){
var state_47375__$1 = state_47375;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47375__$1,(4),ch);
} else {
if((state_val_47376 === (23))){
var state_47375__$1 = state_47375;
var statearr_47426_48526 = state_47375__$1;
(statearr_47426_48526[(2)] = null);

(statearr_47426_48526[(1)] = (24));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (35))){
var inst_47357 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47427_48527 = state_47375__$1;
(statearr_47427_48527[(2)] = inst_47357);

(statearr_47427_48527[(1)] = (29));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (19))){
var inst_47276 = (state_47375[(7)]);
var inst_47280 = cljs.core.chunk_first(inst_47276);
var inst_47281 = cljs.core.chunk_rest(inst_47276);
var inst_47282 = cljs.core.count(inst_47280);
var inst_47254 = inst_47281;
var inst_47255 = inst_47280;
var inst_47256 = inst_47282;
var inst_47257 = (0);
var state_47375__$1 = (function (){var statearr_47428 = state_47375;
(statearr_47428[(14)] = inst_47254);

(statearr_47428[(15)] = inst_47255);

(statearr_47428[(16)] = inst_47256);

(statearr_47428[(17)] = inst_47257);

return statearr_47428;
})();
var statearr_47429_48528 = state_47375__$1;
(statearr_47429_48528[(2)] = null);

(statearr_47429_48528[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (11))){
var inst_47254 = (state_47375[(14)]);
var inst_47276 = (state_47375[(7)]);
var inst_47276__$1 = cljs.core.seq(inst_47254);
var state_47375__$1 = (function (){var statearr_47430 = state_47375;
(statearr_47430[(7)] = inst_47276__$1);

return statearr_47430;
})();
if(inst_47276__$1){
var statearr_47431_48529 = state_47375__$1;
(statearr_47431_48529[(1)] = (16));

} else {
var statearr_47432_48530 = state_47375__$1;
(statearr_47432_48530[(1)] = (17));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (9))){
var inst_47306 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47433_48531 = state_47375__$1;
(statearr_47433_48531[(2)] = inst_47306);

(statearr_47433_48531[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (5))){
var inst_47252 = cljs.core.deref(cs);
var inst_47253 = cljs.core.seq(inst_47252);
var inst_47254 = inst_47253;
var inst_47255 = null;
var inst_47256 = (0);
var inst_47257 = (0);
var state_47375__$1 = (function (){var statearr_47434 = state_47375;
(statearr_47434[(14)] = inst_47254);

(statearr_47434[(15)] = inst_47255);

(statearr_47434[(16)] = inst_47256);

(statearr_47434[(17)] = inst_47257);

return statearr_47434;
})();
var statearr_47435_48538 = state_47375__$1;
(statearr_47435_48538[(2)] = null);

(statearr_47435_48538[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (14))){
var state_47375__$1 = state_47375;
var statearr_47436_48539 = state_47375__$1;
(statearr_47436_48539[(2)] = null);

(statearr_47436_48539[(1)] = (15));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (45))){
var inst_47365 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47437_48540 = state_47375__$1;
(statearr_47437_48540[(2)] = inst_47365);

(statearr_47437_48540[(1)] = (44));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (26))){
var inst_47309 = (state_47375[(27)]);
var inst_47361 = (state_47375[(2)]);
var inst_47362 = cljs.core.seq(inst_47309);
var state_47375__$1 = (function (){var statearr_47438 = state_47375;
(statearr_47438[(29)] = inst_47361);

return statearr_47438;
})();
if(inst_47362){
var statearr_47439_48541 = state_47375__$1;
(statearr_47439_48541[(1)] = (42));

} else {
var statearr_47440_48542 = state_47375__$1;
(statearr_47440_48542[(1)] = (43));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (16))){
var inst_47276 = (state_47375[(7)]);
var inst_47278 = cljs.core.chunked_seq_QMARK_(inst_47276);
var state_47375__$1 = state_47375;
if(inst_47278){
var statearr_47441_48543 = state_47375__$1;
(statearr_47441_48543[(1)] = (19));

} else {
var statearr_47442_48544 = state_47375__$1;
(statearr_47442_48544[(1)] = (20));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (38))){
var inst_47354 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47443_48545 = state_47375__$1;
(statearr_47443_48545[(2)] = inst_47354);

(statearr_47443_48545[(1)] = (35));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (30))){
var state_47375__$1 = state_47375;
var statearr_47444_48546 = state_47375__$1;
(statearr_47444_48546[(2)] = null);

(statearr_47444_48546[(1)] = (32));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (10))){
var inst_47255 = (state_47375[(15)]);
var inst_47257 = (state_47375[(17)]);
var inst_47265 = cljs.core._nth(inst_47255,inst_47257);
var inst_47266 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47265,(0),null);
var inst_47267 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47265,(1),null);
var state_47375__$1 = (function (){var statearr_47445 = state_47375;
(statearr_47445[(24)] = inst_47266);

return statearr_47445;
})();
if(cljs.core.truth_(inst_47267)){
var statearr_47446_48547 = state_47375__$1;
(statearr_47446_48547[(1)] = (13));

} else {
var statearr_47447_48548 = state_47375__$1;
(statearr_47447_48548[(1)] = (14));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (18))){
var inst_47302 = (state_47375[(2)]);
var state_47375__$1 = state_47375;
var statearr_47448_48549 = state_47375__$1;
(statearr_47448_48549[(2)] = inst_47302);

(statearr_47448_48549[(1)] = (12));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (42))){
var state_47375__$1 = state_47375;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47375__$1,(45),dchan);
} else {
if((state_val_47376 === (37))){
var inst_47335 = (state_47375[(23)]);
var inst_47344 = (state_47375[(22)]);
var inst_47245 = (state_47375[(12)]);
var inst_47344__$1 = cljs.core.first(inst_47335);
var inst_47345 = cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$3(inst_47344__$1,inst_47245,done);
var state_47375__$1 = (function (){var statearr_47449 = state_47375;
(statearr_47449[(22)] = inst_47344__$1);

return statearr_47449;
})();
if(cljs.core.truth_(inst_47345)){
var statearr_47450_48556 = state_47375__$1;
(statearr_47450_48556[(1)] = (39));

} else {
var statearr_47451_48557 = state_47375__$1;
(statearr_47451_48557[(1)] = (40));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47376 === (8))){
var inst_47257 = (state_47375[(17)]);
var inst_47256 = (state_47375[(16)]);
var inst_47259 = (inst_47257 < inst_47256);
var inst_47260 = inst_47259;
var state_47375__$1 = state_47375;
if(cljs.core.truth_(inst_47260)){
var statearr_47452_48558 = state_47375__$1;
(statearr_47452_48558[(1)] = (10));

} else {
var statearr_47453_48559 = state_47375__$1;
(statearr_47453_48559[(1)] = (11));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$mult_$_state_machine__46650__auto__ = null;
var cljs$core$async$mult_$_state_machine__46650__auto____0 = (function (){
var statearr_47454 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_47454[(0)] = cljs$core$async$mult_$_state_machine__46650__auto__);

(statearr_47454[(1)] = (1));

return statearr_47454;
});
var cljs$core$async$mult_$_state_machine__46650__auto____1 = (function (state_47375){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47375);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47455){var ex__46653__auto__ = e47455;
var statearr_47456_48560 = state_47375;
(statearr_47456_48560[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47375[(4)]))){
var statearr_47457_48561 = state_47375;
(statearr_47457_48561[(1)] = cljs.core.first((state_47375[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48562 = state_47375;
state_47375 = G__48562;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$mult_$_state_machine__46650__auto__ = function(state_47375){
switch(arguments.length){
case 0:
return cljs$core$async$mult_$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$mult_$_state_machine__46650__auto____1.call(this,state_47375);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$mult_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$mult_$_state_machine__46650__auto____0;
cljs$core$async$mult_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$mult_$_state_machine__46650__auto____1;
return cljs$core$async$mult_$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47458 = f__46686__auto__();
(statearr_47458[(6)] = c__46685__auto___48463);

return statearr_47458;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return m;
});
/**
 * Copies the mult source onto the supplied channel.
 * 
 *   By default the channel will be closed when the source closes,
 *   but can be determined by the close? parameter.
 */
cljs.core.async.tap = (function cljs$core$async$tap(var_args){
var G__47460 = arguments.length;
switch (G__47460) {
case 2:
return cljs.core.async.tap.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.tap.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.tap.cljs$core$IFn$_invoke$arity$2 = (function (mult,ch){
return cljs.core.async.tap.cljs$core$IFn$_invoke$arity$3(mult,ch,true);
}));

(cljs.core.async.tap.cljs$core$IFn$_invoke$arity$3 = (function (mult,ch,close_QMARK_){
cljs.core.async.tap_STAR_(mult,ch,close_QMARK_);

return ch;
}));

(cljs.core.async.tap.cljs$lang$maxFixedArity = 3);

/**
 * Disconnects a target channel from a mult
 */
cljs.core.async.untap = (function cljs$core$async$untap(mult,ch){
return cljs.core.async.untap_STAR_(mult,ch);
});
/**
 * Disconnects all target channels from a mult
 */
cljs.core.async.untap_all = (function cljs$core$async$untap_all(mult){
return cljs.core.async.untap_all_STAR_(mult);
});

/**
 * @interface
 */
cljs.core.async.Mix = function(){};

var cljs$core$async$Mix$admix_STAR_$dyn_48564 = (function (m,ch){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.admix_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4464__auto__.call(null,m,ch));
} else {
var m__4461__auto__ = (cljs.core.async.admix_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4461__auto__.call(null,m,ch));
} else {
throw cljs.core.missing_protocol("Mix.admix*",m);
}
}
});
cljs.core.async.admix_STAR_ = (function cljs$core$async$admix_STAR_(m,ch){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mix$admix_STAR_$arity$2 == null)))))){
return m.cljs$core$async$Mix$admix_STAR_$arity$2(m,ch);
} else {
return cljs$core$async$Mix$admix_STAR_$dyn_48564(m,ch);
}
});

var cljs$core$async$Mix$unmix_STAR_$dyn_48565 = (function (m,ch){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.unmix_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4464__auto__.call(null,m,ch));
} else {
var m__4461__auto__ = (cljs.core.async.unmix_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(m,ch) : m__4461__auto__.call(null,m,ch));
} else {
throw cljs.core.missing_protocol("Mix.unmix*",m);
}
}
});
cljs.core.async.unmix_STAR_ = (function cljs$core$async$unmix_STAR_(m,ch){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mix$unmix_STAR_$arity$2 == null)))))){
return m.cljs$core$async$Mix$unmix_STAR_$arity$2(m,ch);
} else {
return cljs$core$async$Mix$unmix_STAR_$dyn_48565(m,ch);
}
});

var cljs$core$async$Mix$unmix_all_STAR_$dyn_48566 = (function (m){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.unmix_all_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(m) : m__4464__auto__.call(null,m));
} else {
var m__4461__auto__ = (cljs.core.async.unmix_all_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(m) : m__4461__auto__.call(null,m));
} else {
throw cljs.core.missing_protocol("Mix.unmix-all*",m);
}
}
});
cljs.core.async.unmix_all_STAR_ = (function cljs$core$async$unmix_all_STAR_(m){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mix$unmix_all_STAR_$arity$1 == null)))))){
return m.cljs$core$async$Mix$unmix_all_STAR_$arity$1(m);
} else {
return cljs$core$async$Mix$unmix_all_STAR_$dyn_48566(m);
}
});

var cljs$core$async$Mix$toggle_STAR_$dyn_48567 = (function (m,state_map){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.toggle_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(m,state_map) : m__4464__auto__.call(null,m,state_map));
} else {
var m__4461__auto__ = (cljs.core.async.toggle_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(m,state_map) : m__4461__auto__.call(null,m,state_map));
} else {
throw cljs.core.missing_protocol("Mix.toggle*",m);
}
}
});
cljs.core.async.toggle_STAR_ = (function cljs$core$async$toggle_STAR_(m,state_map){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mix$toggle_STAR_$arity$2 == null)))))){
return m.cljs$core$async$Mix$toggle_STAR_$arity$2(m,state_map);
} else {
return cljs$core$async$Mix$toggle_STAR_$dyn_48567(m,state_map);
}
});

var cljs$core$async$Mix$solo_mode_STAR_$dyn_48569 = (function (m,mode){
var x__4463__auto__ = (((m == null))?null:m);
var m__4464__auto__ = (cljs.core.async.solo_mode_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(m,mode) : m__4464__auto__.call(null,m,mode));
} else {
var m__4461__auto__ = (cljs.core.async.solo_mode_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(m,mode) : m__4461__auto__.call(null,m,mode));
} else {
throw cljs.core.missing_protocol("Mix.solo-mode*",m);
}
}
});
cljs.core.async.solo_mode_STAR_ = (function cljs$core$async$solo_mode_STAR_(m,mode){
if((((!((m == null)))) && ((!((m.cljs$core$async$Mix$solo_mode_STAR_$arity$2 == null)))))){
return m.cljs$core$async$Mix$solo_mode_STAR_$arity$2(m,mode);
} else {
return cljs$core$async$Mix$solo_mode_STAR_$dyn_48569(m,mode);
}
});

cljs.core.async.ioc_alts_BANG_ = (function cljs$core$async$ioc_alts_BANG_(var_args){
var args__4777__auto__ = [];
var len__4771__auto___48574 = arguments.length;
var i__4772__auto___48575 = (0);
while(true){
if((i__4772__auto___48575 < len__4771__auto___48574)){
args__4777__auto__.push((arguments[i__4772__auto___48575]));

var G__48576 = (i__4772__auto___48575 + (1));
i__4772__auto___48575 = G__48576;
continue;
} else {
}
break;
}

var argseq__4778__auto__ = ((((3) < args__4777__auto__.length))?(new cljs.core.IndexedSeq(args__4777__auto__.slice((3)),(0),null)):null);
return cljs.core.async.ioc_alts_BANG_.cljs$core$IFn$_invoke$arity$variadic((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),argseq__4778__auto__);
});

(cljs.core.async.ioc_alts_BANG_.cljs$core$IFn$_invoke$arity$variadic = (function (state,cont_block,ports,p__47465){
var map__47466 = p__47465;
var map__47466__$1 = cljs.core.__destructure_map(map__47466);
var opts = map__47466__$1;
var statearr_47467_48577 = state;
(statearr_47467_48577[(1)] = cont_block);


var temp__5804__auto__ = cljs.core.async.do_alts((function (val){
var statearr_47468_48578 = state;
(statearr_47468_48578[(2)] = val);


return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state);
}),ports,opts);
if(cljs.core.truth_(temp__5804__auto__)){
var cb = temp__5804__auto__;
var statearr_47469_48579 = state;
(statearr_47469_48579[(2)] = cljs.core.deref(cb));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}));

(cljs.core.async.ioc_alts_BANG_.cljs$lang$maxFixedArity = (3));

/** @this {Function} */
(cljs.core.async.ioc_alts_BANG_.cljs$lang$applyTo = (function (seq47461){
var G__47462 = cljs.core.first(seq47461);
var seq47461__$1 = cljs.core.next(seq47461);
var G__47463 = cljs.core.first(seq47461__$1);
var seq47461__$2 = cljs.core.next(seq47461__$1);
var G__47464 = cljs.core.first(seq47461__$2);
var seq47461__$3 = cljs.core.next(seq47461__$2);
var self__4758__auto__ = this;
return self__4758__auto__.cljs$core$IFn$_invoke$arity$variadic(G__47462,G__47463,G__47464,seq47461__$3);
}));

/**
 * Creates and returns a mix of one or more input channels which will
 *   be put on the supplied out channel. Input sources can be added to
 *   the mix with 'admix', and removed with 'unmix'. A mix supports
 *   soloing, muting and pausing multiple inputs atomically using
 *   'toggle', and can solo using either muting or pausing as determined
 *   by 'solo-mode'.
 * 
 *   Each channel can have zero or more boolean modes set via 'toggle':
 * 
 *   :solo - when true, only this (ond other soloed) channel(s) will appear
 *        in the mix output channel. :mute and :pause states of soloed
 *        channels are ignored. If solo-mode is :mute, non-soloed
 *        channels are muted, if :pause, non-soloed channels are
 *        paused.
 * 
 *   :mute - muted channels will have their contents consumed but not included in the mix
 *   :pause - paused channels will not have their contents consumed (and thus also not included in the mix)
 */
cljs.core.async.mix = (function cljs$core$async$mix(out){
var cs = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(cljs.core.PersistentArrayMap.EMPTY);
var solo_modes = new cljs.core.PersistentHashSet(null, new cljs.core.PersistentArrayMap(null, 2, [new cljs.core.Keyword(null,"pause","pause",-2095325672),null,new cljs.core.Keyword(null,"mute","mute",1151223646),null], null), null);
var attrs = cljs.core.conj.cljs$core$IFn$_invoke$arity$2(solo_modes,new cljs.core.Keyword(null,"solo","solo",-316350075));
var solo_mode = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(new cljs.core.Keyword(null,"mute","mute",1151223646));
var change = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(cljs.core.async.sliding_buffer((1)));
var changed = (function (){
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(change,true);
});
var pick = (function (attr,chs){
return cljs.core.reduce_kv((function (ret,c,v){
if(cljs.core.truth_((attr.cljs$core$IFn$_invoke$arity$1 ? attr.cljs$core$IFn$_invoke$arity$1(v) : attr.call(null,v)))){
return cljs.core.conj.cljs$core$IFn$_invoke$arity$2(ret,c);
} else {
return ret;
}
}),cljs.core.PersistentHashSet.EMPTY,chs);
});
var calc_state = (function (){
var chs = cljs.core.deref(cs);
var mode = cljs.core.deref(solo_mode);
var solos = pick(new cljs.core.Keyword(null,"solo","solo",-316350075),chs);
var pauses = pick(new cljs.core.Keyword(null,"pause","pause",-2095325672),chs);
return new cljs.core.PersistentArrayMap(null, 3, [new cljs.core.Keyword(null,"solos","solos",1441458643),solos,new cljs.core.Keyword(null,"mutes","mutes",1068806309),pick(new cljs.core.Keyword(null,"mute","mute",1151223646),chs),new cljs.core.Keyword(null,"reads","reads",-1215067361),cljs.core.conj.cljs$core$IFn$_invoke$arity$2(((((cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(mode,new cljs.core.Keyword(null,"pause","pause",-2095325672))) && (cljs.core.seq(solos))))?cljs.core.vec(solos):cljs.core.vec(cljs.core.remove.cljs$core$IFn$_invoke$arity$2(pauses,cljs.core.keys(chs)))),change)], null);
});
var m = (function (){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47470 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.async.Mix}
 * @implements {cljs.core.async.Mux}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47470 = (function (change,solo_mode,pick,cs,calc_state,out,changed,solo_modes,attrs,meta47471){
this.change = change;
this.solo_mode = solo_mode;
this.pick = pick;
this.cs = cs;
this.calc_state = calc_state;
this.out = out;
this.changed = changed;
this.solo_modes = solo_modes;
this.attrs = attrs;
this.meta47471 = meta47471;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47472,meta47471__$1){
var self__ = this;
var _47472__$1 = this;
return (new cljs.core.async.t_cljs$core$async47470(self__.change,self__.solo_mode,self__.pick,self__.cs,self__.calc_state,self__.out,self__.changed,self__.solo_modes,self__.attrs,meta47471__$1));
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47472){
var self__ = this;
var _47472__$1 = this;
return self__.meta47471;
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mux$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mux$muxch_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return self__.out;
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$admix_STAR_$arity$2 = (function (_,ch){
var self__ = this;
var ___$1 = this;
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$4(self__.cs,cljs.core.assoc,ch,cljs.core.PersistentArrayMap.EMPTY);

return (self__.changed.cljs$core$IFn$_invoke$arity$0 ? self__.changed.cljs$core$IFn$_invoke$arity$0() : self__.changed.call(null));
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$unmix_STAR_$arity$2 = (function (_,ch){
var self__ = this;
var ___$1 = this;
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(self__.cs,cljs.core.dissoc,ch);

return (self__.changed.cljs$core$IFn$_invoke$arity$0 ? self__.changed.cljs$core$IFn$_invoke$arity$0() : self__.changed.call(null));
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$unmix_all_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
cljs.core.reset_BANG_(self__.cs,cljs.core.PersistentArrayMap.EMPTY);

return (self__.changed.cljs$core$IFn$_invoke$arity$0 ? self__.changed.cljs$core$IFn$_invoke$arity$0() : self__.changed.call(null));
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$toggle_STAR_$arity$2 = (function (_,state_map){
var self__ = this;
var ___$1 = this;
cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(self__.cs,cljs.core.partial.cljs$core$IFn$_invoke$arity$2(cljs.core.merge_with,cljs.core.merge),state_map);

return (self__.changed.cljs$core$IFn$_invoke$arity$0 ? self__.changed.cljs$core$IFn$_invoke$arity$0() : self__.changed.call(null));
}));

(cljs.core.async.t_cljs$core$async47470.prototype.cljs$core$async$Mix$solo_mode_STAR_$arity$2 = (function (_,mode){
var self__ = this;
var ___$1 = this;
if(cljs.core.truth_((self__.solo_modes.cljs$core$IFn$_invoke$arity$1 ? self__.solo_modes.cljs$core$IFn$_invoke$arity$1(mode) : self__.solo_modes.call(null,mode)))){
} else {
throw (new Error(["Assert failed: ",["mode must be one of: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(self__.solo_modes)].join(''),"\n","(solo-modes mode)"].join('')));
}

cljs.core.reset_BANG_(self__.solo_mode,mode);

return (self__.changed.cljs$core$IFn$_invoke$arity$0 ? self__.changed.cljs$core$IFn$_invoke$arity$0() : self__.changed.call(null));
}));

(cljs.core.async.t_cljs$core$async47470.getBasis = (function (){
return new cljs.core.PersistentVector(null, 10, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"change","change",477485025,null),new cljs.core.Symbol(null,"solo-mode","solo-mode",2031788074,null),new cljs.core.Symbol(null,"pick","pick",1300068175,null),new cljs.core.Symbol(null,"cs","cs",-117024463,null),new cljs.core.Symbol(null,"calc-state","calc-state",-349968968,null),new cljs.core.Symbol(null,"out","out",729986010,null),new cljs.core.Symbol(null,"changed","changed",-2083710852,null),new cljs.core.Symbol(null,"solo-modes","solo-modes",882180540,null),new cljs.core.Symbol(null,"attrs","attrs",-450137186,null),new cljs.core.Symbol(null,"meta47471","meta47471",-486432255,null)], null);
}));

(cljs.core.async.t_cljs$core$async47470.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47470.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47470");

(cljs.core.async.t_cljs$core$async47470.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47470");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47470.
 */
cljs.core.async.__GT_t_cljs$core$async47470 = (function cljs$core$async$mix_$___GT_t_cljs$core$async47470(change__$1,solo_mode__$1,pick__$1,cs__$1,calc_state__$1,out__$1,changed__$1,solo_modes__$1,attrs__$1,meta47471){
return (new cljs.core.async.t_cljs$core$async47470(change__$1,solo_mode__$1,pick__$1,cs__$1,calc_state__$1,out__$1,changed__$1,solo_modes__$1,attrs__$1,meta47471));
});

}

return (new cljs.core.async.t_cljs$core$async47470(change,solo_mode,pick,cs,calc_state,out,changed,solo_modes,attrs,cljs.core.PersistentArrayMap.EMPTY));
})()
;
var c__46685__auto___48584 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47534){
var state_val_47535 = (state_47534[(1)]);
if((state_val_47535 === (7))){
var inst_47530 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
var statearr_47536_48585 = state_47534__$1;
(statearr_47536_48585[(2)] = inst_47530);

(statearr_47536_48585[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (20))){
var inst_47524 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
var statearr_47537_48586 = state_47534__$1;
(statearr_47537_48586[(2)] = inst_47524);

(statearr_47537_48586[(1)] = (16));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (1))){
var inst_47476 = calc_state();
var inst_47477 = cljs.core.__destructure_map(inst_47476);
var inst_47478 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47477,new cljs.core.Keyword(null,"solos","solos",1441458643));
var inst_47479 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47477,new cljs.core.Keyword(null,"mutes","mutes",1068806309));
var inst_47480 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47477,new cljs.core.Keyword(null,"reads","reads",-1215067361));
var inst_47481 = inst_47476;
var state_47534__$1 = (function (){var statearr_47538 = state_47534;
(statearr_47538[(7)] = inst_47478);

(statearr_47538[(8)] = inst_47479);

(statearr_47538[(9)] = inst_47480);

(statearr_47538[(10)] = inst_47481);

return statearr_47538;
})();
var statearr_47539_48587 = state_47534__$1;
(statearr_47539_48587[(2)] = null);

(statearr_47539_48587[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (4))){
var inst_47493 = (state_47534[(11)]);
var inst_47494 = (state_47534[(12)]);
var inst_47492 = (state_47534[(2)]);
var inst_47493__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47492,(0),null);
var inst_47494__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47492,(1),null);
var inst_47495 = (inst_47493__$1 == null);
var inst_47496 = cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(inst_47494__$1,change);
var inst_47497 = ((inst_47495) || (inst_47496));
var state_47534__$1 = (function (){var statearr_47540 = state_47534;
(statearr_47540[(11)] = inst_47493__$1);

(statearr_47540[(12)] = inst_47494__$1);

return statearr_47540;
})();
if(cljs.core.truth_(inst_47497)){
var statearr_47541_48588 = state_47534__$1;
(statearr_47541_48588[(1)] = (5));

} else {
var statearr_47542_48589 = state_47534__$1;
(statearr_47542_48589[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (15))){
var inst_47484 = (state_47534[(13)]);
var inst_47481 = inst_47484;
var state_47534__$1 = (function (){var statearr_47543 = state_47534;
(statearr_47543[(10)] = inst_47481);

return statearr_47543;
})();
var statearr_47544_48592 = state_47534__$1;
(statearr_47544_48592[(2)] = null);

(statearr_47544_48592[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (13))){
var inst_47516 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
if(cljs.core.truth_(inst_47516)){
var statearr_47545_48593 = state_47534__$1;
(statearr_47545_48593[(1)] = (14));

} else {
var statearr_47546_48594 = state_47534__$1;
(statearr_47546_48594[(1)] = (15));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (6))){
var inst_47485 = (state_47534[(14)]);
var inst_47494 = (state_47534[(12)]);
var inst_47508 = (state_47534[(15)]);
var inst_47508__$1 = (inst_47485.cljs$core$IFn$_invoke$arity$1 ? inst_47485.cljs$core$IFn$_invoke$arity$1(inst_47494) : inst_47485.call(null,inst_47494));
var state_47534__$1 = (function (){var statearr_47547 = state_47534;
(statearr_47547[(15)] = inst_47508__$1);

return statearr_47547;
})();
if(cljs.core.truth_(inst_47508__$1)){
var statearr_47548_48595 = state_47534__$1;
(statearr_47548_48595[(1)] = (11));

} else {
var statearr_47549_48596 = state_47534__$1;
(statearr_47549_48596[(1)] = (12));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (17))){
var inst_47519 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
if(cljs.core.truth_(inst_47519)){
var statearr_47550_48597 = state_47534__$1;
(statearr_47550_48597[(1)] = (18));

} else {
var statearr_47551_48598 = state_47534__$1;
(statearr_47551_48598[(1)] = (19));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (3))){
var inst_47532 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47534__$1,inst_47532);
} else {
if((state_val_47535 === (12))){
var inst_47485 = (state_47534[(14)]);
var inst_47486 = (state_47534[(16)]);
var inst_47494 = (state_47534[(12)]);
var inst_47511 = cljs.core.empty_QMARK_(inst_47485);
var inst_47512 = (inst_47486.cljs$core$IFn$_invoke$arity$1 ? inst_47486.cljs$core$IFn$_invoke$arity$1(inst_47494) : inst_47486.call(null,inst_47494));
var inst_47513 = cljs.core.not(inst_47512);
var inst_47514 = ((inst_47511) && (inst_47513));
var state_47534__$1 = state_47534;
var statearr_47552_48599 = state_47534__$1;
(statearr_47552_48599[(2)] = inst_47514);

(statearr_47552_48599[(1)] = (13));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (2))){
var inst_47481 = (state_47534[(10)]);
var inst_47484 = (state_47534[(13)]);
var inst_47484__$1 = cljs.core.__destructure_map(inst_47481);
var inst_47485 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47484__$1,new cljs.core.Keyword(null,"solos","solos",1441458643));
var inst_47486 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47484__$1,new cljs.core.Keyword(null,"mutes","mutes",1068806309));
var inst_47487 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47484__$1,new cljs.core.Keyword(null,"reads","reads",-1215067361));
var state_47534__$1 = (function (){var statearr_47553 = state_47534;
(statearr_47553[(13)] = inst_47484__$1);

(statearr_47553[(14)] = inst_47485);

(statearr_47553[(16)] = inst_47486);

return statearr_47553;
})();
return cljs.core.async.ioc_alts_BANG_(state_47534__$1,(4),inst_47487);
} else {
if((state_val_47535 === (19))){
var state_47534__$1 = state_47534;
var statearr_47554_48600 = state_47534__$1;
(statearr_47554_48600[(2)] = null);

(statearr_47554_48600[(1)] = (20));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (11))){
var inst_47508 = (state_47534[(15)]);
var state_47534__$1 = state_47534;
var statearr_47555_48601 = state_47534__$1;
(statearr_47555_48601[(2)] = inst_47508);

(statearr_47555_48601[(1)] = (13));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (9))){
var state_47534__$1 = state_47534;
var statearr_47556_48602 = state_47534__$1;
(statearr_47556_48602[(2)] = null);

(statearr_47556_48602[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (5))){
var inst_47493 = (state_47534[(11)]);
var inst_47499 = (inst_47493 == null);
var state_47534__$1 = state_47534;
if(cljs.core.truth_(inst_47499)){
var statearr_47557_48603 = state_47534__$1;
(statearr_47557_48603[(1)] = (8));

} else {
var statearr_47558_48604 = state_47534__$1;
(statearr_47558_48604[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (14))){
var inst_47493 = (state_47534[(11)]);
var state_47534__$1 = state_47534;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47534__$1,(17),out,inst_47493);
} else {
if((state_val_47535 === (16))){
var inst_47528 = (state_47534[(2)]);
var state_47534__$1 = state_47534;
var statearr_47559_48605 = state_47534__$1;
(statearr_47559_48605[(2)] = inst_47528);

(statearr_47559_48605[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (10))){
var inst_47504 = (state_47534[(2)]);
var inst_47505 = calc_state();
var inst_47481 = inst_47505;
var state_47534__$1 = (function (){var statearr_47560 = state_47534;
(statearr_47560[(17)] = inst_47504);

(statearr_47560[(10)] = inst_47481);

return statearr_47560;
})();
var statearr_47561_48606 = state_47534__$1;
(statearr_47561_48606[(2)] = null);

(statearr_47561_48606[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (18))){
var inst_47484 = (state_47534[(13)]);
var inst_47481 = inst_47484;
var state_47534__$1 = (function (){var statearr_47562 = state_47534;
(statearr_47562[(10)] = inst_47481);

return statearr_47562;
})();
var statearr_47563_48608 = state_47534__$1;
(statearr_47563_48608[(2)] = null);

(statearr_47563_48608[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47535 === (8))){
var inst_47494 = (state_47534[(12)]);
var inst_47501 = cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(cs,cljs.core.dissoc,inst_47494);
var state_47534__$1 = state_47534;
var statearr_47564_48609 = state_47534__$1;
(statearr_47564_48609[(2)] = inst_47501);

(statearr_47564_48609[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$mix_$_state_machine__46650__auto__ = null;
var cljs$core$async$mix_$_state_machine__46650__auto____0 = (function (){
var statearr_47565 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_47565[(0)] = cljs$core$async$mix_$_state_machine__46650__auto__);

(statearr_47565[(1)] = (1));

return statearr_47565;
});
var cljs$core$async$mix_$_state_machine__46650__auto____1 = (function (state_47534){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47534);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47566){var ex__46653__auto__ = e47566;
var statearr_47567_48614 = state_47534;
(statearr_47567_48614[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47534[(4)]))){
var statearr_47568_48615 = state_47534;
(statearr_47568_48615[(1)] = cljs.core.first((state_47534[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48616 = state_47534;
state_47534 = G__48616;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$mix_$_state_machine__46650__auto__ = function(state_47534){
switch(arguments.length){
case 0:
return cljs$core$async$mix_$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$mix_$_state_machine__46650__auto____1.call(this,state_47534);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$mix_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$mix_$_state_machine__46650__auto____0;
cljs$core$async$mix_$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$mix_$_state_machine__46650__auto____1;
return cljs$core$async$mix_$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47569 = f__46686__auto__();
(statearr_47569[(6)] = c__46685__auto___48584);

return statearr_47569;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return m;
});
/**
 * Adds ch as an input to the mix
 */
cljs.core.async.admix = (function cljs$core$async$admix(mix,ch){
return cljs.core.async.admix_STAR_(mix,ch);
});
/**
 * Removes ch as an input to the mix
 */
cljs.core.async.unmix = (function cljs$core$async$unmix(mix,ch){
return cljs.core.async.unmix_STAR_(mix,ch);
});
/**
 * removes all inputs from the mix
 */
cljs.core.async.unmix_all = (function cljs$core$async$unmix_all(mix){
return cljs.core.async.unmix_all_STAR_(mix);
});
/**
 * Atomically sets the state(s) of one or more channels in a mix. The
 *   state map is a map of channels -> channel-state-map. A
 *   channel-state-map is a map of attrs -> boolean, where attr is one or
 *   more of :mute, :pause or :solo. Any states supplied are merged with
 *   the current state.
 * 
 *   Note that channels can be added to a mix via toggle, which can be
 *   used to add channels in a particular (e.g. paused) state.
 */
cljs.core.async.toggle = (function cljs$core$async$toggle(mix,state_map){
return cljs.core.async.toggle_STAR_(mix,state_map);
});
/**
 * Sets the solo mode of the mix. mode must be one of :mute or :pause
 */
cljs.core.async.solo_mode = (function cljs$core$async$solo_mode(mix,mode){
return cljs.core.async.solo_mode_STAR_(mix,mode);
});

/**
 * @interface
 */
cljs.core.async.Pub = function(){};

var cljs$core$async$Pub$sub_STAR_$dyn_48617 = (function (p,v,ch,close_QMARK_){
var x__4463__auto__ = (((p == null))?null:p);
var m__4464__auto__ = (cljs.core.async.sub_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$4 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$4(p,v,ch,close_QMARK_) : m__4464__auto__.call(null,p,v,ch,close_QMARK_));
} else {
var m__4461__auto__ = (cljs.core.async.sub_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$4 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$4(p,v,ch,close_QMARK_) : m__4461__auto__.call(null,p,v,ch,close_QMARK_));
} else {
throw cljs.core.missing_protocol("Pub.sub*",p);
}
}
});
cljs.core.async.sub_STAR_ = (function cljs$core$async$sub_STAR_(p,v,ch,close_QMARK_){
if((((!((p == null)))) && ((!((p.cljs$core$async$Pub$sub_STAR_$arity$4 == null)))))){
return p.cljs$core$async$Pub$sub_STAR_$arity$4(p,v,ch,close_QMARK_);
} else {
return cljs$core$async$Pub$sub_STAR_$dyn_48617(p,v,ch,close_QMARK_);
}
});

var cljs$core$async$Pub$unsub_STAR_$dyn_48618 = (function (p,v,ch){
var x__4463__auto__ = (((p == null))?null:p);
var m__4464__auto__ = (cljs.core.async.unsub_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$3 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$3(p,v,ch) : m__4464__auto__.call(null,p,v,ch));
} else {
var m__4461__auto__ = (cljs.core.async.unsub_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$3 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$3(p,v,ch) : m__4461__auto__.call(null,p,v,ch));
} else {
throw cljs.core.missing_protocol("Pub.unsub*",p);
}
}
});
cljs.core.async.unsub_STAR_ = (function cljs$core$async$unsub_STAR_(p,v,ch){
if((((!((p == null)))) && ((!((p.cljs$core$async$Pub$unsub_STAR_$arity$3 == null)))))){
return p.cljs$core$async$Pub$unsub_STAR_$arity$3(p,v,ch);
} else {
return cljs$core$async$Pub$unsub_STAR_$dyn_48618(p,v,ch);
}
});

var cljs$core$async$Pub$unsub_all_STAR_$dyn_48626 = (function() {
var G__48627 = null;
var G__48627__1 = (function (p){
var x__4463__auto__ = (((p == null))?null:p);
var m__4464__auto__ = (cljs.core.async.unsub_all_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$1(p) : m__4464__auto__.call(null,p));
} else {
var m__4461__auto__ = (cljs.core.async.unsub_all_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$1 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$1(p) : m__4461__auto__.call(null,p));
} else {
throw cljs.core.missing_protocol("Pub.unsub-all*",p);
}
}
});
var G__48627__2 = (function (p,v){
var x__4463__auto__ = (((p == null))?null:p);
var m__4464__auto__ = (cljs.core.async.unsub_all_STAR_[goog.typeOf(x__4463__auto__)]);
if((!((m__4464__auto__ == null)))){
return (m__4464__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4464__auto__.cljs$core$IFn$_invoke$arity$2(p,v) : m__4464__auto__.call(null,p,v));
} else {
var m__4461__auto__ = (cljs.core.async.unsub_all_STAR_["_"]);
if((!((m__4461__auto__ == null)))){
return (m__4461__auto__.cljs$core$IFn$_invoke$arity$2 ? m__4461__auto__.cljs$core$IFn$_invoke$arity$2(p,v) : m__4461__auto__.call(null,p,v));
} else {
throw cljs.core.missing_protocol("Pub.unsub-all*",p);
}
}
});
G__48627 = function(p,v){
switch(arguments.length){
case 1:
return G__48627__1.call(this,p);
case 2:
return G__48627__2.call(this,p,v);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
G__48627.cljs$core$IFn$_invoke$arity$1 = G__48627__1;
G__48627.cljs$core$IFn$_invoke$arity$2 = G__48627__2;
return G__48627;
})()
;
cljs.core.async.unsub_all_STAR_ = (function cljs$core$async$unsub_all_STAR_(var_args){
var G__47571 = arguments.length;
switch (G__47571) {
case 1:
return cljs.core.async.unsub_all_STAR_.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.unsub_all_STAR_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.unsub_all_STAR_.cljs$core$IFn$_invoke$arity$1 = (function (p){
if((((!((p == null)))) && ((!((p.cljs$core$async$Pub$unsub_all_STAR_$arity$1 == null)))))){
return p.cljs$core$async$Pub$unsub_all_STAR_$arity$1(p);
} else {
return cljs$core$async$Pub$unsub_all_STAR_$dyn_48626(p);
}
}));

(cljs.core.async.unsub_all_STAR_.cljs$core$IFn$_invoke$arity$2 = (function (p,v){
if((((!((p == null)))) && ((!((p.cljs$core$async$Pub$unsub_all_STAR_$arity$2 == null)))))){
return p.cljs$core$async$Pub$unsub_all_STAR_$arity$2(p,v);
} else {
return cljs$core$async$Pub$unsub_all_STAR_$dyn_48626(p,v);
}
}));

(cljs.core.async.unsub_all_STAR_.cljs$lang$maxFixedArity = 2);


/**
 * Creates and returns a pub(lication) of the supplied channel,
 *   partitioned into topics by the topic-fn. topic-fn will be applied to
 *   each value on the channel and the result will determine the 'topic'
 *   on which that value will be put. Channels can be subscribed to
 *   receive copies of topics using 'sub', and unsubscribed using
 *   'unsub'. Each topic will be handled by an internal mult on a
 *   dedicated channel. By default these internal channels are
 *   unbuffered, but a buf-fn can be supplied which, given a topic,
 *   creates a buffer with desired properties.
 * 
 *   Each item is distributed to all subs in parallel and synchronously,
 *   i.e. each sub must accept before the next item is distributed. Use
 *   buffering/windowing to prevent slow subs from holding up the pub.
 * 
 *   Items received when there are no matching subs get dropped.
 * 
 *   Note that if buf-fns are used then each topic is handled
 *   asynchronously, i.e. if a channel is subscribed to more than one
 *   topic it should not expect them to be interleaved identically with
 *   the source.
 */
cljs.core.async.pub = (function cljs$core$async$pub(var_args){
var G__47574 = arguments.length;
switch (G__47574) {
case 2:
return cljs.core.async.pub.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.pub.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.pub.cljs$core$IFn$_invoke$arity$2 = (function (ch,topic_fn){
return cljs.core.async.pub.cljs$core$IFn$_invoke$arity$3(ch,topic_fn,cljs.core.constantly(null));
}));

(cljs.core.async.pub.cljs$core$IFn$_invoke$arity$3 = (function (ch,topic_fn,buf_fn){
var mults = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(cljs.core.PersistentArrayMap.EMPTY);
var ensure_mult = (function (topic){
var or__4160__auto__ = cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(mults),topic);
if(cljs.core.truth_(or__4160__auto__)){
return or__4160__auto__;
} else {
return cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(mults,(function (p1__47572_SHARP_){
if(cljs.core.truth_((p1__47572_SHARP_.cljs$core$IFn$_invoke$arity$1 ? p1__47572_SHARP_.cljs$core$IFn$_invoke$arity$1(topic) : p1__47572_SHARP_.call(null,topic)))){
return p1__47572_SHARP_;
} else {
return cljs.core.assoc.cljs$core$IFn$_invoke$arity$3(p1__47572_SHARP_,topic,cljs.core.async.mult(cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((buf_fn.cljs$core$IFn$_invoke$arity$1 ? buf_fn.cljs$core$IFn$_invoke$arity$1(topic) : buf_fn.call(null,topic)))));
}
})),topic);
}
});
var p = (function (){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47575 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.Pub}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.async.Mux}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47575 = (function (ch,topic_fn,buf_fn,mults,ensure_mult,meta47576){
this.ch = ch;
this.topic_fn = topic_fn;
this.buf_fn = buf_fn;
this.mults = mults;
this.ensure_mult = ensure_mult;
this.meta47576 = meta47576;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47577,meta47576__$1){
var self__ = this;
var _47577__$1 = this;
return (new cljs.core.async.t_cljs$core$async47575(self__.ch,self__.topic_fn,self__.buf_fn,self__.mults,self__.ensure_mult,meta47576__$1));
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47577){
var self__ = this;
var _47577__$1 = this;
return self__.meta47576;
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Mux$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Mux$muxch_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return self__.ch;
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Pub$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Pub$sub_STAR_$arity$4 = (function (p,topic,ch__$1,close_QMARK_){
var self__ = this;
var p__$1 = this;
var m = (self__.ensure_mult.cljs$core$IFn$_invoke$arity$1 ? self__.ensure_mult.cljs$core$IFn$_invoke$arity$1(topic) : self__.ensure_mult.call(null,topic));
return cljs.core.async.tap.cljs$core$IFn$_invoke$arity$3(m,ch__$1,close_QMARK_);
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Pub$unsub_STAR_$arity$3 = (function (p,topic,ch__$1){
var self__ = this;
var p__$1 = this;
var temp__5804__auto__ = cljs.core.get.cljs$core$IFn$_invoke$arity$2(cljs.core.deref(self__.mults),topic);
if(cljs.core.truth_(temp__5804__auto__)){
var m = temp__5804__auto__;
return cljs.core.async.untap(m,ch__$1);
} else {
return null;
}
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Pub$unsub_all_STAR_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.reset_BANG_(self__.mults,cljs.core.PersistentArrayMap.EMPTY);
}));

(cljs.core.async.t_cljs$core$async47575.prototype.cljs$core$async$Pub$unsub_all_STAR_$arity$2 = (function (_,topic){
var self__ = this;
var ___$1 = this;
return cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(self__.mults,cljs.core.dissoc,topic);
}));

(cljs.core.async.t_cljs$core$async47575.getBasis = (function (){
return new cljs.core.PersistentVector(null, 6, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"topic-fn","topic-fn",-862449736,null),new cljs.core.Symbol(null,"buf-fn","buf-fn",-1200281591,null),new cljs.core.Symbol(null,"mults","mults",-461114485,null),new cljs.core.Symbol(null,"ensure-mult","ensure-mult",1796584816,null),new cljs.core.Symbol(null,"meta47576","meta47576",359263492,null)], null);
}));

(cljs.core.async.t_cljs$core$async47575.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47575.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47575");

(cljs.core.async.t_cljs$core$async47575.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47575");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47575.
 */
cljs.core.async.__GT_t_cljs$core$async47575 = (function cljs$core$async$__GT_t_cljs$core$async47575(ch__$1,topic_fn__$1,buf_fn__$1,mults__$1,ensure_mult__$1,meta47576){
return (new cljs.core.async.t_cljs$core$async47575(ch__$1,topic_fn__$1,buf_fn__$1,mults__$1,ensure_mult__$1,meta47576));
});

}

return (new cljs.core.async.t_cljs$core$async47575(ch,topic_fn,buf_fn,mults,ensure_mult,cljs.core.PersistentArrayMap.EMPTY));
})()
;
var c__46685__auto___48643 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47649){
var state_val_47650 = (state_47649[(1)]);
if((state_val_47650 === (7))){
var inst_47645 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47651_48644 = state_47649__$1;
(statearr_47651_48644[(2)] = inst_47645);

(statearr_47651_48644[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (20))){
var state_47649__$1 = state_47649;
var statearr_47652_48645 = state_47649__$1;
(statearr_47652_48645[(2)] = null);

(statearr_47652_48645[(1)] = (21));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (1))){
var state_47649__$1 = state_47649;
var statearr_47653_48647 = state_47649__$1;
(statearr_47653_48647[(2)] = null);

(statearr_47653_48647[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (24))){
var inst_47628 = (state_47649[(7)]);
var inst_47637 = cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$3(mults,cljs.core.dissoc,inst_47628);
var state_47649__$1 = state_47649;
var statearr_47654_48649 = state_47649__$1;
(statearr_47654_48649[(2)] = inst_47637);

(statearr_47654_48649[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (4))){
var inst_47580 = (state_47649[(8)]);
var inst_47580__$1 = (state_47649[(2)]);
var inst_47581 = (inst_47580__$1 == null);
var state_47649__$1 = (function (){var statearr_47655 = state_47649;
(statearr_47655[(8)] = inst_47580__$1);

return statearr_47655;
})();
if(cljs.core.truth_(inst_47581)){
var statearr_47656_48650 = state_47649__$1;
(statearr_47656_48650[(1)] = (5));

} else {
var statearr_47657_48651 = state_47649__$1;
(statearr_47657_48651[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (15))){
var inst_47622 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47658_48652 = state_47649__$1;
(statearr_47658_48652[(2)] = inst_47622);

(statearr_47658_48652[(1)] = (12));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (21))){
var inst_47642 = (state_47649[(2)]);
var state_47649__$1 = (function (){var statearr_47659 = state_47649;
(statearr_47659[(9)] = inst_47642);

return statearr_47659;
})();
var statearr_47660_48653 = state_47649__$1;
(statearr_47660_48653[(2)] = null);

(statearr_47660_48653[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (13))){
var inst_47604 = (state_47649[(10)]);
var inst_47606 = cljs.core.chunked_seq_QMARK_(inst_47604);
var state_47649__$1 = state_47649;
if(inst_47606){
var statearr_47661_48654 = state_47649__$1;
(statearr_47661_48654[(1)] = (16));

} else {
var statearr_47662_48655 = state_47649__$1;
(statearr_47662_48655[(1)] = (17));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (22))){
var inst_47634 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
if(cljs.core.truth_(inst_47634)){
var statearr_47663_48656 = state_47649__$1;
(statearr_47663_48656[(1)] = (23));

} else {
var statearr_47664_48657 = state_47649__$1;
(statearr_47664_48657[(1)] = (24));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (6))){
var inst_47580 = (state_47649[(8)]);
var inst_47628 = (state_47649[(7)]);
var inst_47630 = (state_47649[(11)]);
var inst_47628__$1 = (topic_fn.cljs$core$IFn$_invoke$arity$1 ? topic_fn.cljs$core$IFn$_invoke$arity$1(inst_47580) : topic_fn.call(null,inst_47580));
var inst_47629 = cljs.core.deref(mults);
var inst_47630__$1 = cljs.core.get.cljs$core$IFn$_invoke$arity$2(inst_47629,inst_47628__$1);
var state_47649__$1 = (function (){var statearr_47665 = state_47649;
(statearr_47665[(7)] = inst_47628__$1);

(statearr_47665[(11)] = inst_47630__$1);

return statearr_47665;
})();
if(cljs.core.truth_(inst_47630__$1)){
var statearr_47666_48658 = state_47649__$1;
(statearr_47666_48658[(1)] = (19));

} else {
var statearr_47667_48659 = state_47649__$1;
(statearr_47667_48659[(1)] = (20));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (25))){
var inst_47639 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47668_48660 = state_47649__$1;
(statearr_47668_48660[(2)] = inst_47639);

(statearr_47668_48660[(1)] = (21));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (17))){
var inst_47604 = (state_47649[(10)]);
var inst_47613 = cljs.core.first(inst_47604);
var inst_47614 = cljs.core.async.muxch_STAR_(inst_47613);
var inst_47615 = cljs.core.async.close_BANG_(inst_47614);
var inst_47616 = cljs.core.next(inst_47604);
var inst_47590 = inst_47616;
var inst_47591 = null;
var inst_47592 = (0);
var inst_47593 = (0);
var state_47649__$1 = (function (){var statearr_47669 = state_47649;
(statearr_47669[(12)] = inst_47615);

(statearr_47669[(13)] = inst_47590);

(statearr_47669[(14)] = inst_47591);

(statearr_47669[(15)] = inst_47592);

(statearr_47669[(16)] = inst_47593);

return statearr_47669;
})();
var statearr_47670_48661 = state_47649__$1;
(statearr_47670_48661[(2)] = null);

(statearr_47670_48661[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (3))){
var inst_47647 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47649__$1,inst_47647);
} else {
if((state_val_47650 === (12))){
var inst_47624 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47671_48662 = state_47649__$1;
(statearr_47671_48662[(2)] = inst_47624);

(statearr_47671_48662[(1)] = (9));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (2))){
var state_47649__$1 = state_47649;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47649__$1,(4),ch);
} else {
if((state_val_47650 === (23))){
var state_47649__$1 = state_47649;
var statearr_47672_48663 = state_47649__$1;
(statearr_47672_48663[(2)] = null);

(statearr_47672_48663[(1)] = (25));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (19))){
var inst_47630 = (state_47649[(11)]);
var inst_47580 = (state_47649[(8)]);
var inst_47632 = cljs.core.async.muxch_STAR_(inst_47630);
var state_47649__$1 = state_47649;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47649__$1,(22),inst_47632,inst_47580);
} else {
if((state_val_47650 === (11))){
var inst_47590 = (state_47649[(13)]);
var inst_47604 = (state_47649[(10)]);
var inst_47604__$1 = cljs.core.seq(inst_47590);
var state_47649__$1 = (function (){var statearr_47673 = state_47649;
(statearr_47673[(10)] = inst_47604__$1);

return statearr_47673;
})();
if(inst_47604__$1){
var statearr_47674_48664 = state_47649__$1;
(statearr_47674_48664[(1)] = (13));

} else {
var statearr_47675_48665 = state_47649__$1;
(statearr_47675_48665[(1)] = (14));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (9))){
var inst_47626 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47676_48670 = state_47649__$1;
(statearr_47676_48670[(2)] = inst_47626);

(statearr_47676_48670[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (5))){
var inst_47587 = cljs.core.deref(mults);
var inst_47588 = cljs.core.vals(inst_47587);
var inst_47589 = cljs.core.seq(inst_47588);
var inst_47590 = inst_47589;
var inst_47591 = null;
var inst_47592 = (0);
var inst_47593 = (0);
var state_47649__$1 = (function (){var statearr_47677 = state_47649;
(statearr_47677[(13)] = inst_47590);

(statearr_47677[(14)] = inst_47591);

(statearr_47677[(15)] = inst_47592);

(statearr_47677[(16)] = inst_47593);

return statearr_47677;
})();
var statearr_47678_48671 = state_47649__$1;
(statearr_47678_48671[(2)] = null);

(statearr_47678_48671[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (14))){
var state_47649__$1 = state_47649;
var statearr_47682_48672 = state_47649__$1;
(statearr_47682_48672[(2)] = null);

(statearr_47682_48672[(1)] = (15));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (16))){
var inst_47604 = (state_47649[(10)]);
var inst_47608 = cljs.core.chunk_first(inst_47604);
var inst_47609 = cljs.core.chunk_rest(inst_47604);
var inst_47610 = cljs.core.count(inst_47608);
var inst_47590 = inst_47609;
var inst_47591 = inst_47608;
var inst_47592 = inst_47610;
var inst_47593 = (0);
var state_47649__$1 = (function (){var statearr_47683 = state_47649;
(statearr_47683[(13)] = inst_47590);

(statearr_47683[(14)] = inst_47591);

(statearr_47683[(15)] = inst_47592);

(statearr_47683[(16)] = inst_47593);

return statearr_47683;
})();
var statearr_47684_48673 = state_47649__$1;
(statearr_47684_48673[(2)] = null);

(statearr_47684_48673[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (10))){
var inst_47591 = (state_47649[(14)]);
var inst_47593 = (state_47649[(16)]);
var inst_47590 = (state_47649[(13)]);
var inst_47592 = (state_47649[(15)]);
var inst_47598 = cljs.core._nth(inst_47591,inst_47593);
var inst_47599 = cljs.core.async.muxch_STAR_(inst_47598);
var inst_47600 = cljs.core.async.close_BANG_(inst_47599);
var inst_47601 = (inst_47593 + (1));
var tmp47679 = inst_47592;
var tmp47680 = inst_47591;
var tmp47681 = inst_47590;
var inst_47590__$1 = tmp47681;
var inst_47591__$1 = tmp47680;
var inst_47592__$1 = tmp47679;
var inst_47593__$1 = inst_47601;
var state_47649__$1 = (function (){var statearr_47685 = state_47649;
(statearr_47685[(17)] = inst_47600);

(statearr_47685[(13)] = inst_47590__$1);

(statearr_47685[(14)] = inst_47591__$1);

(statearr_47685[(15)] = inst_47592__$1);

(statearr_47685[(16)] = inst_47593__$1);

return statearr_47685;
})();
var statearr_47686_48679 = state_47649__$1;
(statearr_47686_48679[(2)] = null);

(statearr_47686_48679[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (18))){
var inst_47619 = (state_47649[(2)]);
var state_47649__$1 = state_47649;
var statearr_47687_48680 = state_47649__$1;
(statearr_47687_48680[(2)] = inst_47619);

(statearr_47687_48680[(1)] = (15));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47650 === (8))){
var inst_47593 = (state_47649[(16)]);
var inst_47592 = (state_47649[(15)]);
var inst_47595 = (inst_47593 < inst_47592);
var inst_47596 = inst_47595;
var state_47649__$1 = state_47649;
if(cljs.core.truth_(inst_47596)){
var statearr_47688_48681 = state_47649__$1;
(statearr_47688_48681[(1)] = (10));

} else {
var statearr_47689_48682 = state_47649__$1;
(statearr_47689_48682[(1)] = (11));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47690 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_47690[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47690[(1)] = (1));

return statearr_47690;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47649){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47649);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47691){var ex__46653__auto__ = e47691;
var statearr_47692_48684 = state_47649;
(statearr_47692_48684[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47649[(4)]))){
var statearr_47693_48685 = state_47649;
(statearr_47693_48685[(1)] = cljs.core.first((state_47649[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48686 = state_47649;
state_47649 = G__48686;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47649){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47649);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47694 = f__46686__auto__();
(statearr_47694[(6)] = c__46685__auto___48643);

return statearr_47694;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return p;
}));

(cljs.core.async.pub.cljs$lang$maxFixedArity = 3);

/**
 * Subscribes a channel to a topic of a pub.
 * 
 *   By default the channel will be closed when the source closes,
 *   but can be determined by the close? parameter.
 */
cljs.core.async.sub = (function cljs$core$async$sub(var_args){
var G__47696 = arguments.length;
switch (G__47696) {
case 3:
return cljs.core.async.sub.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
case 4:
return cljs.core.async.sub.cljs$core$IFn$_invoke$arity$4((arguments[(0)]),(arguments[(1)]),(arguments[(2)]),(arguments[(3)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.sub.cljs$core$IFn$_invoke$arity$3 = (function (p,topic,ch){
return cljs.core.async.sub.cljs$core$IFn$_invoke$arity$4(p,topic,ch,true);
}));

(cljs.core.async.sub.cljs$core$IFn$_invoke$arity$4 = (function (p,topic,ch,close_QMARK_){
return cljs.core.async.sub_STAR_(p,topic,ch,close_QMARK_);
}));

(cljs.core.async.sub.cljs$lang$maxFixedArity = 4);

/**
 * Unsubscribes a channel from a topic of a pub
 */
cljs.core.async.unsub = (function cljs$core$async$unsub(p,topic,ch){
return cljs.core.async.unsub_STAR_(p,topic,ch);
});
/**
 * Unsubscribes all channels from a pub, or a topic of a pub
 */
cljs.core.async.unsub_all = (function cljs$core$async$unsub_all(var_args){
var G__47698 = arguments.length;
switch (G__47698) {
case 1:
return cljs.core.async.unsub_all.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.unsub_all.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.unsub_all.cljs$core$IFn$_invoke$arity$1 = (function (p){
return cljs.core.async.unsub_all_STAR_(p);
}));

(cljs.core.async.unsub_all.cljs$core$IFn$_invoke$arity$2 = (function (p,topic){
return cljs.core.async.unsub_all_STAR_(p,topic);
}));

(cljs.core.async.unsub_all.cljs$lang$maxFixedArity = 2);

/**
 * Takes a function and a collection of source channels, and returns a
 *   channel which contains the values produced by applying f to the set
 *   of first items taken from each source channel, followed by applying
 *   f to the set of second items from each channel, until any one of the
 *   channels is closed, at which point the output channel will be
 *   closed. The returned channel will be unbuffered by default, or a
 *   buf-or-n can be supplied
 */
cljs.core.async.map = (function cljs$core$async$map(var_args){
var G__47700 = arguments.length;
switch (G__47700) {
case 2:
return cljs.core.async.map.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.map.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.map.cljs$core$IFn$_invoke$arity$2 = (function (f,chs){
return cljs.core.async.map.cljs$core$IFn$_invoke$arity$3(f,chs,null);
}));

(cljs.core.async.map.cljs$core$IFn$_invoke$arity$3 = (function (f,chs,buf_or_n){
var chs__$1 = cljs.core.vec(chs);
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var cnt = cljs.core.count(chs__$1);
var rets = cljs.core.object_array.cljs$core$IFn$_invoke$arity$1(cnt);
var dchan = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
var dctr = cljs.core.atom.cljs$core$IFn$_invoke$arity$1(null);
var done = cljs.core.mapv.cljs$core$IFn$_invoke$arity$2((function (i){
return (function (ret){
(rets[i] = ret);

if((cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(dctr,cljs.core.dec) === (0))){
return cljs.core.async.put_BANG_.cljs$core$IFn$_invoke$arity$2(dchan,rets.slice((0)));
} else {
return null;
}
});
}),cljs.core.range.cljs$core$IFn$_invoke$arity$1(cnt));
if((cnt === (0))){
cljs.core.async.close_BANG_(out);
} else {
var c__46685__auto___48694 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47743){
var state_val_47744 = (state_47743[(1)]);
if((state_val_47744 === (7))){
var state_47743__$1 = state_47743;
var statearr_47745_48695 = state_47743__$1;
(statearr_47745_48695[(2)] = null);

(statearr_47745_48695[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (1))){
var state_47743__$1 = state_47743;
var statearr_47746_48696 = state_47743__$1;
(statearr_47746_48696[(2)] = null);

(statearr_47746_48696[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (4))){
var inst_47704 = (state_47743[(7)]);
var inst_47703 = (state_47743[(8)]);
var inst_47706 = (inst_47704 < inst_47703);
var state_47743__$1 = state_47743;
if(cljs.core.truth_(inst_47706)){
var statearr_47747_48697 = state_47743__$1;
(statearr_47747_48697[(1)] = (6));

} else {
var statearr_47748_48698 = state_47743__$1;
(statearr_47748_48698[(1)] = (7));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (15))){
var inst_47729 = (state_47743[(9)]);
var inst_47734 = cljs.core.apply.cljs$core$IFn$_invoke$arity$2(f,inst_47729);
var state_47743__$1 = state_47743;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47743__$1,(17),out,inst_47734);
} else {
if((state_val_47744 === (13))){
var inst_47729 = (state_47743[(9)]);
var inst_47729__$1 = (state_47743[(2)]);
var inst_47730 = cljs.core.some(cljs.core.nil_QMARK_,inst_47729__$1);
var state_47743__$1 = (function (){var statearr_47749 = state_47743;
(statearr_47749[(9)] = inst_47729__$1);

return statearr_47749;
})();
if(cljs.core.truth_(inst_47730)){
var statearr_47750_48699 = state_47743__$1;
(statearr_47750_48699[(1)] = (14));

} else {
var statearr_47751_48700 = state_47743__$1;
(statearr_47751_48700[(1)] = (15));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (6))){
var state_47743__$1 = state_47743;
var statearr_47752_48701 = state_47743__$1;
(statearr_47752_48701[(2)] = null);

(statearr_47752_48701[(1)] = (9));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (17))){
var inst_47736 = (state_47743[(2)]);
var state_47743__$1 = (function (){var statearr_47754 = state_47743;
(statearr_47754[(10)] = inst_47736);

return statearr_47754;
})();
var statearr_47755_48702 = state_47743__$1;
(statearr_47755_48702[(2)] = null);

(statearr_47755_48702[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (3))){
var inst_47741 = (state_47743[(2)]);
var state_47743__$1 = state_47743;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47743__$1,inst_47741);
} else {
if((state_val_47744 === (12))){
var _ = (function (){var statearr_47756 = state_47743;
(statearr_47756[(4)] = cljs.core.rest((state_47743[(4)])));

return statearr_47756;
})();
var state_47743__$1 = state_47743;
var ex47753 = (state_47743__$1[(2)]);
var statearr_47757_48703 = state_47743__$1;
(statearr_47757_48703[(5)] = ex47753);


if((ex47753 instanceof Object)){
var statearr_47758_48704 = state_47743__$1;
(statearr_47758_48704[(1)] = (11));

(statearr_47758_48704[(5)] = null);

} else {
throw ex47753;

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (2))){
var inst_47702 = cljs.core.reset_BANG_(dctr,cnt);
var inst_47703 = cnt;
var inst_47704 = (0);
var state_47743__$1 = (function (){var statearr_47759 = state_47743;
(statearr_47759[(11)] = inst_47702);

(statearr_47759[(8)] = inst_47703);

(statearr_47759[(7)] = inst_47704);

return statearr_47759;
})();
var statearr_47760_48705 = state_47743__$1;
(statearr_47760_48705[(2)] = null);

(statearr_47760_48705[(1)] = (4));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (11))){
var inst_47708 = (state_47743[(2)]);
var inst_47709 = cljs.core.swap_BANG_.cljs$core$IFn$_invoke$arity$2(dctr,cljs.core.dec);
var state_47743__$1 = (function (){var statearr_47761 = state_47743;
(statearr_47761[(12)] = inst_47708);

return statearr_47761;
})();
var statearr_47762_48709 = state_47743__$1;
(statearr_47762_48709[(2)] = inst_47709);

(statearr_47762_48709[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (9))){
var inst_47704 = (state_47743[(7)]);
var _ = (function (){var statearr_47763 = state_47743;
(statearr_47763[(4)] = cljs.core.cons((12),(state_47743[(4)])));

return statearr_47763;
})();
var inst_47715 = (chs__$1.cljs$core$IFn$_invoke$arity$1 ? chs__$1.cljs$core$IFn$_invoke$arity$1(inst_47704) : chs__$1.call(null,inst_47704));
var inst_47716 = (done.cljs$core$IFn$_invoke$arity$1 ? done.cljs$core$IFn$_invoke$arity$1(inst_47704) : done.call(null,inst_47704));
var inst_47717 = cljs.core.async.take_BANG_.cljs$core$IFn$_invoke$arity$2(inst_47715,inst_47716);
var ___$1 = (function (){var statearr_47764 = state_47743;
(statearr_47764[(4)] = cljs.core.rest((state_47743[(4)])));

return statearr_47764;
})();
var state_47743__$1 = state_47743;
var statearr_47765_48710 = state_47743__$1;
(statearr_47765_48710[(2)] = inst_47717);

(statearr_47765_48710[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (5))){
var inst_47727 = (state_47743[(2)]);
var state_47743__$1 = (function (){var statearr_47766 = state_47743;
(statearr_47766[(13)] = inst_47727);

return statearr_47766;
})();
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47743__$1,(13),dchan);
} else {
if((state_val_47744 === (14))){
var inst_47732 = cljs.core.async.close_BANG_(out);
var state_47743__$1 = state_47743;
var statearr_47767_48711 = state_47743__$1;
(statearr_47767_48711[(2)] = inst_47732);

(statearr_47767_48711[(1)] = (16));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (16))){
var inst_47739 = (state_47743[(2)]);
var state_47743__$1 = state_47743;
var statearr_47768_48712 = state_47743__$1;
(statearr_47768_48712[(2)] = inst_47739);

(statearr_47768_48712[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (10))){
var inst_47704 = (state_47743[(7)]);
var inst_47720 = (state_47743[(2)]);
var inst_47721 = (inst_47704 + (1));
var inst_47704__$1 = inst_47721;
var state_47743__$1 = (function (){var statearr_47769 = state_47743;
(statearr_47769[(14)] = inst_47720);

(statearr_47769[(7)] = inst_47704__$1);

return statearr_47769;
})();
var statearr_47770_48713 = state_47743__$1;
(statearr_47770_48713[(2)] = null);

(statearr_47770_48713[(1)] = (4));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47744 === (8))){
var inst_47725 = (state_47743[(2)]);
var state_47743__$1 = state_47743;
var statearr_47771_48714 = state_47743__$1;
(statearr_47771_48714[(2)] = inst_47725);

(statearr_47771_48714[(1)] = (5));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47772 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_47772[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47772[(1)] = (1));

return statearr_47772;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47743){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47743);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47773){var ex__46653__auto__ = e47773;
var statearr_47774_48716 = state_47743;
(statearr_47774_48716[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47743[(4)]))){
var statearr_47775_48717 = state_47743;
(statearr_47775_48717[(1)] = cljs.core.first((state_47743[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48718 = state_47743;
state_47743 = G__48718;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47743){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47743);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47776 = f__46686__auto__();
(statearr_47776[(6)] = c__46685__auto___48694);

return statearr_47776;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

}

return out;
}));

(cljs.core.async.map.cljs$lang$maxFixedArity = 3);

/**
 * Takes a collection of source channels and returns a channel which
 *   contains all values taken from them. The returned channel will be
 *   unbuffered by default, or a buf-or-n can be supplied. The channel
 *   will close after all the source channels have closed.
 */
cljs.core.async.merge = (function cljs$core$async$merge(var_args){
var G__47779 = arguments.length;
switch (G__47779) {
case 1:
return cljs.core.async.merge.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.merge.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.merge.cljs$core$IFn$_invoke$arity$1 = (function (chs){
return cljs.core.async.merge.cljs$core$IFn$_invoke$arity$2(chs,null);
}));

(cljs.core.async.merge.cljs$core$IFn$_invoke$arity$2 = (function (chs,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48720 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47811){
var state_val_47812 = (state_47811[(1)]);
if((state_val_47812 === (7))){
var inst_47790 = (state_47811[(7)]);
var inst_47791 = (state_47811[(8)]);
var inst_47790__$1 = (state_47811[(2)]);
var inst_47791__$1 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47790__$1,(0),null);
var inst_47792 = cljs.core.nth.cljs$core$IFn$_invoke$arity$3(inst_47790__$1,(1),null);
var inst_47793 = (inst_47791__$1 == null);
var state_47811__$1 = (function (){var statearr_47813 = state_47811;
(statearr_47813[(7)] = inst_47790__$1);

(statearr_47813[(8)] = inst_47791__$1);

(statearr_47813[(9)] = inst_47792);

return statearr_47813;
})();
if(cljs.core.truth_(inst_47793)){
var statearr_47814_48721 = state_47811__$1;
(statearr_47814_48721[(1)] = (8));

} else {
var statearr_47815_48722 = state_47811__$1;
(statearr_47815_48722[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (1))){
var inst_47780 = cljs.core.vec(chs);
var inst_47781 = inst_47780;
var state_47811__$1 = (function (){var statearr_47816 = state_47811;
(statearr_47816[(10)] = inst_47781);

return statearr_47816;
})();
var statearr_47817_48727 = state_47811__$1;
(statearr_47817_48727[(2)] = null);

(statearr_47817_48727[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (4))){
var inst_47781 = (state_47811[(10)]);
var state_47811__$1 = state_47811;
return cljs.core.async.ioc_alts_BANG_(state_47811__$1,(7),inst_47781);
} else {
if((state_val_47812 === (6))){
var inst_47807 = (state_47811[(2)]);
var state_47811__$1 = state_47811;
var statearr_47818_48729 = state_47811__$1;
(statearr_47818_48729[(2)] = inst_47807);

(statearr_47818_48729[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (3))){
var inst_47809 = (state_47811[(2)]);
var state_47811__$1 = state_47811;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47811__$1,inst_47809);
} else {
if((state_val_47812 === (2))){
var inst_47781 = (state_47811[(10)]);
var inst_47783 = cljs.core.count(inst_47781);
var inst_47784 = (inst_47783 > (0));
var state_47811__$1 = state_47811;
if(cljs.core.truth_(inst_47784)){
var statearr_47820_48730 = state_47811__$1;
(statearr_47820_48730[(1)] = (4));

} else {
var statearr_47821_48731 = state_47811__$1;
(statearr_47821_48731[(1)] = (5));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (11))){
var inst_47781 = (state_47811[(10)]);
var inst_47800 = (state_47811[(2)]);
var tmp47819 = inst_47781;
var inst_47781__$1 = tmp47819;
var state_47811__$1 = (function (){var statearr_47822 = state_47811;
(statearr_47822[(11)] = inst_47800);

(statearr_47822[(10)] = inst_47781__$1);

return statearr_47822;
})();
var statearr_47823_48732 = state_47811__$1;
(statearr_47823_48732[(2)] = null);

(statearr_47823_48732[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (9))){
var inst_47791 = (state_47811[(8)]);
var state_47811__$1 = state_47811;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47811__$1,(11),out,inst_47791);
} else {
if((state_val_47812 === (5))){
var inst_47805 = cljs.core.async.close_BANG_(out);
var state_47811__$1 = state_47811;
var statearr_47824_48734 = state_47811__$1;
(statearr_47824_48734[(2)] = inst_47805);

(statearr_47824_48734[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (10))){
var inst_47803 = (state_47811[(2)]);
var state_47811__$1 = state_47811;
var statearr_47825_48735 = state_47811__$1;
(statearr_47825_48735[(2)] = inst_47803);

(statearr_47825_48735[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47812 === (8))){
var inst_47781 = (state_47811[(10)]);
var inst_47790 = (state_47811[(7)]);
var inst_47791 = (state_47811[(8)]);
var inst_47792 = (state_47811[(9)]);
var inst_47795 = (function (){var cs = inst_47781;
var vec__47786 = inst_47790;
var v = inst_47791;
var c = inst_47792;
return (function (p1__47777_SHARP_){
return cljs.core.not_EQ_.cljs$core$IFn$_invoke$arity$2(c,p1__47777_SHARP_);
});
})();
var inst_47796 = cljs.core.filterv(inst_47795,inst_47781);
var inst_47781__$1 = inst_47796;
var state_47811__$1 = (function (){var statearr_47826 = state_47811;
(statearr_47826[(10)] = inst_47781__$1);

return statearr_47826;
})();
var statearr_47827_48740 = state_47811__$1;
(statearr_47827_48740[(2)] = null);

(statearr_47827_48740[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47828 = [null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_47828[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47828[(1)] = (1));

return statearr_47828;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47811){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47811);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47829){var ex__46653__auto__ = e47829;
var statearr_47830_48741 = state_47811;
(statearr_47830_48741[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47811[(4)]))){
var statearr_47831_48742 = state_47811;
(statearr_47831_48742[(1)] = cljs.core.first((state_47811[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48743 = state_47811;
state_47811 = G__48743;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47811){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47811);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47832 = f__46686__auto__();
(statearr_47832[(6)] = c__46685__auto___48720);

return statearr_47832;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.merge.cljs$lang$maxFixedArity = 2);

/**
 * Returns a channel containing the single (collection) result of the
 *   items taken from the channel conjoined to the supplied
 *   collection. ch must close before into produces a result.
 */
cljs.core.async.into = (function cljs$core$async$into(coll,ch){
return cljs.core.async.reduce(cljs.core.conj,coll,ch);
});
/**
 * Returns a channel that will return, at most, n items from ch. After n items
 * have been returned, or ch has been closed, the return chanel will close.
 * 
 *   The output channel is unbuffered by default, unless buf-or-n is given.
 */
cljs.core.async.take = (function cljs$core$async$take(var_args){
var G__47834 = arguments.length;
switch (G__47834) {
case 2:
return cljs.core.async.take.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.take.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.take.cljs$core$IFn$_invoke$arity$2 = (function (n,ch){
return cljs.core.async.take.cljs$core$IFn$_invoke$arity$3(n,ch,null);
}));

(cljs.core.async.take.cljs$core$IFn$_invoke$arity$3 = (function (n,ch,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48745 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47858){
var state_val_47859 = (state_47858[(1)]);
if((state_val_47859 === (7))){
var inst_47840 = (state_47858[(7)]);
var inst_47840__$1 = (state_47858[(2)]);
var inst_47841 = (inst_47840__$1 == null);
var inst_47842 = cljs.core.not(inst_47841);
var state_47858__$1 = (function (){var statearr_47860 = state_47858;
(statearr_47860[(7)] = inst_47840__$1);

return statearr_47860;
})();
if(inst_47842){
var statearr_47861_48746 = state_47858__$1;
(statearr_47861_48746[(1)] = (8));

} else {
var statearr_47862_48747 = state_47858__$1;
(statearr_47862_48747[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (1))){
var inst_47835 = (0);
var state_47858__$1 = (function (){var statearr_47863 = state_47858;
(statearr_47863[(8)] = inst_47835);

return statearr_47863;
})();
var statearr_47864_48748 = state_47858__$1;
(statearr_47864_48748[(2)] = null);

(statearr_47864_48748[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (4))){
var state_47858__$1 = state_47858;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47858__$1,(7),ch);
} else {
if((state_val_47859 === (6))){
var inst_47853 = (state_47858[(2)]);
var state_47858__$1 = state_47858;
var statearr_47865_48749 = state_47858__$1;
(statearr_47865_48749[(2)] = inst_47853);

(statearr_47865_48749[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (3))){
var inst_47855 = (state_47858[(2)]);
var inst_47856 = cljs.core.async.close_BANG_(out);
var state_47858__$1 = (function (){var statearr_47866 = state_47858;
(statearr_47866[(9)] = inst_47855);

return statearr_47866;
})();
return cljs.core.async.impl.ioc_helpers.return_chan(state_47858__$1,inst_47856);
} else {
if((state_val_47859 === (2))){
var inst_47835 = (state_47858[(8)]);
var inst_47837 = (inst_47835 < n);
var state_47858__$1 = state_47858;
if(cljs.core.truth_(inst_47837)){
var statearr_47867_48750 = state_47858__$1;
(statearr_47867_48750[(1)] = (4));

} else {
var statearr_47868_48751 = state_47858__$1;
(statearr_47868_48751[(1)] = (5));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (11))){
var inst_47835 = (state_47858[(8)]);
var inst_47845 = (state_47858[(2)]);
var inst_47846 = (inst_47835 + (1));
var inst_47835__$1 = inst_47846;
var state_47858__$1 = (function (){var statearr_47869 = state_47858;
(statearr_47869[(10)] = inst_47845);

(statearr_47869[(8)] = inst_47835__$1);

return statearr_47869;
})();
var statearr_47870_48755 = state_47858__$1;
(statearr_47870_48755[(2)] = null);

(statearr_47870_48755[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (9))){
var state_47858__$1 = state_47858;
var statearr_47871_48756 = state_47858__$1;
(statearr_47871_48756[(2)] = null);

(statearr_47871_48756[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (5))){
var state_47858__$1 = state_47858;
var statearr_47872_48757 = state_47858__$1;
(statearr_47872_48757[(2)] = null);

(statearr_47872_48757[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (10))){
var inst_47850 = (state_47858[(2)]);
var state_47858__$1 = state_47858;
var statearr_47873_48758 = state_47858__$1;
(statearr_47873_48758[(2)] = inst_47850);

(statearr_47873_48758[(1)] = (6));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47859 === (8))){
var inst_47840 = (state_47858[(7)]);
var state_47858__$1 = state_47858;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47858__$1,(11),out,inst_47840);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47874 = [null,null,null,null,null,null,null,null,null,null,null];
(statearr_47874[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47874[(1)] = (1));

return statearr_47874;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47858){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47858);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47875){var ex__46653__auto__ = e47875;
var statearr_47876_48759 = state_47858;
(statearr_47876_48759[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47858[(4)]))){
var statearr_47877_48760 = state_47858;
(statearr_47877_48760[(1)] = cljs.core.first((state_47858[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48761 = state_47858;
state_47858 = G__48761;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47858){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47858);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47878 = f__46686__auto__();
(statearr_47878[(6)] = c__46685__auto___48745);

return statearr_47878;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.take.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.map_LT_ = (function cljs$core$async$map_LT_(f,ch){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47880 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Channel}
 * @implements {cljs.core.async.impl.protocols.WritePort}
 * @implements {cljs.core.async.impl.protocols.ReadPort}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47880 = (function (f,ch,meta47881){
this.f = f;
this.ch = ch;
this.meta47881 = meta47881;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47882,meta47881__$1){
var self__ = this;
var _47882__$1 = this;
return (new cljs.core.async.t_cljs$core$async47880(self__.f,self__.ch,meta47881__$1));
}));

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47882){
var self__ = this;
var _47882__$1 = this;
return self__.meta47881;
}));

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$Channel$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$Channel$close_BANG_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.close_BANG_(self__.ch);
}));

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$Channel$closed_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.closed_QMARK_(self__.ch);
}));

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$ReadPort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$ReadPort$take_BANG_$arity$2 = (function (_,fn1){
var self__ = this;
var ___$1 = this;
var ret = cljs.core.async.impl.protocols.take_BANG_(self__.ch,(function (){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47883 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Handler}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47883 = (function (f,ch,meta47881,_,fn1,meta47884){
this.f = f;
this.ch = ch;
this.meta47881 = meta47881;
this._ = _;
this.fn1 = fn1;
this.meta47884 = meta47884;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47885,meta47884__$1){
var self__ = this;
var _47885__$1 = this;
return (new cljs.core.async.t_cljs$core$async47883(self__.f,self__.ch,self__.meta47881,self__._,self__.fn1,meta47884__$1));
}));

(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47885){
var self__ = this;
var _47885__$1 = this;
return self__.meta47884;
}));

(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$async$impl$protocols$Handler$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$async$impl$protocols$Handler$active_QMARK_$arity$1 = (function (___$1){
var self__ = this;
var ___$2 = this;
return cljs.core.async.impl.protocols.active_QMARK_(self__.fn1);
}));

(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$async$impl$protocols$Handler$blockable_QMARK_$arity$1 = (function (___$1){
var self__ = this;
var ___$2 = this;
return true;
}));

(cljs.core.async.t_cljs$core$async47883.prototype.cljs$core$async$impl$protocols$Handler$commit$arity$1 = (function (___$1){
var self__ = this;
var ___$2 = this;
var f1 = cljs.core.async.impl.protocols.commit(self__.fn1);
return (function (p1__47879_SHARP_){
var G__47886 = (((p1__47879_SHARP_ == null))?null:(self__.f.cljs$core$IFn$_invoke$arity$1 ? self__.f.cljs$core$IFn$_invoke$arity$1(p1__47879_SHARP_) : self__.f.call(null,p1__47879_SHARP_)));
return (f1.cljs$core$IFn$_invoke$arity$1 ? f1.cljs$core$IFn$_invoke$arity$1(G__47886) : f1.call(null,G__47886));
});
}));

(cljs.core.async.t_cljs$core$async47883.getBasis = (function (){
return new cljs.core.PersistentVector(null, 6, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"f","f",43394975,null),new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"meta47881","meta47881",22716239,null),cljs.core.with_meta(new cljs.core.Symbol(null,"_","_",-1201019570,null),new cljs.core.PersistentArrayMap(null, 1, [new cljs.core.Keyword(null,"tag","tag",-1290361223),new cljs.core.Symbol("cljs.core.async","t_cljs$core$async47880","cljs.core.async/t_cljs$core$async47880",205965431,null)], null)),new cljs.core.Symbol(null,"fn1","fn1",895834444,null),new cljs.core.Symbol(null,"meta47884","meta47884",-1633030737,null)], null);
}));

(cljs.core.async.t_cljs$core$async47883.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47883.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47883");

(cljs.core.async.t_cljs$core$async47883.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47883");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47883.
 */
cljs.core.async.__GT_t_cljs$core$async47883 = (function cljs$core$async$map_LT__$___GT_t_cljs$core$async47883(f__$1,ch__$1,meta47881__$1,___$2,fn1__$1,meta47884){
return (new cljs.core.async.t_cljs$core$async47883(f__$1,ch__$1,meta47881__$1,___$2,fn1__$1,meta47884));
});

}

return (new cljs.core.async.t_cljs$core$async47883(self__.f,self__.ch,self__.meta47881,___$1,fn1,cljs.core.PersistentArrayMap.EMPTY));
})()
);
if(cljs.core.truth_((function (){var and__4149__auto__ = ret;
if(cljs.core.truth_(and__4149__auto__)){
return (!((cljs.core.deref(ret) == null)));
} else {
return and__4149__auto__;
}
})())){
return cljs.core.async.impl.channels.box((function (){var G__47887 = cljs.core.deref(ret);
return (self__.f.cljs$core$IFn$_invoke$arity$1 ? self__.f.cljs$core$IFn$_invoke$arity$1(G__47887) : self__.f.call(null,G__47887));
})());
} else {
return ret;
}
}));

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$WritePort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47880.prototype.cljs$core$async$impl$protocols$WritePort$put_BANG_$arity$3 = (function (_,val,fn1){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.put_BANG_(self__.ch,val,fn1);
}));

(cljs.core.async.t_cljs$core$async47880.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"f","f",43394975,null),new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"meta47881","meta47881",22716239,null)], null);
}));

(cljs.core.async.t_cljs$core$async47880.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47880.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47880");

(cljs.core.async.t_cljs$core$async47880.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47880");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47880.
 */
cljs.core.async.__GT_t_cljs$core$async47880 = (function cljs$core$async$map_LT__$___GT_t_cljs$core$async47880(f__$1,ch__$1,meta47881){
return (new cljs.core.async.t_cljs$core$async47880(f__$1,ch__$1,meta47881));
});

}

return (new cljs.core.async.t_cljs$core$async47880(f,ch,cljs.core.PersistentArrayMap.EMPTY));
});
/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.map_GT_ = (function cljs$core$async$map_GT_(f,ch){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47888 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Channel}
 * @implements {cljs.core.async.impl.protocols.WritePort}
 * @implements {cljs.core.async.impl.protocols.ReadPort}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47888 = (function (f,ch,meta47889){
this.f = f;
this.ch = ch;
this.meta47889 = meta47889;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47890,meta47889__$1){
var self__ = this;
var _47890__$1 = this;
return (new cljs.core.async.t_cljs$core$async47888(self__.f,self__.ch,meta47889__$1));
}));

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47890){
var self__ = this;
var _47890__$1 = this;
return self__.meta47889;
}));

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$Channel$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$Channel$close_BANG_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.close_BANG_(self__.ch);
}));

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$ReadPort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$ReadPort$take_BANG_$arity$2 = (function (_,fn1){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.take_BANG_(self__.ch,fn1);
}));

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$WritePort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47888.prototype.cljs$core$async$impl$protocols$WritePort$put_BANG_$arity$3 = (function (_,val,fn1){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.put_BANG_(self__.ch,(self__.f.cljs$core$IFn$_invoke$arity$1 ? self__.f.cljs$core$IFn$_invoke$arity$1(val) : self__.f.call(null,val)),fn1);
}));

(cljs.core.async.t_cljs$core$async47888.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"f","f",43394975,null),new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"meta47889","meta47889",-1139468283,null)], null);
}));

(cljs.core.async.t_cljs$core$async47888.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47888.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47888");

(cljs.core.async.t_cljs$core$async47888.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47888");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47888.
 */
cljs.core.async.__GT_t_cljs$core$async47888 = (function cljs$core$async$map_GT__$___GT_t_cljs$core$async47888(f__$1,ch__$1,meta47889){
return (new cljs.core.async.t_cljs$core$async47888(f__$1,ch__$1,meta47889));
});

}

return (new cljs.core.async.t_cljs$core$async47888(f,ch,cljs.core.PersistentArrayMap.EMPTY));
});
/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.filter_GT_ = (function cljs$core$async$filter_GT_(p,ch){
if((typeof cljs !== 'undefined') && (typeof cljs.core !== 'undefined') && (typeof cljs.core.async !== 'undefined') && (typeof cljs.core.async.t_cljs$core$async47891 !== 'undefined')){
} else {

/**
* @constructor
 * @implements {cljs.core.async.impl.protocols.Channel}
 * @implements {cljs.core.async.impl.protocols.WritePort}
 * @implements {cljs.core.async.impl.protocols.ReadPort}
 * @implements {cljs.core.IMeta}
 * @implements {cljs.core.IWithMeta}
*/
cljs.core.async.t_cljs$core$async47891 = (function (p,ch,meta47892){
this.p = p;
this.ch = ch;
this.meta47892 = meta47892;
this.cljs$lang$protocol_mask$partition0$ = 393216;
this.cljs$lang$protocol_mask$partition1$ = 0;
});
(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$IWithMeta$_with_meta$arity$2 = (function (_47893,meta47892__$1){
var self__ = this;
var _47893__$1 = this;
return (new cljs.core.async.t_cljs$core$async47891(self__.p,self__.ch,meta47892__$1));
}));

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$IMeta$_meta$arity$1 = (function (_47893){
var self__ = this;
var _47893__$1 = this;
return self__.meta47892;
}));

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$Channel$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$Channel$close_BANG_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.close_BANG_(self__.ch);
}));

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$Channel$closed_QMARK_$arity$1 = (function (_){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.closed_QMARK_(self__.ch);
}));

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$ReadPort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$ReadPort$take_BANG_$arity$2 = (function (_,fn1){
var self__ = this;
var ___$1 = this;
return cljs.core.async.impl.protocols.take_BANG_(self__.ch,fn1);
}));

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$WritePort$ = cljs.core.PROTOCOL_SENTINEL);

(cljs.core.async.t_cljs$core$async47891.prototype.cljs$core$async$impl$protocols$WritePort$put_BANG_$arity$3 = (function (_,val,fn1){
var self__ = this;
var ___$1 = this;
if(cljs.core.truth_((self__.p.cljs$core$IFn$_invoke$arity$1 ? self__.p.cljs$core$IFn$_invoke$arity$1(val) : self__.p.call(null,val)))){
return cljs.core.async.impl.protocols.put_BANG_(self__.ch,val,fn1);
} else {
return cljs.core.async.impl.channels.box(cljs.core.not(cljs.core.async.impl.protocols.closed_QMARK_(self__.ch)));
}
}));

(cljs.core.async.t_cljs$core$async47891.getBasis = (function (){
return new cljs.core.PersistentVector(null, 3, 5, cljs.core.PersistentVector.EMPTY_NODE, [new cljs.core.Symbol(null,"p","p",1791580836,null),new cljs.core.Symbol(null,"ch","ch",1085813622,null),new cljs.core.Symbol(null,"meta47892","meta47892",-29507153,null)], null);
}));

(cljs.core.async.t_cljs$core$async47891.cljs$lang$type = true);

(cljs.core.async.t_cljs$core$async47891.cljs$lang$ctorStr = "cljs.core.async/t_cljs$core$async47891");

(cljs.core.async.t_cljs$core$async47891.cljs$lang$ctorPrWriter = (function (this__4404__auto__,writer__4405__auto__,opt__4406__auto__){
return cljs.core._write(writer__4405__auto__,"cljs.core.async/t_cljs$core$async47891");
}));

/**
 * Positional factory function for cljs.core.async/t_cljs$core$async47891.
 */
cljs.core.async.__GT_t_cljs$core$async47891 = (function cljs$core$async$filter_GT__$___GT_t_cljs$core$async47891(p__$1,ch__$1,meta47892){
return (new cljs.core.async.t_cljs$core$async47891(p__$1,ch__$1,meta47892));
});

}

return (new cljs.core.async.t_cljs$core$async47891(p,ch,cljs.core.PersistentArrayMap.EMPTY));
});
/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.remove_GT_ = (function cljs$core$async$remove_GT_(p,ch){
return cljs.core.async.filter_GT_(cljs.core.complement(p),ch);
});
/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.filter_LT_ = (function cljs$core$async$filter_LT_(var_args){
var G__47895 = arguments.length;
switch (G__47895) {
case 2:
return cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$2 = (function (p,ch){
return cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$3(p,ch,null);
}));

(cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$3 = (function (p,ch,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48774 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47916){
var state_val_47917 = (state_47916[(1)]);
if((state_val_47917 === (7))){
var inst_47912 = (state_47916[(2)]);
var state_47916__$1 = state_47916;
var statearr_47918_48775 = state_47916__$1;
(statearr_47918_48775[(2)] = inst_47912);

(statearr_47918_48775[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (1))){
var state_47916__$1 = state_47916;
var statearr_47919_48776 = state_47916__$1;
(statearr_47919_48776[(2)] = null);

(statearr_47919_48776[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (4))){
var inst_47898 = (state_47916[(7)]);
var inst_47898__$1 = (state_47916[(2)]);
var inst_47899 = (inst_47898__$1 == null);
var state_47916__$1 = (function (){var statearr_47920 = state_47916;
(statearr_47920[(7)] = inst_47898__$1);

return statearr_47920;
})();
if(cljs.core.truth_(inst_47899)){
var statearr_47921_48777 = state_47916__$1;
(statearr_47921_48777[(1)] = (5));

} else {
var statearr_47922_48778 = state_47916__$1;
(statearr_47922_48778[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (6))){
var inst_47898 = (state_47916[(7)]);
var inst_47903 = (p.cljs$core$IFn$_invoke$arity$1 ? p.cljs$core$IFn$_invoke$arity$1(inst_47898) : p.call(null,inst_47898));
var state_47916__$1 = state_47916;
if(cljs.core.truth_(inst_47903)){
var statearr_47923_48779 = state_47916__$1;
(statearr_47923_48779[(1)] = (8));

} else {
var statearr_47924_48780 = state_47916__$1;
(statearr_47924_48780[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (3))){
var inst_47914 = (state_47916[(2)]);
var state_47916__$1 = state_47916;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47916__$1,inst_47914);
} else {
if((state_val_47917 === (2))){
var state_47916__$1 = state_47916;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47916__$1,(4),ch);
} else {
if((state_val_47917 === (11))){
var inst_47906 = (state_47916[(2)]);
var state_47916__$1 = state_47916;
var statearr_47925_48781 = state_47916__$1;
(statearr_47925_48781[(2)] = inst_47906);

(statearr_47925_48781[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (9))){
var state_47916__$1 = state_47916;
var statearr_47926_48782 = state_47916__$1;
(statearr_47926_48782[(2)] = null);

(statearr_47926_48782[(1)] = (10));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (5))){
var inst_47901 = cljs.core.async.close_BANG_(out);
var state_47916__$1 = state_47916;
var statearr_47927_48783 = state_47916__$1;
(statearr_47927_48783[(2)] = inst_47901);

(statearr_47927_48783[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (10))){
var inst_47909 = (state_47916[(2)]);
var state_47916__$1 = (function (){var statearr_47928 = state_47916;
(statearr_47928[(8)] = inst_47909);

return statearr_47928;
})();
var statearr_47929_48784 = state_47916__$1;
(statearr_47929_48784[(2)] = null);

(statearr_47929_48784[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47917 === (8))){
var inst_47898 = (state_47916[(7)]);
var state_47916__$1 = state_47916;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47916__$1,(11),out,inst_47898);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_47930 = [null,null,null,null,null,null,null,null,null];
(statearr_47930[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_47930[(1)] = (1));

return statearr_47930;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_47916){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47916);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e47931){var ex__46653__auto__ = e47931;
var statearr_47932_48785 = state_47916;
(statearr_47932_48785[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47916[(4)]))){
var statearr_47933_48786 = state_47916;
(statearr_47933_48786[(1)] = cljs.core.first((state_47916[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48787 = state_47916;
state_47916 = G__48787;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_47916){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_47916);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_47934 = f__46686__auto__();
(statearr_47934[(6)] = c__46685__auto___48774);

return statearr_47934;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.filter_LT_.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.remove_LT_ = (function cljs$core$async$remove_LT_(var_args){
var G__47936 = arguments.length;
switch (G__47936) {
case 2:
return cljs.core.async.remove_LT_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.remove_LT_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.remove_LT_.cljs$core$IFn$_invoke$arity$2 = (function (p,ch){
return cljs.core.async.remove_LT_.cljs$core$IFn$_invoke$arity$3(p,ch,null);
}));

(cljs.core.async.remove_LT_.cljs$core$IFn$_invoke$arity$3 = (function (p,ch,buf_or_n){
return cljs.core.async.filter_LT_.cljs$core$IFn$_invoke$arity$3(cljs.core.complement(p),ch,buf_or_n);
}));

(cljs.core.async.remove_LT_.cljs$lang$maxFixedArity = 3);

cljs.core.async.mapcat_STAR_ = (function cljs$core$async$mapcat_STAR_(f,in$,out){
var c__46685__auto__ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_47998){
var state_val_47999 = (state_47998[(1)]);
if((state_val_47999 === (7))){
var inst_47994 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
var statearr_48000_48789 = state_47998__$1;
(statearr_48000_48789[(2)] = inst_47994);

(statearr_48000_48789[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (20))){
var inst_47964 = (state_47998[(7)]);
var inst_47975 = (state_47998[(2)]);
var inst_47976 = cljs.core.next(inst_47964);
var inst_47950 = inst_47976;
var inst_47951 = null;
var inst_47952 = (0);
var inst_47953 = (0);
var state_47998__$1 = (function (){var statearr_48001 = state_47998;
(statearr_48001[(8)] = inst_47975);

(statearr_48001[(9)] = inst_47950);

(statearr_48001[(10)] = inst_47951);

(statearr_48001[(11)] = inst_47952);

(statearr_48001[(12)] = inst_47953);

return statearr_48001;
})();
var statearr_48002_48790 = state_47998__$1;
(statearr_48002_48790[(2)] = null);

(statearr_48002_48790[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (1))){
var state_47998__$1 = state_47998;
var statearr_48003_48791 = state_47998__$1;
(statearr_48003_48791[(2)] = null);

(statearr_48003_48791[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (4))){
var inst_47939 = (state_47998[(13)]);
var inst_47939__$1 = (state_47998[(2)]);
var inst_47940 = (inst_47939__$1 == null);
var state_47998__$1 = (function (){var statearr_48004 = state_47998;
(statearr_48004[(13)] = inst_47939__$1);

return statearr_48004;
})();
if(cljs.core.truth_(inst_47940)){
var statearr_48005_48792 = state_47998__$1;
(statearr_48005_48792[(1)] = (5));

} else {
var statearr_48006_48793 = state_47998__$1;
(statearr_48006_48793[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (15))){
var state_47998__$1 = state_47998;
var statearr_48010_48794 = state_47998__$1;
(statearr_48010_48794[(2)] = null);

(statearr_48010_48794[(1)] = (16));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (21))){
var state_47998__$1 = state_47998;
var statearr_48011_48795 = state_47998__$1;
(statearr_48011_48795[(2)] = null);

(statearr_48011_48795[(1)] = (23));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (13))){
var inst_47953 = (state_47998[(12)]);
var inst_47950 = (state_47998[(9)]);
var inst_47951 = (state_47998[(10)]);
var inst_47952 = (state_47998[(11)]);
var inst_47960 = (state_47998[(2)]);
var inst_47961 = (inst_47953 + (1));
var tmp48007 = inst_47951;
var tmp48008 = inst_47952;
var tmp48009 = inst_47950;
var inst_47950__$1 = tmp48009;
var inst_47951__$1 = tmp48007;
var inst_47952__$1 = tmp48008;
var inst_47953__$1 = inst_47961;
var state_47998__$1 = (function (){var statearr_48012 = state_47998;
(statearr_48012[(14)] = inst_47960);

(statearr_48012[(9)] = inst_47950__$1);

(statearr_48012[(10)] = inst_47951__$1);

(statearr_48012[(11)] = inst_47952__$1);

(statearr_48012[(12)] = inst_47953__$1);

return statearr_48012;
})();
var statearr_48013_48796 = state_47998__$1;
(statearr_48013_48796[(2)] = null);

(statearr_48013_48796[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (22))){
var state_47998__$1 = state_47998;
var statearr_48014_48797 = state_47998__$1;
(statearr_48014_48797[(2)] = null);

(statearr_48014_48797[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (6))){
var inst_47939 = (state_47998[(13)]);
var inst_47948 = (f.cljs$core$IFn$_invoke$arity$1 ? f.cljs$core$IFn$_invoke$arity$1(inst_47939) : f.call(null,inst_47939));
var inst_47949 = cljs.core.seq(inst_47948);
var inst_47950 = inst_47949;
var inst_47951 = null;
var inst_47952 = (0);
var inst_47953 = (0);
var state_47998__$1 = (function (){var statearr_48015 = state_47998;
(statearr_48015[(9)] = inst_47950);

(statearr_48015[(10)] = inst_47951);

(statearr_48015[(11)] = inst_47952);

(statearr_48015[(12)] = inst_47953);

return statearr_48015;
})();
var statearr_48016_48801 = state_47998__$1;
(statearr_48016_48801[(2)] = null);

(statearr_48016_48801[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (17))){
var inst_47964 = (state_47998[(7)]);
var inst_47968 = cljs.core.chunk_first(inst_47964);
var inst_47969 = cljs.core.chunk_rest(inst_47964);
var inst_47970 = cljs.core.count(inst_47968);
var inst_47950 = inst_47969;
var inst_47951 = inst_47968;
var inst_47952 = inst_47970;
var inst_47953 = (0);
var state_47998__$1 = (function (){var statearr_48017 = state_47998;
(statearr_48017[(9)] = inst_47950);

(statearr_48017[(10)] = inst_47951);

(statearr_48017[(11)] = inst_47952);

(statearr_48017[(12)] = inst_47953);

return statearr_48017;
})();
var statearr_48018_48809 = state_47998__$1;
(statearr_48018_48809[(2)] = null);

(statearr_48018_48809[(1)] = (8));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (3))){
var inst_47996 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
return cljs.core.async.impl.ioc_helpers.return_chan(state_47998__$1,inst_47996);
} else {
if((state_val_47999 === (12))){
var inst_47984 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
var statearr_48019_48810 = state_47998__$1;
(statearr_48019_48810[(2)] = inst_47984);

(statearr_48019_48810[(1)] = (9));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (2))){
var state_47998__$1 = state_47998;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_47998__$1,(4),in$);
} else {
if((state_val_47999 === (23))){
var inst_47992 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
var statearr_48020_48811 = state_47998__$1;
(statearr_48020_48811[(2)] = inst_47992);

(statearr_48020_48811[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (19))){
var inst_47979 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
var statearr_48021_48812 = state_47998__$1;
(statearr_48021_48812[(2)] = inst_47979);

(statearr_48021_48812[(1)] = (16));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (11))){
var inst_47950 = (state_47998[(9)]);
var inst_47964 = (state_47998[(7)]);
var inst_47964__$1 = cljs.core.seq(inst_47950);
var state_47998__$1 = (function (){var statearr_48022 = state_47998;
(statearr_48022[(7)] = inst_47964__$1);

return statearr_48022;
})();
if(inst_47964__$1){
var statearr_48023_48816 = state_47998__$1;
(statearr_48023_48816[(1)] = (14));

} else {
var statearr_48024_48817 = state_47998__$1;
(statearr_48024_48817[(1)] = (15));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (9))){
var inst_47986 = (state_47998[(2)]);
var inst_47987 = cljs.core.async.impl.protocols.closed_QMARK_(out);
var state_47998__$1 = (function (){var statearr_48025 = state_47998;
(statearr_48025[(15)] = inst_47986);

return statearr_48025;
})();
if(cljs.core.truth_(inst_47987)){
var statearr_48026_48818 = state_47998__$1;
(statearr_48026_48818[(1)] = (21));

} else {
var statearr_48027_48819 = state_47998__$1;
(statearr_48027_48819[(1)] = (22));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (5))){
var inst_47942 = cljs.core.async.close_BANG_(out);
var state_47998__$1 = state_47998;
var statearr_48028_48823 = state_47998__$1;
(statearr_48028_48823[(2)] = inst_47942);

(statearr_48028_48823[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (14))){
var inst_47964 = (state_47998[(7)]);
var inst_47966 = cljs.core.chunked_seq_QMARK_(inst_47964);
var state_47998__$1 = state_47998;
if(inst_47966){
var statearr_48029_48824 = state_47998__$1;
(statearr_48029_48824[(1)] = (17));

} else {
var statearr_48030_48825 = state_47998__$1;
(statearr_48030_48825[(1)] = (18));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (16))){
var inst_47982 = (state_47998[(2)]);
var state_47998__$1 = state_47998;
var statearr_48031_48826 = state_47998__$1;
(statearr_48031_48826[(2)] = inst_47982);

(statearr_48031_48826[(1)] = (12));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_47999 === (10))){
var inst_47951 = (state_47998[(10)]);
var inst_47953 = (state_47998[(12)]);
var inst_47958 = cljs.core._nth(inst_47951,inst_47953);
var state_47998__$1 = state_47998;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47998__$1,(13),out,inst_47958);
} else {
if((state_val_47999 === (18))){
var inst_47964 = (state_47998[(7)]);
var inst_47973 = cljs.core.first(inst_47964);
var state_47998__$1 = state_47998;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_47998__$1,(20),out,inst_47973);
} else {
if((state_val_47999 === (8))){
var inst_47953 = (state_47998[(12)]);
var inst_47952 = (state_47998[(11)]);
var inst_47955 = (inst_47953 < inst_47952);
var inst_47956 = inst_47955;
var state_47998__$1 = state_47998;
if(cljs.core.truth_(inst_47956)){
var statearr_48032_48830 = state_47998__$1;
(statearr_48032_48830[(1)] = (10));

} else {
var statearr_48033_48831 = state_47998__$1;
(statearr_48033_48831[(1)] = (11));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__ = null;
var cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____0 = (function (){
var statearr_48034 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_48034[(0)] = cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__);

(statearr_48034[(1)] = (1));

return statearr_48034;
});
var cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____1 = (function (state_47998){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_47998);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e48035){var ex__46653__auto__ = e48035;
var statearr_48036_48833 = state_47998;
(statearr_48036_48833[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_47998[(4)]))){
var statearr_48037_48834 = state_47998;
(statearr_48037_48834[(1)] = cljs.core.first((state_47998[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48835 = state_47998;
state_47998 = G__48835;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__ = function(state_47998){
switch(arguments.length){
case 0:
return cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____1.call(this,state_47998);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____0;
cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$mapcat_STAR__$_state_machine__46650__auto____1;
return cljs$core$async$mapcat_STAR__$_state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_48038 = f__46686__auto__();
(statearr_48038[(6)] = c__46685__auto__);

return statearr_48038;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));

return c__46685__auto__;
});
/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.mapcat_LT_ = (function cljs$core$async$mapcat_LT_(var_args){
var G__48040 = arguments.length;
switch (G__48040) {
case 2:
return cljs.core.async.mapcat_LT_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.mapcat_LT_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.mapcat_LT_.cljs$core$IFn$_invoke$arity$2 = (function (f,in$){
return cljs.core.async.mapcat_LT_.cljs$core$IFn$_invoke$arity$3(f,in$,null);
}));

(cljs.core.async.mapcat_LT_.cljs$core$IFn$_invoke$arity$3 = (function (f,in$,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
cljs.core.async.mapcat_STAR_(f,in$,out);

return out;
}));

(cljs.core.async.mapcat_LT_.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.mapcat_GT_ = (function cljs$core$async$mapcat_GT_(var_args){
var G__48042 = arguments.length;
switch (G__48042) {
case 2:
return cljs.core.async.mapcat_GT_.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.mapcat_GT_.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.mapcat_GT_.cljs$core$IFn$_invoke$arity$2 = (function (f,out){
return cljs.core.async.mapcat_GT_.cljs$core$IFn$_invoke$arity$3(f,out,null);
}));

(cljs.core.async.mapcat_GT_.cljs$core$IFn$_invoke$arity$3 = (function (f,out,buf_or_n){
var in$ = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
cljs.core.async.mapcat_STAR_(f,in$,out);

return in$;
}));

(cljs.core.async.mapcat_GT_.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.unique = (function cljs$core$async$unique(var_args){
var G__48044 = arguments.length;
switch (G__48044) {
case 1:
return cljs.core.async.unique.cljs$core$IFn$_invoke$arity$1((arguments[(0)]));

break;
case 2:
return cljs.core.async.unique.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.unique.cljs$core$IFn$_invoke$arity$1 = (function (ch){
return cljs.core.async.unique.cljs$core$IFn$_invoke$arity$2(ch,null);
}));

(cljs.core.async.unique.cljs$core$IFn$_invoke$arity$2 = (function (ch,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48854 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_48068){
var state_val_48069 = (state_48068[(1)]);
if((state_val_48069 === (7))){
var inst_48063 = (state_48068[(2)]);
var state_48068__$1 = state_48068;
var statearr_48070_48855 = state_48068__$1;
(statearr_48070_48855[(2)] = inst_48063);

(statearr_48070_48855[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (1))){
var inst_48045 = null;
var state_48068__$1 = (function (){var statearr_48071 = state_48068;
(statearr_48071[(7)] = inst_48045);

return statearr_48071;
})();
var statearr_48072_48856 = state_48068__$1;
(statearr_48072_48856[(2)] = null);

(statearr_48072_48856[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (4))){
var inst_48048 = (state_48068[(8)]);
var inst_48048__$1 = (state_48068[(2)]);
var inst_48049 = (inst_48048__$1 == null);
var inst_48050 = cljs.core.not(inst_48049);
var state_48068__$1 = (function (){var statearr_48073 = state_48068;
(statearr_48073[(8)] = inst_48048__$1);

return statearr_48073;
})();
if(inst_48050){
var statearr_48074_48857 = state_48068__$1;
(statearr_48074_48857[(1)] = (5));

} else {
var statearr_48075_48858 = state_48068__$1;
(statearr_48075_48858[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (6))){
var state_48068__$1 = state_48068;
var statearr_48076_48859 = state_48068__$1;
(statearr_48076_48859[(2)] = null);

(statearr_48076_48859[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (3))){
var inst_48065 = (state_48068[(2)]);
var inst_48066 = cljs.core.async.close_BANG_(out);
var state_48068__$1 = (function (){var statearr_48077 = state_48068;
(statearr_48077[(9)] = inst_48065);

return statearr_48077;
})();
return cljs.core.async.impl.ioc_helpers.return_chan(state_48068__$1,inst_48066);
} else {
if((state_val_48069 === (2))){
var state_48068__$1 = state_48068;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_48068__$1,(4),ch);
} else {
if((state_val_48069 === (11))){
var inst_48048 = (state_48068[(8)]);
var inst_48057 = (state_48068[(2)]);
var inst_48045 = inst_48048;
var state_48068__$1 = (function (){var statearr_48078 = state_48068;
(statearr_48078[(10)] = inst_48057);

(statearr_48078[(7)] = inst_48045);

return statearr_48078;
})();
var statearr_48079_48860 = state_48068__$1;
(statearr_48079_48860[(2)] = null);

(statearr_48079_48860[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (9))){
var inst_48048 = (state_48068[(8)]);
var state_48068__$1 = state_48068;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_48068__$1,(11),out,inst_48048);
} else {
if((state_val_48069 === (5))){
var inst_48048 = (state_48068[(8)]);
var inst_48045 = (state_48068[(7)]);
var inst_48052 = cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(inst_48048,inst_48045);
var state_48068__$1 = state_48068;
if(inst_48052){
var statearr_48081_48867 = state_48068__$1;
(statearr_48081_48867[(1)] = (8));

} else {
var statearr_48082_48868 = state_48068__$1;
(statearr_48082_48868[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (10))){
var inst_48060 = (state_48068[(2)]);
var state_48068__$1 = state_48068;
var statearr_48083_48869 = state_48068__$1;
(statearr_48083_48869[(2)] = inst_48060);

(statearr_48083_48869[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48069 === (8))){
var inst_48045 = (state_48068[(7)]);
var tmp48080 = inst_48045;
var inst_48045__$1 = tmp48080;
var state_48068__$1 = (function (){var statearr_48084 = state_48068;
(statearr_48084[(7)] = inst_48045__$1);

return statearr_48084;
})();
var statearr_48085_48870 = state_48068__$1;
(statearr_48085_48870[(2)] = null);

(statearr_48085_48870[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_48086 = [null,null,null,null,null,null,null,null,null,null,null];
(statearr_48086[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_48086[(1)] = (1));

return statearr_48086;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_48068){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_48068);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e48087){var ex__46653__auto__ = e48087;
var statearr_48088_48871 = state_48068;
(statearr_48088_48871[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_48068[(4)]))){
var statearr_48089_48872 = state_48068;
(statearr_48089_48872[(1)] = cljs.core.first((state_48068[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48873 = state_48068;
state_48068 = G__48873;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_48068){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_48068);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_48090 = f__46686__auto__();
(statearr_48090[(6)] = c__46685__auto___48854);

return statearr_48090;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.unique.cljs$lang$maxFixedArity = 2);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.partition = (function cljs$core$async$partition(var_args){
var G__48092 = arguments.length;
switch (G__48092) {
case 2:
return cljs.core.async.partition.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.partition.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.partition.cljs$core$IFn$_invoke$arity$2 = (function (n,ch){
return cljs.core.async.partition.cljs$core$IFn$_invoke$arity$3(n,ch,null);
}));

(cljs.core.async.partition.cljs$core$IFn$_invoke$arity$3 = (function (n,ch,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48875 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_48130){
var state_val_48131 = (state_48130[(1)]);
if((state_val_48131 === (7))){
var inst_48126 = (state_48130[(2)]);
var state_48130__$1 = state_48130;
var statearr_48132_48876 = state_48130__$1;
(statearr_48132_48876[(2)] = inst_48126);

(statearr_48132_48876[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (1))){
var inst_48093 = (new Array(n));
var inst_48094 = inst_48093;
var inst_48095 = (0);
var state_48130__$1 = (function (){var statearr_48133 = state_48130;
(statearr_48133[(7)] = inst_48094);

(statearr_48133[(8)] = inst_48095);

return statearr_48133;
})();
var statearr_48134_48883 = state_48130__$1;
(statearr_48134_48883[(2)] = null);

(statearr_48134_48883[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (4))){
var inst_48098 = (state_48130[(9)]);
var inst_48098__$1 = (state_48130[(2)]);
var inst_48099 = (inst_48098__$1 == null);
var inst_48100 = cljs.core.not(inst_48099);
var state_48130__$1 = (function (){var statearr_48135 = state_48130;
(statearr_48135[(9)] = inst_48098__$1);

return statearr_48135;
})();
if(inst_48100){
var statearr_48136_48884 = state_48130__$1;
(statearr_48136_48884[(1)] = (5));

} else {
var statearr_48137_48885 = state_48130__$1;
(statearr_48137_48885[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (15))){
var inst_48120 = (state_48130[(2)]);
var state_48130__$1 = state_48130;
var statearr_48138_48886 = state_48130__$1;
(statearr_48138_48886[(2)] = inst_48120);

(statearr_48138_48886[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (13))){
var state_48130__$1 = state_48130;
var statearr_48139_48887 = state_48130__$1;
(statearr_48139_48887[(2)] = null);

(statearr_48139_48887[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (6))){
var inst_48095 = (state_48130[(8)]);
var inst_48116 = (inst_48095 > (0));
var state_48130__$1 = state_48130;
if(cljs.core.truth_(inst_48116)){
var statearr_48140_48888 = state_48130__$1;
(statearr_48140_48888[(1)] = (12));

} else {
var statearr_48141_48889 = state_48130__$1;
(statearr_48141_48889[(1)] = (13));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (3))){
var inst_48128 = (state_48130[(2)]);
var state_48130__$1 = state_48130;
return cljs.core.async.impl.ioc_helpers.return_chan(state_48130__$1,inst_48128);
} else {
if((state_val_48131 === (12))){
var inst_48094 = (state_48130[(7)]);
var inst_48118 = cljs.core.vec(inst_48094);
var state_48130__$1 = state_48130;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_48130__$1,(15),out,inst_48118);
} else {
if((state_val_48131 === (2))){
var state_48130__$1 = state_48130;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_48130__$1,(4),ch);
} else {
if((state_val_48131 === (11))){
var inst_48110 = (state_48130[(2)]);
var inst_48111 = (new Array(n));
var inst_48094 = inst_48111;
var inst_48095 = (0);
var state_48130__$1 = (function (){var statearr_48142 = state_48130;
(statearr_48142[(10)] = inst_48110);

(statearr_48142[(7)] = inst_48094);

(statearr_48142[(8)] = inst_48095);

return statearr_48142;
})();
var statearr_48143_48890 = state_48130__$1;
(statearr_48143_48890[(2)] = null);

(statearr_48143_48890[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (9))){
var inst_48094 = (state_48130[(7)]);
var inst_48108 = cljs.core.vec(inst_48094);
var state_48130__$1 = state_48130;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_48130__$1,(11),out,inst_48108);
} else {
if((state_val_48131 === (5))){
var inst_48094 = (state_48130[(7)]);
var inst_48095 = (state_48130[(8)]);
var inst_48098 = (state_48130[(9)]);
var inst_48103 = (state_48130[(11)]);
var inst_48102 = (inst_48094[inst_48095] = inst_48098);
var inst_48103__$1 = (inst_48095 + (1));
var inst_48104 = (inst_48103__$1 < n);
var state_48130__$1 = (function (){var statearr_48144 = state_48130;
(statearr_48144[(12)] = inst_48102);

(statearr_48144[(11)] = inst_48103__$1);

return statearr_48144;
})();
if(cljs.core.truth_(inst_48104)){
var statearr_48145_48897 = state_48130__$1;
(statearr_48145_48897[(1)] = (8));

} else {
var statearr_48146_48898 = state_48130__$1;
(statearr_48146_48898[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (14))){
var inst_48123 = (state_48130[(2)]);
var inst_48124 = cljs.core.async.close_BANG_(out);
var state_48130__$1 = (function (){var statearr_48148 = state_48130;
(statearr_48148[(13)] = inst_48123);

return statearr_48148;
})();
var statearr_48149_48899 = state_48130__$1;
(statearr_48149_48899[(2)] = inst_48124);

(statearr_48149_48899[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (10))){
var inst_48114 = (state_48130[(2)]);
var state_48130__$1 = state_48130;
var statearr_48150_48900 = state_48130__$1;
(statearr_48150_48900[(2)] = inst_48114);

(statearr_48150_48900[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48131 === (8))){
var inst_48094 = (state_48130[(7)]);
var inst_48103 = (state_48130[(11)]);
var tmp48147 = inst_48094;
var inst_48094__$1 = tmp48147;
var inst_48095 = inst_48103;
var state_48130__$1 = (function (){var statearr_48151 = state_48130;
(statearr_48151[(7)] = inst_48094__$1);

(statearr_48151[(8)] = inst_48095);

return statearr_48151;
})();
var statearr_48152_48901 = state_48130__$1;
(statearr_48152_48901[(2)] = null);

(statearr_48152_48901[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_48153 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_48153[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_48153[(1)] = (1));

return statearr_48153;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_48130){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_48130);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e48154){var ex__46653__auto__ = e48154;
var statearr_48155_48902 = state_48130;
(statearr_48155_48902[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_48130[(4)]))){
var statearr_48156_48903 = state_48130;
(statearr_48156_48903[(1)] = cljs.core.first((state_48130[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48904 = state_48130;
state_48130 = G__48904;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_48130){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_48130);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_48157 = f__46686__auto__();
(statearr_48157[(6)] = c__46685__auto___48875);

return statearr_48157;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.partition.cljs$lang$maxFixedArity = 3);

/**
 * Deprecated - this function will be removed. Use transducer instead
 */
cljs.core.async.partition_by = (function cljs$core$async$partition_by(var_args){
var G__48159 = arguments.length;
switch (G__48159) {
case 2:
return cljs.core.async.partition_by.cljs$core$IFn$_invoke$arity$2((arguments[(0)]),(arguments[(1)]));

break;
case 3:
return cljs.core.async.partition_by.cljs$core$IFn$_invoke$arity$3((arguments[(0)]),(arguments[(1)]),(arguments[(2)]));

break;
default:
throw (new Error(["Invalid arity: ",cljs.core.str.cljs$core$IFn$_invoke$arity$1(arguments.length)].join('')));

}
});

(cljs.core.async.partition_by.cljs$core$IFn$_invoke$arity$2 = (function (f,ch){
return cljs.core.async.partition_by.cljs$core$IFn$_invoke$arity$3(f,ch,null);
}));

(cljs.core.async.partition_by.cljs$core$IFn$_invoke$arity$3 = (function (f,ch,buf_or_n){
var out = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1(buf_or_n);
var c__46685__auto___48906 = cljs.core.async.chan.cljs$core$IFn$_invoke$arity$1((1));
cljs.core.async.impl.dispatch.run((function (){
var f__46686__auto__ = (function (){var switch__46649__auto__ = (function (state_48201){
var state_val_48202 = (state_48201[(1)]);
if((state_val_48202 === (7))){
var inst_48197 = (state_48201[(2)]);
var state_48201__$1 = state_48201;
var statearr_48203_48907 = state_48201__$1;
(statearr_48203_48907[(2)] = inst_48197);

(statearr_48203_48907[(1)] = (3));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (1))){
var inst_48160 = [];
var inst_48161 = inst_48160;
var inst_48162 = new cljs.core.Keyword("cljs.core.async","nothing","cljs.core.async/nothing",-69252123);
var state_48201__$1 = (function (){var statearr_48204 = state_48201;
(statearr_48204[(7)] = inst_48161);

(statearr_48204[(8)] = inst_48162);

return statearr_48204;
})();
var statearr_48205_48908 = state_48201__$1;
(statearr_48205_48908[(2)] = null);

(statearr_48205_48908[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (4))){
var inst_48165 = (state_48201[(9)]);
var inst_48165__$1 = (state_48201[(2)]);
var inst_48166 = (inst_48165__$1 == null);
var inst_48167 = cljs.core.not(inst_48166);
var state_48201__$1 = (function (){var statearr_48206 = state_48201;
(statearr_48206[(9)] = inst_48165__$1);

return statearr_48206;
})();
if(inst_48167){
var statearr_48207_48909 = state_48201__$1;
(statearr_48207_48909[(1)] = (5));

} else {
var statearr_48208_48910 = state_48201__$1;
(statearr_48208_48910[(1)] = (6));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (15))){
var inst_48191 = (state_48201[(2)]);
var state_48201__$1 = state_48201;
var statearr_48209_48911 = state_48201__$1;
(statearr_48209_48911[(2)] = inst_48191);

(statearr_48209_48911[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (13))){
var state_48201__$1 = state_48201;
var statearr_48210_48912 = state_48201__$1;
(statearr_48210_48912[(2)] = null);

(statearr_48210_48912[(1)] = (14));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (6))){
var inst_48161 = (state_48201[(7)]);
var inst_48186 = inst_48161.length;
var inst_48187 = (inst_48186 > (0));
var state_48201__$1 = state_48201;
if(cljs.core.truth_(inst_48187)){
var statearr_48211_48913 = state_48201__$1;
(statearr_48211_48913[(1)] = (12));

} else {
var statearr_48212_48914 = state_48201__$1;
(statearr_48212_48914[(1)] = (13));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (3))){
var inst_48199 = (state_48201[(2)]);
var state_48201__$1 = state_48201;
return cljs.core.async.impl.ioc_helpers.return_chan(state_48201__$1,inst_48199);
} else {
if((state_val_48202 === (12))){
var inst_48161 = (state_48201[(7)]);
var inst_48189 = cljs.core.vec(inst_48161);
var state_48201__$1 = state_48201;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_48201__$1,(15),out,inst_48189);
} else {
if((state_val_48202 === (2))){
var state_48201__$1 = state_48201;
return cljs.core.async.impl.ioc_helpers.take_BANG_(state_48201__$1,(4),ch);
} else {
if((state_val_48202 === (11))){
var inst_48165 = (state_48201[(9)]);
var inst_48169 = (state_48201[(10)]);
var inst_48179 = (state_48201[(2)]);
var inst_48180 = [];
var inst_48181 = inst_48180.push(inst_48165);
var inst_48161 = inst_48180;
var inst_48162 = inst_48169;
var state_48201__$1 = (function (){var statearr_48213 = state_48201;
(statearr_48213[(11)] = inst_48179);

(statearr_48213[(12)] = inst_48181);

(statearr_48213[(7)] = inst_48161);

(statearr_48213[(8)] = inst_48162);

return statearr_48213;
})();
var statearr_48214_48917 = state_48201__$1;
(statearr_48214_48917[(2)] = null);

(statearr_48214_48917[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (9))){
var inst_48161 = (state_48201[(7)]);
var inst_48177 = cljs.core.vec(inst_48161);
var state_48201__$1 = state_48201;
return cljs.core.async.impl.ioc_helpers.put_BANG_(state_48201__$1,(11),out,inst_48177);
} else {
if((state_val_48202 === (5))){
var inst_48165 = (state_48201[(9)]);
var inst_48169 = (state_48201[(10)]);
var inst_48162 = (state_48201[(8)]);
var inst_48169__$1 = (f.cljs$core$IFn$_invoke$arity$1 ? f.cljs$core$IFn$_invoke$arity$1(inst_48165) : f.call(null,inst_48165));
var inst_48170 = cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(inst_48169__$1,inst_48162);
var inst_48171 = cljs.core.keyword_identical_QMARK_(inst_48162,new cljs.core.Keyword("cljs.core.async","nothing","cljs.core.async/nothing",-69252123));
var inst_48172 = ((inst_48170) || (inst_48171));
var state_48201__$1 = (function (){var statearr_48215 = state_48201;
(statearr_48215[(10)] = inst_48169__$1);

return statearr_48215;
})();
if(cljs.core.truth_(inst_48172)){
var statearr_48216_48918 = state_48201__$1;
(statearr_48216_48918[(1)] = (8));

} else {
var statearr_48217_48919 = state_48201__$1;
(statearr_48217_48919[(1)] = (9));

}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (14))){
var inst_48194 = (state_48201[(2)]);
var inst_48195 = cljs.core.async.close_BANG_(out);
var state_48201__$1 = (function (){var statearr_48219 = state_48201;
(statearr_48219[(13)] = inst_48194);

return statearr_48219;
})();
var statearr_48220_48920 = state_48201__$1;
(statearr_48220_48920[(2)] = inst_48195);

(statearr_48220_48920[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (10))){
var inst_48184 = (state_48201[(2)]);
var state_48201__$1 = state_48201;
var statearr_48221_48921 = state_48201__$1;
(statearr_48221_48921[(2)] = inst_48184);

(statearr_48221_48921[(1)] = (7));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
if((state_val_48202 === (8))){
var inst_48161 = (state_48201[(7)]);
var inst_48165 = (state_48201[(9)]);
var inst_48169 = (state_48201[(10)]);
var inst_48174 = inst_48161.push(inst_48165);
var tmp48218 = inst_48161;
var inst_48161__$1 = tmp48218;
var inst_48162 = inst_48169;
var state_48201__$1 = (function (){var statearr_48222 = state_48201;
(statearr_48222[(14)] = inst_48174);

(statearr_48222[(7)] = inst_48161__$1);

(statearr_48222[(8)] = inst_48162);

return statearr_48222;
})();
var statearr_48223_48922 = state_48201__$1;
(statearr_48223_48922[(2)] = null);

(statearr_48223_48922[(1)] = (2));


return new cljs.core.Keyword(null,"recur","recur",-437573268);
} else {
return null;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
});
return (function() {
var cljs$core$async$state_machine__46650__auto__ = null;
var cljs$core$async$state_machine__46650__auto____0 = (function (){
var statearr_48224 = [null,null,null,null,null,null,null,null,null,null,null,null,null,null,null];
(statearr_48224[(0)] = cljs$core$async$state_machine__46650__auto__);

(statearr_48224[(1)] = (1));

return statearr_48224;
});
var cljs$core$async$state_machine__46650__auto____1 = (function (state_48201){
while(true){
var ret_value__46651__auto__ = (function (){try{while(true){
var result__46652__auto__ = switch__46649__auto__(state_48201);
if(cljs.core.keyword_identical_QMARK_(result__46652__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
continue;
} else {
return result__46652__auto__;
}
break;
}
}catch (e48225){var ex__46653__auto__ = e48225;
var statearr_48226_48925 = state_48201;
(statearr_48226_48925[(2)] = ex__46653__auto__);


if(cljs.core.seq((state_48201[(4)]))){
var statearr_48227_48926 = state_48201;
(statearr_48227_48926[(1)] = cljs.core.first((state_48201[(4)])));

} else {
throw ex__46653__auto__;
}

return new cljs.core.Keyword(null,"recur","recur",-437573268);
}})();
if(cljs.core.keyword_identical_QMARK_(ret_value__46651__auto__,new cljs.core.Keyword(null,"recur","recur",-437573268))){
var G__48927 = state_48201;
state_48201 = G__48927;
continue;
} else {
return ret_value__46651__auto__;
}
break;
}
});
cljs$core$async$state_machine__46650__auto__ = function(state_48201){
switch(arguments.length){
case 0:
return cljs$core$async$state_machine__46650__auto____0.call(this);
case 1:
return cljs$core$async$state_machine__46650__auto____1.call(this,state_48201);
}
throw(new Error('Invalid arity: ' + arguments.length));
};
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$0 = cljs$core$async$state_machine__46650__auto____0;
cljs$core$async$state_machine__46650__auto__.cljs$core$IFn$_invoke$arity$1 = cljs$core$async$state_machine__46650__auto____1;
return cljs$core$async$state_machine__46650__auto__;
})()
})();
var state__46687__auto__ = (function (){var statearr_48228 = f__46686__auto__();
(statearr_48228[(6)] = c__46685__auto___48906);

return statearr_48228;
})();
return cljs.core.async.impl.ioc_helpers.run_state_machine_wrapped(state__46687__auto__);
}));


return out;
}));

(cljs.core.async.partition_by.cljs$lang$maxFixedArity = 3);


//# sourceMappingURL=cljs.core.async.js.map
