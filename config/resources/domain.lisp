(in-package :mu-cl-resources)

(defparameter *cache-count-queries* nil)
(defparameter *supply-cache-headers-p* t
  "when non-nil, cache headers are supplied.  this works together with mu-cache.")
;;(setf *cache-model-properties-p* t)
(defparameter *include-count-in-paginated-responses* t
  "when non-nil, all paginated listings will contain the number
   of responses in the result object's meta.")
(defparameter *max-group-sorted-properties* nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COMMON MODELS ;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-resource file ()
  :class (s-prefix "nfo:FileDataObject")
  :properties `((:name :string ,(s-prefix "nfo:fileName"))
                (:format :string ,(s-prefix "dct:format"))
                (:size :number ,(s-prefix "nfo:fileSize"))
                (:extension :string ,(s-prefix "dbpedia:fileExtension"))
                (:created :datetime ,(s-prefix "nfo:fileCreated")))
  :has-one `((file :via ,(s-prefix "nie:dataSource")
                   :inverse t
                   :as "download"))
  :resource-base (s-url "http://data.example.com/files/")
  :features `(include-uri)
  :on-path "files"
)

(define-resource concept ()
  :class (s-prefix "skos:Concept")
  :properties `((:label :string ,(s-prefix "skos:prefLabel"))
                (:notation :string ,(s-prefix "skos:notation"))
                (:search-label :string ,(s-prefix "ext:searchLabel")))
  :has-many `((concept-scheme :via ,(s-prefix "skos:inScheme")
                              :as "concept-schemes")
              (concept-scheme :via ,(s-prefix "skos:topConceptOf")
                              :as "top-concept-schemes"))
  :resource-base (s-url "http://lblod.data.gift/concepts/")
  :features `(include-uri)
  :on-path "concepts"
)

(define-resource concept-scheme ()
  :class (s-prefix "skos:ConceptScheme")
  :properties `((:label :string ,(s-prefix "skos:prefLabel")))
  :has-many `((concept :via ,(s-prefix "skos:inScheme")
                       :inverse t
                       :as "concepts")
              (concept :via ,(s-prefix "skos:topConceptOf")
                       :inverse t
                       :as "top-concepts"))
  :resource-base (s-url "http://lblod.data.gift/concept-schemes/")
  :features `(include-uri)
  :on-path "concept-schemes"
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MEETING/ZITTING MODELS ;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;TODO how to relate to superclass 'Agent' for heeftAanwezige
(define-resource zitting ()
  :class (s-prefix "besluit:Zitting")
  :properties `((:geplande-start :datetime ,(s-prefix "besluit:geplandeStart"))
                (:gestart-op-tijdstip :datetime ,(s-prefix "prov:startedAtTime"))
                (:geeindigd-op-tijdstip :datetime ,(s-prefix "prov:endedAtTime"))
                (:op-locatie :url ,(s-prefix "prov:atLocation")))

  :has-many `((agendapunt :via ,(s-prefix "besluit:behandelt")
                          :as "agendapunten")
              (uittreksel :via ,(s-prefix "ext:uittreksel")
                          :as "uittreksels")
              (agenda :via ,(s-prefix "ext:agenda")
                          :as "agendas"))

  :has-one `((bestuursorgaan :via ,(s-prefix "besluit:isGehoudenDoor")
                             :as "bestuursorgaan")
             (notulen :via ,(s-prefix "besluit:heeftNotulen")
                      :as "notulen")
             (besluitenlijst :via ,(s-prefix "ext:besluitenlijst")
                      :as "besluitenlijst"))
  :resource-base (s-url "http://data.lblod.info/id/zittingen/")
  :features '(include-uri)
  :on-path "zittingen"
)

(define-resource agendapunt ()
  :class (s-prefix "besluit:Agendapunt")
  :properties `((:beschrijving :string ,(s-prefix "dct:description"))
                (:gepland-openbaar :boolean ,(s-prefix "besluit:geplandOpenbaar"))
                (:heeft-ontwerpbesluit :url ,(s-prefix "besluit:heeftOntwerpbesluit"))
                (:titel :string ,(s-prefix "dct:title"))
                (:position :int ,(s-prefix "schema:position")))
  :has-many `((agendapunt :via ,(s-prefix "dct:references")
                          :as "referenties")
              (published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                                  :as "publications"))
  :has-one `((agendapunt :via ,(s-prefix "besluit:aangebrachtNa")
                         :as "vorige-agendapunt")
             (concept :via ,(s-prefix "besluit:Agendapunt.type")
                         :as "type")
             (behandeling-van-agendapunt :via ,(s-prefix "dct:subject")
                                         :inverse t
                                         :as "behandeling"))
  :resource-base (s-url "http://data.lblod.info/id/agendapunten/")
  :features '(include-uri)
  :on-path "agendapunten"
)

(define-resource behandeling-van-agendapunt ()
  :class (s-prefix "besluit:BehandelingVanAgendapunt")
  :properties `((:openbaar :boolean ,(s-prefix "besluit:openbaar"))
                (:gevolg :language-string ,(s-prefix "besluit:gevolg"))
                (:afgeleid-uit :string ,(s-prefix "pav:derivedFrom"))
                (:position :int ,(s-prefix "schema:position")))
  :has-many `((besluit :via ,(s-prefix "prov:generated")
                       :as "besluiten")
              (stemming :via ,(s-prefix "besluit:heeftStemming")
                          :as "stemmingen"))
  :has-one `((behandeling-van-agendapunt :via ,(s-prefix "besluit:gebeurtNa")
                                         :as "vorige-behandeling-van-agendapunt")
             (agendapunt :via ,(s-prefix "dct:subject")
                              :as "onderwerp")
            (uittreksel :via ,(s-prefix "ext:uittrekselBvap")
                                         :inverse t
                                         :as "uittreksel"))
  :resource-base (s-url "http://data.lblod.info/id/behandelingen-van-agendapunt")
  :features '(include-uri)
  :on-path "behandelingen-van-agendapunten"
)

(define-resource stemming ()
  :class (s-prefix "besluit:Stemming")
  :properties `((:aantal-onthouders :number ,(s-prefix "besluit:aantalOnthouders"))
                (:aantal-tegenstanders :number ,(s-prefix "besluit:aantalTegenstanders"))
                (:aantal-voorstanders :number ,(s-prefix "besluit:aantalVoorstanders"))
                (:geheim :boolean ,(s-prefix "besluit:geheim"))
                (:title :string ,(s-prefix "dct:title"))
                (:gevolg :string ,(s-prefix "besluit:gevolg"))
                (:onderwerp :string ,(s-prefix "besluit:onderwerp")))
  :resource-base (s-url "http://data.lblod.info/id/stemmingen/")
  :features '(include-uri)
  :on-path "stemmingen"
)

(define-resource besluit ()
  :class (s-prefix "besluit:Besluit")
  :properties `((:beschrijving :string ,(s-prefix "eli:description"))
                (:citeeropschrift :string ,(s-prefix "eli:title_short"))
                (:motivering :language-string ,(s-prefix "besluit:motivering"))
                (:publicatiedatum :date ,(s-prefix "eli:date_publication"))
                (:inhoud :string ,(s-prefix "prov:value"))
                (:taal :url ,(s-prefix "eli:language"))
                (:parts :uri-set ,(s-prefix "eli:related_to"))
                (:titel :string ,(s-prefix "eli:title"))
                (:type :uri-set ,(s-prefix "rdf:type"))
                (:score :float ,(s-prefix "nao:score")))
  :has-one `((behandeling-van-agendapunt :via ,(s-prefix "prov:generated")
                                         :inverse t
                                         :as "volgend-uit-behandeling-van-agendapunt")
             (besluitenlijst :via ,(s-prefix "ext:besluitenlijstBesluit")
                             :inverse t
                             :as "besluitenlijst")
              (besluit :via ,(s-prefix "eli:consolidates") :as "linked-decision"))
  :has-many `((published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                                  :as "publications"))
  :resource-base (s-url "http://data.lblod.info/id/besluiten/")
  :features '(include-uri)
  :on-path "besluiten"
)

(define-resource besluitenlijst ()
  :class (s-prefix "ext:Besluitenlijst")
  :properties `((:inhoud :string ,(s-prefix "prov:value"))
                (:publicatiedatum :date ,(s-prefix "eli:date_publication")))
  :has-one `((published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                                 :as "publication")
             (zitting :via ,(s-prefix "ext:besluitenlijst")
                      :inverse t
                      :as "zitting"))
  :has-many `((besluit :via ,(s-prefix "ext:besluitenlijstBesluit")
                                          :as "besluiten"))
  :resource-base (s-url "http://data.lblod.info/id/besluitenlijsten/")
  :features '(include-uri)
  :on-path "besluitenlijsten"
)

(define-resource notulen ()
  :class (s-prefix "ext:Notulen")
  :properties `((:inhoud :string ,(s-prefix "prov:value")))
  :has-one `((zitting :via ,(s-prefix "besluit:heeftNotulen")
                      :inverse t
                      :as "zitting")
             (published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                                  :as "publication")
             (file :via ,(s-prefix "prov:generated")
                   :as "file"))
  :resource-base (s-url "http://data.lblod.info/id/notulen/")
  :features '(include-uri)
  :on-path "notulen"
)

(define-resource uittreksel ()
  :class (s-prefix "ext:Uittreksel")
  :properties `((:inhoud :string ,(s-prefix "prov:value")))
  :has-one `((published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                                 :as "publication")
             (behandeling-van-agendapunt :via ,(s-prefix "ext:uittrekselBvap")
                                         :as "behandeling-van-agendapunt")
             (zitting :via ,(s-prefix "ext:uittreksel")
                      :inverse t
                      :as "zitting"))
  :resource-base (s-url "http://data.lblod.info/id/uittreksels/")
  :features '(include-uri)
  :on-path "uittreksels"
)

(define-resource versioned-agenda ()
  :class (s-prefix "ext:VersionedAgenda")
  :properties `((:state :string ,(s-prefix "ext:stateString"))
                (:content :string ,(s-prefix "ext:content"))
                (:kind :string ,(s-prefix "ext:agendaKind")))
  :has-many `((signed-resource :via ,(s-prefix "ext:signsAgenda")
                               :inverse t
                               :as "signed-resources"))
  :has-one `((published-resource :via ,(s-prefix "ext:publishesAgenda")
                                 :inverse t
                                 :as "published-resource"))
  :resource-base (s-url "http://data.lblod.info/prepublished-agendas/")
  :features '(include-uri)
  :on-path "versioned-agendas"
)

(define-resource versioned-behandeling ()
  :class (s-prefix "ext:VersionedBehandeling")
  :properties `((:state :string ,(s-prefix "ext:stateString"))
                (:content :string ,(s-prefix "ext:content")))
  :has-many `((signed-resource :via ,(s-prefix "ext:signsBehandeling")
                               :inverse t
                               :as "signed-resources"))
  :has-one `((published-resource :via ,(s-prefix "ext:publishesBehandeling")
                                 :inverse t
                                 :as "published-resource")
             (behandeling-van-agendapunt :via ,(s-prefix "ext:behandeling")
                                         :as "behandeling"))
  :resource-base (s-url "http://data.lblod.info/prepublished-behandeling/")
  :features '(include-uri)
  :on-path "versioned-behandelingen"
)

(define-resource versioned-besluiten-lijst ()
  :class (s-prefix "ext:VersionedBesluitenLijst")
  :properties `((:state :string ,(s-prefix "ext:stateString"))
                (:content :string ,(s-prefix "ext:content")))
  :has-many `((signed-resource :via ,(s-prefix "ext:signsBesluitenlijst")
                               :inverse t
                               :as "signed-resources"))
  :has-one `((published-resource :via ,(s-prefix "ext:publishesBesluitenlijst")
                                 :inverse t
                                 :as "published-resource"))
  :resource-base (s-url "http://data.lblod.info/prepublished-besluiten-lijsten/")
  :features '(include-uri)
  :on-path "versioned-besluiten-lijsten"
)

(define-resource versioned-notulen ()
  :class (s-prefix "ext:VersionedNotulen")
  :properties `((:state :string ,(s-prefix "ext:stateString"))
                (:content :string ,(s-prefix "ext:content"))
                (:public-content :string ,(s-prefix "ext:publicContent"))
                (:public-behandelingen :uri-set ,(s-prefix "ext:publicBehandeling"))
                (:kind :string ,(s-prefix "ext:notulenKind")))
  :has-many `((signed-resource :via ,(s-prefix "ext:signsNotulen")
                               :inverse t
                               :as "signed-resources"))
  :has-one `((published-resource :via ,(s-prefix "ext:publishesNotulen")
                                 :inverse t
                                 :as "published-resource"))
  :resource-base (s-url "http://data.lblod.info/prepublished-notulen/")
  :features '(include-uri)
  :on-path "versioned-notulen"
)

(define-resource published-resource ()
  :class (s-prefix "sign:PublishedResource")
  :properties `((:content :string ,(s-prefix "sign:text"))
                (:hash-value :string ,(s-prefix "sign:hashValue"))
                (:created-on :datetime ,(s-prefix "dct:created"))
                (:submission-status :uri ,(s-prefix "ext:submissionStatus")))
  :has-one `((blockchain-status :via ,(s-prefix "sign:status")
                                :as "status")
             (versioned-agenda :via ,(s-prefix "ext:publishesAgenda")
                               :as "versioned-agenda")
             (versioned-besluiten-lijst :via ,(s-prefix "ext:publishesBesluitenlijst")
                                        :as "versioned-besluiten-lijst")
             (versioned-behandeling :via ,(s-prefix "ext:publishesBehandeling")
                                        :as "versioned-behandeling")
             (versioned-notulen :via ,(s-prefix "ext:publiseshNotulen")
                                :as "versioned-notulen"))
  :resource-base (s-url "http://data.lblod.info/published-resources/")
  :features '(include-uri)
  :on-path "published-resources"
)

(define-resource signed-resource ()
  :class (s-prefix "sign:SignedResource")
  :properties `((:content :string ,(s-prefix "sign:text"))
                (:hash-value :string ,(s-prefix "sign:hashValue"))
                (:created-on :datetime ,(s-prefix "dct:created")))
  :has-one `((blockchain-status :via ,(s-prefix "sign:status")
                                :as "status")
             (versioned-agenda :via ,(s-prefix "ext:signsAgenda")
                               :as "versioned-agenda")
             (versioned-besluiten-lijst :via ,(s-prefix "ext:signsBesluitenlijst")
                                        :as "versioned-besluiten-lijst")
             (versioned-notulen :via ,(s-prefix "ext:signsNotulen")
                                :as "versioned-notulen")
             (versioned-behandeling :via ,(s-prefix "ext:signsBehandeling")
                                    :as "versioned-behandeling"))
  :resource-base (s-url "http://data.lblod.info/signed-resources/")
  :features '(include-uri)
  :on-path "signed-resources"
)

(define-resource blockchain-status ()
  :class (s-prefix "sign:BlockchainStatus")
  :properties `((:title :string ,(s-prefix "dct:title"))
                (:description :string ,(s-prefix "dct:description")))
  :resource-base (s-url "http://data.lblod.info/blockchain-statuses/")
  :features '(include-uri)
  :on-path "blockchain-statuses"
)

(define-resource artikel ()
  :class (s-prefix "besluit:Artikel")
  :properties `((:nummer :string ,(s-prefix "eli:number"))
                (:inhoud :string ,(s-prefix "prov:value"))
                (:taal :url ,(s-prefix "eli:language"))
                (:titel :string ,(s-prefix "eli:title"))
                (:page :url ,(s-prefix "foaf:page"))
                (:score :float ,(s-prefix "nao:score")))
  :resource-base (s-url "http://data.lblod.info/id/artikels/")
  :features '(include-uri)
  :on-path "artikels"
)

(define-resource agenda ()
  :class (s-prefix "ext:Agenda")
  :properties `((:inhoud :string ,(s-prefix "prov:value")))
  :has-one `((published-resource :via ,(s-prefix "prov:wasDerivedFrom")
                             :as "publication")
             (zitting :via ,(s-prefix "ext:agenda")
                      :inverse t
                      :as "zitting"))
  :has-many `((agendapunt :via ,(s-prefix "ext:agendaAgendapunt")
                                  :as "agendapunten"))
  :resource-base (s-url "http://data.lblod.info/id/agendas/")
  :features '(include-uri)
  :on-path "agendas"
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ADMINISTRATION/BESTUUR MODELS ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-resource bestuurseenheid ()
  :class (s-prefix "besluit:Bestuurseenheid")
  :properties `((:naam :string ,(s-prefix "skos:prefLabel"))
                (:alternatieve-naam :string-set ,(s-prefix "skos:altLabel"))
                (:wil-mail-ontvangen :boolean ,(s-prefix "ext:wilMailOntvangen")) ;;Voorkeur in berichtencentrum
                (:mail-adres :string ,(s-prefix "ext:mailAdresVoorNotificaties")))
  :has-one `((werkingsgebied :via ,(s-prefix "besluit:werkingsgebied")
                             :as "werkingsgebied")
             (werkingsgebied :via ,(s-prefix "ext:inProvincie")
                             :as "provincie")
             (bestuurseenheid-classificatie-code :via ,(s-prefix "besluit:classificatie")
                                                 :as "classificatie"))
  :has-many `((bestuursorgaan :via ,(s-prefix "besluit:bestuurt")
                              :inverse t
                              :as "bestuursorganen"))
  :resource-base (s-url "http://data.lblod.info/id/bestuurseenheden/")
  :features '(include-uri)
  :on-path "bestuurseenheden"
)

(define-resource bestuurseenheid-classificatie-code ()
  :class (s-prefix "ext:BestuurseenheidClassificatieCode")
  :properties `((:label :string ,(s-prefix "skos:prefLabel"))
                (:scope-note :string ,(s-prefix "skos:scopeNote")))
  :resource-base (s-url "http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/")
  :features '(include-uri)
  :on-path "bestuurseenheid-classificatie-codes"
)

(define-resource bestuursorgaan ()
  :class (s-prefix "besluit:Bestuursorgaan")
  :properties `((:naam :string ,(s-prefix "skos:prefLabel"))
                (:binding-einde :date ,(s-prefix "mandaat:bindingEinde"))
                (:binding-start :date ,(s-prefix "mandaat:bindingStart")))
  :has-one `((bestuurseenheid :via ,(s-prefix "besluit:bestuurt")
                              :as "bestuurseenheid")
             (bestuursorgaan-classificatie-code :via ,(s-prefix "besluit:classificatie")
                                                :as "classificatie")
             (bestuursorgaan :via ,(s-prefix "mandaat:isTijdspecialisatieVan")
                             :as "is-tijdsspecialisatie-van"))
  :has-many `((bestuursorgaan :via ,(s-prefix "mandaat:isTijdspecialisatieVan")
                       :inverse t
                       :as "heeft-tijdsspecialisaties"))
  :resource-base (s-url "http://data.lblod.info/id/bestuursorganen/")
  :features '(include-uri)
  :on-path "bestuursorganen"
)

(define-resource bestuursorgaan-classificatie-code ()
  :class (s-prefix "ext:BestuursorgaanClassificatieCode")
  :properties `((:label :string ,(s-prefix "skos:prefLabel"))
                (:scope-note :string ,(s-prefix "skos:scopeNote")))
  :resource-base (s-url "http://data.vlaanderen.be/id/concept/BestuursorgaanClassificatieCode/")
  :features '(include-uri)
  :on-path "bestuursorgaan-classificatie-codes"
)

(define-resource werkingsgebied ()
  :class (s-prefix "prov:Location")
  :properties `((:naam :string ,(s-prefix "rdfs:label"))
                (:niveau :string, (s-prefix "ext:werkingsgebiedNiveau")))

  :has-many `((bestuurseenheid :via ,(s-prefix "besluit:werkingsgebied")
                               :inverse t
                               :as "bestuurseenheid"))
  :resource-base (s-url "http://data.lblod.info/id/werkingsgebieden/")
  :features '(include-uri)
  :on-path "werkingsgebieden"
)
