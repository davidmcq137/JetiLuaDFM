(ns gauge
  (:require
    [goog.string :as gstring]
    [clojure.string :as string]
    [shadow.resource :as rc]
    [rum.core :as rum]))


(def static-input-data [])


(defonce db (atom {}))
(defonce panels (atom {})) 


(def config-json (js->clj (js/JSON.parse (rc/inline "config.json"))))


(def draw-scale 2)


(def disp-scale 2)


(defn shape->bbox
  [{:strs [type radius x0 y0 width height] :as sh}]
  (case type
    ("roundGauge" "virtualGauge" "roundNeedleGauge" "roundArcGauge")
    (let [d (* 2 radius)]
      [(- x0 radius) (- y0 radius) d d])
    
    ("horizontalBar" "textBox" "rawText"
     "sequencedTextBox" "stackedTextBox"
     "panelLight")
    (let [halfw (* 0.5 width)
          halfh (* 0.5 height)]
      [(- x0 halfw) (- y0 halfh) width height])
    (println "Do not understand shape of" (pr-str type) "SH" (pr-str sh))))


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
         (.clearRect ctx 0 0 (.-width bmap) (.-height bmap))
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
         c #_(js/OffscreenCanvas. (* w scl) (* h scl))
         (doto (js/document.createElement "canvas")
           (aset "width" (* w scl))
           (aset "height" (* h scl)))
         ctx (doto (.getContext c "2d")
               (.scale scl scl)
               (.translate (- x) (- y)))]
     (try
       (js/renderGauge ctx (clj->js i))
       (catch :default ex (js/console.log "Render exception" ex)))
     {:bitmap c
      :params i})))


(rum/defc static-bitmap-canvas
  [bmap]
  (let [cref (rum/create-ref)]
    (rum/use-effect!
     (fn []
       (when (rum/deref cref)
        (let [cvs (rum/deref cref)
              ctx (.getContext cvs "2d")]
          (.clearRect ctx 0 0 (.-width bmap) (.-height bmap))
          (.drawImage ctx bmap 0 0))))
     [bmap])
    [:canvas {:ref cref
              :width (.-width bmap)
              :height (.-height bmap)}]))

(defn update-gauge*
  ([a f] (swap! a (fn [av] (merge av (render-gauge* (f (:params av)))))))
  ([a f k v] (swap! a (fn [av] (merge av (render-gauge* (f (:params av) k v))))))
  ([a f k v & more]
   (swap! a (fn [av] (merge av (render-gauge* (apply f (:params av) (list* k v more))))))))

(rum/defc gaugeparam-slider
  < rum/reactive
  [da k props]
  (let [{:keys [params]  :as d} (rum/react da)
        v (get params k)]
    [:input
     (merge
      {:type "range"
       :min 0
       :max 100
       :value (or v 0)
       :onChange (fn [^js ev] 
                   (update-gauge* da assoc k (js/parseFloat (.-value (.-target ev)))))}
      props)]))


(rum/defc gaugeparam-text < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get params k)]
    [:input {:type "text"
             :value (or v "")
             :onChange (fn [^js ev]
                         (update-gauge* da assoc k (.-value (.-target ev))))}]))


(rum/defc gaugeparam-plusminus < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get-in params k)]
    [:span.plusminus {}
     [:input {:type "button"
              :value "-"
              :onClick #(update-gauge* da update-in k dec)}]
     [:input {:type "text"
              :style {:margin "0 1ex 0 1ex"}
              :value (or v "0")
              :onChange (fn [^js ev]
                          (update-gauge* da assoc-in k (js/parseInt (.-value (.-target ev)))))}]
     [:input {:type "button"
              :value "+"
              :onClick #(update-gauge* da update-in k inc)}]]))

(rum/defc edit-spectrum
  < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        {:strs [spectrum]} params]
    [:div
     
     [:div.edit-spectrum {}
      (for [i (range (count spectrum))
            t [:swatch :label]
            :let [color (nth spectrum i)]]
        (case t
          :swatch
          (if (string/starts-with? color "#")
            [:input
             {:type :color
              :value color
              :onChange (fn [ev]
                          (update-gauge* da assoc-in
                                         ["spectrum" i]
                                         (.-value (.-target ev))))}]
            [:span
             {:key (str "w" i)
              :style {:height "2ex"
                      :align-self "center"
                      :width "4ex"
                      :background-color color}}])
          :label [:input
                  {:type "text"
                   :key (str "c" i)
                   :value color
                   :onChange (fn [^js ev]
                               (update-gauge* da assoc-in
                                              ["spectrum" i]
                                              (.-value (.-target ev))))}]))]]))


(rum/defc edit-colorvals
  < rum/reactive
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
           t [:label :swatch :range :slider]]
       (case t
         :range [:div {:key (str "l" i)}
                 (str val)]
         :swatch [:span
                  {:key (str "w" i)
                   :style {:height "2ex"
                           :align-self "center"
                           :width "4ex"
                           :background-color color}}]
         :label [:input
                 {:type "text"
                  :key (str "c" i)
                  :value color
                  :onChange (fn [^js ev]
                              (update-gauge* da assoc-in
                                             ["colorvals" i "color"]
                                             (.-value (.-target ev))))}]
         :slider
           [:input
            {:type "range"
             :key (str "s" i)
             :min minv
             :max maxv
             :value val
             :onChange (fn [^js ev]
                         (update-gauge* da assoc-in 
                                        ["colorvals" i "val"]
                                        (js/parseInt (.-value (.-target ev)))))}]))
     [:input.add-arc
      {:type "button"
       :value "+"
       :onClick
       #(update-gauge* da update "colorvals" conj
                       {"color" "red"
                        "val" (get params "max")})}]]))

(rum/defc spectrum-or-colorvals < rum/reactive
  [da]
  (let [{:keys [params] :as d} (rum/react da)
        {:strs [colorvals spectrum] :as kq} params]
    
    (cond
      colorvals (rum/fragment
                 [:div.edit-spectrum-label {}
                  "Manual colors"
                  [:input
                   {:type "button"
                    :value "Auto"
                    :onClick (fn [^js ev]
                               (update-gauge* da
                                              #(-> %
                                                   (dissoc "colorvals")
                                                   (assoc "spectrum"
                                                          (vec
                                                           (for [c colorvals]
                                                             (get c "color")))))))}]]
                 (edit-colorvals da))
      
      spectrum (rum/fragment
                [:div.edit-spectrum-label {}
                 "Auto spectrum"
                 [:input
                  {:type "button"
                   :value "Manual"
                   :onClick (fn [^js ev]
                              (update-gauge* da
                                             #(-> %
                                                  (dissoc "spectrum")
                                                  (assoc "colorvals"
                                                         (js->clj
                                                          (js/returnColorVals
                                                           (clj->js spectrum)
                                                           (get params  "min")
                                                           (get params  "max")))))))
                   :style {:margin-left "2ex"}}]]
                (edit-spectrum da))
      
      :else "Malformed gauge")))

(rum/defc edit-horizontalbar
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label "Width"]
     (gaugeparam-slider da "width" {:min 10  :max 320})
     [:span.slider-label "Height"]
     (gaugeparam-slider da "height" {:min 10  :max 80})
     
     [:span.slider-label "Minimum"]
     (gaugeparam-plusminus da ["min"])
     [:span.slider-label "Maximum"]
     (gaugeparam-plusminus da ["max"])
     
     [:span.slider-label "Divisions"]
     (gaugeparam-plusminus da ["divs"])
     [:span.slider-label "Subdivisions"]
     (gaugeparam-plusminus da ["subdivs"])
     (spectrum-or-colorvals da)
     )))


(rum/defc edit-roundgauge
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label "Radius"]
     (gaugeparam-plusminus da ["radius"])
     [:span.slider-label "Minimum"]
     (gaugeparam-plusminus da ["min"])
     [:span.slider-label "Maximum"]
     (gaugeparam-plusminus da ["max"])
     [:span.slider-label "Divisions"]
     (gaugeparam-plusminus da ["divs"])
     [:span.slider-label "Subdivisions"]
     (gaugeparam-plusminus da ["subdivs"])
     [:span.slider-label "Arc start"]
     (gaugeparam-slider da "start" {:min -180 :max 180})
     [:span.slider-label "Arc end"]
     (gaugeparam-slider da "end" {:min -180 :max 180})
     
     (spectrum-or-colorvals da)
     
     #_ #_"Colors"
     (cond (get params "colorvals") (edit-colorvals da)
           (get params "spectrum") (edit-spectrum da)))))

(rum/defc edit-virtualgauge
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label "Radius"]
     (gaugeparam-plusminus da ["radius"])
     [:span.slider-label "Minimum"]
     (gaugeparam-plusminus da ["min"])
     [:span.slider-label "Maximum"]
     (gaugeparam-plusminus da ["max"])
     [:span.slider-label (str "Arc start = " (get params "start"))]
     (gaugeparam-slider da "start" {:min -180 :max 180})
     [:span.slider-label (str "Arc end = " (get params "end"))]
     (gaugeparam-slider da "end" {:min -180 :max 180})
     [:span.slider-label "Needle clipping"]
     (gaugeparam-slider da "needleClip"))))

(rum/defc edit-multitext < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        {:strs [text]} params]
    [:div.textvalue-list {}
     (for [i (range (count text))
           t [:index :textinput :remove-btn]]
       (case t
         :index [:span {:key (str "i" i)} (str i)]
         :textinput [:input
                     {:type "text"
                      :value (nth text i)
                      :key (str "t" i) 
                      :onChange (fn [^js ev]
                                  (update-gauge* da assoc-in ["text" i]
                                                 (.-value (.-target ev))))}]
         :remove-btn [:input
                      {:type "button"
                       :value "-"
                       :key (str "r" i) 
                       :onClick #(update-gauge* da update "text"
                                                (fn [v]
                                                  (vec (concat (take i v)
                                                               (drop (inc i) v)))))}]))
    
     [:input
      {:type "button"
       :value "+"
       :style {:grid-column 2 :width "8ex"}
       :onClick #(update-gauge* da update "text" conj "")}]]))

(rum/defc edit-textbox
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label (str "Width = " (get params "width"))]
     (gaugeparam-slider da "width" {:min 10 :max 320})
     [:span.slider-label (str "Height = " (get params "height"))]
     (gaugeparam-slider da "height" {:min 10 :max 80})
     
     [:span.slider-label "Text values"]
     (edit-multitext da))))

(rum/defc edit-rawtext
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label (str "Width = " (get params "width"))]
     (gaugeparam-slider da "width" {:min 10 :max 320})
     [:span.slider-label (str "Height = " (get params "height"))]
     (gaugeparam-slider da "height" {:min 10 :max 80})
     
     [:span.slider-label "Font height"]
     (gaugeparam-slider da "fontHeight" {:min 4 :max 80})
     
     [:span.slider-label "Color"]
     (gaugeparam-text da "textColor"))))

(rum/defc edit-panellight
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
     [:span.slider-label "Radius"]
     (gaugeparam-plusminus da ["radius"])
     [:span.slider-label (str "Width = " (get params "width"))]
     (gaugeparam-slider da "width" {:min 10 :max 320})
     [:span.slider-label (str "Height = " (get params "height"))]
     (gaugeparam-slider da "height" {:min 10 :max 80})
     
     [:span "Light color"]
     (gaugeparam-text da "lightColor"))))



(rum/defc onegauge-editor
  < rum/reactive
  [da i]
  (let [d   (rum/react da)
        x0  (get (:params d) "x0")
        y0  (get (:params d) "y0")
        val (get (:params d) "value")]
    [:div.onegauge {}
     (when-let [bmap (:bitmap d)]
       (static-bitmap-canvas bmap))
     [:div.sliders
      [:span.slider-label "Label"]
      (gaugeparam-text da "label")
      [:span.slider-label (str "X = " x0)]
      (gaugeparam-slider da "x0" {:min 0 :max 320})
      [:span.slider-label (str "Y = " y0)]
      (gaugeparam-slider da "y0" {:min 0 :max 160})

      (when val [:span.slider-label "Value"])
      (when val
        (let [{:strs [type min max]} (:params d)]
          (case type
            ("textBox" "rawText" "sequencedTextBox" "stackedTextBox")
            (gaugeparam-plusminus da  ["value"])
            (gaugeparam-slider da "value"
                               {:min  min
                                :max  max
                                :step (* 0.01 (- max min))}))))]
     [:div.controls
      [:input
       {:type    "button"
        :value   (if-not (:editing d) "Edit" "Finish")
        :onClick #(swap! da update :editing not)}]
      
      #_[:input
         {:type    "button"
          :value   (if-not (:hidden d) "Hide" "Show")
          :onClick #(swap! da update :hidden not)}]
      
      [:input
       {:type    "button"
        :value   "Duplicate"
        :onClick #(swap! db update :gauges assoc (count (:gauges @db)) d)}]
      [:input
       {:type    "button"
        :value   "Delete"
        :onClick #(swap! da assoc :deleted true)}]]
     [:div.sliders
      {:style {:grid-column     "1/4"
               :width           "100%"
               :justify-content "space-between"}}
      (when (:editing d)
        (case (get (:params d) "type")
          ("roundGauge" "roundNeedleGauge" "roundArcGauge")
          (edit-roundgauge da)
          
          "textBox"       (edit-textbox da)
          "horizontalBar" (edit-horizontalbar da)
          "virtualGauge"  (edit-virtualgauge da)
          "rawText"       (edit-rawtext da)
          "panelLight"    (edit-panellight da)
          nil))]]))


(defn ask-download-file
  [path contents]
  (let [b (js/Blob. #js [contents])
        u (js/URL.createObjectURL b)
        a (js/document.createElement "a")]
    (set! (.-href a) u)
    (set! (.-download a) path)
    (.click a)))


(defn download-json!
  [w h]
  (let [c (js/OffscreenCanvas. w h)
        ctx (.getContext c "2d")
        +calc (for [[i d] (:gauges @db)]
                (merge (:params d)
                       (js->clj (js/renderGauge ctx (clj->js (:params d))))))]
    (->> (js/JSON.stringify (clj->js +calc) nil 2)
         (ask-download-file "gauges.json"))))


(defn download-png!
  [w h]
  (let [c (js/OffscreenCanvas. w h)
        ctx (.getContext c "2d")
        {:keys [gauges background-image]} @db]
    (when background-image
      (.drawImage ctx
                  (doto (js/document.createElement "img")
                    (aset "src" background-image))
                  0 0 w h))
    
    (doseq [[i {:keys [deleted]  :as d}] gauges
            :when (not deleted)]
      (js/renderGauge ctx
                      (clj->js
                       (dissoc (:params d)
                               "value"
                               "label"))))
    (.then (.convertToBlob c)
           (fn [v] (ask-download-file "gauges.png" v)))))


(rum/defc app-controls
  [w h]
  [:div
   [:div [:h4 "Background image"]
    [:ul
     [:li [:input {:type "file"
                   :onChange (fn [ev]
                               (when-let [f (first (.-files (.-target ev)))]
                                 (swap! db assoc :background-image (js/URL.createObjectURL f))))}]]
     [:li [:input {:type "button"  :value "Clear" :onClick #(swap!  db dissoc :background-image)}]]]]
   [:div [:h4 "Download"]
    [:ul
     [:li [:input {:type "button"  :value "Download JSON"  :onClick #(download-json! w h)}]]
     [:li [:input {:type "button"  :value "Download PNG"  :onClick #(download-png! w h)}]]]]])


#_(rum/defc panel-list
  [ps]
  [:ul
   (for [[k {:panel/keys [name]}] ps]
     [:li.panel-item {}
      (str name)])])


(defn reload-json!
  [url]
  (-> (js/fetch url)
      (.then (fn [fr] (.json fr)))
      (.then (fn [jd]
               (reset! db
                       {:gauges (zipmap (range)
                                        (map render-gauge* (js->clj jd)))})))))

(defn new-gauge!
  [new-gauge-type]
  (swap! db update
    :gauges
    assoc
    (count (:gauges @db))
    (assoc (render-gauge* (get-in config-json ["prototypes" new-gauge-type]))
      :editing true)))




(rum/defc gauge-list-controls
  []
  (let [gauge-types (keys (get config-json "prototypes"))
        [new-gauge-type set-new-gauge-type!] (rum/use-state "roundGauge")]
    [:div
     [:input
      {:type :button
       :value "New"
       :onClick (fn [] (new-gauge! new-gauge-type))}]
     [:select
      {:value new-gauge-type
       :onChange (fn [ev] (set-new-gauge-type! (.-value (.-target ev))))}
      (for [gt gauge-types]
        [:option {:key gt  :value gt} gt])]]))


(rum/defc gauge-list
  [gauges]
  [:div.gauge-list {}
   (gauge-list-controls)
   [:div
    (for [[i {:keys [deleted]  :as d}] gauges
          :when (not deleted)]
      (rum/with-key (onegauge-editor (rum/cursor-in db [:gauges i]) i)
                    i))]])


(rum/defc panel-list-controls
  [ps]
  (let [[panel-name set-panel-name!] (rum/use-state "New panel")]
    [:div
     [:input {:type "button"
              :value "Save as:"
              :onClick #(swap! panels assoc
                               @panels
                               (assoc @db :panel/name panel-name))}]
     [:input {:type "text"
              :value panel-name
              :onChange (fn [^js ev]
                          (set-panel-name! (.-value (.-target ev))))}]]))


(rum/defc panel-list*
  [ps]
  [:div {}
   (when (not-empty ps)
     [:ul.panel-list {}
      (for [[i {:panel/keys [name] :as p}] ps]
        [:li {:key i}
         [:input {:type "button"
                  :value name
                  :onClick (fn []
                             (reset! db p))}]])])
   
   
   (panel-list-controls ps)])

(rum/defc panel-list < rum/reactive
  []
  (panel-list* (rum/react panels)))

(rum/defc root
  < rum/reactive
  []
  (let [cref (rum/create-ref)
        w 320
        h 160
        {:keys [gauges panels background-image]} (rum/react db)]
    [:div.container
     [:div {:style {:margin-left "2ex"}}
      [:h2 "Gauge creator"]
      [:p "This app is for creating instrument panels for use with the companion"
       " app on the JETI transmitter."]
      
      [:h4 "Example panels"]
      [:ul.example-panel-list
       (for [[name {:strs [file]}] (get config-json "examples")]
         [:li {:key (str name)}
          [:input {:type "button"  :value name  :onClick #(reload-json! (str "/" file))}]])]

      [:h4 "My panels"]
      (panel-list panels)
      
      (app-controls w h)]
     [:div {}
      [:div.composite
       {:style (cond-> {:width (str (* w draw-scale disp-scale) "px")
                        :height (str (* h draw-scale disp-scale) "px")
                        :position :relative}
                 background-image (assoc :background-image (str "url(" background-image ")")
                                         :background-size "cover"))}
       (for [[i d] gauges
             :when (and (:bitmap d) (not (or (:hidden d) (:deleted d))))
             :let [[x y w h] (shape->bbox (:params d))]]
         (->> i
              (rum/with-key (bitmap-canvas-drag
                             (:bitmap d)
                             (* x draw-scale disp-scale)
                             (* y draw-scale disp-scale)
                             [:gauges i]))))]]
     (gauge-list gauges)]))


(defn ^:dev/after-load init
  []
  
  (let [el (.getElementById js/document "root")]
    (when (empty? @db)
      (reload-json! "/Turbine.json"))
    (rum/mount (root) el)))
