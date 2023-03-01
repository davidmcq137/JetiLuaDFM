(ns user
  (:require
   [shadow.cljs.devtools.api :as shadow]
   [shadow.cljs.devtools.server :as server]
   [nrepl.server :as nrepl-server]
   [clojure.java.io :as io]
   [clojure.edn :as edn]
   [clojure.walk :as walk]
   [clojure.string :as string]
   [uberdeps.api :as uberdeps]))

(defonce shadow-server (delay (future (server/start!))))

(defonce nrepl-server
  (let [port-file (io/file ".nrepl-port")
        {:keys [port]} (nrepl-server/start-server #_#_:handler cnr/cider-nrepl-handler)]
    (println "started nrepl server on port" port)
    (spit ".nrepl-port" port)))

(defonce shadow-watch
  (delay
    (future
      @@shadow-server
      (shadow/watch :gauge))))

(defonce server-lazy
  (delay
   (future
     @@shadow-watch
     (println "######### Requiring server....")
     (require '[drs.server])
     (println "!!!!!!!!! Starting server...")
     ((ns-resolve 'drs.server 'start-dev)))))

(defn go []
  @@server-lazy
  :ok)


(defn release-cljs
  [& what]
  @shadow-server
  (doseq [w what]
    (shadow/release w)))

(defn release-cljs-and-exit
  [& what]
  (apply release-cljs what)
  (System/exit 0))

(defn clean []
  (let [cls (io/file "classes")]
    (some->> cls
             file-seq
             not-empty
             next
             reverse
             (run! io/delete-file))
    (io/make-parents (io/file cls "whatever"))))

(defn jar []
  (let [exclusions [#"\.DS_Store"
                    #".*\.cljs"
                    #"cljsjs/.*"
                    #"user\.clj"]
        deps       (-> (slurp "deps.edn")
                       (clojure.edn/read-string)
                       (update :paths conj "classes")
                       (update :deps dissoc
                               'thheller/shadow-cljs
                               'uberdeps/uberdeps))]
    (binding [uberdeps/level :error]
      (uberdeps/package deps "ffff.jar"
                        {:aliases    #{:uberjar}
                         :exclusions exclusions
                         :main-class "drs.main"}))))

(defn uberjar []
  (clean)
  (println "Compile clj...")
  (compile 'drs.main)
  #_(run! println (file-seq (io/file "classes")))
  (println "Compile cljs...")
  (release-cljs :gauge)
  (println "Jar...")
  (jar))

(defn build-uberjar-and-exit []
  (uberjar)
  (println "Finished")
  (System/exit 0))

