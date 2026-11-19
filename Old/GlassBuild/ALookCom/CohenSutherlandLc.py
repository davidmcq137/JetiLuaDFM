## Cohen Sutherland line clipping algo

def lineClipping(x1, y1, x2, y2, xmin, ymin, xmax, ymax):
    ## bit mask
    INSIDE, LEFT, RIGHT, LOWER, UPPER = 0, 1, 2, 4, 8

    def _getclip(xa, ya):
        p = INSIDE

        if xa < xmin:
            p |= LEFT
        elif xa > xmax:
            p |= RIGHT

        if ya < ymin:
            p |= LOWER
        elif ya > ymax:
            p |= UPPER
        
        return p

    # check for trivially outside lines
    k1 = _getclip(x1, y1)
    k2 = _getclip(x2, y2)

    # %% examine non-trivially outside points
    # bitwise OR |
    while (k1 | k2) != 0:  # if both points are inside box (0000) , ACCEPT trivial whole line in box

        # if line trivially outside window, REJECT
        if (k1 & k2) != 0:  # bitwise AND &
            return None, None, None, None

        # non-trivial case, at least one point outside window
        # this is not a bitwise or, it's the word "or"
        opt = k1 or k2  # take first non-zero point, short circuit logic
        if opt & UPPER:  # these are bitwise ANDS
            x = x1 + (x2 - x1) * (ymax - y1) // (y2 - y1)
            y = ymax
        elif opt & LOWER:
            x = x1 + (x2 - x1) * (ymin - y1) // (y2 - y1)
            y = ymin
        elif opt & RIGHT:
            y = y1 + (y2 - y1) * (xmax - x1) // (x2 - x1)
            x = xmax
        elif opt & LEFT:
            y = y1 + (y2 - y1) * (xmin - x1) // (x2 - x1)
            x = xmin
        else:
            raise RuntimeError('Undefined clipping state')

        if opt == k1:
            x1, y1 = x, y
            k1 = _getclip(x1, y1)
        elif opt == k2:
            x2, y2 = x, y
            k2 = _getclip(x2, y2)

    return x1, y1, x2, y2