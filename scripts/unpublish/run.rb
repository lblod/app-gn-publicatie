#!/usr/bin/env ruby

require 'bundler/inline'
require 'yaml'
require 'securerandom'
require 'date'
require 'tty-prompt'

$stdout.sync = true
ENV['LOG_SPARQL_ALL']='false'
ENV['MU_SPARQL_ENDPOINT']='http://virtuoso:8890/sparql'
ENV['MU_SPARQL_TIMEOUT']='180'

require 'mu/auth-sudo'

def sparql_escape_uri(value)
  '<' + value.to_s.gsub(/[\\"<>]/) { |s| '\\' + s } + '>'
end

def sparql_escape_string(str)
  '"""' + str.gsub(/[\\"]/) { |s| '\\' + s } + '"""'
end

def search_organization(name)
  # as this query does not know the organization, it can not limit
  # its search to a specific graph.
  name_search="'#{name}*'"
  query = <<~EOF
PREFIX besluit: <http://data.vlaanderen.be/ns/besluit#>
PREFIX bif:     <http://www.openlinksw.com/schemas/bif#>
PREFIX skos:    <http://www.w3.org/2004/02/skos/core#>
SELECT DISTINCT ?org ?name ?classification WHERE {
    ?org a besluit:Bestuurseenheid;
         besluit:classificatie/skos:prefLabel ?classification;
            skos:prefLabel ?name.
    ?name bif:contains #{sparql_escape_string(name_search)}
}
EOF
  Mu::AuthSudo.query(query)
end

def create_quarantine_graph(org_uri)
  graph = "http://lblod.data.gift/graphs/quarantine-#{SecureRandom.uuid}"
  query = <<~EOF
PREFIX besluit: <http://data.vlaanderen.be/ns/besluit#>
PREFIX bif:     <http://www.openlinksw.com/schemas/bif#>
PREFIX skos:    <http://www.w3.org/2004/02/skos/core#>
INSERT DATA {
  GRAPH #{sparql_escape_uri(graph)}{ #{sparql_escape_uri(graph)} a <http://lblod.data.gift/ns/QuarantineGraph>; prov:wasDerivedFrom #{sparql_escape_uri(org_uri)}. }
}
EOF
  result = Mu::AuthSudo.update(query)
  graph
end

def get_meeting_uris_for_org(org_uri)
  query = <<~EOF
SELECT distinct ?meeting WHERE { GRAPH <http://mu.semte.ch/graphs/public> {
 ?meeting a <http://data.vlaanderen.be/ns/besluit#Zitting>.
?meeting <http://data.vlaanderen.be/ns/besluit#isGehoudenDoor>/<http://data.vlaanderen.be/ns/mandaat#isTijdspecialisatieVan>/<http://data.vlaanderen.be/ns/besluit#bestuurt> #{sparql_escape_uri(org_uri)}.
}}
EOF
  Mu::AuthSudo.query(query).map { |b| b[:meeting] }
end

def move_resource_to_quarantine(resource, quarantine_graph)
  query = <<~EOF
  DELETE {
    GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(resource)} ?p ?o
  }}
  INSERT {
   GRAPH #{sparql_escape_uri(quarantine_graph)} {
      #{sparql_escape_uri(resource)} ?p ?o
}
} WHERE { GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(resource)} ?p ?o
}};
EOF
  Mu::AuthSudo.update(query)
end

def existing_quarantine_graph(org_uri)
  query = <<~EOF
PREFIX besluit: <http://data.vlaanderen.be/ns/besluit#>
PREFIX bif:     <http://www.openlinksw.com/schemas/bif#>
PREFIX skos:    <http://www.w3.org/2004/02/skos/core#>
SELECT DISTINCT ?graph WHERE {
  GRAPH ?graph { ?graph a <http://lblod.data.gift/ns/QuarantineGraph>; prov:wasDerivedFrom #{sparql_escape_uri(org_uri)}. }
}
EOF
  result = Mu::AuthSudo.query(query)
  if result.length > 0
    result[0][:graph]
  end
end


def ensure_quarantine_graph(prompt, org_uri)
  graph = existing_quarantine_graph(org_uri)
  if graph
    prompt.say("Reusing existing quarantine graph #{graph}")
  else
    graph = create_quarantine_graph(org_uri)
    prompt.say("Created new quarantine graph #{graph}")
  end
  graph
end

def get_published_uittreksels_for_org(org_uri)
  query = <<~EOF
SELECT distinct ?resource WHERE {
  GRAPH ?h {
   ?meeting a <http://data.vlaanderen.be/ns/besluit#Zitting>.
  ?meeting <http://mu.semte.ch/vocabularies/ext/uittreksel> ?resource.
           ?meeting <http://data.vlaanderen.be/ns/besluit#isGehoudenDoor> ?bestuursorgaan.
  }
  GRAPH <http://mu.semte.ch/graphs/public> {
  ?resource a <http://mu.semte.ch/vocabularies/ext/Uittreksel>.
?bestuursorgaan <http://data.vlaanderen.be/ns/mandaat#isTijdspecialisatieVan>/<http://data.vlaanderen.be/ns/besluit#bestuurt> #{sparql_escape_uri(org_uri)}.
  }
}
EOF
  Mu::AuthSudo.query(query).map { |b| b[:resource] }
end

def quarantine_org(prompt, org_uri)
  prompt.say("This option will move all meeting data related to #{org_uri} to a separate graph and add some metadata to the main graph")
  graph = ensure_quarantine_graph(prompt, org_uri)
  meetings = get_meeting_uris_for_org(org_uri)
  prompt.say("Found #{meetings.size} meetings to quarantine")
  meetings.each do |meeting|
    move_resource_to_quarantine(meeting, graph)
  end
  prompt.say("All meetings moved to quarantine")
  files = get_file_uris_for_org(org_uri)
  prompt.say("Found #{files.size} files to quarantine")
  files.each do |file|
    move_file_to_quarantine(file, graph)
  end
  prompt.say("All files moved to quarantine")
  publications = get_published_uittreksels_for_org(org_uri)
  prompt.say("Found #{publications.size} published uittreksels to quarantine")
  publications.each do |publication|
    move_resource_to_quarantine(publication, graph)
  end
  prompt.say("All uittreksels moved to quarantine")
end

def get_file_uris_for_org(org_uri)
  query = <<~EOF
SELECT distinct ?file WHERE {
  GRAPH ?h {
   ?meeting a <http://data.vlaanderen.be/ns/besluit#Zitting>.
   ?meeting prov:wasDerivedFrom ?resource.
   ?meeting <http://data.vlaanderen.be/ns/besluit#isGehoudenDoor> ?bestuursorgaan.
  }

  GRAPH <http://mu.semte.ch/graphs/public> {
   ?resource <http://mu.semte.ch/vocabularies/ext/hasAttachments> ?attachment.
?bestuursorgaan <http://data.vlaanderen.be/ns/mandaat#isTijdspecialisatieVan>/<http://data.vlaanderen.be/ns/besluit#bestuurt> ?org.
  }
  GRAPH ?g {
    ?attachment <http://mu.semte.ch/vocabularies/ext/hasFile> ?file.
  }
  GRAPH <http://mu.semte.ch/graphs/public> {
    ?file a ?type.
  }
}
EOF
  Mu::AuthSudo.query(query).map { |b| b[:file] }
end

def move_file_to_quarantine(file_uri, quarantine_graph)
  query = <<~EOF
  DELETE {
    GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(file_uri)} ?p ?o.
      ?fileOnDisk <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#dataSource> #{sparql_escape_uri(file_uri)}.
      ?fileOnDisk ?p ?o.
  }}
  INSERT {
   GRAPH #{sparql_escape_uri(quarantine_graph)} {
      #{sparql_escape_uri(file_uri)} ?p ?o.
      ?fileOnDisk <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#dataSource> #{sparql_escape_uri(file_uri)}.
      ?fileOnDisk ?p ?o.
}
} WHERE { GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(file_uri)} ?p ?o.
      ?fileOnDisk <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#dataSource> #{sparql_escape_uri(file_uri)}.
      ?fileOnDisk ?p ?o.
}};
EOF
  Mu::AuthSudo.update(query)
end

def find_file(file_id, org_uri)
  # note query is weird because ext:hasFile link is currently not in the correct graph
  # we also take into account that the meeting etc may already be moved to a quarantine graph
    query = <<~EOF
PREFIX prov: <http://www.w3.org/ns/prov#>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
SELECT DISTINCT ?file ?name WHERE {
  GRAPH <http://mu.semte.ch/graphs/public> {
?file mu:uuid #{sparql_escape_string(file_id.strip)};
<http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#fileName> ?name.
?resource <http://mu.semte.ch/vocabularies/ext/hasAttachments> ?attachment.
}
  GRAPH ?g {
?attachment <http://mu.semte.ch/vocabularies/ext/hasFile> ?file.
}
  GRAPH ?h {
 ?meeting a <http://data.vlaanderen.be/ns/besluit#Zitting>.
  ?meeting prov:wasDerivedFrom ?resource.
?meeting <http://data.vlaanderen.be/ns/besluit#isGehoudenDoor>/<http://data.vlaanderen.be/ns/mandaat#isTijdspecialisatieVan>/<http://data.vlaanderen.be/ns/besluit#bestuurt> #{sparql_escape_uri(org_uri)}.}
}
EOF
    result = Mu::AuthSudo.query(query)
    if result.length > 0
      return result[0]
    end
end

prompt = TTY::Prompt.new
prompt.say("\n\n")
prompt.say("Welcome to the \"someone else fucked up and you get to clean it up script!\"")
name = prompt.ask("Name of the admin unit to search:")
options = search_organization(name).map do |binding|
  {name: "#{binding[:classification]} #{binding[:name]} (#{binding[:org]})", value: binding[:org]}
end

if options.size > 0
  org_uri = prompt.select("Please select the matching admin unit", options)
else
  abort("No admin unit found for '#{name}'")
end


todo = prompt.select("What do you wan to do") do |menu|
  menu.choice name: "remove an attachment", value: :attachment
  menu.choice name: "Hide everything for an admin unit", value: :quarantine_admin
end

case todo
when :quarantine_admin
  quarantine_org(prompt, org_uri)
when :attachment
  file_id = prompt.ask("please provide the file id (can be found in the public facing url):")
  file = find_file(file_id, org_uri)
  if prompt.yes?("Found file with name #{file[:name]}, move file to quarantine?")
    graph = ensure_quarantine_graph(prompt, org_uri)
    move_file_to_quarantine(file[:file], graph)
    prompt.say("File #{file[:file]} metadata has been moved to quarantine graphs")
  end
else
  prompt.say("the selected option is not supported yet")

end
