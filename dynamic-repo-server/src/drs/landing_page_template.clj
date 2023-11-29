(ns drs.landing-page-template
  (:require
   [drs.server :as serv]
   [clojure.java.io :as io]
   [clojure.string :as string]
   [rum.core :as rum]
   [hickory.core :as hc]
   [hickory.select :as hs]
   [hickory.render :as hr]
   [hickory.convert :as hconv]))

;; FILE base dir: this is part of build 
(def apps-base-dir (str "release-output/" "compiled-apps"))

(defn go []
 (let [app->html (into {}
                       (for [a (get @serv/static-app-repos "DFMHC")]
                         [a
                          (->> (str apps-base-dir "/" a "/" a ".html")
                               io/file
                               slurp
                               hc/parse
                               hc/as-hickory)]))
       appslist [:div {:style {:display :grid
                               :grid-template-columns "8em 1fr"}}
                 (for [[a h] app->html]
                   (rum/fragment
                    [:a {:href (str "#appdesc-" a)} a]
                    [:span {}
                     (->> h
                          (hs/select (hs/class "ShortDescription"))
                          first
                          :content
                          (string/join "")
                          (string/trim))]))]
       appsbody [:div {:class "lp-static-apps-list"}
                 (interpose
                  [:hr]
                  (for [[a h] app->html]
                    [:div.lp-static-app-desc {:id (str "appdesc-" a)}
                     (->> h
                          (hs/select (hs/tag :body))
                          first
                          ((fn [el] (assoc el :tag :div)))
                          hconv/hickory-to-hiccup)]))]]
   (spit 
    (io/file "common-resources/common/landing.html")
    (-> (slurp (io/file "common-resources/common/landing.html.in"))
        (string/replace "%%appslist%%" (rum/render-html appslist))
        (string/replace "%%appsbody%%" (rum/render-html appsbody))))))
