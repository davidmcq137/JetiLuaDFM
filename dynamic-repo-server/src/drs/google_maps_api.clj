(ns drs.google-maps-api
  (:require [clj-http.lite.client :as client]
            [clojure.java.io :as io]
            [cheshire.core :as json])
  (:import [javax.imageio ImageIO]
           [java.awt Graphics2D Color]
           [java.io ByteArrayOutputStream]
           [java.awt.geom AffineTransform]
           [java.awt.image BufferedImage]))

(defn get-elevation*
  [lat lng]
  ;; https://maps.googleapis.com/maps/api/elevation/json
  ;; ?locations=39.7391536%2C-104.9847034
  ;; &key=YOUR_API_KEY
  (-> "https://maps.googleapis.com/maps/api/elevation/json"
      (client/get
       {:as :byte-array
        :query-params {:locations (str lat "," lng)
                       :key (System/getenv "GOOGLE_MAPS_API_KEY")}})
      :body
      io/input-stream
      io/reader
      json/parse-stream))

(defn get-elevation
  [lat lng]
  (let [{:strs [status results]} (get-elevation* lat lng)
        [r & more]               results]
    (cond
      (not= "OK" status) (throw (ex-info "Bad status" {:status status}))
      (some? more)       (throw (ex-info "Multiple results" {:r r :more more}))
      :else              r)))


(defn get-image
  [params]
  (client/get
   "https://maps.googleapis.com/maps/api/staticmap"
   {:as :byte-array
    :query-params (assoc params :key (System/getenv "GOOGLE_MAPS_API_KEY"))}))


(defn meters-per-pixel
  [zoom lat]
  (/ (* 156543.03392 (Math/cos (Math/toRadians lat)))
     (bit-shift-left 1 zoom)))

(defn get-rotated-small-image
  [{:keys [lat lng heading zoom out-width out-height]}]
  (let [out-im (BufferedImage. out-width out-height BufferedImage/TYPE_INT_ARGB)
        zoom-for-google (int (Math/floor zoom))
        sf (Math/pow 2 (- zoom zoom-for-google ))
        map-im (-> {:center (str lat ", " lng)
                    :zoom zoom-for-google
                    :maptype "satellite"
                    :size "640x640"
                    ;; :scale 2
                    }
                   (get-image)
                   :body
                   (io/input-stream)
                   (ImageIO/read))
        out (ByteArrayOutputStream.)]
    (doto (.createGraphics out-im)
      (.transform (doto (AffineTransform.)
                    (.translate (/ (.getWidth out-im) 2.0)
                                (/ (.getHeight out-im) 2.0))
                    (.rotate (Math/toRadians (- heading)))
                    (.scale sf sf)
                    (.translate (- (/ (.getWidth map-im) 2.0))
                                (- (/ (.getHeight map-im) 2.0)))))
      (.setColor Color/YELLOW)
      (.setStroke (java.awt.BasicStroke. 4))
      (.drawRect 0 0 out-width out-height)
      (.drawImage map-im 0 0 nil))
    
    (ImageIO/write out-im "png" out)
    (.close out)
    (.toByteArray out)))



