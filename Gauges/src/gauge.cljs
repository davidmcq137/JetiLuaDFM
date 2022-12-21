(ns gauge
  (:require
   [goog.string :as gstring]
   [clojure.string :as string]
   [rum.core :as rum]))

(def static-input-data [])

(def db (atom {}))

(defn shape->bbox
  [{:strs [type radius x0 y0 width height]}]
  (case type
    "roundGauge" (let [d (* 2 radius)]
                   [(- x0 radius) (- y0 radius) d d])
    
    ("horizontalBar" "textBox")
    (let [halfw (* 0.5 width)
          halfh (* 0.5 height)]
      [(- x0 halfw) (- y0 halfh) width height])
    
    nil))

(rum/defc bitmap-canvas-drag
  [bmap ix iy k scl]
  (let [cref (rum/create-ref)
        [^js drag-state set-drag-state!] (rum/use-state {})]
    (rum/use-effect!
     (fn []
       (let [cvs (rum/deref cref)
             ctx (.getContext cvs "2d")]
         (.drawImage ctx bmap 0 0)))
     [bmap])
    
    
    [:canvas {:ref cref
              :width (.-width bmap)
              :height (.-height bmap)
              :style {:position :absolute
                      ;; :background-color (if (:mousedown drag-state) "tomato" "peachpuff")
                      :width (* scl (.-width bmap))
                      :height (* scl (.-height bmap))
                      ;; :outline "1px solid blue"
                      :border (if-not (:mousedown drag-state) "none" "1px solid #fff")
                      :top (str (or (:y drag-state) iy) "px")
                      :left (str (or (:x drag-state) ix) "px")
                      :z-index (if (:mousedown drag-state) 999 0)
                      :user-select (if (:mousedown drag-state) "none" "auto")}
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
                             (when (:mousedown drag-state)
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
                           (swap! db update-in k update :params assoc
                                  "x0" (+ (/ (:x drag-state) scl)
                                          (* 0.5 (.-width bmap)))
                                  "y0" (+ (/ (:y drag-state) scl)
                                          (* 0.5 (.-height bmap)))))}]))



(defn render-gauge*
  [i]
  (let [[x y w h :as bbox] (shape->bbox i)
        c (js/OffscreenCanvas. w h)
        ctx (doto (.getContext c "2d")
              (.translate (- x) (- y)))]

    (js/renderGauges ctx (clj->js [i]))
    
    { ;; :bbox bbox
     :bitmap (.transferToImageBitmap c)
     :params i}))

(defn render-gauges!
  []
  (reset! db
          {:gauges (zipmap (range)
                           (map render-gauge* static-input-data))}))


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

(rum/defc onegauge-editor < rum/reactive
  [da]
  (let [d (rum/react da)]
    [:div.onegauge
     (static-bitmap-canvas (:bitmap d))
    
     [:div.sliders
      [:span.slider-label "X"]
      [:input {:type "range" :min 0 :max 320
               :value (get (:params d) "x0")
               :onChange (fn [^js ev]
                           (swap! da assoc-in [:params "x0"]
                                  (.-value (.-target ev))))}]
      [:span.slider-label "Y"]
      [:input {:type "range" :min 0 :max 320
               :value (get (:params d) "y0")
               :onChange (fn [^js ev]
                           (swap! da assoc-in [:params "y0"]
                                  (.-value (.-target ev))))}]
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
        scl 4
        gauges (:gauges (rum/react db))]
    [:div.container
     [:ul.inputs
      (for [[i d] gauges]
        (rum/with-key (onegauge-editor (rum/cursor-in db [:gauges i]))
          i))]
     
     [:div.composite
      {:style {:width (str (* w scl) "px")
               :height (str (* h scl) "px")
               :position :relative}}

      (for [[i d] gauges
            :when (:bitmap d)
            :let [[x y w h] #_(:bbox d)
                  (shape->bbox (:params d))]]
        (->> i
             (rum/with-key (bitmap-canvas-drag
                            (:bitmap d) (* x scl) (* y scl)
                            [:gauges i]
                            scl))))]
     [:ul 
      
      [:input {:type "button"
               :value "Download JSON"
               :onClick (fn []
                          (ask-download-file
                             "gauges.json"
                             (-> (map :params (vals gauges))
                                 (clj->js)
                                 (js/JSON.stringify nil 2))))}]

      [:input {:type "button"
               :value "Download PNG"
               :onClick (fn []
                          (let [c (js/OffscreenCanvas. w h)
                                ctx (.getContext c "2d")]
                            
                            (doseq [[i d] gauges]
                              (js/renderGauges ctx (clj->js [(:params d)])))
                            
                            (.then (.convertToBlob c)
                                   (fn [v] (ask-download-file "gauges.png" v)))))
               }]]]))

(defn  ^:dev/after-load init []
  (let [el (.getElementById js/document "root")]
    (-> (js/fetch "/gauges.json")
        (.then (fn [fr] (.json fr)))
        (.then (fn [jd]
                 (reset! db
                         {:gauges (zipmap (range)
                                          (map render-gauge* (js->clj jd)))}))))

    (rum/mount (root) el)))
