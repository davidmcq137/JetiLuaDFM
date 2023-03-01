(ns dynamic-repo
  (:require [rum.core :as rum])
  (:import [goog.net XhrIo]
           [goog.net EventType]))

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

(def apps-request-result (atom nil))
(def modal-state (atom nil))

(defn send-dynamic-repo-request! [json-data]
  (reset! modal-state :repo-request)
  (let [xhr (XhrIo.)]
    (.listen xhr EventType/COMPLETE
             (fn [_]
               (reset! apps-request-result (.getResponseJson xhr))))
    (.send xhr (str "/dynamic-repo-v2?token=" (get-or-create-token!))
           "POST"
           (.stringify js/JSON json-data nil 2)
           #js {"Content-Type" "application/json;charset=UTF-8"})))

(rum/defc repo-result-modal < rum/reactive
  [] 
  (when-let [st (rum/react modal-state)]
    [:div.modal
     [:div.modal-content
      [:span.close {:on-click #(reset! modal-state nil)} "\u00d7"]
      (case st
        :repo-request (let [res (rum/react apps-request-result)
                            repo_url (some-> res (aget "repo_url"))
                            error (some-> res (aget "error"))]
                        [:div
                         "Dynamic repo request"
                         (cond
                           (nil? res) [:span "Waiting for server..."]
                           error [:p "Server error."]
                           repo_url [:code [:pre repo_url]])])
        (str "Weird modal state:" (pr-str st) ))
      [:div [:button {:on-click #(reset! modal-state nil)} "Close"]]]]))

