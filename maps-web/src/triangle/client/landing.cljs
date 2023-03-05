(ns triangle.client.landing
  (:require [rum.core :as rum]))

(defn youtube-embed
  [url]
  [:iframe {:src url
            :width 320
            :height 240
            :frameborder 0
            :allow "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            :allowfullscreen true}])

(rum/defc root-component < rum/reactive [conn bus]
  [:div.lp-root {:style {:font-family "sans-serif"}}
   [:h1 "Dave and Harry's Jeti Lua Apps"]
   [:p.lp-indent
    "Extending the functions of the Jeti RC systems can provide significant "
    "new capabilities, especially in the use of telemetry sensors. This is "
    "the home page for a collaboration between Dave McQueeney and Harry "
    "Curzon for a series of Jeti apps that we have developed to further our "
    "interests in our RC aircraft hobby. Harry also has a " [:a {:href "https://www.youtube.com/user/cotswoldpilot"} "YouTube channel "]
    "with information and tutorials on the use of Jeti systems."]
   
   [:h3 "DFM-Maps"]
   [:div.lp-indent
    [:p
     "Our first release on this site is a flight display app (DFM-Maps) that "
     "can overlay your aircraft's flight pattern on a series of Google maps "
     "images while flying. We have a website where you can create a set of "
     "maps for your flying field(s). These maps can include a runway, a set of "
     "circular or polygonal no-fly zones, and even a GPS triangle race course."]
    [:h4 "Screenshots"]
    [:div.lp-screenshot
     [:img {:src "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/dev/Screenshots/DFM-Maps196.png"}]
     [:img {:src "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/dev/Screenshots/DFM-Maps199.png"}]
     [:img {:src "https://raw.githubusercontent.com/davidmcq137/JetiLuaDFM/dev/Screenshots/DFM-Maps190.png"}]]
    [:h4 "Video tutorials"]
    [:div.lp-screenshot {:style {:margin-top "2ex"}}
     (youtube-embed "https://www.youtube.com/embed/53ELHC4AZJc")
     (youtube-embed "https://www.youtube.com/embed/JX3DzkZhP_U")
     (youtube-embed "https://www.youtube.com/embed/TuDt0r6rF5I")]
    
    
    [:h4 "Setup"]
    [:div.lp-indent
     [:p "To install DFM-Maps, you will need to use our web setup tool - "
      [:a {:target "_blank" :href "/create-maps"} "click here to open it. "]]
     [:p "Then, after following these three steps, you will have the app up and running with maps for your field!"]
     [:ol
      [:li [:span.lp-step "Create the field information"]
       [:p "Navigate so that your flying field is in the middle of the map, and click "
        "\"New field at map center\"."]
       [:p "If you can't find the field, you can right-click anywhere on "
        [:a {:target "_blank" :href "https://www.google.com/maps"} "regular Google maps"]
        " to copy a lat/long, which you can paste into our tool at the lower left."]]

      [:li [:span.lp-step "Create your JETI repository"]
       [:p "When you are happy with the field, click \"Create JETI repository\". "]
       [:p "This will create for you a unique URL which you can add as a repository in "
        [:a {:href "https://www.jetimodel.com/support/jeti-studio/jeti-studio.html"} "JETI Studio"]
        ". The repository is unique to you - it includes both the app itself, and your field data."]]
      [:li
       [:span.lp-step "Install DFM-Maps with " [:a {:href "https://www.jetimodel.com/support/jeti-studio/jeti-studio.html"} "JETI Studio"]]
       [:p "In JETI Studio, open File > Configuration > App Sources, and paste your repository URL."]
       [:p "Then use the Lua App Manager to download the app and your maps to your transmitter."]]]
     
     [:p "When you load the DFM-Maps app into one of your models, it will display the set "
      "of images for the field where the aircraft is located, and while flying "
      "it will overlay the aircraft's position on the map in the transmitter's "
      "screen. It will also warn of upcoming no-fly zones, and can announce "
      "verbally or via a stick shaker a no-fly breach. It can even verbally "
      "direct you to fly around a "
      [:a {:href "https://gps-triangle.net/"} "GPS triangle"]
      " race course."]]]

   [:h4 "Note"]
   [:p.lp-indent "We are doing this as part of our hobby and these apps are offered free of charge."]
   [:p.lp-indent
    "We welcome anyone who would like to collaborate on their future development! "
    [:a {:href "https://github.com/davidmcq137/JetiLuaDFM/tree/master/DFM-Maps"}
     "Check us out on GitHub!"]]
     
   [:h4 "Disclaimer"]
   [:p.lp-indent
    "The apps are provided \"as-is\" under the MIT open source license, and you "
    "are soley responsible to determine if they are suitable for your own "
    "purposes, and for their safe and prudent operation. We do not offer any "
    "guarantee and will not accept any liability for their use."]])
