defmodule Dispatcher do
  use Matcher
  define_accept_types [
    html: [ "text/html", "application/xhtml+html" ],
    any: [ "*/*" ]
  ]

  @html %{ accept: %{ html: true } }
  @any %{ accept: %{ any: true } }

  match "/published-resource-consumer/*path", @any do
    Proxy.forward conn, path, "http://published-resource-consumer/"
  end
  match "/agendas/*path", @any do
    Proxy.forward conn, path, "http://resource/agendas/"
  end

  match "/besluitenlijsten/*path", @any do
    Proxy.forward conn, path, "http://resource/besluitenlijsten/"
  end

  match "/uittreksels/*path", @any do
    Proxy.forward conn, path, "http://resource/uittreksels/"
  end

  match "/agendapunten/*path", @any do
    Proxy.forward conn, path, "http://resource/agendapunten/"
  end

  match "/behandelingen-van-agendapunten/*path", @any do
    Proxy.forward conn, path, "http://resource/behandelingen-van-agendapunten/"
  end

  match "/stemmingen/*path", @any do
    Proxy.forward conn, path, "http://resource/stemmingen/"
  end

  match "/besluiten/*path", @any do
    Proxy.forward conn, path, "http://resource/besluiten/"
  end

  match "/bestuurseenheden/*path", @any do
    Proxy.forward conn, path, "http://cache/bestuurseenheden/"
  end

  match "/werkingsgebieden/*path", @any do
    Proxy.forward conn, path, "http://cache/werkingsgebieden/"
  end

  match "/bestuurseenheid-classificatie-codes/*path", @any do
    IO.inspect(conn, label: "conn to cache")
    Proxy.forward conn, path, "http://resource/bestuurseenheid-classificatie-codes/"
  end

  match "/bestuursorganen/*path", @any do
    Proxy.forward conn, path, "http://cache/bestuursorganen/"
  end

  match "/bestuursorgaan-classificatie-codes/*path", @any do
    Proxy.forward conn, path, "http://cache/bestuursorgaan-classificatie-codes/"
  end

  match "/zittingen/*path", @any do
    Proxy.forward conn, path, "http://resource/zittingen/"
  end

  match "/notulen/*path", @any do
    Proxy.forward conn, path, "http://resource/notulen/"
  end


  match "/signed-resources/*path", @any do
    Proxy.forward conn, path, "http://resource/signed-resources/"
  end

  match "/published-resources/*path", @any do
    Proxy.forward conn, path, "http://resource/published-resources/"
  end

  match "/versioned-agendas/*path", @any do
    Proxy.forward conn, path, "http://resource/versioned-agendas/"
  end

  match "/versioned-besluiten-lijsten/*path", @any do
    Proxy.forward conn, path, "http://resource/versioned-besluiten-lijsten/"
  end

  match "/versioned-behandelingen/*path", @any do
    Proxy.forward conn, path, "http://resource/versioned-behandelingen/"
  end

  match "/versioned-notulen/*path", @any do
    Proxy.forward conn, path, "http://resource/versioned-notulen/"
  end

  match "/concepts/*path", @any do
    Proxy.forward conn, path, "http://cache/concepts/"
  end

  match "/concept-schemes/*path", @any do
    Proxy.forward conn, path, "http://cache/concept-schemes/"
  end

  match "/@appuniversum/*path", @any do
    Proxy.forward conn, path, "http://publicatie/@appuniversum/"
  end

  match "/assets/*path", @any do
    IO.puts "forwarding assets"
    Proxy.forward conn, path, "http://publicatie/assets/"
  end

  get "/files/:id/download" do
    Proxy.forward conn, [], "http://file/files/" <> id <> "/download"
  end
  
  post "/files/*path" do
    Proxy.forward conn, path, "http://file/files/"
  end

  match "/favicon.ico", @any do
    send_resp( conn, 404, "" )
  end

  match "/*path", @html do
    # *_path allows a path to be supplied, but will not yield
    # an error that we don't use the path variable.
    Proxy.forward conn, path, "http://publicatie/"
  end

  match "/*_", %{ last_call: true, accept: %{ json: true } } do
    send_resp( conn, 404, "{ \"error\": { \"code\": 404, \"message\": \"Route not found.  See config/dispatcher.ex\" } }" )
  end
end
