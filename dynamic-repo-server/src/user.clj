(ns user
  (:require
   [shadow.cljs.devtools.api :as shadow]
   [shadow.cljs.devtools.server :as server]
   [nrepl.server :as nrepl-server]
   [clojure.java.io :as io]
   [clojure.edn :as edn]
   [clojure.walk :as walk]
   [clojure.string :as string]))

(defonce shadow-server (future (server/start!)))

(defonce nrepl-server
  (let [port-file (io/file ".nrepl-port")
        {:keys [port]} (nrepl-server/start-server #_#_:handler cnr/cider-nrepl-handler)]
    (println "started nrepl server on port" port)
    (spit ".nrepl-port" port)))

(defn release-cljs-and-exit
  [& what]
  @shadow-server
  (doseq [w what]
   (shadow/release w))
  (System/exit 0))
