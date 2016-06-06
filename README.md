# LCDA Accounts Interface
[![Build Status](https://travis-ci.org/CromFr/LcdaAccountManager.svg?branch=master)](https://travis-ci.org/CromFr/LcdaAccountManager)
[![codecov](https://codecov.io/gh/CromFr/LcdaAccountManager/branch/master/graph/badge.svg)](https://codecov.io/gh/CromFr/LcdaAccountManager)

Web interface for managing accounts & characters of "La Colère d'Aurile", a French Neverwinter Nights 2 Server (RPG)


# Front end features
- Character list
- Character details
    + name, level, race, alignment, ...
    + Leveling history
    + Delete/reactivate character
    + Download file
- Account settings:
    + Change password
- Account switch for admins

# Backend features
- GFF, 2DA, TLK reading
- Json based web API
- Database link (MySQL)
- Session store link (redis, memory)
- Configuration file

# May be done
- Auction browsing
- Multi-language localization (currently French only)
- File modifications (tlk edit?)
- Search items across characters on an account in:
    + Character equipment
    + Character inventory
    + Persistent storage (ie casier d'Ibee)



# Build

```sh
# Public files
npm install
npm run build:prod

# Server
git clone https://github.com/CromFr/nwn-lib-d.git ../nwn-lib-d
dub add local ../nwn-lib-d
dub build --build=release
```

# Usage

see
```sh
./LcdaAccountManager --help
```


---

Dirty hacks to remove:
- Edit `node_modules/angular2-materialize/dist/index.js` to require `materialize-css` instead of `materialize`
- `cp node_modules/materialize-css/js/date_picker/picker.js node_modules/materialize-css/bin` (should be done automatically with npm `postinstall`)
