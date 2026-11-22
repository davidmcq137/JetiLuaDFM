import cv2

## convert image to MDP05 default format
def convertDefault(img):
    img = cv2.rotate(img, cv2.ROTATE_180)
    
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    height = img.shape[0]
    width = img.shape[1]

    ## reduce to 4bpp
    for i in range(height):
        for j in range(width):
            ## convert gray8bit to gray4bit
            img[i, j] = img[i, j] // 16

    return img

## convert image to MDP05 1bpp format
def convert1Bpp(img):
    img = cv2.rotate(img, cv2.ROTATE_180)
    
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    height = img.shape[0]
    width = img.shape[1]

    ## reduce to 1bpp
    for i in range(height):
        for j in range(width):
            ## convert gray8bit in gray1bit
            if (img[i,j] > 0):
                img[i,j] = 1
            else:
                img[i,j] = 0

    return img


## convert image to MDP05 8bpp mono+alpha format
def convert8Bpp(img):
    img = cv2.rotate(img, cv2.ROTATE_180)

    height = img.shape[0]
    width = img.shape[1]

    if len(img.shape)==2:
        isAlpha=False
        mono_alpha_img=img
    elif img.shape[2] == 3:
        isAlpha = False
        mono_alpha_img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    else:
        isAlpha=True
        mono_alpha_img = cv2.cvtColor(img, cv2.COLOR_BGRA2GRAY)

   
    ## mix grayscale and alpha onto 8bpp
    for i in range(height):
        for j in range(width):
            ## convert gray8bit to gray4bit then shift 4 bits left then add alpha converted to 4 bits (defaults to 15)
            grayscale_left = (mono_alpha_img[i,j] // 16) << 4
            # if alpha channel exists we use it
            if isAlpha:
                mono_alpha_img[i, j] = grayscale_left + img[i,j,3] // 16
            # if it does not exists we add full opacity
            else:
                mono_alpha_img[i, j] = grayscale_left + 15

    return mono_alpha_img
