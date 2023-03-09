(ns drs.server
  (:require
   [clj-http.lite.client :as client]
   [org.httpkit.server :as hk]
   [ring.util.response :as ring-resp]
   [clojure.walk :as walk]
   [ring.middleware.params :as ring-params]
   [ring.middleware.content-type :refer (wrap-content-type)]
   [ring.middleware.not-modified :refer (wrap-not-modified)]
   [clojure.java.io :as io]
   [cheshire.core :as json]
   [drs.google-maps-api :as gmaps]

   [clojure.string :as string]
   [rum.core :as rum]
   
   [bidi.bidi :as bidi]
   [bidi.ring :as bring])
  (:import
   [java.io ByteArrayInputStream ByteArrayOutputStream OutputStreamWriter]
   [java.util.zip ZipOutputStream ZipInputStream ZipEntry]
   [java.util Base64]
   [java.security MessageDigest]
   [java.util.zip GZIPOutputStream GZIPInputStream]
   [java.nio.charset StandardCharsets]))

(defonce servers (atom []))

(def analytics-script [:script {:defer "true"
                                :data-domain "jetiluadfm.app"
                                :src "https://plausible.io/js/plausible.js"}])

(defn landing-page
  [request]
  {:status  200
   :headers {"Content-Type" "text/html"}
   :body (str "<!DOCTYPE html>\n"
              (rum/render-html
               [:html
                [:head
                 [:title "JETI Lua DFM"]
                 [:meta {:charset "utf-8"}]
                 [:link {:rel "stylesheet" :href "/app.css"}]

                 analytics-script]
                [:div#landing-page-root]
                [:script {:type "text/javascript" :src "/js/main.js"}]
                ]))})

(defn maps-app
  [request]
  {:status  200
   :headers {"Content-Type" "text/html"}
   :body (str "<!DOCTYPE html>\n"
              (rum/render-html
               [:html
                [:head
                 [:title "JETI Map Generator"]
                 [:meta {:charset "utf-8"}]

                 [:link {:rel "stylesheet" :href "/maps/app.css"}]
                 [:script {:type "text/javascript"
                           :src "https://maps.googleapis.com/maps/api/js?key=AIzaSyCsDIgcntL8vPV1WZPUuXPh-ennc7HAXCI&libraries=drawing"}]
                 analytics-script
                 ]
                [:div#root]
                [:script {:type "text/javascript" :src "/maps/js/main.js"}]]))})

(defn gauge-app
  [request]
  {:status  200
   :headers {"Content-Type" "text/html"}
   :body
   (str "<!DOCTYPE html>\n"
        (rum/render-html
         [:html
          [:head
           [:title "Instrument Panel Creator"]
           [:meta {:charset "utf-8"}]

           [:link {:rel "stylesheet" :href "/gauge/index.css"}]]
          [:div#root]
          [:script {:type "text/javascript" :src "/gauge/template.js"}]
          [:script {:type "text/javascript" :src "/gauge/js/main.js"}]]))})

(def static-file-root (atom  "resources/"))

(defn add-content-type
  [response requested-path]
  (let [dot (string/last-index-of requested-path ".")
        mime (get {".js" "text/javascript"
                   ".css" "text/css"}
                  (and dot (subs requested-path dot)))]
    (cond-> response mime (ring-resp/content-type mime))))

(defn gzip-bytes
  [bs]
  (let [out (ByteArrayOutputStream.)]
    (with-open [gz (GZIPOutputStream. out)]
      (io/copy bs gz))
    (.toByteArray out)))

(defonce all-client-states (atom {}))

(defn image-for-request
  [{:keys [query-params]}]
  (let [{:strs [lat lng heading zoom out-width out-height]} query-params]
    (gmaps/get-rotated-small-image
     {:lat (Double/parseDouble lat)
      :lng (Double/parseDouble lng)
      :heading (Double/parseDouble heading)
      :zoom (Double/parseDouble zoom)
      :out-width (Integer/parseInt out-width)
      :out-height (Integer/parseInt out-height)})))

(defn get-static-map
  [{:keys [query-params query-string] :as req}]
  (-> {:status 200 :body (image-for-request req)}
      (ring-resp/content-type "image/png")))

(defn bytes-as-hex
  [bs]
  (apply str
         (for [b bs]
           (let [bh (Integer/toHexString (bit-and 0xff (int b)))]
             (cond->> bh
               (= 1 (count bh)) (str "0"))))))

(defn sha1hex
  [bytes]
  (->> bytes
       (.digest (MessageDigest/getInstance "SHA-1"))
       bytes-as-hex))


(defonce dynamic-repo-cache (atom {}))
(comment (reset! dynamic-repo-cache {}))

(defn process-json-data
  [jd]
  (walk/postwalk
   (fn [e]
     (if-not (vector? e)
       e
       (case (first e)
         "elevaterloy" (let [[_ lat lng] e]
                         (gmaps/get-elevation lat lng))
         e)))
   jd))

(defn cached-url-fetch
  [url]
  (let [k [:url url] ]
    (if-let [cache (get @dynamic-repo-cache k)]
      cache
      (let [{:keys [status body]} (try (client/get url {:as :byte-array})
                                       (catch Exception e
                                         (throw (ex-info "Cannot fetch url " {:url url} e))))]
        (swap! dynamic-repo-cache assoc k body)
        body))))

(defn stream->bytes
  [in]
  (let [ba (ByteArrayOutputStream.)]
    (io/copy in ba)
    (.toByteArray ba)))

(defn process-zip!
  [istream prefix]
  (with-open [zis (ZipInputStream. istream)]
    (loop [ze (.getNextEntry zis)
           acc []]
      (if-not ze
        acc
        (let [n (.getSize ze)
              ba (ByteArrayOutputStream.)
              _ (io/copy zis ba)
              buf (.toByteArray ba)
              hash (sha1hex buf)
              cas-key [:sha1 hash]]

          (when-not (contains? @dynamic-repo-cache cas-key)
            (swap! dynamic-repo-cache assoc cas-key buf))
          
          (.closeEntry zis)
          (recur (.getNextEntry zis)
                 (if (.isDirectory ze)
                   acc
                   (conj acc
                         {:destination (str prefix (.getName ze))
                          :size n
                          :hash (sha1hex buf)}))))))))


(def included-apps
  (delay
    (let [base "compiled-apps"]
      (into {}
            (for [ma (string/split-lines (slurp (io/resource (str base "/manifest.txt"))))
                  :let [[_ app vers] (re-find #"(.*)-v(.*)\.zip" ma)]]
              [app (io/resource (str base "/" ma))])))))

(def app-info-map
  (delay
    (let [base "compiled-apps"
          apps (keys @included-apps)]
      (->> apps
           (map #(-> (str base "/" % "/App.json") io/resource io/reader (json/parse-stream true)))
           (zipmap apps)))))

(defn appslist
  [req]
  {:status  200
   :headers {"Content-Type" "text/html"}
   :body    (str "<!DOCTYPE html>\n"
                 (rum/render-html
                  [:html
                   [:head
                    [:title "Apps index"]
                    [:meta {:charset "utf-8"}]
                    [:link {:rel "stylesheet" :href "/maps/app.css"}]]
                   [:body
                    [:ul {}
                     (for [[app info] @app-info-map]
                       [:li {}
                        [:div {}
                         [:p (-> info :name :en)]
                         (let [durl (-> info :description :en)
                               [_ path]    (->> durl
                                                (re-find (re-pattern (str app "/(.*)"))))]
                           (when path
                             [:iframe {:src         (str "/app-file/" app "/" path)
                                       :width       "50%"
                                       :height      "500px"
                                       :frameborder 0}]))
                         ]])]]]))})

(defn cached-proxy
  [url]
  (let [body (cached-url-fetch url)
        hash-val (sha1hex body)]
    (swap! dynamic-repo-cache assoc [:sha1 hash-val]
           (with-open [baos (ByteArrayOutputStream.)]
             (io/copy body baos)
             (.toByteArray baos)))
    {:size (count body)
     :hash hash-val}))

(defn process-file-spec
  [{:strs [url data data-base64 json-data zip-url prefix app] :as obj}]
  (or
   (when json-data
     (let [enc (-> json-data
                   (process-json-data)
                   (json/generate-string)
                   (.getBytes "utf-8"))
           hash (sha1hex enc)]
       (swap! dynamic-repo-cache assoc [:sha1 hash] enc)
       [(-> obj
            (dissoc "json-data")
            (assoc :hash hash
                   :size (count enc)))]))
   (when data
     (let [bs (.getBytes data "utf-8")
           hash (sha1hex bs)]
       (swap! dynamic-repo-cache assoc [:sha1 hash] bs)
       [(-> obj
            (dissoc "data")
            (assoc :size (count bs)
                   :hash hash))]))
   
   (when data-base64
     nil 
     (let [bs (.decode (Base64/getDecoder) data-base64)
           hash (sha1hex bs)]
       (swap! dynamic-repo-cache assoc [:sha1 hash] bs)
       [(-> obj
            (dissoc "data-base64")
            (assoc :size (count bs)
                   :hash hash))]))
   
   (when url
     (let [body (cached-url-fetch url)
           hash-val (sha1hex body)]
       (swap! dynamic-repo-cache assoc [:sha1 hash-val]
              (with-open [baos (ByteArrayOutputStream.)]
                (io/copy body baos)
                (.toByteArray baos)))
       [(-> obj
            (dissoc "url")
            (assoc
             :size (count body)
             :hash hash-val))]))

   (when zip-url
     (let [{:keys [status body]} (try (client/get zip-url {:as :byte-array})
                                      (catch Exception e (throw (ex-info "Cannot fetch zip" {:url url} e))))]
       (with-open [in (ByteArrayInputStream. body)]
         (process-zip! in prefix))))

   (when app
     (prn "!!!!!!!!!!!!!!!!!!!!" app)
     (if-let [zr (get @included-apps app)]
       (with-open [in (io/input-stream zr)]
         (process-zip! in "Apps/"))
       (throw (ex-info "No such app" {:app app}))))))

(comment
  
  (process-file-spec {:app "DFM-InsP"})
  (with-open [i (io/input-stream (io/resource "compiled-apps/DFM-InsP-v0.56.zip"))]
    (run! prn (process-zip! i "What"))))

(defn add-cas-url
  [my-url {:keys [url hash] :as e} ]
  (if url
    e
    (assoc e :url (str my-url "/cas?sha1=" hash))))

(def apps-json-empty-repo
  (delay
    {"applications"
     [{"author"      "DFM"
       "description" {"en" "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/master/emptyRepo.html"}
       "files"       [{"destination" "Apps/dummy.lua"
                       "url" "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/master/doesnotexist.lua"
                       "size" 0
                       "hash" "da39a3ee5e6b4b0d3255bfef95601890afd80709"}]
       "hw"          [678 679 680]
       "id"          0
       "name"        {"en" "DFM-Maps - GPS Maps [expired]"}
       "previewIcon" "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/master/DFM.png"
       "releaseDate" "Fri 15 Jan 2021 09:01:54 +0000"
       "version"     "1"}]}))

(defn create-app-json!
  [yoururl dynamic-files]
  (let [files (->> dynamic-files
                   (mapv #(future (process-file-spec %)))
                   (mapcat deref)
                   (map (partial add-cas-url yoururl)))
        [manifest-file?] (->> files
                              (filter #(string/ends-with? (get % :destination "") "/App.json")))
        
        _ (when-not manifest-file?
            (throw (ex-info "No app.json" {:files files})))
        
        app-json-data (->> (get @dynamic-repo-cache [:sha1 (:hash manifest-file?)])
                           (io/reader)
                           (json/parse-stream)
                           (walk/postwalk
                            (fn [e]
                              (if-not (and (string? e) (string/starts-with? e "https://"))
                                e
                                (str yoururl "/cas?sha1=" (:hash (cached-proxy e)))))))]
    (assoc app-json-data
           :files files
           :description {:en (str yoururl "/app/" )})))

(defn app-json-next!
  [yoururl base-app dynamic-files]
  (let [base "compiled-apps"
        files (->> (into [{"app" base-app}] dynamic-files)
                   (mapv #(future (process-file-spec %)))
                   (mapcat deref)
                   (map (partial add-cas-url yoururl)))
        manifest-file (io/resource (str base "/" base-app "/App.json"))
        
        app-json-data (->> manifest-file
                           (io/reader)
                           (json/parse-stream))]
    (assoc app-json-data
           "files" files
           "description" {"en" (str yoururl "/app/" base-app "/" base-app ".html" )})))

(defn no-https
  [url]
  (let [http "http://"
        https "https://"]
    (if-not (string/starts-with? url https)
      url
      (str http (subs url (count https))))))


#_(defn do-dynamic-repo-v2
  [{:keys [query-params query-string body] :as req}]
  (let [{:strs [token]} query-params
        {:strs [dynamic-files yoururl] :as opts} (json/parse-stream (io/reader body))
        yoururl (no-https yoururl)
        
        apps-json (cond
                    (sequential? dynamic-files)
                    {:applications [(create-app-json! yoururl dynamic-files)]}
                    
                    (map? dynamic-files)
                    {:applications (for [[_ fs] dynamic-files
                                         :when (not-empty fs)]
                                     (create-app-json! yoururl fs))})]
    
    (swap! dynamic-repo-cache assoc [:token token]
           (-> apps-json
               (json/generate-string)
               (.getBytes "utf-8")))
    
    {:status 200
     :headers {"Content-Type" "application/json"} 
     :body (json/generate-string
            {"repo_url"
             (str yoururl "/repo/" token "/Apps.json") })}))


(defn do-dynamic-repo-v3
  [{:keys [query-params query-string body] :as req}]
  (let [{:strs [token]} query-params
        {:strs [apps yoururl] :as opts} (json/parse-stream (io/reader body))
        yoururl (no-https yoururl)
        
        apps-json {:applications
                   (for [{:strs [base-app dynamic-files]} apps]
                     (app-json-next! yoururl base-app dynamic-files))}]
    
    (swap! dynamic-repo-cache assoc [:token token]
           (-> apps-json
               (json/generate-string)
               (.getBytes "utf-8")))
    
    {:status 200
     :headers {"Content-Type" "application/json"} 
     :body (json/generate-string
            {"repo_url"
             (str yoururl "/repo/" token "/Apps.json") })}))

(defn do-dynamic-repo-zip
  [{:keys [route-params]}]
  (let [{:keys [token]} route-params
        {:strs [applications]} (json/parse-stream (io/reader (get @dynamic-repo-cache [:token token])))
        [{:strs [files]} & more] applications]
    {:status 200
     :body (with-open [baos (ByteArrayOutputStream.)]
             (with-open  [zip-out (ZipOutputStream. baos)]
               (doseq [{:strs [destination hash]} files]
                 (.putNextEntry zip-out (ZipEntry. destination))
                 (io/copy (get @dynamic-repo-cache [:sha1 hash]) zip-out)))
             (.toByteArray baos))}))

(defn do-cas
  [{:keys [query-params query-string body] :as req}]
  (when-let [bs (get @dynamic-repo-cache [:sha1 (get query-params "sha1")]) ]
    {:status 200 :body bs}))

(defn do-repo
  [token]
  (if-let [bs (get @dynamic-repo-cache [:token token]) ]
    {:status 200 :body bs}
    {:status 200 :body (-> @apps-json-empty-repo
                           (json/generate-string )
                           (.getBytes "utf-8"))}))

(defn do-elevation
  [{:keys [query-params query-string body] :as req}]
  (let [{:strs [lat lng]} query-params]
    (gmaps/get-elevation
     (Double/parseDouble lat)
     (let [x (Double/parseDouble lng)]
       (if ( < x -180)
         (+ 360 x)
         x)))))

#_(defn handler
  [{:keys [uri] :as req}]
  (let [u (string/lower-case uri) ]
    (println "Handler" u)
    (cond
      (= "/" uri)            (landing-page req)
      (= "/create-maps" uri) (maps-app req)
      (= "/gauges" uri)      (gauge-app req)
      
      (string/includes? u "..") {:status 402}
      (#{"/js/main.js" "/app.css"} u)
      (let [sfp (str "static" uri)]
        (some-> (or (ring-resp/resource-response sfp)
                    (ring-resp/file-response (str @static-file-root sfp)))
                (add-content-type u)
                (update :headers assoc "Cache-Control" "no-cache" )))
      
      (string/starts-with? u "/gauge")
      (some-> (or (ring-resp/resource-response uri)
                  (ring-resp/file-response (str @static-file-root uri)))
              (add-content-type u)
              (update :headers assoc "Cache-Control" "no-cache" ))
      
      (string/starts-with? u "/staticmap")
      (get-static-map req)
      
      (string/starts-with? u "/dynamic-repo-zip")
      (do-dynamic-repo-zip req)
      
      (string/starts-with? u "/dynamic-repo-v2")
      (do-dynamic-repo-v2 req)

      
      (string/starts-with? u "/cas")
      (do-cas req)

      :else
      (when-let [[[_ token]] (re-seq #".*/(.*)/Apps.json" uri)]
        (println 'Token token)
        (do-repo token)))))

(defn do-token-repo
  [{:keys [route-params]}]
  (if-let [t (:token route-params)]
    (do-repo t)
    {:status 400 :body "No token?"}))

(defn do-info
  [req]
  {:status 200 :body "This is my info handler."})



(comment
  (io/resource "compiled-apps/DFM-InsP-v0.5.zip")
  (io/resource "maps/app.css")
  )

(defn gauge-app
  [req]
  (prn "Gauge app")
  (ring-resp/resource-response "gauges/template.html"))


(defn do-app-file
  [{:keys [route-params] :as req}]
  (let [app (:appname route-params)]
    (println "Dooappfile" route-params)
    (if-not app
      {:status 400 :body "No token?"}
      (if-not (some? (io/resource (str  "compiled-apps/" app "/App.json" )))
        {:status 404 :body "No such app"}
        (ring-resp/resource-response (str "compiled-apps/" (subs (:uri req) (count "/app/"))))
        #_{:status 200 :body (subs (:uri req)
                                   (count "/app/"))}))))


(def routes
  ["/" {"gauges"          #'gauge-app
        "gauges/"         (bring/resources {:prefix "gauges/"})
        ;; "DFM-InsP/"       (bring/files {:dir "DFM-InsP"})n
        "dynamic-repo-v2" #'do-dynamic-repo-v2
        "dynamic-repo-v3" #'do-dynamic-repo-v3
        "repo/"           {[:token "/Apps.json"] (bidi/tag #'do-token-repo :apps-json)
                           [:token ".zip"]       (bidi/tag #'do-dynamic-repo-zip :zip)}
        "cas"             (bidi/tag #'do-cas :cas)
        "info"            #'do-info
        "create-maps"     #'maps-app
        "maps/"           (bring/resources {:prefix "maps/"})
        "staticmap"       #'get-static-map
        "apps"            #'appslist
        "app/"            {[:appname] {true (bidi/tag #'do-app-file :app-file)}}
        "app-file/"       (bring/files {:dir "."})}])

(def app
  (-> (bring/make-handler routes)
      (ring-params/wrap-params)))

(comment
  
  (for [ma (string/split-lines (slurp (io/resource "compiled-apps/manifest.txt")))]
    [(io/resource (str "compiled-apps/" ma ".lua"))
     (io/resource (str "compiled-apps/" ma ".lc") )
     (io/resource (str "compiled-apps/" ma) )]))

(comment
  (bidi/match-route routes "/repo/GTH47HRF/Apps.json")
  (bidi/match-route routes "/repo/GTH47HRF.zip")
  (bidi/path-for routes :repo :id "F")

  (bidi/match-route routes "/app/DFM-InsP/DFM-InsP.html")
  
  )

(defn start-dev
  []
  (doseq [s @servers] (s))
  (reset! servers [])
  (swap! servers conj
         (hk/run-server
          app
          #_(-> #'handler
                (ring-params/wrap-params))
          {:port 8098})))

(comment
  (start-dev))
