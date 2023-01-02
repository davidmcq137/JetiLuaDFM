(ns gauge
  (:require
    [goog.string :as gstring]
    [clojure.string :as string]
    [shadow.resource :as rc]
    [rum.core :as rum]))


(def static-input-data [])


(defonce db (atom {}))

(def config-json (js->clj (js/JSON.parse (rc/inline "config.json"))))


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
         c (js/OffscreenCanvas. (* w scl) (* h scl))
         ctx (doto (.getContext c "2d")
               (.scale scl scl)
               (.translate (- x) (- y)))]
     (try
       (js/renderGauge ctx (clj->js i))
       (catch :default ex (js/console.log "Render exception" ex)))
     {:bitmap (.transferToImageBitmap c)
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
                    (swap! da merge
                      (render-gauge*
                        (assoc params
                          k
                            (js/parseFloat (.-value (.-target ev)))))))}
       props)]))


(rum/defc gaugeparam-text < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get params k)]
    [:input {:type "text"
             :value (or v "")
             :onChange (fn [^js ev]
                         (swap! da merge
                                (render-gauge*
                                 (assoc params k (.-value (.-target ev))))))}]))


(rum/defc gaugeparam-plusminus < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get-in params k)]
    [:span.plusminus {}
     [:input {:type "button"
              :value "-"
              :onClick #(swap! da merge (render-gauge* (update-in params k dec)))}]
     [:input {:type "text"
              :style {:margin "0 1ex 0 1ex"}
              :value v
              :onChange (fn [^js ev]
                          (swap! da merge
                                 (render-gauge*
                                  (assoc-in params
                                            k
                                            (js/parseInt (.-value (.-target ev)))))))}]
     [:input {:type "button"
              :value "+"
              :onClick #(swap! da merge (render-gauge* (update-in params k inc)))}]]))

(rum/defc edit-spectrum
  < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        {:strs [spectrum]} params]
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
                           (swap! da merge
                             (render-gauge*
                               (assoc-in params
                                 ["spectrum" i]
                                 (.-value (.-target ev))))))}]
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
                              (swap! da merge
                                (render-gauge*
                                  (assoc-in params
                                    ["spectrum" i]
                                    (.-value (.-target ev))))))}]))]))


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
                              (swap! da merge
                                (render-gauge*
                                  (assoc-in params
                                    ["colorvals" i "color"]
                                    (.-value (.-target ev))))))}]
         :slider
           [:input
            {:type "range"
             :key (str "s" i)
             :min minv
             :max maxv
             :value val
             :onChange (fn [^js ev]
                         (swap! da merge
                           (render-gauge*
                             (assoc-in params
                               ["colorvals" i "val"]
                               (js/parseInt (.-value (.-target ev)))))))}]))
     [:input.add-arc
      {:type "button"
       :value "+"
       :onClick #(swap! da merge
                   (render-gauge* (update params
                                          "colorvals"
                                          conj
                                          {"color" "red"
                                           "val" (get params "max")})))}]]))

(rum/defc edit-horizontalbar
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
      [:span.slider-label "Width"]
      (gaugeparam-slider da "width" {:min 10  :max 320})
      [:span.slider-label "Height"]
      (gaugeparam-slider da "height" {:min 10  :max 80})
      [:span.slider-label "Divisions"]
      (gaugeparam-plusminus da ["divs"])
      [:span.slider-label "Subdivisions"]
      (gaugeparam-plusminus da ["subdivs"])
      "Colors"
      (cond (get params "colorvals") (edit-colorvals da)
            (get params "spectrum") (edit-spectrum da)))))


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
      [:span.slider-label "Value"]
      (gaugeparam-slider da
                         "value"
                         {:min (get params "min")
                          :max (get params "max")})
      [:span.slider-label "Divisions"]
      (gaugeparam-plusminus da ["divs"])
      [:span.slider-label "Subdivisions"]
      (gaugeparam-plusminus da ["subdivs"])
      "Colors"
      (cond (get params "colorvals") (edit-colorvals da)
            (get params "spectrum") (edit-spectrum da)))))


(rum/defc edit-textbox
  < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
    (rum/fragment
      [:span.slider-label "Width"]
      (gaugeparam-slider da "width" {:min 10 :max 320})
      [:span.slider-label "Height"]
      (gaugeparam-slider da "height" {:min 10 :max 80})
      #_[:span.slider-label "Value"]
      #_(gaugeparam-text da ["value"]))))

(rum/defc onegauge-editor
  < rum/reactive
  [da i]
  (let [d (rum/react da)
        x0 (get (:params d) "x0")
        y0 (get (:params d) "y0")]
    [:div.onegauge {}
     (when-let [bmap (:bitmap d)]
       (static-bitmap-canvas bmap))
     [:div.sliders
      [:span.slider-label "Label"]
      (gaugeparam-text da "label")
      [:span.slider-label (str "X = " x0)]
      (gaugeparam-slider da "x0" {:min 0  :max 320})
      [:span.slider-label (str "Y = " y0)]
      (gaugeparam-slider da "y0" {:min 0  :max 160})]
     [:div.controls
      [:input
       {:type "button"
        :value (if-not (:editing d) "Edit" "Finish")
        :onClick #(swap! da update :editing not)}]
      [:input
       {:type "button"
        :value (if-not (:hidden d) "Hide" "Show")
        :onClick #(swap! da update :hidden not)}]
      [:input
       {:type "button"
        :value "Duplicate"
        :onClick #(swap! db update :gauges assoc (count (:gauges @db)) d)}]
      [:input
       {:type "button"
        :value "Delete"
        :onClick #(swap! da assoc :deleted true)}]]
     [:div.sliders
      {:style {:grid-column "1/4"
               :width "100%"
               :justify-content "space-between"}}
      (when (:editing d)
        (case (get (:params d) "type")
          "roundGauge" (edit-roundgauge da)
          "textBox" (edit-textbox da)
          "horizontalBar" (edit-horizontalbar da)
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
        ctx (.getContext c "2d")]
    (doseq [[i d] (:gauges @db)]
      (js/renderGauge ctx
                      (clj->js
                       (dissoc (:params d)
                               "value"
                               "label"))))
    (.then (.convertToBlob c)
           (fn [v] (ask-download-file "gauges.png" v)))))


(rum/defc app-controls
  [w h]
  [:div [:h4 "Download"]
   [:ul
    [:li [:input {:type "button"  :value "Download JSON"  :onClick #(download-json! w h)}]]
    [:li [:input {:type "button"  :value "Download PNG"  :onClick #(download-png! w h)}]]]])


(rum/defc panel-list
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


(rum/defc root
  < rum/reactive
  []
  (let [cref (rum/create-ref)
        w 320
        h 160
        gauges (:gauges (rum/react db))]
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
      (app-controls w h)]
     [:div {}
      [:div.composite
       {:style {:width (str (* w draw-scale disp-scale) "px")
                :height (str (* h draw-scale disp-scale) "px")
                :position :relative}}
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
      (reload-json! "/turbine.json"))
    (rum/mount (root) el)))