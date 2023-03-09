(ns triangle.client.main
  (:require
   [clojure.string :as string]
   [clojure.edn :as edn]
   [cljs.core.async :as async]
   [triangle.client.download :as dl]
   [triangle.client.landing :as landing]
   [cljs.pprint :as pprint]
   [rum.core :as rum]
   [datascript.core :as d]
   #_[datascript.serialize :as dser]
   [goog.object :as gobj]
   [goog.functions :as gfunc]
   [goog.date :as gdate])
  (:import
   [goog.net XhrIo]
   [goog.async Debouncer]
   [goog.net EventType]
   [goog.string format])
  (:require-macros
   [cljs.core.async.macros :refer [go go-loop]]))

(declare gmaps-force-render)

(def ^:dynamic *debug-q* false)

(defn -q [q & args]
  (if *debug-q*
    (let [key (str q)
          _   (.time js/console key)
          res (apply d/q q args)
          _   (.timeEnd js/console key)]
      res)
    (apply d/q q args)))

(defn qes
  "If queried entity ids, return all entities of result"
  [q db & sources]
  (->> (apply -q q db sources)
       (map #(d/entity db (first %)))))

(defn qes-by
  "Return all entities by attribute existence or specific value"
  ([db attr]
   (qes '[:find ?e :in $ ?a :where [?e ?a]] db attr))
  ([db attr value]
   (qes '[:find ?e :in $ ?a ?v :where [?e ?a ?v]] db attr value)))

(def datascript-schema
  {
   ;; map singleton db/ident ::map
   :map/center-lat {}
   :map/center-lng {}
   :map/marker-complete-action {}
   
   ;; state singleton ::state
   :state/current-field {:db/valueType :db.type/ref}
   :state/save-status {:persistence :ephemeral}
   :state/current-tab {}
   :state/modal {}
   
   :state/dynamic-repo-git-ref {:deprecated true}
   
   :state/selected-release {:db/valueType :db.type/ref}
   :state/release-deletion-warning {}
   :state/show-prereleases {}
   
   :state/releases {:db.valueType :db.type/ref
                    :db.cardinality :db.cardinality/many}
   
   :release/id {:db/unique :db.unique/identity}
   :release/name {}
   :release/created-at {}
   :release/published-at {}
   :release/zip-url {}
   :release/html-url {}
   :release/prerelease {}
   :release/deleted {}
   
   
   :zone/type {:db/index true}
   :zone/center-lat {}
   :zone/center-lng {}
   :zone/heading {}
   :zone/length-m {}
   :zone/width-m {}
   :zone/hidden {}
   :zone/map.marker {:persistence :ephemeral}
   :zone/map.polygon {:persistence :ephemeral}
   :zone/map.circle {:persistence :ephemeral}
   :zone/polygon.path {}   
   
   :nofly/inside-outside {}
   :nofly/type {}                       ; circle or polygon
   :nofly/circle.radius {}
   :nofly/circle.original-radius {}
   
   :triangle/size-m {}
   
   :clipbox/preview-zoom {} 
   
   :field/name {}
   :field/short-name {}
   :field/clipbox {:db/valueType :db.type/ref
                   :db/cardinality :db.cardinality/many}
   :field/current-clipbox {:db/valueType :db.type/ref}
   :field/heading {}
   :field/runway {:db/valueType :db.type/ref}
   :field/triangle {:db/valueType :db.type/ref}
   :field/noflys {:db/valueType :db.type/ref
                  :db/cardinality :db.cardinality/many}
   :field/editing-name {}

   :image/data-url {:persistence :ephemeral}})

(defmulti attach-zone! :zone/type)
(defmulti create-zone* :zone/type)

(defmethod create-zone* :default [thing]
  (println "Dfealt" thing))

(defn create-zone!
  ([zone]
   (when-not (:zone/hidden zone)
     (create-zone* zone)))
  ([zone force?]
   (if force?
     (create-zone* zone)
     (create-zone! zone))))

(def default-db-conn
  (doto (d/create-conn datascript-schema)
    (d/transact!
     [{:db/ident ::map
       :map/center-lat 39.147398
       :map/center-lng -77.337639}
      {:db/ident ::state
       :state/save-status "No save status"
       :state/current-tab :map
       :state/dynamic-repo-git-ref "master"
       }])))

(def conn (d/conn-from-db @default-db-conn))

(def bus (async/chan))
(def pub (async/pub bus first))

(defonce the-map (atom nil))
(defonce the-drawing-manager (atom nil))


(defn db-transact-debouncer
  [func]
  (Debouncer. func 77))

(defn new-random-token [n-random-bytes]
  (let [alphabet "234679CDFGHJRTWX"
        bs (doto (js/Uint8Array. n-random-bytes)
               (js/window.crypto.getRandomValues))]
   (apply str
          (for [i (range (.-length bs))]
            (str (nth alphabet (bit-shift-right (bit-and (aget bs i) 2r00001111) 0))
                 (nth alphabet (bit-shift-right (bit-and (aget bs i) 2r11110000) 4)))))))

(defn get-or-create-token! []
  (let [key  "user-id-token"]
    (or (.getItem js/window.localStorage key)
        (let [t (new-random-token 4)]
          (.setItem js/window.localStorage key t)
          t))))

(defn encode-db-for-save
  [db]
  {:schema datascript-schema
   :datoms
   (vec
    (keep
     (fn [[e a v t added?] ]
       (when-not added?
         (println "Retraction?"))
       (when (not= :ephemeral (:persistence (get datascript-schema a)))
         [e a v t]))
     (d/datoms db :eavt)))})

(defn load-db-from-edn-string
  [s]
  (let [{:keys [schema datoms]} (edn/read-string s)
        loaded-db @(d/conn-from-datoms
                    (vec
                     (for [[e a v t] datoms]
                       (d/datom e a v t)))
                    datascript-schema)
        new-defaults (for [[e a v t] (d/datoms @default-db-conn :eavt)
                           :when (nil? (d/datoms loaded-db :eavt e a))]
                       [:db/add e a v])]
    (d/reset-conn! conn (d/db-with loaded-db new-defaults))
    (d/transact! conn [{:db/ident ::state :state/save-status "Just loaded"}])
    (swap! gmaps-force-render inc)))

#_(defn load-db!
    [text]
    (let [{:keys [schema datoms]} (edn/read-string text)]
      (when (not= schema datascript-schema)
        (println "The schema was different")
        (doseq [[k v] schema]
          (when (not= v (get datascript-schema k))
            (prn k v (get datascript-schema k)))))
      (run! prn datoms)
      (reset! conn @(d/conn-from-datoms
                     (for [[e a v t] datoms]
                       (d/datom e a v t))
                     datascript-schema))))




(def localstorage-db-key "db-edn-string")


(d/listen!
 conn
 (-> (fn [{:keys [tx-data tempids] :as tx-report}]
       (when (->> (map (comp :persistence datascript-schema :a) tx-data)
                  (some (partial not= :ephemeral)))
         (.setItem js/window.localStorage
                   localstorage-db-key
                   (encode-db-for-save @conn))))
     (gfunc/throttle 5000)))

#_(d/listen! conn
             (-> (fn [{:keys [tx-data tempids] :as tx-report}]
                   (when (->> (map (comp :persistence datascript-schema :a) tx-data)
                              (some (partial not= :ephemeral)))

                     (let [xhr (XhrIo.)
                           stx (:db/current-tx tempids)]
                       (d/transact! conn [{:db/ident ::state :state/save-status (str "saving " stx)}])
                       (.listen xhr EventType/COMPLETE
                                (fn [_] 
                                  (println "Save complete")
                                  (d/transact! conn [{:db/ident ::state
                                                      :state/save-status
                                                      ;; https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/readyState
                                                      (str "save request "
                                                           (pr-str stx)
                                                           " "
                                                           (case (.getReadyState xhr)
                                                             0 "unsent"
                                                             1 "opened"
                                                             2 "headers"
                                                             3 "loading"
                                                             4 "done"))}])))
                       (println "Saving")
                       (.send xhr (str "/save?token=" (get-or-create-token!)) "PUT"
                              (pr-str (for [[e a v t] (d/datoms @conn :eavt)
                                            :when (->> a (get datascript-schema) :persistence (not= :ephemeral))]
                                        [e a v t]))))))
                 (gfunc/throttle 5000)))


(defn register-sub
  [topic action]
  (let [ch (async/chan)]
    (async/sub pub topic ch)
    (go-loop []
      (action (async/<! ch))
      (recur))))

(register-sub ::tab-switch
              (fn [[_ new-tab]]
                (d/transact! conn [{:db/ident ::state
                                    :state/current-tab new-tab}])))

(register-sub ::map-recenter
              (fn [[_ nlat nlng]]
                (let [c (.getCenter @the-map)
                      lat (or nlat (.lat c))
                      lng (or nlng (.lng c))]
                  (.setCenter @the-map (js/google.maps.LatLng. lat lng))
                  (d/transact! conn [{:db/ident ::map
                                      :map/center-lat lat 
                                      :map/center-lng lng}]))))

(defn offset-point
  [lat lng m-north m-east]
  (let [earth-radius-m 6378137
        m-lat (/ 360 (* 2 js/Math.PI earth-radius-m))]
    #js{:lat (+ lat (* m-north m-lat))
        :lng (+ lng (/ (* m-east m-lat)
                       (js/Math.cos (/ (* lat js/Math.PI) 180))))}))

(defn rectangle-path
  [lat lng heading {:zone/keys [width-m length-m]}]
  (let [theta (* heading (/ js/Math.PI 180))
        vy (* 0.5 length-m (js/Math.sin theta))
        vx (* 0.5 length-m (js/Math.cos theta))
        hy (* 0.5 width-m (js/Math.sin (+ theta (/ js/Math.PI 2))))
        hx (* 0.5 width-m (js/Math.cos (+ theta (/ js/Math.PI 2))))]
    #js [(offset-point lat lng (- vx hx) (- vy hy))
         (offset-point lat lng (+ vx hx) (+ vy hy))
         (offset-point lat lng (- hx vx) (- hy vy))
         (offset-point lat lng (- 0 hx vx) (- 0 hy vy))]))

(defn clipbox-path
  [lat lng heading {:zone/keys [width-m length-m]}]
  (let [theta (* heading (/ js/Math.PI 180))
        vy (* 0.5 length-m (js/Math.sin theta))
        vx (* 0.5 length-m (js/Math.cos theta))
        hy (* 0.5 width-m (js/Math.sin (+ theta (/ js/Math.PI 2))))
        hx (* 0.5 width-m (js/Math.cos (+ theta (/ js/Math.PI 2))))]
    
    #js [(offset-point lat lng (- vx hx) (- vy hy)) ; top left
         ;; (offset-point lat lng  0 0) ; pointy bit
         (offset-point lat lng (+ vx hx) (+ vy hy)) ; top right
         (offset-point lat lng (- hx vx) (- hy vy)) ; bottom right
         (offset-point lat lng (- 0 hx vx) (- 0 hy vy)) ; bottom left
         ]))

(defn triangle-path
  [lat lng heading {:triangle/keys [size-m]}]
  (let [theta (* heading (/ js/Math.PI 180))
        vy (* size-m (js/Math.sin theta))
        vx (* size-m (js/Math.cos theta))
        hy (* size-m (js/Math.sin (+ theta (/ js/Math.PI 2))))
        hx (* size-m (js/Math.cos (+ theta (/ js/Math.PI 2))))]
    #js [(offset-point lat lng vx vy)
         (offset-point lat lng hx hy)
         (offset-point lat lng (- hx) (- hy))]))

(defn polygon->clj-path
  [path]
  (vec
   (map-indexed
    (fn [i pt]
      {:lat (.lat pt)
       :lng (.lng pt)})
    (js->clj (.getArray (.getPath path))))))

(defn clj-path->js
  [path]
  (clj->js
   (for [{:keys [lat lng]} path]
     (js/google.maps.LatLng. lat lng))))

(def update-zone-transact-debounced!
  (let [d (-> (fn [zone-eid lat lng hdg path]
                (let [txn (cond-> [[:db/add zone-eid :zone/polygon.path path]]
                            lat (conj [:db/add zone-eid :zone/center-lat lat])
                            lng (conj [:db/add zone-eid :zone/center-lng lng])
                            hdg (conj [:db/add zone-eid :zone/heading    hdg]))]
                  #_(println "Transact" txn)
                  (d/transact! conn txn)))
              (Debouncer. 66))]
    (fn [z lat lng hdg path] (.fire d z lat lng hdg path))))

(def update-map-center-transact-debounced!
  (let [d (-> (fn [lat lng]
                (d/transact! conn [{:db/ident ::map
                                    :map/center-lat lat 
                                    :map/center-lng lng}]))
              
              (Debouncer. 66))]
    (fn [lat lng] (.fire d lat lng))))

(defn update-zone!
  [zone lat lng hdg] 
  (let [new-path ((case (:zone/type zone)
                    :runway rectangle-path
                    ;; :clipbox rectangle-path
                    :clipbox clipbox-path
                    :triangle triangle-path
                    (println "No path for zone"))
             
                  (or lat (:zone/center-lat zone))
                  (or lng (:zone/center-lng zone))
                  (or hdg (:zone/heading zone))
                  zone)]
    (when new-path
      (update-zone-transact-debounced! (:db/id zone) lat lng hdg new-path)
      (some-> (:zone/map.polygon zone)
              (.setPath new-path)))))







(declare detach-zone!)

(defn detach-field-zones!
  [field]
  (when-let [r (:field/runway field)]
    (detach-zone! r))
  (when-let [t (:field/triangle field)]
    (detach-zone! t))
  (doseq [nf (:field/noflys field)]
    (detach-zone! nf))
  (doseq [cb (:field/clipbox field)]
    (detach-zone! cb)))

(defn field->zones
  [field]
  (filterv some?
   (concat
    [(:field/runway field)
     (:field/triangle field)]
    (:field/noflys field)
    (:field/clipbox field))))

(register-sub ::select-field
              (fn [[_ field]]
                (let [{:state/keys [current-field]} (d/entity @conn ::state)]
                  (some->> current-field field->zones (run! detach-zone!)))

                (d/transact! conn [{:db/ident ::state
                                    :state/current-field (:db/id field)}])
                (when-let [{:zone/keys [center-lat center-lng]} (first (:field/clipbox field))]
                  (.setCenter @the-map (js/google.maps.LatLng. center-lat center-lng)))
                
                (when-let [r (:field/runway field)]
                  (attach-zone! r))
                (when-let [t (:field/triangle field)]
                  (attach-zone! t))
                (doseq [nf (:field/noflys field)]
                  (attach-zone! nf))
                (doseq [cb (:field/clipbox field)]
                  (attach-zone! cb))))

(register-sub ::deselect-field
              (fn [[_ field]]
                (run! detach-zone! (field->zones field))))

(defn setup-zone-marker-listeners!
  [zone]
  (let [marker (:zone/map.marker zone)
        zone-eid (:db/id zone)]
    (when marker
      (doto marker
        (js/google.maps.event.addListener
         "rightclick" #(async/put! bus [::remove-zone zone-eid])) 
        (js/google.maps.event.addListener
         "drag" (fn [a b c d]
                  (update-zone! (d/entity @conn zone-eid)
                                (.lat (.getPosition marker))
                                (.lng (.getPosition marker))
                                nil)))))))

(defn detach-zone! [zone]
  (some-> zone :zone/map.marker (.setMap nil))
  (some-> zone :zone/map.polygon (.setMap nil))
  (some-> zone :zone/map.circle (.setMap nil)))

(defn reattach-zone! [zone]
  (some-> zone :zone/map.marker (.setMap @the-map))
  (some-> zone :zone/map.polygon (.setMap @the-map))
  (some-> zone :zone/map.circle (.setMap @the-map)))

(defmethod attach-zone! :runway [zone]
  (setup-zone-marker-listeners! zone)
  (reattach-zone! zone)
  (update-zone! zone nil nil nil))

(defmethod attach-zone! :clipbox [zone]
  (setup-zone-marker-listeners! zone)
  (reattach-zone! zone)
  (update-zone! zone nil nil nil))

(defmethod attach-zone! :triangle [zone]
  (setup-zone-marker-listeners! zone)
  (reattach-zone! zone)
  (update-zone! zone nil nil nil))

(defn create-marker-controlled-poly!
  [{:zone/keys [center-lat center-lng] :as zone}]
  {:db/id (:db/id zone)
   :zone/map.polygon (js/google.maps.Polygon. #js{:strokeOpacity 0.8
                                                  :strokeWeight 2})
   :zone/map.marker (js/google.maps.Marker. #js{:draggable true
                                                :position (js/google.maps.LatLng. center-lat center-lng)})})

(defmethod create-zone* :runway   [zone] (create-marker-controlled-poly! zone))
(defmethod create-zone* :triangle [zone] (create-marker-controlled-poly! zone))
(defmethod create-zone* :clipbox  [zone]
  (create-marker-controlled-poly! zone))

(register-sub ::place-runway-center
              (fn [[_ lat lng]]
                (let [runway {:db/id "runway"
                              :zone/type :runway
                              :zone/center-lat lat
                              :zone/center-lng lng
                              :zone/heading 0
                              :zone/length-m 100
                              :zone/width-m 10}
                      
                      {:state/keys [current-field]} (d/entity @conn ::state)
                      {:keys [tempids]} (d/transact! conn [runway
                                                           (create-zone! runway)
                                                           {:db/id (:db/id current-field)
                                                            :field/runway "runway"}])]
                  (attach-zone! (d/entity @conn (get tempids "runway"))))))

(defn staticmap-meters-per-pixel
  [zoom lat]
  (/ (* 156543.03392
        (js/Math.cos (* lat (/ js/Math.PI 180))))
     (js/Math.pow 2 zoom)))

(defn staticmap-pixels-per-meter
  [zoom lat]
  (/ 1 (staticmap-meters-per-pixel zoom lat)))

(defn set-clipbox-zoom* [{:zone/keys [center-lat center-lng] :as c} zoom]
  (let [mpp (staticmap-meters-per-pixel zoom center-lat)]
    {:clipbox/preview-zoom zoom
     :zone/length-m (* 160 mpp)
     :zone/width-m (* 320 mpp)
     }))

(defn set-clipbox-zoom [c zoom]
  (cond-> (set-clipbox-zoom* c zoom)
    (:db/id c) (assoc :db/id (:db/id c))))

(defn make-clipbox [zoom lat lng]
  (-> {:zone/type :clipbox
       :zone/center-lat lat
       :zone/center-lng lng
       :zone/heading 0}
      (set-clipbox-zoom* zoom)))

(def zoom-levels [14 14.5 15 15.5 16 16.5 17])


(register-sub ::create-field
              (fn [[_]]
                (let  [{:map/keys [center-lat center-lng]} (d/entity @conn ::map)
                       {:state/keys [current-field]} (d/entity @conn ::state)
                       _ (when current-field
                           (async/put! bus [::deselect-field current-field]))
                       clipbox-template {:zone/type :clipbox
                                         :zone/center-lat center-lat
                                         :zone/center-lng center-lng
                                         :zone/heading 0
                                         :zone/hidden true}
                       default-clip (assoc clipbox-template
                                           :db/id "default-clip"
                                           :zone/hidden false)
                       tx [{:db/ident ::state :state/current-field "field"}
                           (create-zone! default-clip)
                           {:db/id "field"
                            :field/name "Unnamed field"
                            :field/short-name "NONAME"
                            :field/current-clipbox "default-clip"
                            :field/clipbox (for [i zoom-levels]
                                             (cond-> (merge clipbox-template (set-clipbox-zoom* clipbox-template i))
                                               (= i 17) (merge default-clip)))}]
                       {:keys [tempids]} (d/transact! conn tx)]
                  
                  (attach-zone! (d/entity @conn (get tempids "default-clip"))))))

(defn sorted-clipboxes
  [f]
  (sort-by
   #(- 0 (:clipbox/preview-zoom %))
   (:field/clipbox f)))

(register-sub ::align-bottoms
              (fn [[_]]
                (let [{:state/keys [current-field]} (d/entity @conn ::state)
                      cbs (sorted-clipboxes current-field)
                      {:zone/keys [center-lat center-lng heading] :as sc} (first cbs)
                      rads (* heading (/ js/Math.PI 180))]
                  (d/transact!
                   conn 
                   (for [c (next cbs)]
                     (let [half-height (* 0.5 (:zone/length-m c))
                           dd (- half-height (* 0.5 (:zone/length-m sc)))
                           new-center (offset-point center-lat
                                                    center-lng
                                                    (* dd (js/Math.cos rads))
                                                    (* dd (js/Math.sin rads)))]
                       {:db/id (:db/id c)
                        :zone/center-lat (.-lat new-center)
                        :zone/center-lng (.-lng new-center)}
                      
                       #_(prn 'Myheight my-height)))))))

(register-sub ::align-centers
              (fn [[_]]
                (let [{:state/keys [current-field]} (d/entity @conn ::state)
                      cbs (sorted-clipboxes current-field)
                      {:zone/keys [center-lat center-lng]} (first cbs)]
                  (d/transact!
                   conn 
                   (for [c (next cbs)]
                     {:db/id (:db/id c)
                      :zone/center-lat center-lat
                      :zone/center-lng center-lng})))))

(register-sub ::place-triangle-center
              (fn [[_ lat lng]]
                (let [triangle {:db/id "triangle"
                                :zone/type :triangle
                                :zone/center-lat lat
                                :zone/center-lng lng
                                :zone/heading 0
                                :triangle/size-m 100}
                      {:state/keys [current-field]} (d/entity @conn ::state)
                      {:keys [tempids]} (d/transact! conn [triangle
                                                           (create-zone! triangle)
                                                           {:db/id (:db/id current-field)
                                                            :field/triangle triangle}
                                                           #_{:db/ident ::map
                                                            :map/marker-complete-action ::place-runway-center}])]
                  (attach-zone! (d/entity @conn (get tempids "triangle"))))))


(def nofly-color-map {:outside "#43973c", :inside "#773030"})

(defn update-nofly-inside-outside*
  [nofly]
  (some-> (or (:zone/map.circle nofly)
              (:zone/map.polygon nofly))
          (.setOptions #js {:fillColor (get nofly-color-map (:nofly/inside-outside nofly))})))

(defmethod create-zone* :nofly-circle [{:zone/keys [center-lat center-lng] :as zone}]
  {:db/id (:db/id zone)
   :zone/map.circle (js/google.maps.Circle. #js{:draggable true
                                                :center (js/google.maps.LatLng. center-lat center-lng)
                                                :radius (:nofly/circle.radius zone)})})

(defmethod attach-zone! :nofly-circle [{:db/keys [id] :as zone}]
  (update-nofly-inside-outside* zone)
  (let [circle (:zone/map.circle zone)
        db (db-transact-debouncer
            (fn []
              (d/transact! conn [{:db/id id
                                  :zone/center-lat (.lat (.getCenter circle))
                                  :zone/center-lng (.lng (.getCenter circle))
                                  :nofly/circle.radius (.getRadius circle)}])))]
    (reattach-zone! zone)
    (when circle
      (doto circle
        (js/google.maps.event.addListener "rightclick" #(async/put! bus [::remove-zone id]))
        (js/google.maps.event.addListener "drag" #(.fire db))))))


(defmethod create-zone* :nofly-polygon [zone]
  {:db/id (:db/id zone)
   :zone/map.polygon (js/google.maps.Polygon.
                      #js{:strokeOpacity 0.8
                          :strokeWeight 2
                          :draggable true
                          :editable true
                          :path (clj-path->js (:zone/polygon.path zone))})})

(defmethod attach-zone! :nofly-polygon [{:db/keys [id] :as zone}]
  (update-nofly-inside-outside* zone)
  (let [poly (:zone/map.polygon zone)
        db (db-transact-debouncer
            (fn []
              (d/transact! conn [{:db/id id
                                  :zone/polygon.path (polygon->clj-path poly)}])))]

    (reattach-zone! zone)
    (when poly
      (doto poly
        (js/google.maps.event.addListener "rightclick" #(async/put! bus [::remove-zone id]))
        (js/google.maps.event.addListener "drag" #(.fire db)))
      (doto (.getPath poly)
        (js/google.maps.event.addListener "insert_at" #(.fire db))
        (js/google.maps.event.addListener "remove_at" #(.fire db))
        (js/google.maps.event.addListener "set_at" #(.fire db))))))

(register-sub ::place-nofly-circle
              (fn [[_ lat lng radius]]
                (let [nofly {:db/id "nofly"
                             :zone/type :nofly-circle
                             :nofly/type :circle
                             :nofly/inside-outside :inside
                             :nofly/circle.radius radius
                             :nofly/circle.original-radius radius
                             :zone/center-lat lat
                             :zone/center-lng lng}
                      
                      {:state/keys [current-field]} (d/entity @conn ::state)
                      {:keys [tempids]} (d/transact! conn [nofly
                                                           (create-zone! nofly)
                                                           {:db/id (:db/id current-field)
                                                            :field/noflys ["nofly"]}])]
                  (attach-zone! (d/entity @conn (get tempids "nofly"))))))

(register-sub ::place-nofly-polygon
              (fn [[_ path]]
                (let [nofly {:db/id "nofly"
                             :zone/type :nofly-polygon
                             :nofly/type :polygon
                             :nofly/inside-outside :inside
                             :zone/polygon.path path}
                      
                        {:state/keys [current-field]} (d/entity @conn ::state)
                        {:keys [tempids]} (d/transact! conn [nofly
                                                             (create-zone! nofly)
                                                             {:db/id (:db/id current-field)
                                                              :field/noflys ["nofly"]}])]
                  (attach-zone! (d/entity @conn (get tempids "nofly"))))))

(register-sub ::update-nofly-inside-outside
              (fn [[_ nofly inside-outside]]
                (-> (d/transact! conn [{:db/id (:db/id nofly)
                                        :nofly/inside-outside inside-outside}])
                    :db-after
                    (d/entity (:db/id nofly))
                    (update-nofly-inside-outside*))))

(def update-nofly-radius-debouncer
  (-> (fn [nofly-eid radius]
        (d/transact! conn [[:db/add nofly-eid :nofly/circle.radius radius]]))
      (Debouncer. 66)))

(defn update-nofly-radius!
  [nofly radius]
  (if-let [circle (:zone/map.circle nofly)]
    (.setRadius circle radius)
    (.fire update-nofly-radius-debouncer (:db/id nofly) radius)))

(register-sub ::triangle-placement-start
              (fn [_]
                (.setDrawingMode @the-drawing-manager "marker")
                (d/transact! conn [{:db/ident ::map
                                    :map/marker-complete-action ::place-triangle-center}])))

(register-sub ::runway-placement-start
              (fn [_]
                (.setDrawingMode @the-drawing-manager "marker")
                (d/transact! conn [{:db/ident ::map
                                    :map/marker-complete-action ::place-runway-center}])))

(register-sub ::clipbox-placement-start
              (fn [_]
                (.setDrawingMode @the-drawing-manager "marker")
                (d/transact! conn [{:db/ident ::map
                                    :map/marker-complete-action ::place-clipbox-center}])))

(register-sub ::nofly-circle-placement-start
              (fn [_]
                (.setDrawingMode @the-drawing-manager "circle")
                #_(d/transact! conn [{:db/ident ::map
                                      :map/marker-complete-action ::place-clipbox-center}])))

(register-sub ::nofly-polygon-placement-start
              (fn [_]
                (.setDrawingMode @the-drawing-manager "polygon")
                #_(d/transact! conn [{:db/ident ::map
                                      :map/marker-complete-action ::place-clipbox-center}])))

(register-sub ::field-edit-start
              (fn [[_ field-eid]]
                (d/transact! conn [{:db/id field-eid
                                    :field/editing-name true}])))
(register-sub ::delete-field
              (fn [[_ field-eid]]
                (swap! gmaps-force-render inc)
                (d/transact! conn (into [[:db/retractEntity field-eid]]
                                        (concat
                                         (for [c (:field/clipbox (d/entity @conn field-eid))]
                                           [:db/retractEntity (:db/id c)])
                                         (for [n (:field/noflys (d/entity @conn field-eid))]
                                           [:db/retractEntity (:db/id n)]))))))

(register-sub ::field-edit-finish
              (fn [[_ field-eid name short-name]]
                (d/transact! conn [{:db/id field-eid
                                    :field/name name
                                    :field/short-name short-name
                                    :field/editing-name false}])))

(register-sub ::update-zone
              (fn [[_ e a v]]
                (-> (d/transact! conn [[:db/add e a v]])
                    :db-after
                    (d/entity e)
                    (update-zone! nil nil nil))))

(register-sub ::set-clipbox-zoom
              (fn [[_ e z]]
                (-> (d/transact! conn [(set-clipbox-zoom (d/entity @conn e) z)])
                    :db-after
                    (d/entity e)
                    (update-zone! nil nil nil))))

(register-sub ::move-clipbox
              (fn [[_ clipbox-eid distance-meters heading-offset]]
                (let [{:zone/keys [heading center-lat center-lng]} (d/entity @conn clipbox-eid)
                      theta (* (+ heading heading-offset) (/ js/Math.PI 180))
                      new-center (offset-point center-lat
                                               center-lng
                                               (* distance-meters (js/Math.cos theta))
                                               (* distance-meters (js/Math.sin theta)))
                      {:keys [db-after]}  (d/transact! conn [{:db/id clipbox-eid
                                                              :zone/center-lat (.-lat new-center)
                                                              :zone/center-lng (.-lng new-center)}])
                      modified-clipbox (d/entity db-after clipbox-eid)]
                  (update-zone! modified-clipbox nil nil nil)
                  (some-> modified-clipbox :zone/map.marker  (.setPosition new-center)))))



(register-sub ::remove-zone (fn [[_ zone-eid]]
                              (detach-zone! (d/entity @conn zone-eid))
                              (d/transact! conn [[:db/retractEntity zone-eid]])))

(register-sub ::hide-zone (fn [[_ zone-eid]]
                            (detach-zone! (d/entity @conn zone-eid))
                            (d/transact! conn [[:db/add zone-eid :zone/hidden true]])))

(register-sub ::show-zone (fn [[_ zone-eid]]
                            (let [{:keys [db-after]} (d/transact! conn [(create-zone! (d/entity @conn zone-eid) true)
                                                                        [:db/add zone-eid :zone/hidden false]])]
                              (attach-zone! (d/entity db-after zone-eid)))))

(def apps-request-result (atom nil))
(register-sub ::close-modal (fn [[_]]
                              (reset! apps-request-result nil)
                              (d/transact! conn [{:db/ident ::state
                                                  :state/modal false}])))

(register-sub ::show-modal (fn [[_ mt]]
                              (d/transact! conn [{:db/ident ::state
                                                  :state/modal mt}])))



;; 

(defn json-data-for-field
  [{:field/keys [name short-name runway triangle noflys] :as field}]
  (let [cbs (sorted-clipboxes field)]
    (cond-> {:name name :shortname short-name}
      runway (assoc :runway
                    {:path (:zone/polygon.path runway)
                     :heading (:zone/heading runway)})
      triangle (assoc :triangle
                      {:path (:zone/polygon.path triangle)
                       :heading (:zone/heading triangle)
                       :size (:triangle/size-m triangle)
                       :center {:lat (:zone/center-lat triangle)
                                :lng (:zone/center-lng triangle)}})
      (seq cbs) (assoc
                 :elevation [:elevaterloy
                             (:zone/center-lat (first cbs))
                             (:zone/center-lng (first cbs))]
                   
                 :images
                 (for [{:zone/keys [center-lat heading center-lng] :as c} cbs]
                   (let [i (:clipbox/preview-zoom c)]
                     {:file (str "Apps/DFM-Maps/Maps/" short-name "/" i ".png")
                      :meters_per_pixel (staticmap-meters-per-pixel i center-lat)
                      :heading heading
                      :center {:lat center-lat
                               :lng center-lng}})))
      (seq noflys) (assoc :nofly
                          (for [{:nofly/keys [inside-outside] :zone/keys [type center-lat center-lng] :as nf} noflys]
                            (merge
                             {:inside_or_outside inside-outside}
                             (case type
                               :nofly-circle {:type :circle
                                              :lat center-lat
                                              :lng center-lng
                                              :diameter (* 2 (:nofly/circle.radius nf))}
                               :nofly-polygon {:type :polygon
                                               :path (:zone/polygon.path nf)})))))))

(defn simple-json-data-for-field
  [{:field/keys [name short-name runway triangle noflys] :as field}]
  (let [cb (first (sorted-clipboxes field))]
    (cond-> {:rotation (:zone/heading (:field/current-clipbox field))
             :lat (:zone/center-lat cb)
             :lng (:zone/center-lng cb)}
      (seq noflys)
      (assoc :nfz
             (for [{:nofly/keys [inside-outside] :zone/keys [type center-lat center-lng] :as nf} noflys]
               (merge
                {:type inside-outside}
                (case type
                  :nofly-circle {:shape :circle
                                 :radius (:nofly/circle.radius nf)
                                 :path [{:lat center-lat :lng center-lng}]}
                  :nofly-polygon {:shape :polygon
                                  :path (:zone/polygon.path nf)})))))))


#_(defn make-json-data [db]
    (clj->js
     (for [field (qes-by db :field/name)]
       (json-data-for-field field))))


(rum/defc gmaps [fake-dep bus] 
  (let [my-ref (rum/create-ref)]
    (rum/use-effect!
     (fn []
       (reset! the-map 
               (js/google.maps.Map. (rum/deref my-ref)
                                    #js {:zoom 4
                                         #_ #_:center (js/google.maps.LatLng.
                                                       39.147398 -77.337639)
                                         :center (let [{:map/keys [center-lat center-lng]} (d/entity @conn ::map)
                                                       {:state/keys [current-field]} (d/entity @conn ::state)]
                                                   (cond
                                                     (and center-lat center-lng)
                                                     (js/google.maps.LatLng. center-lat center-lng)
                                                     
                                                     (seq (:field/clipbox current-field))
                                                     (let [{:zone/keys [center-lat center-lng]} (first (:field/clipbox current-field))]
                                                       (js/google.maps.LatLng. center-lat center-lng))

                                                     :else
                                                     (js/google.maps.LatLng. 40.363578 -42.005608)
                                                     #_(js/google.maps.LatLng. 39.147398 -77.337639)))
                                         :mapTypeId "hybrid"
                                         :rotateControl true}))
       (reset! the-drawing-manager
               (js/google.maps.drawing.DrawingManager.
                (clj->js
                 {:drawingControl true
                  :drawingMode nil
                  :drawingControlOptions {:position js/google.maps.ControlPosition.TOP_CENTER
                                          :drawingModes ["marker" "circle" "polygon"]}
                  :polygonOptions {:editable true :draggable true}
                  :markerOptions {:draggable true}
                  :circleOptions {:draggable true}})))
       (.setMap @the-drawing-manager @the-map)
       
       (->> (fn overlay-complete [event]
              (js/console.log "Drawing event" (.-type event) event)
              (let [overlay (.-overlay event)]
                (case (.-type event)
                  "circle" (let [center (.getCenter overlay)]
                             (.setMap overlay nil)
                             (async/put! bus [::place-nofly-circle (.lat center) (.lng center) (.getRadius overlay)]))
                  "polygon" (let []
                              (.setMap overlay nil)
                              (async/put! bus [::place-nofly-polygon (polygon->clj-path overlay)]))
                  "marker" (when-let [mca (:map/marker-complete-action (d/entity @conn ::map))]
                             (.setMap overlay nil)
                             ;; do it here 

                             (prn "Reteacterino" (:tx-data (d/transact! conn [[:db/retract (d/entid @conn ::map) :map/marker-complete-action mca]])))
                             (async/put! bus [mca
                                              (.lat (.getPosition overlay))
                                              (.lng (.getPosition overlay))]))
                  (js/console.log "Other event" event)))
              (.setDrawingMode @the-drawing-manager nil))
            (js/google.maps.event.addListener @the-drawing-manager "overlaycomplete"))

       (->> (fn center-changed []
              (let [c (.getCenter @the-map)]
                (update-map-center-transact-debounced! (.lat c) (.lng c) )))
            (js/google.maps.event.addListener @the-map "center_changed"))

       (->> (fn map-clicked [ev]
              (.log js/console "Event clicked" ev))
            (js/google.maps.event.addListener @the-map "click"))
       
       ;; hydrate zones
       (d/transact! conn (map create-zone! (qes-by @conn :zone/type)))
       (let [{:state/keys [current-field]} (d/entity @conn ::state)
             zones (field->zones current-field)]
         (run! attach-zone! zones))
       (fn effect-cleanup []
         (reset! the-map nil)))
     [fake-dep])
    [:div#map-canvas {:ref my-ref}]))

(defn ->coords-str
  [lat lng]
  (str (-> lat (.toFixed 6) str)
       ", "
       (-> lng (.toFixed 6) str)))

(defn parse-coords
  [coords]
  (when-let [[[_m lat-s lng-s]] (re-seq #"([^,]*?),(.*)" coords)]
    (let [lat (js/parseFloat lat-s)
          lng (js/parseFloat lng-s)]
      (cond
        (js/isNaN lat) {:error "Invalid lat"}
        (js/isNaN lng) {:error "Invalid lng"}
        :else {:lat lat :lng lng}))))

(rum/defcs map-center-input-next < (rum/local nil ::formdata)
  [{::keys [formdata]} db bus]
  (let [map-ent (d/entity db ::map)]
    [:.hflex
     [:form
      [:input {:style {:width "14em"}
               :on-change #(do
                             (reset! formdata (.-value (.-target %)) )
                             (println "Formdata" @formdata (parse-coords @formdata))
                             (when-let [{:keys [lat lng error]} (parse-coords @formdata)]
                               (when error 
                                 (println "Errorloy" error))
                               (async/put! bus [::map-recenter lat lng])))
               :value (->coords-str (:map/center-lat map-ent) (:map/center-lng map-ent) )}]]]))

(rum/defcs field-edit-form < (rum/local nil ::formdata)
  [{::keys [formdata]} f bus]
  (when (:field/editing-name f)
    (let [name (or (:field/name @formdata) (:field/name f))
          short-name (or (:field/short-name @formdata) (:field/short-name f))]
     [:fieldset
      [:legend "Edit field name"]
      [:label "Field name"
       [:input {:value  name
                :on-change #(swap! formdata assoc :field/name (.-value (.-target %)))}]]
      [:label "Short name"
       [:input {:value short-name
                :on-change #(swap! formdata assoc :field/short-name (.-value (.-target %)))}]]
      [:input {:type "button"
               :value "Save"
               :on-click #(async/put! bus [::field-edit-finish (:db/id f) name short-name])}]])))

(rum/defcs zone-heading-slider < (rum/local [0 nil] ::slider)
  [{::keys [slider]} {:zone/keys [heading] :as r} bus {:keys [on-change] :as opts}]
  (let [[t local-value] @slider
        {:keys [max-tx]} (d/entity-db r)
        value (if (or (nil? local-value) (< t max-tx))
                heading
                local-value)]
    [:label [:span.label (str "Heading: " value)]
    [:input {:value value
             :type "range"
             :min "0"
             :max "360"
             :on-change #(let [new-heading (js/parseFloat (.-value (.-target %)))]
                           (reset! slider [max-tx new-heading] )
                           (update-zone! r nil nil new-heading)
                           (when on-change
                             (on-change new-heading)))}]]))

#_(defn clipbox-heading-slider
  [c bus]
  (zone-heading-slider
   c bus
   {:on-change (fn [new-heading]
                 (println "Change" new-heading)
                 (d/transact! conn
                              (for [[e a v t] (d/datoms @conn :avet :zone/type :clipbox)]
                                (do
                                  (println "Eavt" e a v t)
                                  [:db/add e :zone/heading new-heading]))))}))
(rum/defc clipbox-heading-slider
  [c bus]
  (zone-heading-slider
   c bus
   {:on-change (fn [new-heading]
                 (let [{:state/keys [current-field]} (d/entity @conn ::state)]
                  (d/transact! conn
                               (for [c (:field/clipbox current-field)]
                                 [:db/add (:db/id c) :zone/heading new-heading])
                               #_(for [[e a v t] (d/datoms @conn :avet :zone/type :clipbox)]
                                   [:db/add e :zone/heading new-heading]))))}))

(rum/defc runway-edit-form
  [{:zone/keys [heading length-m width-m] :as r} bus]
  [:fieldset.vflex {:key (:db/id r)}
   [:legend "Runway"]
   [:label [:span.label "Length (meters)"]
    [:input {:value length-m
             :on-change #(async/put! bus [::update-zone (:db/id r) :zone/length-m (.-value (.-target %))])}]]
   [:label [:span.label "Width (meters)"]
    [:input {:value width-m
             :on-change #(async/put! bus [::update-zone (:db/id r) :zone/width-m (.-value (.-target %))])}]]
   (zone-heading-slider r bus)
   [:input.remove-button {:type "button"
                          :value "Remove"
                          :on-click #(async/put! bus [::remove-zone (:db/id r)])}]])


(rum/defc triangle-edit-form
  [{:zone/keys [heading] :triangle/keys [size-m] :as t} bus]
  [:fieldset {:key (:db/id t)}
   [:legend "Triangle"]
   [:label [:span.label "Size (meters)"]
    [:input {:value size-m
             :on-change #(async/put! bus [::update-zone (:db/id t) :triangle/size-m (.-value (.-target %))])}]]
   (zone-heading-slider t bus)
   [:input.remove-button {:type "button"
                          :value "Remove"
                          :on-click #(async/put! bus [::remove-zone (:db/id t)])}]])

(rum/defcs nofly-radius-slider < (rum/local nil ::slider)
  [{::keys [slider]} nf bus]
  (let [r (:nofly/circle.radius nf)
        orig-r (:nofly/circle.original-radius nf)]
    [:label (str "Radius: " (js/Math.ceil (or @slider r)) " meters")
    [:input {:value (or @slider r)
             :type "range"
             :min "0"
             :max (str (js/Math.ceil (* 2 orig-r)))
             :on-change #(let [new-r (js/parseFloat (.-value (.-target %)))]
                           (reset! slider new-r )
                           (update-nofly-radius! nf new-r))}]]))

(rum/defc nofly-edit-form
  [{:nofly/keys [inside-outside] :as nf} bus]
  [:fieldset.vflex
   [:legend (str "Nofly #" (:db/id nf))]
   [:div.hflex
    [:button {:disabled (= :inside inside-outside)
              :on-click #(async/put! bus [::update-nofly-inside-outside nf :inside])}
     "Inside"]
    [:button {:disabled (= :outside inside-outside)
              :on-click #(async/put! bus [::update-nofly-inside-outside nf :outside])}
     "Outside"]]
   (when-let [radius (:nofly/circle.radius nf)]
     (nofly-radius-slider nf bus))
   [:input.remove-button {:type "button"
                          :value "Remove"
                          :on-click #(async/put! bus [::remove-zone (:db/id nf)])}]])

(rum/defc add-triangle-helper [db bus]
  (if (= ::place-triangle-center (:map/marker-complete-action (d/entity db ::map)))
    [:span "Click on the map to place the midpoint of the triangle base leg."]
    [:input {:type "button"
             :style {:width "10em"} 
             :value "Add triangle"
             :on-click #(async/put! bus [::triangle-placement-start])}]))

(rum/defc add-runway-helper [db bus]
  (if (= ::place-runway-center (:map/marker-complete-action (d/entity db ::map)))
    [:span "Click on the map to place the center of the runway"]
    [:input {:type "button"
             :value "Add runway"
             :style {:width "10em"} 
             :on-click #(async/put! bus [::runway-placement-start])}]))

(rum/defc add-noflys-helper [db bus]
  [:div
   [:input {:type "button"
            :value "Start drawing no-fly circle"
            :style {:width "15em"}
            :on-click #(async/put! bus [::nofly-circle-placement-start])}]
   [:input {:type "button"
            :value "Start drawing no-fly polygon"
            :style {:width "15em"}
            :on-click #(async/put! bus [::nofly-polygon-placement-start])}]])

(rum/defc field-info-header [f bus]
  [:div
   (if (:state/_current-field f) 
     [:a {:href "#" :on-click #(async/put! bus [::deselect-field f])} "(-)"]
     [:a {:href "#" :on-click #(do (async/put! bus [::select-field f])
                                   (async/put! bus [::map-recenter
                                                    (some-> f :field/clipbox :zone/center-lat)
                                                    (some-> f :field/clipbox :zone/center-lng)]))} "(+)"])
   
   [:span (:field/name f)]
   [:span {:style {:width "1em"}} " "]
   "(" [:span (:field/short-name f)] ")"
   [:span {:style {:width "1em"}} " "]
   [:a {:href "#" :on-click #(async/put! bus [::field-edit-start (:db/id f)])}
    "(edit)"]
   [:a {:href "#" :on-click #(async/put! bus [::delete-field (:db/id f)])}
    "(delete)"]])

(def default-image-width 320)
(def default-image-height 160)
(defn zone-image-query-params
  [{:zone/keys [center-lat center-lng heading] :as zone} img-width img-height]
  (.toString
   (js/URLSearchParams.
    (clj->js
     {:lat center-lat
      :lng center-lng
      :heading heading
      :zoom (:clipbox/preview-zoom zone)
      :out-width img-width
      :out-height img-height}))))

(rum/defc zone-image-preview [zone bus]
  [:img {:width default-image-width
         :height default-image-height
         :src (str "/staticmap?"
                   (zone-image-query-params zone
                                            default-image-width
                                            default-image-height))}])


;; whatever
(rum/defcs clipbox-zoom-slider < (rum/local nil ::slider)
  [{::keys [slider]} {:clipbox/keys [preview-zoom] :as c} bus]
  (let [value (or @slider preview-zoom)]
    [:label [:span.label (str "Zoom: " value)]
     [:input {:value value
              :type "range"
              :min "12"
              :max "20"
              :on-change #(let [new-zoom (js/parseInt (.-value (.-target %)))]
                            (reset! slider new-zoom )
                            (async/put! bus [::set-clipbox-zoom (:db/id c) new-zoom]))}]]))

(rum/defc clipbox-edit [{:zone/keys [hidden] :as c} bus]
  [:div
   (zone-image-preview c bus)
   [:fieldset.vflex.clipbox-edit-form
    [:legend (str "Transmitter image")]
    (clipbox-heading-slider c bus)
    ;; todo Make this "Boundary - Hide/show"
    (if hidden
      [:button {:style {:width "10em"} :on-click #(async/put! bus [::show-zone (:db/id c)])} "Show boundary"]
      [:button {:style {:width "14em"} :on-click #(async/put! bus [::hide-zone (:db/id c)])} "Hide boundary rectangle"])
    [:input {:type "button"
             :style {:width "10em"} 
             :value "Edit clipboxes "   ; Document this as showing the other zoom levels
             :on-click #(async/put! bus [::show-modal :clipbox-modal])}]]])

(rum/defc field-info [f bus]
  [:fieldset.vflex.field-info-form
   [:span 
    (field-info-header f bus)]
   
   (field-edit-form f bus)
   
   (when-let [c (:field/current-clipbox f)]
     (clipbox-edit c bus))
   (if-let [r (:field/runway f)]
     (runway-edit-form r bus)
     (add-runway-helper (d/entity-db f) bus))
   (add-noflys-helper  (d/entity-db f) bus)
   
   
   (if-let [t (:field/triangle f)]
     (triangle-edit-form t bus)
     (add-triangle-helper (d/entity-db f) bus))
   
   (for [nf (:field/noflys f)]
     [:div {:key (:db/id nf)}
      (nofly-edit-form nf bus)])])

(rum/defc field-info-collapse [f bus]
  (if (:state/_current-field f)
    (field-info f bus)
    [:span {:style {:background-color "tomato"}}
     (field-info-header f bus)]))




(rum/defc upload-db-box
  []
  [:input {:type "file"
           :on-change (fn [e]
                        (when-let [file (some-> e (.-target) (.-files) (aget 0))]
                          (let [rdr (js/FileReader.)]
                            (set! (.-onload rdr)
                                  (fn [fe] (load-db-from-edn-string (.. fe -target -result))))
                            (.readAsText rdr file))))}])

(defn make-dynamic-repo-request [db]
  ;; apps json?
  (let [origin js/window.location.origin
        state (d/entity db ::state)]
    (clj->js
     {:yoururl origin
      :apps [{:base-app "DFM-Maps"
              :dynamic-files 
              (into
               [{:destination "Apps/DFM-Maps/Maps/Fields.jsn"
                 :json-data (into {}
                                  (for [{:field/keys [short-name] :as field} (qes-by db :field/name)]
                                    [short-name (json-data-for-field field)]))}]
               
               (for [{:field/keys [name short-name clipbox runway triangle noflys]} (qes-by db :field/name)
                     c clipbox]
                 (let [i (:clipbox/preview-zoom c)]
                   {:destination (str "Apps/DFM-Maps/Maps/" short-name "/" i ".png")
                    :url (str (.-origin (.-location js/window))
                              "/staticmap?"
                              (zone-image-query-params c
                                                       default-image-width
                                                       default-image-height))})))}
             {:base-app "DFM-GPS"
              :dynamic-files 
              (into [{:app "DFM-GPS" :prefix "Apps/"}]
                    (for [f (qes-by db :field/name)]
                      {:destination (str "Apps/DFM-GPS/FF_" (:field/short-name f) ".jsn")
                       :json-data (simple-json-data-for-field f)}))}]})))

(defn send-dynamic-repo-request! [json-data]
  (let [xhr (XhrIo.)]
    (.listen xhr EventType/COMPLETE
             (fn [_]
               (println "complete")
               (reset! apps-request-result (.getResponseJson xhr))))
    (.send xhr (str "/dynamic-repo-v3?token=" (get-or-create-token!))
           "POST"
           (.stringify js/JSON json-data nil 2)
           #js {"Content-Type" "application/json;charset=UTF-8"})))


(defn send-github-releases-request!
  [bus]
  (let [xhr (XhrIo.)]
    (.listen xhr EventType/COMPLETE
             #(async/put! bus [::github-releases-fetched (.getResponseJson xhr)]))
    (.send xhr "https://api.github.com/repos/davidmcq137/JetiLuaDFM/releases")))

(register-sub ::change-git-ref (fn [[_ new-ref]]
                                 (reset! apps-request-result nil)
                                 (d/transact! conn [{:db/ident ::state
                                                     :state/dynamic-repo-git-ref new-ref}])
                                 (send-dynamic-repo-request! (make-dynamic-repo-request @conn))))

(register-sub ::select-github-release
              (fn [[_ new-release-id]]
                (println "Select release" (pr-str new-release-id))
                (reset! apps-request-result nil) 
                (d/transact! conn [{:db/ident ::state
                                    :state/selected-release [:release/id new-release-id]}])
                (send-dynamic-repo-request! (make-dynamic-repo-request @conn))))

(register-sub ::github-releases-fetched
              (fn [[_ json]]
                (let [{:state/keys [selected-release] :as state} (d/entity @conn ::state)
                      
                      releases (sort-by #(get % "name") (js->clj json) )
                      latest (->> releases
                                  (filter #(not (get % "prerelease")))
                                  (sort-by #(get % "published_at"))
                                  first)
                      current-release-ids (into #{} (map #(get % "id")) releases)
                      txdata (concat
                              (for [{:strs [id name prerelease created_at published_at html_url assets] :as elem} releases]
                                {:release/id id
                                 :release/name name
                                 :release/prerelease prerelease
                                 :release/created-at created_at
                                 :release/published-at published_at
                                 :release/zip-url-map (into {}
                                                            (for [{:strs [name browser_download_url]} assets]
                                                              [(string/replace name #"-v\d+\.\d+\.zip" "")
                                                               browser_download_url]))
                                 :release/zip-url (-> (fn [a] (string/starts-with? (get a "name") "DFM-Maps"))
                                                      (filter assets)
                                                      (first)
                                                      (get "browser_download_url"))
                                 :release/html-url html_url})
                              (for [rel (qes-by @conn :release/id)
                                    :when (not (contains? current-release-ids (:release/id rel)))]
                                {:db/id (:db/id rel)
                                 :release/deleted true})
                              
                              (when-not selected-release
                                [{:release/id (get latest "id")
                                  :state/_selected-release (:db/id state)}]))] 
                  
                  (println "Release txdata")
                  (cljs.pprint/pprint
                   (:tx-data (d/with @conn txdata)))
                  
                  (d/transact! conn txdata)
                  (send-dynamic-repo-request! (make-dynamic-repo-request @conn)))))

(register-sub ::set-show-prereleases
              (fn [[_ show?]]
                (println "show?" (pr-str show?))
                (d/transact! conn [{:db/ident ::state
                                    :state/show-prereleases show?}])))


(def month-names-vec
  ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"])

(defn db-filename
  []
  ;; DFM-Maps07Apr2021.edn
  (let [d (gdate/Date.)]
    (str
     "DFM-Maps "
     (.getDate d)
     " "
     (-> month-names-vec
         (nth (.getMonth d))
         (subs 0 3))
     " "
     (.getFullYear d)
     ".edn")))

(rum/defc sidebar-form [db bus]
  [:.sidebar-left
   [:.sidebar
    #_(:state/save-status (d/entity @conn ::state))
    (for [f (sort-by :db/id (qes-by db :field/name))]
      [:div {:key (:db/id f)}
       #_(field-info f bus)
       (field-info-collapse f bus)])
    
    [:div.vflex {:style {:width "14em"}}

     #_ [:input {:type "button"
                 :value "Show JSON"
                 :on-click #(async/put! bus [::show-modal :json-data])}]
     [:input {:type "button"
              :value "New field at map center"
              :on-click #(async/put! bus [::create-field])}]
     [:input {:type "button"
              :value "Create JETI repository"
              :on-click #(do
                           (send-github-releases-request! bus)
                           #_(send-dynamic-repo-request! (make-dynamic-repo-request db))
                           (async/put! bus [::show-modal :repo-request]))}]
     [:input 
      {:type "button" :value "Clear all fields"
       :style     {:background-color "#773030"} 
       :on-click (fn [ev]
                   (swap! gmaps-force-render inc)
                   (.setItem js/window.localStorage localstorage-db-key nil)
                   (d/reset-conn! conn @default-db-conn))}]
     [:input {:type "button" :value "Save all to file"
              :on-click (fn [ev]
                          (dl/download-string
                           (encode-db-for-save @conn)
                           (db-filename)))}]
     (upload-db-box)]]])

(rum/defc datoms-table-eavt [ds]
  [:table
    [:thead
     [:tr
      [:td "E"]
      [:td "A"]
      [:td "V"]
      [:td "T"]
      [:td "R"]]]
    [:tbody
     {} 
     (for [[e a v t r] ds]
       [:tr
        [:td [:code (str e)]]
        [:td [:code (str a)]]
        [:td [:code (str v)]]
        [:td [:code (str t)]]
        [:td [:code (str r)]]])]])

(rum/defcs transaction-edit-area < (rum/local nil ::text) < (rum/local nil ::tx-result)
  [{::keys [text tx-result]}]
  [:div
   [:textarea {:value (or @text "")
               :style {:width "50%"
                       :height "100px"}
               :on-change (fn [ev]
                            (let [new-text (.-value (.-target ev))]
                              (reset! text new-text)))}]
   [:input {:type "button" :value "Reset DB"
            :on-click (fn [ev]
                        (swap! gmaps-force-render inc)
                        (d/reset-conn! conn @default-db-conn))}]
   (try
     (let [edn (edn/read-string @text)]
       [:div
        [:pre (pr-str edn)]
        [:input {:type "button"
                 :value "Transact"
                 :on-click (fn [ev]
                             (try
                               (reset! tx-result {:tx-success (d/transact! conn edn)})
                               (catch js/Error e
                                 (reset! tx-result {:tx-error e}))))}]])
     (catch js/Error e
       [:div (str "error" e)]))
   (when-let [ex (:tx-error @tx-result)]
     [:div "Transaction error!"
      [:pre (str ex)]])
   (when-let [r (:tx-success @tx-result)]
     [:div
      "Transaction success!"
      [:br]
      "tx-data:"
      (datoms-table-eavt (:tx-data r))
      [:br]
      "tempids"
      [:pre
       (with-out-str (pprint/pprint (:tempids r)))]])])

(rum/defc debug-tab [db bus]
  [:.app.vflex#main
   (datoms-table-eavt (d/datoms db :eavt))
   (transaction-edit-area)])

(rum/defc images-tab [db bus]
  (let [{:state/keys [current-field]} (d/entity @conn ::state)]
   [:.app.vflex#main
    (for [c (:field/clipbox current-field)]
      [:div.hflex {:key (:db/id c)}
       (clipbox-edit c bus)])]))



(rum/defc clipbox-modal [db bus]
  (let [{:state/keys [current-field]} (d/entity @conn ::state)]
    [:div.vflex
     [:div
      [:input {:type "button"
               :value "Align bottoms"
               :on-click #(async/put! bus [::align-bottoms ])}]
      [:input {:type "button"
               :value "Align centers"
               :on-click #(async/put! bus [::align-centers ])}]]
     
     (for [c (sorted-clipboxes current-field)]
       [:div.hflex {:key (:db/id c)
                    :style {:margin-top "10px"}}
        (zone-image-preview c bus)
        [:div {:style {:margin-left "10px"}}
         [:fieldset.vflex.clipbox-edit-form
          [:legend (str "Zoom " (:clipbox/preview-zoom c))]
          (let [e (:db/id c)
                d (* 3
                     (staticmap-meters-per-pixel (:clipbox/preview-zoom c)
                                                 (:zone/center-lat c)))]
            [:div
             [:button {:style {:width "4em"} :on-click #(async/put! bus [::move-clipbox e d 0])} "Up"]
             [:button {:style {:width "4em"} :on-click #(async/put! bus [::move-clipbox e d 180])} "Down"]
             [:button {:style {:width "4em"} :on-click #(async/put! bus [::move-clipbox e d 270])} "Left"]
             [:button {:style {:width "4em"} :on-click #(async/put! bus [::move-clipbox e d 90])} "Right"]])]]])]))

(def gmaps-force-render (atom 0))
(rum/defc thinger < rum/reactive [bus]
  (gmaps (rum/react gmaps-force-render) bus))



(rum/defc map-tab < rum/reactive [db bus]
  [:.app.vflex
   [:#main.hflex
    (sidebar-form db bus)
    [:.map
     (thinger bus)
     
     (map-center-input-next db bus)]
    #_[:div {:style {:padding "0px 32px 0px 16px"}}]
    #_[:#images-preview.vflex
       [:.margin-auto "Images preview"]]]])


(rum/defc git-ref-selector < (rum/local nil ::branch)
  [db bus]
  (let [value (or (:state/dynamic-repo-git-ref (d/entity db ::state))
                  "master")]
    [:div
     [:label
      [:span {:style {:margin-right "1ex"}} "Include app version:"]
      [:select  {:value value
                 :on-change #(async/put! bus [::change-git-ref (.-value (.-target %))])}
       [:option {:value "master"} "Release version (default)"]
       [:option {:value "dev"} "Development version (advanced users)"]]]]))


(rum/defc releases-table
  [releases]
  [:table {:style {:border-spacing "1ex"}}
   [:thead
    [:tr
     [:th ""]
     [:th "Version"]
     [:th "Release date"]]]
   [:tbody
    (for [{:release/keys [id name html-url created-at published-at deleted] :as elem} releases
          :when (not deleted)]
      [:tr {:key id}
       [:td [:input {:type "radio"
                     :checked (some? (:state/_selected-release elem))
                     :name "selected-release"
                     :value id
                     :on-change #(do (async/put! bus [::select-github-release (js/parseInt (.-value (.-target %)))])
                                     true)}]]
       [:td [:a {:href html-url} [:span name]]]
       [:td [:span
             #_(.toLocaleString (js/Date. created-at))
             (.toLocaleString (js/Date. published-at))]]])]])




(rum/defc apps-request-view < rum/reactive
  [json-data db bus]
  (if-let [r (rum/react apps-request-result)]
    (let [jj (aget r "repo_url")]
      [:div
       [:p "This is your temporary JETI repository.  Use it soon since it won't live forever!"]
       [:code jj]
       [:p
        "If you prefer manual installation, you can also "
        [:a {:download (str "DFM-Maps " (get-or-create-token!) ".zip")
             :href (str "/repo/" (get-or-create-token!) ".zip")}
         "download a zip archive"]
        "."]])
    [:div {} "Creating repository..."]))

(rum/defc root-component < rum/reactive [conn bus]
  (let [db (rum/react conn)
        tabs {:map map-tab
              :debug debug-tab
              :images images-tab}
        {:state/keys [current-tab modal]} (d/entity @conn ::state)
        tab-component (get tabs current-tab)]
    [:div
     (when modal
       [:div.modal
        [:div.modal-content
         [:span.close {:on-click #(async/put! bus [::close-modal])} "\u00d7"]
         (case modal
           ;; :json-data [:pre (.stringify js/JSON (make-json-data db) nil 2)] 
           :image-request  "Image request lol"
           :repo-request (apps-request-view (make-dynamic-repo-request db) db bus)
           :clipbox-modal (clipbox-modal db bus))
         [:button {:on-click #(async/put! bus [::close-modal])} "Close"]]])
    
     (map-tab @conn bus)]))

(defn mount-root []
  (let [el (.getElementById js/document "root")]
    (when el (rum/mount (root-component conn bus) el))))

(defn ^:dev/after-load init []
  (try
    (get-or-create-token!)
    (catch js/Error e
      (.log js/console "Error" e )))
  
  
  (let [dingu-re #"-v\d+\.\d+\.zip"]
    (println "Find" (re-seq dingu-re "DFM-Maps-v8.11.zip"))
    (println "Replac" (string/replace "DFM-Maps-v8.11.zip" dingu-re "")))
  
  (or (when-let [el (.getElementById js/document "root")]
        (when-let [saved-db (.getItem js/window.localStorage localstorage-db-key)]
          (load-db-from-edn-string saved-db))
        (rum/mount (root-component conn bus) el))
      (when-let [el (.getElementById js/document "landing-page-root")]
        (rum/mount (landing/root-component) el))))

