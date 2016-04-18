exports.config =
  npm:
    enabled: true
    styles:
      'materialize-css': ['bin/materialize.css']
  files:
    javascripts:
      joinTo:
        'vendor.js': /^(app\/vendor)|(node_modules)/
        'main.js': /^app\/(?!vendor)/
    stylesheets:
      joinTo:
        'vendor.css': /^(app\/vendor)|(node_modules)/
        'app.css': /^app\/(?!vendor)/

    templates:
      joinTo: 'main.js'