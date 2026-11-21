#!/usr/bin/env python3
"""Fit GpsTest output (gpstest.out) against candidate GPS formulas.

usage: python3 compare.py [gpstest.out]

For each distance the script prints the error of every candidate and the
earth radius the result implies if it were haversine (a constant radius
means a sphere). Bearings are compared with great-circle initial bearing,
rhumb line and flat-earth bearing; destinations with the spherical formula
at several radii, with and without altitude added; the Mercator calls with
Web Mercator at 256 px tiles, R = 6378137 m. A summary at the end gives the
RMS relative error of each candidate.
"""
import math
import sys

R_MEAN = 6371000.0          # Veness latlon-spherical default
RADII = {"hav6371000": 6371000.0, "hav6371008.8": 6371008.8,
         "hav6372795(TinyGPS)": 6372795.0, "hav6378137": 6378137.0}
WGS_A, WGS_F = 6378137.0, 1 / 298.257223563


def rad(x):
    return math.radians(x)


def central(lat1, lng1, lat2, lng2):
    f1, l1, f2, l2 = map(rad, (lat1, lng1, lat2, lng2))
    a = (math.sin((f2 - f1) / 2) ** 2
         + math.cos(f1) * math.cos(f2) * math.sin((l2 - l1) / 2) ** 2)
    return 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def dlng(l1, l2):
    d = l2 - l1
    while d > 180:
        d -= 360
    while d < -180:
        d += 360
    return d


def flat_ardupilot(lat1, lng1, lat2, lng2):
    k = 111318.84502145034          # ArduPilot LOCATION_SCALING_FACTOR * 1e7
    dy = (lat2 - lat1) * k
    dx = dlng(lng1, lng2) * k * math.cos(rad((lat1 + lat2) / 2))
    return math.hypot(dx, dy)


def equirect(lat1, lng1, lat2, lng2, R=R_MEAN):
    dy = rad(lat2 - lat1)
    dx = rad(dlng(lng1, lng2)) * math.cos(rad((lat1 + lat2) / 2))
    return R * math.hypot(dx, dy)


def vincenty(lat1, lng1, lat2, lng2):
    a, f = WGS_A, WGS_F
    b = (1 - f) * a
    L = rad(dlng(lng1, lng2))
    U1 = math.atan((1 - f) * math.tan(rad(lat1)))
    U2 = math.atan((1 - f) * math.tan(rad(lat2)))
    sU1, cU1, sU2, cU2 = math.sin(U1), math.cos(U1), math.sin(U2), math.cos(U2)
    lam = L
    for _ in range(500):
        sl, cl = math.sin(lam), math.cos(lam)
        ss = math.hypot(cU2 * sl, cU1 * sU2 - sU1 * cU2 * cl)
        if ss == 0:
            return 0.0
        cs = sU1 * sU2 + cU1 * cU2 * cl
        sg = math.atan2(ss, cs)
        sa = cU1 * cU2 * sl / ss
        c2a = 1 - sa * sa
        c2m = cs - 2 * sU1 * sU2 / c2a if c2a else 0.0
        C = f / 16 * c2a * (4 + f * (4 - 3 * c2a))
        lp = lam
        lam = L + (1 - C) * f * sa * (sg + C * ss * (c2m + C * cs * (-1 + 2 * c2m * c2m)))
        if abs(lam - lp) < 1e-12:
            break
    u2 = c2a * (a * a - b * b) / (b * b)
    A = 1 + u2 / 16384 * (4096 + u2 * (-768 + u2 * (320 - 175 * u2)))
    B = u2 / 1024 * (256 + u2 * (-128 + u2 * (74 - 47 * u2)))
    ds = B * ss * (c2m + B / 4 * (cs * (-1 + 2 * c2m * c2m)
                                  - B / 6 * c2m * (-3 + 4 * ss * ss) * (-3 + 4 * c2m * c2m)))
    return b * A * (sg - ds)


def bearing_gc(lat1, lng1, lat2, lng2):
    f1, f2 = rad(lat1), rad(lat2)
    dl = rad(dlng(lng1, lng2))
    y = math.sin(dl) * math.cos(f2)
    x = math.cos(f1) * math.sin(f2) - math.sin(f1) * math.cos(f2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def bearing_rhumb(lat1, lng1, lat2, lng2):
    f1, f2 = rad(lat1), rad(lat2)
    dl = rad(dlng(lng1, lng2))
    dpsi = math.log(math.tan(math.pi / 4 + f2 / 2) / math.tan(math.pi / 4 + f1 / 2))
    return (math.degrees(math.atan2(dl, dpsi)) + 360) % 360


def bearing_flat(lat1, lng1, lat2, lng2):
    dy = lat2 - lat1
    dx = dlng(lng1, lng2) * math.cos(rad((lat1 + lat2) / 2))
    return (math.degrees(math.atan2(dx, dy)) + 360) % 360


def dest_sphere(lat, lng, d, brg, R):
    f1, l1, t = rad(lat), rad(lng), rad(brg)
    dd = d / R
    f2 = math.asin(math.sin(f1) * math.cos(dd) + math.cos(f1) * math.sin(dd) * math.cos(t))
    l2 = l1 + math.atan2(math.sin(t) * math.sin(dd) * math.cos(f1),
                         math.cos(dd) - math.sin(f1) * math.sin(f2))
    return math.degrees(f2), (math.degrees(l2) + 540) % 360 - 180


def merc_world(lat, lng, z, tile=256):
    s = tile * 2 ** z
    x = (lng + 180) / 360 * s
    sl = math.sin(rad(lat))
    y = (0.5 - math.log((1 + sl) / (1 - sl)) / (4 * math.pi)) * s
    return x, y


def angdiff(a, b):
    return (a - b + 180) % 360 - 180


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "gpstest.out"
    rows = [l.rstrip("\n").split(",") for l in open(path) if l.strip()]
    sq = {}                       # candidate -> list of relative errors

    def tally(name, rel):
        sq.setdefault(name, []).append(rel)

    print("== distances (error in m per candidate; implied haversine radius)")
    cands = dict((k, (lambda R: (lambda *p: R * central(*p)))(R)) for k, R in RADII.items())
    cands["flat(ArduPilot)"] = flat_ardupilot
    cands["equirect6371"] = equirect
    cands["WGS84 Vincenty"] = vincenty
    hdr = "".join(f"{k[:14]:>15}" for k in cands)
    print(f"{'test':14}{'JETI':>13}{'R implied':>12}{hdr}")
    brg_rows = []
    for r in rows:
        if r[0] == "ERR":
            print("ERR", r[1], r[2] if len(r) > 2 else "")
        if r[0] != "D":
            continue
        n = r[1]
        lat1, lng1, alt1, lat2, lng2, alt2 = map(float, r[2:8])
        d, b12, b21 = float(r[8]), float(r[9]), float(r[10])
        c = central(lat1, lng1, lat2, lng2)
        line = f"{n:14}{d:13.3f}{(d / c if c else 0):12.1f}"
        for k, f in cands.items():
            p = f(lat1, lng1, lat2, lng2)
            line += f"{d - p:15.3f}"
            if p > 50 and "alt" not in n:     # tiny pairs test precision, not formula
                tally("dist " + k, (d - p) / p)
        print(line)
        brg_rows.append((n, lat1, lng1, lat2, lng2, b12, b21))

    print("\n== altitude pairs (altitude implied by the distance at R = 6378137)")
    print(f"{'test':14}{'alt1':>9}{'alt2':>9}{'implied':>11}  matches")
    for r in rows:
        if r[0] != "D" or (float(r[4]) == 0 and float(r[7]) == 0):
            continue
        lat1, lng1, a1, lat2, lng2, a2 = map(float, r[2:8])
        imp = float(r[8]) / central(lat1, lng1, lat2, lng2) - WGS_A
        rules = {"alt1": a1, "alt2": a2, "mean": (a1 + a2) / 2, "max": max(a1, a2),
                 "min": min(a1, a2), "none": 0.0}
        hit = [k for k, v in rules.items() if abs(imp - v) < 5]
        print(f"{r[1]:14}{a1:9.0f}{a2:9.0f}{imp:11.1f}  {', '.join(hit) or 'none of alt1/alt2/mean/max/min'}")

    print("\n== bearings (JETI minus candidate, degrees; b21 is the reverse bearing)")
    print(f"{'test':14}{'b12':>10}{'gc':>9}{'rhumb':>9}{'flat':>9}{'b21':>10}{'gc':>9}{'rhumb':>9}")
    for n, lat1, lng1, lat2, lng2, b12, b21 in brg_rows:
        g1 = angdiff(b12, bearing_gc(lat1, lng1, lat2, lng2))
        h1 = angdiff(b12, bearing_rhumb(lat1, lng1, lat2, lng2))
        f1 = angdiff(b12, bearing_flat(lat1, lng1, lat2, lng2))
        g2 = angdiff(b21, bearing_gc(lat2, lng2, lat1, lng1))
        h2 = angdiff(b21, bearing_rhumb(lat2, lng2, lat1, lng1))
        print(f"{n:14}{b12:10.4f}{g1:9.4f}{h1:9.4f}{f1:9.4f}{b21:10.4f}{g2:9.4f}{h2:9.4f}")
        if central(lat1, lng1, lat2, lng2) * R_MEAN > 50:   # tiny pairs are float noise
            for k, e in (("gc", g1), ("rhumb", h1), ("flat", f1), ("gc", g2), ("rhumb", h2)):
                tally("brg " + k, e / 90)

    print("\n== alternative lat/lng-string form (should equal the D line)")
    dmap = {r[1]: r for r in rows if r[0] == "D"}
    for r in rows:
        if r[0] == "A" and r[1] in dmap:
            dd = float(r[6]) - float(dmap[r[1]][8])
            db = angdiff(float(r[7]), float(dmap[r[1]][9]))
            if abs(dd) > 1e-3 or abs(db) > 1e-4:
                print(f"{r[1]:14} differs: distance {dd:+.4f} m, bearing {db:+.5f} deg")
    print("(no lines above means every A matched its D)")

    print("\n== destinations (miss in m against spherical formula; alt = altitude added to R)")
    radii = [("6371000", 6371000.0), ("6378137", 6378137.0), ("6372795", 6372795.0)]
    print(f"{'test':16}" + "".join(f"{k:>12}" for k, _ in radii) + f"{'6371k+alt':>12}")
    for r in rows:
        if r[0] != "X":
            continue
        n = r[1]
        lat, lng, d, brg = map(float, r[2:6])
        alt = float(r[6]) if r[6] else (float(r[7]) if r[7] else 0.0)
        jla, jlo = float(r[8]), float(r[9])
        line = f"{n:16}"
        for k, R in radii:
            pla, plo = dest_sphere(lat, lng, d, brg, R)
            miss = central(jla, jlo, pla, plo) * R_MEAN
            line += f"{miss:12.3f}"
            if not alt:
                tally("dest hav" + k, miss / d)
        pla, plo = dest_sphere(lat, lng, d, brg, R_MEAN + alt)
        line += f"{central(jla, jlo, pla, plo) * R_MEAN:12.3f}"
        print(line)

    print("\n== Mercator scale (JETI pixels for 1000 m; Web Mercator 256 px tiles, R=6378137)")
    for r in rows:
        if r[0] == "M":
            lat, z = float(r[2]), int(r[4])
            px, py = float(r[7]), float(r[8])
            mpp = math.cos(rad(lat)) * 2 * math.pi * WGS_A / (256 * 2 ** z)
            pred = 1000 / mpp
            print(f"m2px {r[1]:8} JETI {px:12.4f} {py:12.4f}  pred {pred:12.4f}"
                  f"  ratio x {px / pred:.6f} y {py / pred:.6f}")
        elif r[0] == "P":
            lat, z = float(r[2]), int(r[4])
            mx, my = float(r[7]), float(r[8])
            pred = 100 * math.cos(rad(lat)) * 2 * math.pi * WGS_A / (256 * 2 ** z)
            print(f"px2m {r[1]:8} JETI {mx:12.4f} {my:12.4f}  pred {pred:12.4f}"
                  f"  ratio x {mx / pred:.6f} y {my / pred:.6f}")
    print("(ratio 2.0 or 0.5 everywhere means a zoom numbering offset of one level)")

    print("\n== getLcdXY / getLL (Web Mercator world pixels, 256 px tiles)")
    for r in rows:
        if r[0] != "L":
            continue
        tla, tlo, la, lo, z = float(r[2]), float(r[3]), float(r[4]), float(r[5]), int(r[6])
        x, y = float(r[7]), float(r[8])
        x0, y0 = merc_world(tla, tlo, z)
        x1, y1 = merc_world(la, lo, z)
        back = central(la, lo, float(r[9]), float(r[10])) * R_MEAN
        print(f"{r[1]:8} JETI x {x:10.3f} y {y:10.3f}  pred x {x1 - x0:10.3f} y {y1 - y0:10.3f}"
              f"  getLL round trip miss {back:.3f} m")

    print("\n== summary: RMS relative error per candidate (smallest wins)")
    for k, v in sorted(sq.items(), key=lambda kv: math.sqrt(sum(e * e for e in kv[1]) / len(kv[1]))):
        rms = math.sqrt(sum(e * e for e in v) / len(v))
        print(f"{k:30}{rms:14.3e}   n={len(v)}")


if __name__ == "__main__":
    main()
