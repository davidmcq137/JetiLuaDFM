(ns drs.main
  (:require
   [drs.server :as s]
   [org.httpkit.server :as hk])
  (:gen-class))

(defn -main [& args]
  (println "Drs main???????")
  (let [port (or (some-> (System/getenv "PORT")
                         (Integer/parseInt))
                 8080)] 
    (println "Server port??????" port)
    (hk/run-server s/app {:port port})))

