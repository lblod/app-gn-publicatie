;;;;;;;;;;;;;;;;;;;
;;; delta messenger
(in-package :delta-messenger)

(setf *delta-handlers* nil)
(add-delta-logger)
(add-delta-messenger "http://deltanotifier/")

;;;;;;;;;;;;;;;;;
;;; configuration
(in-package :client)
(setf *backend* "http://virtuoso:8890/sparql")
(setf *log-sparql-query-roundtrip* t)

;;; Enable for extra logging
; (setf *log-sparql-query-roundtrip* t)
; (setf *log-incoming-requests* t)

;;;;;;;;;;;;;;;;;
;;; access rights

(in-package :acl)

(defparameter *access-specifications* nil
  "All known ACCESS specifications.")

(defparameter *graphs* nil
  "All known GRAPH-SPECIFICATION instances.")

(defparameter *rights* nil
  "All known GRANT instances connecting ACCESS-SPECIFICATION to GRAPH.")

; This incantation tells sparql-parser to treat any subject with a URI starting with a certain
; prefix as having a specific rdf:type
(type-cache::add-type-for-prefix "http://mu.semte.ch/sessions/" "http://mu.semte.ch/vocabularies/session/Session")

(define-graph session-graph ("http://mu.semte.ch/graphs/sessions")
  ("http://mu.semte.ch/vocabularies/session/Session" -> _)
)

(define-graph public-graph ("http://mu.semte.ch/graphs/public")
  ("http://mu.semte.ch/vocabularies/ext/BestuursorgaanClassificatieCode" -> _)
  ("http://mu.semte.ch/vocabularies/ext/BestuurseenheidClassificatieCode" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Bestuursorgaan" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Bestuurseenheid" -> _)
  ("http://www.w3.org/ns/prov#Location" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Zitting" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Stemming" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Besluit" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Artikel" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Agenda" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Agendapunt" -> _)
  ("http://data.vlaanderen.be/ns/besluit#BehandelingVanAgendapunt" -> _)
  ("http://data.vlaanderen.be/ns/besluit#Stemming" -> _)
  ("http://data.vlaanderen.be/ns/mandaat#Mandaat" -> _)
  ("http://data.vlaanderen.be/ns/mandaat#Mandataris" -> _)
  ("http://data.vlaanderen.be/ns/mandaat#Fractie" -> _)
  ("http://mu.semte.ch/vocabularies/ext/signing/PublishedResource" -> _)
  ("http://www.w3.org/2004/02/skos/core#Concept" -> _)
  ("http://www.w3.org/2004/02/skos/core#ConceptScheme" -> _)
  ("http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#FileDataObject" -> _))

(supply-allowed-group "public")

(grant (read)
       :to-graph public-graph
       :for-allowed-group "public")