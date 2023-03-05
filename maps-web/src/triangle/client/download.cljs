(ns triangle.client.download)

(defn download-string
  [s filename]
  (let [a (.createElement js/document "a")]
    (set! (.-href a)
          (str "data:text/plain;charset=utf-8," (js/encodeURIComponent s)))
    
    (set! (.-download a) filename)
    (.appendChild js/document.body a)
    (.click a)
    (.removeChild js/document.body a)))
