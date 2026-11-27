/*
   testmx_c: C helpers for TestMitter (the fake JETI firmware)

   - gps: the JETI gps library, measured with GpsTest on emulator 6.06 and
     a DS-24 on firmware 5.08 (identical results). GpsPoints hold doubles;
     numbers only drop to lua_Number (float32 in the LUA_32BITS build) when
     they are returned to Lua, as on the TX. Formulas: haversine distance
     and great-circle bearing/destination on a sphere of R = 6378137 m plus
     the first point's altitude; Web Mercator with 256 px tiles (m2px and
     px2m in float32, as measured).
   - ms():        monotonic wall clock, ms since the module loaded
   - sleep(ms):   sleep that many ms (paced mode)

   Build with TestMX/build.sh against the JETI-like Lua headers, and run
   with that Lua: package.loadlib("Apps/TestMX/testmx_c.so", "luaopen_testmx_c")

   Coded by Claude Code with guidance from D. McQueeney
*/

#define _POSIX_C_SOURCE 200809L
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "lua.h"
#include "lauxlib.h"

#define GPS_META "GpsPoint"
#define EARTH_R 6378137.0
#define TILE 256.0

typedef struct { double lat, lng, alt; } GpsPoint;

static const double PI = 3.14159265358979323846;
static double rad(double d) { return d * PI / 180.0; }
static double deg(double r) { return r * 180.0 / PI; }

/* a number or a numeric string as a double; strings keep full precision */
static double getd(lua_State *L, int i) {
   if (lua_type(L, i) == LUA_TSTRING) {
      const char *s = lua_tostring(L, i);
      char *end;
      double v = strtod(s, &end);
      if (end == s) luaL_argerror(L, i, "number expected");
      return v;
   }
   return (double)luaL_checknumber(L, i);
}

static double optd(lua_State *L, int i, double def) {
   return lua_isnoneornil(L, i) ? def : getd(L, i);
}

static GpsPoint *checkpt(lua_State *L, int i) {
   return (GpsPoint *)luaL_checkudata(L, i, GPS_META);
}

static GpsPoint *pushpt(lua_State *L, double lat, double lng, double alt) {
   GpsPoint *p = (GpsPoint *)lua_newuserdata(L, sizeof(GpsPoint));
   p->lat = lat; p->lng = lng; p->alt = alt;
   luaL_setmetatable(L, GPS_META);
   return p;
}

/* gps.newPoint(lat, lng [, alt]) or gps.newPoint(point) */
static int l_newPoint(lua_State *L) {
   GpsPoint *src = (GpsPoint *)luaL_testudata(L, 1, GPS_META);
   if (src) { pushpt(L, src->lat, src->lng, src->alt); return 1; }
   double lat = getd(L, 1), lng = getd(L, 2), alt = optd(L, 3, 0.0);
   pushpt(L, lat, lng, alt);
   return 1;
}

/* the second position: a point at i, or lat/lng at i and i+1 (altitude 0) */
static GpsPoint second(lua_State *L, int i) {
   GpsPoint q;
   GpsPoint *p = (GpsPoint *)luaL_testudata(L, i, GPS_META);
   if (p) return *p;
   q.lat = getd(L, i); q.lng = getd(L, i + 1); q.alt = 0.0;
   return q;
}

static int l_getDistance(lua_State *L) {
   GpsPoint a = *checkpt(L, 1), b = second(L, 2);
   double f1 = rad(a.lat), f2 = rad(b.lat);
   double df = f2 - f1, dl = rad(b.lng - a.lng);
   double h = sin(df / 2) * sin(df / 2)
      + cos(f1) * cos(f2) * sin(dl / 2) * sin(dl / 2);
   double c = 2 * atan2(sqrt(h), sqrt(1 - h));
   lua_pushnumber(L, (lua_Number)((EARTH_R + a.alt) * c));
   return 1;
}

static int l_getBearing(lua_State *L) {
   GpsPoint a = *checkpt(L, 1), b = second(L, 2);
   double f1 = rad(a.lat), f2 = rad(b.lat), dl = rad(b.lng - a.lng);
   double y = sin(dl) * cos(f2);
   double x = cos(f1) * sin(f2) - sin(f1) * cos(f2) * cos(dl);
   double t = fmod(deg(atan2(y, x)) + 360.0, 360.0);
   lua_pushnumber(L, (lua_Number)t);
   return 1;
}

/* gps.getDestination(point, distance, bearing [, altitude]) */
static int l_getDestination(lua_State *L) {
   GpsPoint a = *checkpt(L, 1);
   double d = getd(L, 2), brg = rad(getd(L, 3));
   double alt = optd(L, 4, a.alt);
   double dr = d / (EARTH_R + alt);
   double f1 = rad(a.lat), l1 = rad(a.lng);
   double f2 = asin(sin(f1) * cos(dr) + cos(f1) * sin(dr) * cos(brg));
   double l2 = l1 + atan2(sin(brg) * sin(dr) * cos(f1),
                          cos(dr) - sin(f1) * sin(f2));
   double lng = fmod(deg(l2) + 540.0, 360.0) - 180.0;
   pushpt(L, deg(f2), lng, a.alt);
   return 1;
}

static int l_getValue(lua_State *L) {
   GpsPoint *p = checkpt(L, 1);
   lua_pushnumber(L, (lua_Number)p->lat);
   lua_pushnumber(L, (lua_Number)p->lng);
   return 2;
}

static int l_getString(lua_State *L) {
   GpsPoint *p = checkpt(L, 1);
   char b[64];
   snprintf(b, sizeof b, "%.8f", p->lat); lua_pushstring(L, b);
   snprintf(b, sizeof b, "%.8f", p->lng); lua_pushstring(L, b);
   return 2;
}

/* Web Mercator world pixels at zoom z */
static double world(double z) { return TILE * pow(2.0, z); }
static double mx(double lng, double z) { return (lng + 180.0) / 360.0 * world(z); }
static double my(double lat, double z) {
   double f = rad(lat);
   return (1.0 - log(tan(f) + 1.0 / cos(f)) / PI) / 2.0 * world(z);
}
static double ilng(double x, double z) { return x / world(z) * 360.0 - 180.0; }
static double ilat(double y, double z) {
   double n = PI * (1.0 - 2.0 * y / world(z));
   return deg(atan(sinh(n)));
}

/* gps.getLcdXY(point, topLeft, zoom) */
static int l_getLcdXY(lua_State *L) {
   GpsPoint *p = checkpt(L, 1), *tl = checkpt(L, 2);
   double z = getd(L, 3);
   lua_pushnumber(L, (lua_Number)(mx(p->lng, z) - mx(tl->lng, z)));
   lua_pushnumber(L, (lua_Number)(my(p->lat, z) - my(tl->lat, z)));
   return 2;
}

/* gps.getLL(x, y, topLeft, zoom) */
static int l_getLL(lua_State *L) {
   double x = getd(L, 1), y = getd(L, 2);
   GpsPoint *tl = checkpt(L, 3);
   double z = getd(L, 4);
   pushpt(L, ilat(my(tl->lat, z) + y, z), ilng(mx(tl->lng, z) + x, z), 0.0);
   return 1;
}

/* gps.offset(point, dx, dy, zoom): moves the point, returns nothing */
static int l_offset(lua_State *L) {
   GpsPoint *p = checkpt(L, 1);
   double dx = getd(L, 2), dy = getd(L, 3), z = getd(L, 4);
   double nx = mx(p->lng, z) + dx, ny = my(p->lat, z) + dy;
   p->lat = ilat(ny, z);
   p->lng = ilng(nx, z);
   return 0;
}

/* metres per pixel at the point's latitude. Unlike the rest of the
   library this is float32 maths on the TX: cosf, then float products
   (fitted to all 12 m2px/px2m results of GpsTest; double maths misses
   the 60 degree pair by one float32 step) */
static float mpp(GpsPoint *p, double z) {
   float c = cosf((float)rad(p->lat));
   return ((float)(2.0 * PI * EARTH_R) * c) / (float)world(z);
}

static int l_m2px(lua_State *L) {
   GpsPoint *p = checkpt(L, 1);
   float x = (float)optd(L, 2, 0.0), y = (float)optd(L, 3, 0.0);
   float k = mpp(p, getd(L, 4));
   lua_pushnumber(L, (lua_Number)(x / k));
   lua_pushnumber(L, (lua_Number)(y / k));
   return 2;
}

static int l_px2m(lua_State *L) {
   GpsPoint *p = checkpt(L, 1);
   float x = (float)optd(L, 2, 0.0), y = (float)optd(L, 3, 0.0);
   float k = mpp(p, getd(L, 4));
   lua_pushnumber(L, (lua_Number)(x * k));
   lua_pushnumber(L, (lua_Number)(y * k));
   return 2;
}

/* wall clock: ms since load, as an integer (fits 32 bits for 24 days) */
static struct timespec t0;

static int l_ms(lua_State *L) {
   struct timespec t;
   clock_gettime(CLOCK_MONOTONIC, &t);
   double ms = (t.tv_sec - t0.tv_sec) * 1000.0 + (t.tv_nsec - t0.tv_nsec) / 1e6;
   lua_pushinteger(L, (lua_Integer)ms);
   return 1;
}

static int l_sleep(lua_State *L) {
   double ms = (double)luaL_checknumber(L, 1);
   if (ms > 0) {
      struct timespec t;
      t.tv_sec = (time_t)(ms / 1000.0);
      t.tv_nsec = (long)((ms - t.tv_sec * 1000.0) * 1e6);
      nanosleep(&t, NULL);
   }
   return 0;
}

static const luaL_Reg gpsfuncs[] = {
   {"newPoint", l_newPoint}, {"getDistance", l_getDistance},
   {"getBearing", l_getBearing}, {"getDestination", l_getDestination},
   {"getValue", l_getValue}, {"getString", l_getString},
   {"getLcdXY", l_getLcdXY}, {"getLL", l_getLL}, {"offset", l_offset},
   {"m2px", l_m2px}, {"px2m", l_px2m}, {NULL, NULL}
};

int luaopen_testmx_c(lua_State *L) {
   clock_gettime(CLOCK_MONOTONIC, &t0);
   luaL_newmetatable(L, GPS_META);
   lua_pop(L, 1);
   lua_newtable(L);
   luaL_newlib(L, gpsfuncs);
   lua_setfield(L, -2, "gps");
   lua_pushcfunction(L, l_ms);
   lua_setfield(L, -2, "ms");
   lua_pushcfunction(L, l_sleep);
   lua_setfield(L, -2, "sleep");
   return 1;
}
