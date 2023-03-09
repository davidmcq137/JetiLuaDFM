(ns gauge
  (:require
   [clojure.edn :as edn]
   [goog.string :as gstring]
   [clojure.string :as string]
   [shadow.resource :as rc]
   [goog.functions :as gfunc]
   [clojure.walk :as walk]
   [rum.core :as rum]
   [dynamic-repo]))


(def static-input-data [])

(defonce db (atom {}))

(def config-json (js->clj (js/JSON.parse (rc/inline "gauges/config.json"))))

(def release-banner (rc/inline "common/banner.txt"))

(def draw-scale 2)

(def disp-scale
  (if (and (< 2450 js/window.innerWidth)
           (< 600 js/window.innerHeight))
    2
    1))

(def screen-width 318)
(def screen-height 159)

(defn shape->bbox
  [{:strs [radius x0 y0 width height] :as sh}]
  (cond
    (and width height x0 y0)
    (let [halfw (* 0.5 width)
          halfh (* 0.5 height)]
      [(- x0 halfw) (- y0 halfh) width height])
    
    (and radius x0 y0)
    (let [d (* 2 radius)]
      [(- x0 radius) (- y0 radius) d d])

    :else (js/console.error "Cannot determine bounding box" sh)))


(rum/defc bitmap-canvas-drag
  [bmap ix iy k]
  (let [cref (rum/create-ref)
        [{:keys [x y mousedown] :as drag-state} set-drag-state!] (rum/use-state {})
        pos-top (str (or y iy) "px")
        pos-left (str (or x ix) "px")
        scaled-x (js/Math.round
                  (/ (+ (/ (or x ix) disp-scale)
                        (* 0.5 (.-width bmap)))
                     draw-scale))
        scaled-y (js/Math.round
                  (/ (+ (/ (or y iy) disp-scale)
                        (* 0.5 (.-height bmap)))
                     draw-scale))]
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
                       :z-index (if mousedown 998 0)
                       :user-select (if mousedown "none" "auto")}
               :onMouseDown (fn [^js ev]
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
                            (set-drag-state! (assoc drag-state :mousedown nil :x nil :y nil))
                            (when (and x y)
                              (swap! db update-in k update :params assoc
                                     "x0" scaled-x
                                     "y0" scaled-y)))}])))

(defn render-gauge*
  ([i] (render-gauge* i draw-scale))
  ([i scl]
   (let [[x y w h :as bbox] (shape->bbox i)
         c (doto (js/document.createElement "canvas")
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

#_(rum/defc gaugeparam-slider
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

(rum/defc gaugeparam-slider
  < rum/reactive
  [da k props]
  (let [{:keys [params]  :as d} (rum/react da)
        v (get params k)]
    [:span {:style {:display "inline-grid"
                    :grid-template-columns "1fr 5fr"
                    :column-gap "1ch"
                    :align-items "center"
                    :justify-content "space-between"
                    :width "100%"}}
     [:span (str v)]
     [:input 
      (merge
       {:type "range"
        :min 0
        :max 100
        :value (or v 0)
        :onChange (fn [^js ev] 
                    (update-gauge* da assoc k (js/parseFloat (.-value (.-target ev)))))}
       props)]]))


(rum/defc gaugeparam-text < rum/reactive
  [da k]
  (let [{:keys [params] :as d} (rum/react da)
        v (get params k)]
    [:input {:type "text"
             :value (or v "")
             :onChange (fn [^js ev]
                         (update-gauge* da assoc k (.-value (.-target ev))))}]))


(def font-size-options ["Mini" "Normal" "Bold" "Big" "Maxi" "None"])

(rum/defc gaugeparam-fontsize
  < rum/reactive
  [da k]
  (let [{:keys [params]  :as d} (rum/react da)
        v (get params k)]
    [:select
     {:value (or v "Mini")
      :style {:width "8em"
              :justify-self "end"}
      :onChange (fn [ev]
                  (update-gauge* da assoc k (.-value (.-target ev))))}
     (for [fs font-size-options]
       [:option {:key fs  :value fs} fs])]))

(rum/defc gaugeparam-select
  < rum/reactive
  [da k {:strs [options def]}]
  (let [{:keys [params]  :as d} (rum/react da)
        v (get params k)]
    [:select
     {:value (or v def)
      :style {:width "12em"
              :justify-self "end"}
      :onChange (fn [ev]
                  (update-gauge* da assoc k (.-value (.-target ev))))}
     (for [o options]
       (if (string? o)
         [:option {:key o  :value o} o]
         (let [{:strs [value label]} o]
           [:option {:key value :value value} label])))]))

(rum/defc float-input
  [{:keys [value on-change decimal-places] :or {decimal-places 2}}]
  (let [[{:keys [text valid] :as st } set-st!] (rum/use-state {:text value :valid true})]
    (rum/use-effect!
     (fn []
       (let [fx (.toFixed value decimal-places)
             nv (js/parseFloat fx)
             d (- nv (js/parseFloat text) )]
         (when (or (js/isNaN d)
                   (> (js/Math.abs d) (/ 1.0 (js/Math.pow 10 decimal-places))))
           (set-st! {:valid true
                     :text (-> fx
                               (string/replace #"\.0+$" "")
                               (string/replace #"00+$" ""))})))
       nil)
     [value])
    [:input {:type "text"
             :value text
             :style {:outline (if valid "unset" "2px solid tomato")}
             :on-change (fn [^js ev]
                          (let [n (js/parseFloat (.-value (.-target ev)))
                                v? (not (js/isNaN n))]
                            (set-st! {:text (.-value (.-target ev))
                                      :valid v?})
                            (when v? (on-change n))))}]))

(rum/defc gaugeparam-plusminus < rum/reactive
  [da k {:keys [d] :or {d 1} :as opts}]
  (let [{:keys [params]} (rum/react da)
        v (get-in params k)]
    [:span.plusminus {}
     [:input {:type "button"
              :value "-"
              :onClick #(update-gauge* da update-in k dec)}]
     
     (float-input {:value (or v 0)
                   :on-change #(update-gauge* da assoc-in k %)})
     
     [:input {:type "button"
              :value "+"
              :onClick #(update-gauge* da update-in k inc)}]]))

(rum/defc gaugeparam-plusminus-fixed < rum/reactive
  [da k {:keys [d] :or {d 1} :as opts}]
  (let [{:keys [params]} (rum/react da)
        v (get params k)]
    [:span.plusminus {}
     [:input {:type "button"
              :value "-"
              :onClick #(update-gauge* da update k dec)}]
     
     (float-input {:value (or v 0)
                   :on-change #(update-gauge* da assoc k %)})
     
     [:input {:type "button"
              :value "+"
              :onClick #(update-gauge* da update k inc)}]]))

(rum/defc gaugeparam-color < rum/reactive
  [da k]
  (let [{:keys [params]} (rum/react da)
        v (get params k)]
    [:div {:style {:justify-self "end"
                   :display "grid"
                   :align-items "center"
                   :column-gap "2ex"
                   :grid-template-columns "1.5em 8em"}}
     
     (if (string/starts-with? k "#")
       [:input
        {:type :color
         :value k
         :onChange (fn [ev]
                     (update-gauge* da assoc k (.-value (.-target ev))))}]
       [:div
        {:style {:height "2ex"
                 :width "4ex"
                 :background-color v}}])
     
     [:input
      {:type "text"
       :value (or v "transparent")
       :onChange (fn [^js ev]
                   (update-gauge* da assoc k (.-value (.-target ev))))}]]))

(rum/defc edit-spectrum
  < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        {:strs [spectrum]} params
        n (count spectrum)]
    [:div.edit-spectrum {}
     (for [i (range n)
           t [:label :swatch :delete]
           :let [color (nth spectrum i)]]
       (case t
         :swatch
         (if (string/starts-with? color "#")
           [:input
            {:type :color
             :value color
             :key (str "cc" i)
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
                                             (.-value (.-target ev))))}]
         :delete [:input.delete-button
                  {:type :button
                   :value "-"
                   :key (str "d" i)
                   :disabled (< n 2)
                   :onClick (fn []
                              (update-gauge* da update "spectrum"
                                             (fn [v]
                                               (if (< n 2)
                                                 v
                                                 (vec (concat (take i v)
                                                              (drop (inc i) v))) ))))}]))
     [:input
      {:type "button"
       :value "+"
       :onClick #(update-gauge* da update "spectrum" conj "red")}]]))

(rum/defc edit-colorvals
  < rum/reactive
  [da]
  (let [{:keys [params]} (rum/react da)
        cvs (get params "colorvals")
        n (count cvs)]
    [:div.colorvals {}
     (for [i (range n)
           :let [{:strs [val color]} (nth cvs i)
                 minv (if (= i 0)
                        (get params "min")
                        (get (nth cvs (dec i)) "val"))
                 maxv (if (= i (dec n))
                        (get params "max")
                        (get (nth cvs (inc i)) "val"))]
           t [ :label :swatch :range :slider :delete]]
       (case t
         :delete [:input.delete-button
                  {:type :button
                   :key (str "b" i)
                   :value "-"
                   :disabled (< n 2)
                   :onClick (fn []
                              (update-gauge* da
                                             update "colorvals"
                                             (fn [v]
                                               (if (< n 2)
                                                 v
                                                 (vec (concat (take i v)
                                                              (drop (inc i) v))) ))))}]
         :range [:div {:key (str "l" i)}
                 (-> (.toFixed val 3)
                     (string/replace #"\.0+$" "")
                     (string/replace #"0+$" ""))
                 #_(str val)]
         :swatch [:span
                  {:key (str "w" i)
                   :style {:height "2ex"
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
         :slider (let [{:strs [max min majdivs subdivs]} params
                       step (/ (- max min)
                                (* majdivs subdivs))]
                   [:input
                    {:type "range"
                     :key (str "s" i)
                     :min minv
                     :max maxv
                     :step step
                     :value val
                     :onChange (fn [^js ev]
                                 (update-gauge* da assoc-in 
                                                ["colorvals" i "val"]
                                                (js/parseFloat (.-value (.-target ev)))))}])))
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
        {:strs [colorvals spectrum min max] :as kq} params]
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
                                                          (cond-> (for [c colorvals]
                                                                    (get c "color"))
                                                            true vec
                                                            (< max min) reverse)))))}]]
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

(rum/defcs edit-multitext < rum/reactive (rum/local nil ::value)
  [{::keys [value] :as cls} da]
  (let [{:keys [params]} (rum/react da)
        {:strs [text]} params]
    [:textarea
     {:rows (count text)
      :value (or (not-empty (some-> value deref))
               (string/join "\n" text))
      :onChange (fn [^js ev]
                  (let [v (.-value (.-target ev))]
                    (some-> value (reset! v))
                    (update-gauge* da assoc "text"
                                   (string/split v #"\n"))))}]))

(rum/defc textbox-mode-switcher < rum/reactive
  [da]
  (let [{:keys [params]  :as d} (rum/react da)]
   [:div {}
    [:input {:type "button" :value "Line chosen by value"
             :disabled (= "sequencedTextBox" (get params "type"))
             :onClick #(update-gauge* da assoc "type" "sequencedTextBox")}]
    [:input {:type "button" :value "Multi-line"
             :disabled (if (= "stackedTextBox" (get params "type")) true false)
             :onClick #(update-gauge* da assoc "type" "stackedTextBox")}]]))

(def gauge-editor-map (js->clj (js/setupWidgets)))

(defn type->fields
  [t]
  (let [fs? (get gauge-editor-map t)
        fs (if-not (string? fs?)
             fs?
             (get gauge-editor-map fs?))]
    (when-not fs
      (throw (ex-info (str "Don't know about " fs?) {:t t})))
    fs))

(rum/defc gauge-field
  [da {:strs [key label type props]}]
  (rum/fragment
   (when label
     [:span {} label])
   (case type
     "plusminus" (gaugeparam-plusminus-fixed da key)
     "fontsize"  (gaugeparam-fontsize da key)
     "slider"    (gaugeparam-slider da key props)
     "color"     (gaugeparam-color da key)
     "select"    (gaugeparam-select da key props)
     
     "multitext"             (edit-multitext da)
     "textbox-mode-switcher" (textbox-mode-switcher da)
     "spectrum-or-colorvals" (spectrum-or-colorvals da)
     
     (do (js/console.error "No gauge type:" type)
         nil))))

(rum/defc generic-gauge < rum/reactive
  [da]
  (let [{:keys [params] :as d} (rum/react da)
        ty (get params "type")
        fs (type->fields ty)]
    (when-not (seq fs)
      (js/console.error "Cannot get field list" params))
    (rum/fragment
     (for [i (range (count fs))]
       (-> (gauge-field da (nth fs i))
           (rum/with-key i))))))

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
      
      [:span.slider-label "X"]
      (gaugeparam-slider da "x0" {:min 0 :max screen-width})
      [:span.slider-label "Y"]
      (gaugeparam-slider da "y0" {:min 0 :max screen-height})

      (when val [:span.slider-label "Value"])
      (when val
        (let [{:strs [type min max]} (:params d)]
          (case type
            ("textBox" "rawText" "sequencedTextBox" "stackedTextBox")
            (gaugeparam-plusminus da  ["value"])
            
            (let [real-min (clojure.core/min min max)
                  real-max (clojure.core/max min max)]
              (gaugeparam-slider da "value"
                                 {:min  real-min
                                  :max  real-max
                                  :step (* 0.01 (- real-max real-min))})))))]
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

        :onClick (fn []
                   (swap! db update-in
                          [:panels (:selected-panel @db) :gauges]
                          (fn [gs] (assoc gs (count gs) d))))}]
      [:input
       {:type    "button"
        :value   "Delete"
        :onClick #(swap! da assoc :deleted true)}]]
     [:div.sliders
      {:style {:grid-column     "1/4"
               :width           "100%"
               :justify-content "space-between"}}
      (when (:editing d)
        (generic-gauge da))]]))

(defn ask-download-file
  [path contents]
  (let [b (js/Blob. #js [contents])
        u (js/URL.createObjectURL b)
        a (js/document.createElement "a")]
    (set! (.-href a) u)
    (set! (.-download a) path)
    (.click a)))

(defn render-panel
  [pdb w h]
  (let [c (doto (js/document.createElement "canvas")
            (aset "width" w)
            (aset "height" h))
        ctx (.getContext c "2d")
        {:keys [gauges background-image]} pdb
        bg (when background-image
             (doto (js/document.createElement "img")
               (aset "src" background-image)))
        _ (when bg (.drawImage ctx bg 0 0 w h))
        +calc (vec
               (for [[i {:keys [deleted]  :as d}] gauges
                     :when (not deleted)]
                 (merge
                  (:params d)
                  (->> (dissoc (:params d) "value" "label")
                       (clj->js)
                       (js/renderGauge ctx)
                       (js->clj)))))]
    (js/Promise.
     (fn [resolve reject]
       (.toBlob c (fn [b] (resolve {:image b :data +calc}))
                "png")))))

(defn download-json!
  [w h]
  (.then (render-panel (get (:panels @db) (get @db :selected-panel)) w h)
         (fn [{:keys [data]}]
           (ask-download-file "gauges.json" (js/JSON.stringify (clj->js data) nil 2))
           (ask-download-file "gauges.new.json"
                              (js/JSON.stringify
                               (clj->js {:panel data
                                         :timestamp (.toISOString (js/Date.))})
                               nil 2)))))


(defn download-png!
  [w h]
  (.then (render-panel (get (:panels @db) (get @db :selected-panel)) w h)
         (fn [{:keys [image]}]
           (ask-download-file "gauges.png" image))))

(defn blob->base64
  [v]
  (js/Promise.
   (fn [resolve reject]
     (let [fr (doto (js/FileReader.)
               (.readAsDataURL v))]
      (set! (.-error fr) reject)
      (set! (.-onloadend fr) #(resolve (.-result fr)))))))

(defn make-dynamic-repo-request*
  [w h]
  (js/Promise.all
   (into-array
    (for [[panel-name panel] (:panels @db)]
      (.then (render-panel panel w h)
             (fn [{:keys [image data]}]
               (.then (blob->base64 image)
                      (fn [base]
                        #js [{:destination (str "Apps/DFM-InsP/Panels/" panel-name ".json")
                              :json-data (clj->js data)}
                             {:destination (str "Apps/DFM-InsP/Panels/" panel-name ".new.json")
                              :json-data (clj->js {:panel data
                                                   :timestamp (.toISOString (js/Date.))})}
                             {:destination (str "Apps/DFM-InsP/Panels/" panel-name ".png")
                              :data-base64 (subs base (count "data:image/png;base64,"))}]))))))))

(defn make-dynamic-repo-request
  [w h]
  (-> (make-dynamic-repo-request* w h)
      (.then (fn [filesets]
               (clj->js
                {:yoururl js/window.location.origin
                 :apps [{:base-app "DFM-InsP"
                         :dynamic-files (into [] cat filesets)}]})))))


(def localstorage-db-key "gauges-db")
(def save-watch-key :save-watch-key)

(defn encode-edn-string
  [dbval]
  (->> dbval
       (walk/prewalk
        (fn [j]
          (if-not (map? j)
            j
            (dissoc j :bitmap))))
       (pr-str)))

(defn save-to-localstorage!
  [dbval]
  (.setItem js/window.localStorage localstorage-db-key
            (encode-edn-string dbval)))

(defn restore-db!
  [saved-db]
  (reset! db
          (update saved-db :panels
                  (fn [ps]
                    (into {}
                          (for [[pk p] ps]
                            [pk (update p :gauges
                                        (fn [gs]
                                          (into {}
                                                (for [[gk g] gs]
                                                  [gk (merge g (render-gauge* (:params g)))]))))]))))))

(defn load-from-localstorage!
  []
  (when-let [saved-db (some-> js/window.localStorage
                              (.getItem localstorage-db-key)
                              (edn/read-string))]
    (restore-db! saved-db))) 

(defn download-edn!
  []
  (ask-download-file "panels.edn" (encode-edn-string @db)))



(rum/defc app-controls
  [w h]
  [:div
   [:div [:h4 "Background image"]
    [:ul
     [:li [:input {:type "file"
                   :onChange (fn [ev]
                               (when-let [f (first (.-files (.-target ev)))]
                                 (swap! db assoc-in
                                        [:panels (:selected-panel @db) :background-image]
                                        (js/URL.createObjectURL f))))}]]
     [:li [:input {:type "button"
                   :value "Clear"
                   :onClick #(swap! db update-in
                                    [:panels (:selected-panel @db)]
                                    dissoc :background-image)}]]]]
   [:div [:h4 "Download"]
    [:p
     "When you are ready to install the Lua app along with all your created panels, "
     "click here to get the URL to paste into Jeti studio: "
     [:input {:type "button"
              :display "inline"
              :value "Create app source"
              :class "dynamic-repo-button"
              :onClick (fn [ev]
                         (-> (make-dynamic-repo-request w h)
                             (.then dynamic-repo/send-dynamic-repo-request! )))}]]
    
    [:p "You can also manually download this panel's configuration data:"]
    [:ul
     [:li [:input {:type "button"  :value "Download JSON" :onClick #(download-json! w h)}]]
     [:li [:input {:type "button"  :value "Download PNG"  :onClick #(download-png! w h)}]]]]
   
   [:div [:h4 "Backup & restore"]
    [:p "Data for ALL panels can be saved to a file and reloaded.  "
     "Be careful - restoring replaces all your panels!"]
    [:ul
     [:li [:input {:type "button"  :value "Download EDN backup" :onClick #(download-edn!)}]]
     [:li [:label
           "Restore"
           [:input.delete-button
            {:type "file"
             :style {:margin-left "1ch"}
             :onChange (fn [ev]
                         (when-let [f (first (.-files (.-target ev)))]
                           (let [fr (doto (js/FileReader.)
                                      (.readAsText f "utf-8"))]
                             (set! (.-onloadend fr)
                                   #(restore-db! (edn/read-string (.-result fr)))))))}]]]]]
   (dynamic-repo/repo-result-modal)])


(defn reload-json!
  [panel-name url]
  (-> (js/fetch url)
      (.then (fn [fr] (.json fr)))
      (.then (fn [jd]
               (swap! db #(-> %
                              (assoc-in [:panels panel-name]
                                        {:gauges (zipmap (range)
                                                         (map render-gauge* (js->clj jd)))})
                              (assoc :selected-panel panel-name)))))))

(defn new-gauge!
  [new-gauge-type]
  (swap! db update-in
         [:panels (:selected-panel @db) :gauges]
         (fn [gs]
           (assoc gs
                  (count gs)
                  (assoc (render-gauge*
                          (get-in config-json ["prototypes" new-gauge-type])) :editing true)))))

(rum/defc gauge-list-controls
  []
  (let [gauge-types (keys (get config-json "prototypes"))
        [new-gauge-type set-new-gauge-type!] (rum/use-state (first gauge-types))]
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
  [which-panel gauges]
  [:div.gauge-list {}
   (gauge-list-controls)
   [:div
    (for [[i {:keys [deleted]  :as d}] gauges
          :when (not deleted)]
      (rum/with-key (onegauge-editor (rum/cursor-in db [:panels which-panel :gauges i]) i)
        i))]])




(defn get-panel-unique-name
  [proposed]
  (first
   (filter (or (some->> @db :panels (comp not))
               #(do true))
           (map str
                (repeat proposed)
                (cons nil
                      (for [i (range)]
                        (str " (" (inc i) ")")))))))

(rum/defc panel-list-controls
  [sel ps]
  (let [[panel-name set-panel-name!] (rum/use-state "New panel")]
    [:div
     [:input.save-panel-button
      {:type "button"
       :value "Save this panel as:"
       :onClick (fn []
                  (let [uname (get-panel-unique-name panel-name)]
                   (swap! db
                          #(-> %
                               (update :panels assoc uname (get ps sel))
                               (assoc :selected-panel uname)))))}]
     [:input {:type "text"
              :value panel-name
              :onChange (fn [^js ev]
                          (set-panel-name! (.-value (.-target ev))))}]]))


(defn do-panel-rename
  [db old-name new-name]
  (cond-> db
    true (update :panels dissoc old-name)
    true (update :panels assoc new-name (get (:panels db) old-name))
    
    (= old-name (:selected-panel db))
    (assoc :selected-panel new-name)))

(rum/defc panel-renamer
  [ps old-name]
  (let [[new-name set-new-name!] (rum/use-state old-name)
        [collapse set-collapse!] (rum/use-state true)
        taken? (contains? ps new-name)]
    (if collapse
      [:input.panel-rename-button
       {:type "button"
        :value "Rename"
        :onClick #(set-collapse! nil)}]
      
      [:div.panel-rename
       [:input {:type "text"
                :value (or new-name "")
                :placeholder "New name"
                :onChange (fn [^js ev]
                            (set-new-name! (.-value (.-target ev))))}]
       [:input {:type "button"
                :value "OK"
                :disabled taken?
                :onClick (fn [ev]
                           (set-collapse! true)
                           (swap! db do-panel-rename old-name new-name))}]
       [:input {:type "button"
                :value "Cancel"
                :onClick #(set-collapse! true)}]])))

(defn ensure-selected-panel
  [{:keys [panels selected-panel] :as db}]
  (println "Ensure SelectedPanel" selected-panel (keys panels) )
  (cond
    (contains? panels selected-panel) db
    (empty? panels)                   db
    :else                             (assoc db :selected-panel (ffirst panels))))

(defn do-panel-delete
  [db panel-name]
  (-> db
      (update :panels dissoc panel-name)
      (ensure-selected-panel)))

(rum/defc panel-deleter
  [ps panel-name]
  (let [[collapse set-collapse!] (rum/use-state true)]
    (if collapse
      [:input.delete-button
       {:type "button"
        :value "Delete"
        :style {:width "8ex" :justify-self "end"}
        :onClick #(set-collapse! nil)}]
      
      [:div.panel-delete
       [:input.delete-button
        {:type "button"
         :value "Really delete"
         :onClick (fn [ev]
                    (set-collapse! true)
                    (swap! db do-panel-delete panel-name))}]
       [:input {:type "button"
                :value "Cancel"
                :onClick #(set-collapse! true)}]])))

(rum/defc panel-list*
  [sel ps]
  [:div {}
   (when (not-empty ps)
     [:div.panel-list {}
      (for [[panel-name panel] (sort-by first ps)
            c [:select :spacer :rename :delete]]
        (case c
          :rename (rum/with-key (panel-renamer ps panel-name) (str c panel-name))
          :delete (rum/with-key (panel-deleter ps panel-name) (str c panel-name))
          :spacer [:div {:key (str c panel-name)}
                   (when (= panel-name sel) "(editing)")]
          :select [:input {:key (str c panel-name)
                           :type "button"
                           :value panel-name
                           :disabled (= sel panel-name)
                           :onClick #(swap! db assoc :selected-panel panel-name)}]))])
   
   (panel-list-controls sel ps)])

(rum/defc alignment-grid
  [d ww hh]
  (when (and d ww hh)
   [:svg {:width ww
          :height hh
          :viewBox (str "0 0 " ww " " hh) 
          :style {:position :absolute
                  :pointer-events "none"
                  :z-index 999
                  :top 0
                  :left 0
                  :width (str ww "px")
                  :height (str hh "px")}}
    [:g {:stroke "#fff"
         :stroke-width 1
         :stroke-dasharray "8 5"}
     (for [i (range 1 d)]
       [:line {:key i
               :x1 (* i (/ ww d)) :y1 0
               :x2 (* i (/ ww d)) :y2 hh}])
     (for [i (range 1 d)]
       [:line {:key i
               :x1 0 :y1 (* i (/ hh d))
               :x2 ww :y2 (* i (/ hh d))}])]]))

(rum/defc root
  < rum/reactive
  []
  (let [cref (rum/create-ref)
        w screen-width
        h screen-height
        ;; {:keys [gauges panels align-divs background-image] :as gdb} (rum/react db)
        {:keys [panels selected-panel align-divs]} (rum/react db)
        {:keys [gauges background-image]} (get panels selected-panel)]
    [:div.container
     [:div {:style {:margin-left "2ex"
                    :z-index 1000}}
      [:h2 "Instrument Panel creator"]
      #_[:p "This app is for creating instrument panels for use with the companion app on the JETI transmitter."]
      [:p "This web app is for creating instrument panels for display on Jeti transmitters using a Jeti Lua app named DFM-InsP."]
      [:p "Once you have finished drawing your panels here, you will get a link to paste into Jeti studio that will install the Lua app and all of your panels using the Transmitter Wizard."]
      [:p "You assign telemetry sensors to the gauges in the Lua app menus to animate the gauges and text boxes. Fine tuning of labels and fonts can be done on the transmitter."]
      
      
      [:h4 "Example panels"]
      
      [:div.example-panels
       (for [[name {:strs [file]}] (get config-json "examples")]
         [:div {:key (str name)}
          [:input {:type "button" :value name  :onClick #(reload-json! name (str "gauges/" file))}]])]

      [:h4 "My panels"]
      (panel-list* selected-panel panels)
      #_(panel-list selected-panel)
      
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
                             [:panels selected-panel :gauges i]))))
       
       (when align-divs
         (alignment-grid align-divs
                         (* w draw-scale disp-scale)
                         (* h draw-scale disp-scale)))]
      
      [:div {:style {:position "relative"
                     :z-index 1000}}
       [:label 
        "Alignment grid:"
        [:select {:value (or align-divs "none")
                  :style {:margin-left "2ex"}
                  :onChange (fn [ev]
                              (let [s (.-value (.-target ev))]
                                (swap! db assoc :align-divs
                                       (case s
                                         "none" nil
                                         s))))}
         [:option {:value "none"} "none"]
         (for [i [2 3 4 5 6 7 8]]
           [:option {:key i :value (str i)} (str i)])]]]]
     
     (gauge-list selected-panel gauges)]))

(defn ^:def/before-load stop
  []
  (remove-watch db save-watch-key))

(defn ^:dev/after-load init
  []
  (js/console.log "Release:" release-banner)
  (let [el (.getElementById js/document "root")]
    
    (add-watch db save-watch-key
               (-> (fn [_ _ _ new]
                     (save-to-localstorage! new))
                   (gfunc/throttle 5000)))
    
    (rum/mount (root) el)
    
    (-> (fn []
          (or (load-from-localstorage!)
              (reload-json! "Turbine" "gauges/Turbine.json")))
        (js/setTimeout 0))))
