exports.config =
  npm:
    enabled: true
    styles:
      'materialize-css': ['bin/materialize.css']
    globals:
      jQuery: "jquery"
      Hammer: "hammerjs/hammer"
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

  plugins:
    copyfilemon:
      fonts: ["node_modules/materialize-css/dist/fonts"]