(ns build
  (:require
   [uberdeps.api :as uberdeps]
   [clojure.java.io :as io]))

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

(defn go []
  (clean)
  (println "Compile clj...")
  (compile 'drs.main)
  (println "Compile cljs...")
  (user/release-cljs :br)
  (println "Jar...")
  (jar))

(defn build-uberjar-and-exit []
  (go)
  (println "Finished")
  (System/exit 0))

(comment
  (time (go) ))
