
shadow.cljs.devtools.client.env.module_loaded('main');

try { gauge.init(); } catch (e) { console.error("An error occurred when calling (gauge/init)"); throw(e); }