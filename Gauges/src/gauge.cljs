(ns gauge
  (:require
   [goog.string :as gstring]
   [clojure.string :as string]
   [rum.core :as rum]))

(def static-input-data [])

(def db (atom {}))

(def draw-scale 2)
(def disp-scale 2)

(defn shape->bbox
  [{:strs [type radius x0 y0 width height] :as sh}]
  (case type
    "roundGauge" (let [d (* 2 radius)]
                   [(- x0 radius) (- y0 radius) d d])
    
    ("horizontalBar" "textBox")
    (let [halfw (* 0.5 width)
          halfh (* 0.5 height)]
      [(- x0 halfw) (- y0 halfh) width height])
    
    (println "Do not understand shape of" (pr-str type) "SH" sh)))

(rum/defc bitmap-canvas-drag
  [bmap ix iy k]
  (let [cref (rum/create-ref)
        [{:keys [x y mousedown] :as drag-state} set-drag-state!] (rum/use-state {})
        pos-top (str (or y iy) "px")
        pos-left (str (or x ix) "px")
        scaled-x (js/Math.round
                  (/ (+ (/ (or x ix) draw-scale)
                        (* 0.5 (.-width bmap)))
                     disp-scale))
        
        scaled-y (js/Math.round
                  (/ (+ (/ (or y iy) draw-scale)
                        (* 0.5 (.-height bmap)))
                     disp-scale))]
    
    (rum/use-effect!
     (fn []
       (let [cvs (rum/deref cref)
             ctx (.getContext cvs "2d")]
         (.drawImage ctx bmap 0 0)))
     [bmap])
    
    (rum/fragment
     
     (when mousedown
       [:div
        {:style {:position :absolute
                 :top pos-top
                 :left pos-left}}
        (str scaled-x "," scaled-y)])
     
     [:canvas {:ref cref
               :width (.-width bmap)
               :height (.-height bmap)
               :style {:position :absolute
                       ;; :background-color (if (:mousedown drag-state) "tomato" "peachpuff")
                       :width (* disp-scale (.-width bmap))
                       :height (* disp-scale (.-height bmap))
                       ;; :outline "1px solid blue"
                       :outline (if-not mousedown "none" "1px solid #fff")
                       :top pos-top
                       :left pos-left
                       :z-index (if mousedown 999 0)
                       :user-select (if mousedown "none" "auto")}
               :onMouseDown (fn [^js ev]
                              #_(.preventDefault ev)
                              #_(.stopPropagation ev)
                              (let [ox (.-offsetX (.-nativeEvent ev))
                                    oy (.-offsetY (.-nativeEvent ev))
                                   
                                    cx (.-clientX ev)
                                    cy (.-clientY ev)]
                                (set-drag-state! (assoc drag-state
                                                        :mousedown true
                                                        :xinit cx
                                                        :yinit cy))))
               :onMouseMove (fn [^js ev]
                              (when mousedown
                                (let [dx (- (:xinit drag-state)
                                            (.-clientX ev))
                                      dy (- (:yinit drag-state)
                                            (.-clientY ev))]
                                  (set-drag-state! (assoc drag-state
                                                          :x (- (.-offsetLeft (.-target ev))
                                                                 dx)
                                                          :y (- (.-offsetTop (.-target ev))
                                                                dy)
                                                          :xinit (.-clientX ev)
                                                          :yinit (.-clientY ev))))))
               :onMouseUp (fn [^js ev]
                            #_(.preventDefault ev)
                            #_(.stopPropagation ev)
                            (set-drag-state! (assoc drag-state :mousedown nil :x nil :y nil))
                            (when (and x y)
                              (swap! db update-in k update :params assoc
                                     "x0" scaled-x
                                     "y0" scaled-y)))}])))



(defn render-gauge*
  ([i] (render-gauge* i draw-scale))
  ([i scl]
   (let [[x y w h :as bbox] (shape->bbox i)
         c (js/OffscreenCanvas. (* w scl) (* h scl))
         ctx (doto (.getContext c "2d")
               (.scale scl scl)
               (.translate (- x) (- y)))]

      (js/renderGauge ctx (clj->js i))
    
     { ;; :bbox bbox
      :bitmap (.transferToImageBitmap c)
      :params i})))

(rum/defc static-bitmap-canvas
  [bmap]
  (let [cref (rum/create-ref)]
    
    (rum/use-effect!
     (fn []
       (let [cvs (rum/deref cref)
             ctx (.getContext cvs "2d")]
         (.drawImage ctx bmap 0 0)))
     [bmap])
    
    [:canvas {:ref cref
              :width (.-width bmap)
              :height (.-height bmap)}]))

(rum/defc json-edit-box
  [init-data cursor]
  (let [[state set-state!] (rum/use-state
                            {:data init-data
                             :text (js/JSON.stringify (clj->js init-data) nil 2)
                             :error nil})]
    [:div
     
     [:textarea {:value (:text state)
                 :style {:width "min-content"
                         :height (str (* 1.25 (count (string/split-lines (:text state)))) "em")}
                 :onChange (fn [^js ev]
                             (let [nt (.-value (.-target ev))]
                               (try
                                 (let [nd (js/JSON.parse nt)]
                                   (set-state! {:text nt :data nd :error nil})
                                   (swap! cursor merge (render-gauge* (js->clj nd))))
                                 (catch js/Error e
                                   (set-state! {:text nt :data nil :error (str e)})))))}]
     
     (when-let [err (:error state)]
       [:span.json-error err])]))


(rum/defc gaugeparam-slider < rum/reactive
  [da k props]
  (let [{:keys [params] :as d} (rum/react da)
        v (get params k)]
    [:input (merge
             {:type "range"
              :min 0
              :max 100
              :value v
              :onChange (fn [^js ev]
                          (swap! da
                                 (fn [g]
                                   (render-gauge*
                                    (assoc (:params g)
                                           k
                                           (js/parseFloat (.-value (.-target ev))))))))}
             props)]))

(rum/defc gaugeparam-text < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get params k)]
    [:input {:type "text"
             :value v
             :onChange (fn [^js ev]
                         (swap! da
                                (fn [g]
                                  (render-gauge*
                                   (assoc (:params g) k (.-value (.-target ev)))))))}]))

(rum/defc gaugeparam-plusminus < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get-in params k)]
    [:span.plusminus {}
     [:input {:type "button"
              :value "-"
              :onClick #(swap! da (fn [g] (render-gauge* (update-in (:params g) k dec))))}]
     [:input {:type "text"
              :style {:margin "0 1ex 0 1ex"}
              :value v
              :onChange (fn [^js ev]
                          (swap! da
                                 (fn [g]
                                   (render-gauge*
                                    (assoc-in (:params g)
                                              k
                                              (js/parseInt (.-value (.-target ev))))))))}]
     [:input {:type "button"
              :value "+"
              :onClick #(swap! da (fn [g] (render-gauge* (update-in (:params g) k inc))))}]]))

(rum/defc edit-colorvals < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        cvs (get params "colorvals")
        n (count cvs)]
    [:div.colorvals {}
     (for [i (range (count cvs))
           :let [{:strs [val color]} (nth cvs i)
                 minv (if (= i 0)
                        (get params "min")
                        (get (nth cvs (dec i)) "val"))
                 maxv (if (= i (dec n))
                        (get params "max")
                        (get (nth cvs (inc i)) "val"))]
           t [:label :range :slider]]
       (case t
         :range [:span {:key (str "l" i)} (str val)]
          
         :label [:input {:type "text"
                         :key (str "c" i)
                         :value color
                         :onChange (fn [^js ev]
                                     (swap! da
                                            (fn [g]
                                              (render-gauge*
                                               (assoc-in (:params g)
                                                         ["colorvals" i "color"]
                                                         (.-value (.-target ev)))))))}]
         :slider
         [:input {:type "range"
                  :key (str "s" i)
                  :min minv
                  :max maxv
                  :value val
                  :onChange (fn [^js ev]
                              (swap! da
                                     (fn [g]
                                       (render-gauge*
                                        (assoc-in (:params g)
                                                  ["colorvals" i "val"]
                                                  (js/parseInt (.-value (.-target ev))))))))}]))
     [:input.add-arc
      {:type "button"
       :value "+"
       :onClick #(swap! da (fn [g] (render-gauge* (update (:params g)
                                                          "colorvals"
                                                          conj {"color" "red"
                                                                "val" (get params "max")}))))}]]))

(rum/defc edit-roundgauge < rum/reactive
  [da]
  (let [{:keys [params] :as d} (rum/react da)]
    (rum/fragment
     
     [:span.slider-label "Label"]
     (gaugeparam-text da "label")
     
     [:span.slider-label "Minimum"]
     (gaugeparam-plusminus da ["min"])
     
     [:span.slider-label "Maximum"]
     (gaugeparam-plusminus da ["max"])
     
     [:span.slider-label "Value"]
     (gaugeparam-slider da "value" {:min (get params "min")
                                    :max (get params "max")})
     
     
     
     [:span.slider-label "Divisions"]
     (gaugeparam-plusminus da ["divs"])
     
     [:span.slider-label "Subdivisions"]
     (gaugeparam-plusminus da ["subdivs"])
     
     "Colors"
     (edit-colorvals da))))

(rum/defc onegauge-editor < rum/reactive
  [da]
  (let [d (rum/react da)
        x0 (get (:params d) "x0")
        y0 (get (:params d) "y0")]
    [:div.onegauge
     (static-bitmap-canvas (:bitmap d))
    
     [:div.sliders
      [:span.slider-label (str "X = " x0)]
      [:input {:type "range" :min 0 :max 320
               :value x0
               :onChange (fn [^js ev]
                           (swap! da assoc-in [:params "x0"]
                                  (.-value (.-target ev))))}]
      [:span.slider-label (str "Y = " y0)]
      [:input {:type "range" :min 0 :max 320
               :value y0
               :onChange (fn [^js ev]
                           (swap! da assoc-in [:params "y0"]
                                  (.-value (.-target ev))))}]
      
      (case (get (:params d) "type")
        "roundGauge" (edit-roundgauge da)
        nil)
      
      (when-not (:jsonedit d)
        [:input {:type "button"
                 :value "Edit json"
                 :onClick (fn [] (swap! da assoc :jsonedit true))}])]
   
     (when (:jsonedit d)
       (rum/fragment
        [:input {:type "button"
                 :value "Hide"
                 :onClick (fn [] (swap! da dissoc :jsonedit))}]
        (json-edit-box (:params d) da)))]))

(defn ask-download-file
  [path contents]
  (let [b (js/Blob. #js [contents])
        u (js/URL.createObjectURL b)
        a (js/document.createElement "a")]
    (set! (.-href a) u)
    (set! (.-download a) path)
    (.click a)))

(rum/defc root < rum/reactive
  []
  (let [cref (rum/create-ref)
        w 320
        h 160
        gauges (:gauges (rum/react db))]
    [:div.container
     [:ul.inputs
      (for [[i d] gauges]
        (rum/with-key (onegauge-editor (rum/cursor-in db [:gauges i]))
          i))]
     
     [:div.composite
      {:style {:width (str (* w draw-scale disp-scale) "px")
               :height (str (* h draw-scale disp-scale) "px")
               :position :relative}}

      (for [[i d] gauges
            :when (:bitmap d)
            :let [[x y w h] (shape->bbox (:params d))]]
        (->> i
             (rum/with-key (bitmap-canvas-drag
                            (:bitmap d)
                            (* x draw-scale disp-scale)
                            (* y draw-scale disp-scale)
                            [:gauges i]))))]
     [:ul 
      
      [:input {:type "button"
               :value "Download JSON"
               :onClick (fn []
                          (let [c (js/OffscreenCanvas. w h)
                                ctx (.getContext c "2d")
                                +calc (for [[i d] gauges]
                                        (merge (:params d)
                                               (js->clj (js/renderGauge ctx (clj->js (:params d))))))]
                            
                            (->> (js/JSON.stringify (clj->js +calc) nil 2)
                                 (ask-download-file "gauges.json"))))}]

      [:input {:type "button"
               :value "Download PNG"
               :onClick (fn []
                          (let [c (js/OffscreenCanvas. w h)
                                ctx (.getContext c "2d")]
                            
                            (doseq [[i d] gauges]
                              (js/renderGauge ctx
                                              (clj->js
                                               (dissoc (:params d)
                                                       "value"
                                                       "label"))))
                            
                            (.then (.convertToBlob c)
                                   (fn [v] (ask-download-file "gauges.png" v)))))
               }]]]))

(defn reload-json!
  []
  (-> (js/fetch "/gauges.json")
      (.then (fn [fr] (.json fr)))
      (.then (fn [jd]
               (reset! db
                       {:gauges (zipmap (range)
                                        (map render-gauge* (js->clj jd)))})))))

(defn  ^:dev/after-load init []
  (let [el (.getElementById js/document "root")]
    (reload-json!)

    (rum/mount (root) el)))
