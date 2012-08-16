__aceSettings =    

  compilerCallNames: 
    coffee    :
      class   : 'CoffeeScript'
      method  : 'compile'
      options : 
        bare  : on

  softWrapOptions: [
      value: 'off'
      title: 'Off'
    ,
      value: 40
      title: '40 chars'
    ,
      value: 80
      title: '80 chars'
    ,
      value: 'free'
      title: 'Free'
  ]  
  
  fontSizes: [
      value: 10
      title: '10px'
    ,
      value: 11
      title: '11px'
    ,
      value: 12
      title: '12px'
    ,
      value: 14
      title: '14px'
    ,
      value: 16
      title: '16px'
    ,
      value: 20
      title: '20px'
    ,
      value: 24
      title: '24px'
  ]  

  tabSizes: [
      value: 2
      title: '2 chars'
    ,
      value: 4
      title: '4 chars'
    ,
      value: 8
      title: '8 chars'
  ]
  
  themes: 
    Bright : [
      { title: 'Chrome',                value: 'chrome' }
      { title: 'Clouds',                value: 'clouds' }
      { title: 'Crimson Editor',        value: 'crimson_editor' }
      { title: 'Dawn',                  value: 'dawn' }
      { title: 'Dreamweaver',           value: 'dreamweaver' }
      { title: 'Eclipse',               value: 'eclipse' }
      { title: 'GitHub',                value: 'GitHub' }
      { title: 'Solarized Light',       value: 'solarized_light' }
      { title: 'TextMate',              value: 'textmate' }
      { title: 'Tomorrow',              value: 'tomorrow' }
    ].sort (a, b) -> if a.title < b.title then -1 else 1
    
    Dark : [
      { title: 'Clouds Midnight',       value: 'clouds_midnight' }
      { title: 'Cobalt',                value: 'cobalt' }
      { title: 'Idle Fingers',          value: 'idle_fingers' }
      { title: 'KR Theme',              value: 'kr_theme' }
      { title: 'Merbivore',             value: 'merbivore' }
      { title: 'Merbivore Soft',        value: 'merbivore_soft' }
      { title: 'Mono Industrial',       value: 'mono_industrial' }
      { title: 'Monokai',               value: 'monokai' }
      { title: 'Pastel on Dark',        value: 'pastel_on_dark' }
      { title: 'Solarized Dark',        value: 'solarized_dark' }
      { title: 'Twilight',              value: 'twilight' }
      { title: 'Tomorrow Night',        value: 'tomorrow_night' }
      { title: 'Tomorrow Night Blue',   value: 'tomorrow_night_blue' }
      { title: 'Tomorrow Night Bright', value: 'tomorrow_night_bright' }
      { title: 'Tomorrow Night 80s',    value: 'tomorrow_night_eighties' }
      { title: 'Vibrant Ink',           value: 'vibrant_ink' }
    ].sort (a, b) -> if a.title < b.title then -1 else 1


  syntaxAssociations :

    coffee      : ["CoffeeScript" , "coffee|Cakefile"]
    coldfusion  : ["ColdFusion"   , "cfm"]
    csharp      : ["C#"           , "cs"]
    css         : ["CSS"          , "css"]
    diff        : ["Diff"         , "diff|patch"]
    golang      : ["Go"           , "go"]
    groovy      : ["Groovy"       , "groovy"]
    haxe        : ["haXe"         , "hx"]
    html        : ["HTML"         , "htm|html|xhtml"]
    c_cpp       : ["C/C++"        , "c|cc|cpp|cxx|h|hh|hpp"]
    clojure     : ["Clojure"      , "clj"]
    java        : ["Java"         , "java"]
    javascript  : ["JavaScript"   , "js"]
    json        : ["JSON"         , "json|manifest|kdapp"]
    jsx         : ["JSX"          , "jsx"]
    latex       : ["LaTeX"        , "latex|tex|ltx|bib"]
    less        : ["LESS"         , "less"]
    liquid      : ["Liquid"       , "liquid"]
    lua         : ["Lua"          , "lua"]
    luapage     : ["LuaPage"      , "lp"]
    markdown    : ["Markdown"     , "md|markdown"]
    ocaml       : ["OCaml"        , "ml|mli"]
    perl        : ["Perl"         , "pl|pm"]
    pgsql       : ["pgSQL"        , "pgsql"]
    php         : ["PHP"          , "php|phtml"]
    powershell  : ["Powershell"   , "ps1"]
    python      : ["Python"       , "py"]
    ruby        : ["Ruby"         , "ru|gemspec|rake|rb"]
    scad        : ["OpenSCAD"     , "scad"]
    scala       : ["Scala"        , "scala"]
    scss        : ["SCSS"         , "scss|sass"]
    sh          : ["SH"           , "sh|bash|bat"]
    sql         : ["SQL"          , "sql"]
    svg         : ["SVG"          , "svg"]
    text        : ["Text"         , "txt"]
    textile     : ["Textile"      , "textile"]
    xml         : ["XML"          , "xml|rdf|rss|wsdl|xslt|atom|mathml|mml|xul|xbl"]
    xquery      : ["XQuery"       , "xq"]
    yaml        : ["YAML"         , "yaml"]

  getSyntaxOptions : -> 

    o = for syntax, info of __aceSettings.syntaxAssociations
      { title : info[0], value : syntax }
    
    o.sort (a, b) -> if a.title < b.title then -1 else 1
    
    return o

  aceToHighlightJsSyntaxMap :

    coffee      : "coffee"
    # coldfusion  : null
    csharp      : "cs"
    css         : "css"
    diff        : "diff"
    golang      : "go"
    # groovy      : null
    # haxe        : null
    html        : "xml"
    c_cpp       : "cpp"
    # clojure     : null
    java        : "java"
    javascript  : "javascript"
    json        : "javascript"
    # json        : "json"
    latex       : "tex"
    less        : "css"
    # liquid      : null
    lua         : "lua"
    # markdown    : "markdown"
    # ocaml       : null
    perl        : "perl"
    pgsql       : "sql"
    php         : "php"
    powershell  : "bash"
    python      : "python"
    ruby        : "ruby"
    # scad        : null
    scala       : "scala"
    scss        : "css"
    sh          : "bash"
    sql         : "sql"
    # svg         : null
    # text        : null
    # textile     : null
    xml         : "xml"
    # xquery      : null
    # yaml        : null