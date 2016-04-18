# LCDA Accounts Interface ![](https://travis-ci.org/CromFr/LcdaAccountManager.svg?branch=master)

Web interface for managing accounts & characters of "La Colère d'Aurile", a French Neverwinter Nights 2 Server (RPG)


# Features
- Character browsing (name, level, race, classes)
- Character deactivation/activation
- GFF and TLK reader for localized data
- Database link for login credentials

# May be done
- Auction browsing
- Multi-language localization (currently French only)
- File modifications (tlk edit?)
- Search items on characters


# Install

```sh
npm install
npm run build:prod

dub build --build=release
```


Dirty hacks to remove:
- Edit `node_modules/angular2-materialize/dist/index.js` to require `materialize-css` instead of `materialize`
- `cp node_modules/materialize-css/js/date_picker/picker.js node_modules/materialize-css/bin` (should be done automatically with npm `postinstall`)
