#!/usr/bin/env ruby

require 'bundler/inline'
require 'yaml'
require 'securerandom'
require 'date'

$stdout.sync = true
print "installing dependencies..."
gemfile do
  source 'https://rubygems.org'
  gem 'mu-auth-sudo', '~> 0.4.0'
  gem 'rdf-vocab', '~> 3.3'
  gem 'tty-prompt'
end
print "DONE"
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
  menu.choice name: "Unpublish a meeting", value: :meeting
  menu.choice name: "Hide everything for an admin unit", value: :quarantine_admin
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

def move_meeting_to_quarantine(meeting, quarantine_graph)
  query = <<~EOF
  DELETE {
    GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(meeting)} ?p ?o
  }}
  INSERT {
   GRAPH #{sparql_escape_uri(quarantine_graph)} {
      #{sparql_escape_uri(meeting)} ?p ?o
}
} WHERE { GRAPH <http://mu.semte.ch/graphs/public> {
      #{sparql_escape_uri(meeting)} ?p ?o
}};
EOF
  Mu::AuthSudo.update(query)
end

def quarantine_org(prompt, org_uri)
  prompt.say("This option will move all meeting data related to #{org_uri} to a separate graph and add some metadata to the main graph")
  graph = existing_quarantine_graph(org_uri)
  if graph
    prompt.say("Reusing existing quarantine graph #{graph}")
  else
    graph = create_quarantine_graph(org_uri)
    prompt.say("Created new quarantine graph #{graph}")
  end
  meetings = get_meeting_uris_for_org(org_uri)
  prompt.say("Found #{meetings.size} meetings to quarantine")
  meetings.each do |meeting|
    move_meeting_to_quarantine(meeting, graph)
  end
  prompt.say("All meetings moved to quarantine")
end

case todo
when :quarantine_admin
  quarantine_org(prompt, org_uri)
else
  prompt.say("the selected option is not supported yet")

end
