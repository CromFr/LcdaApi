# LCDA REST API
[![Build Status](https://travis-ci.org/CromFr/LcdaAccountManager.svg?branch=master)](https://travis-ci.org/CromFr/LcdaAccountManager)
[![codecov](https://codecov.io/gh/CromFr/LcdaAccountManager/branch/master/graph/badge.svg)](https://codecov.io/gh/CromFr/LcdaAccountManager)

REST API for managing accounts & characters of "La Colère d'Aurile", a French Neverwinter Nights 2 Server (RPG)


# Backend features
- Account API
	* Change password
	* Manage access tokens

- Character API
	* Basic info
	* Build details (level per level)
	* Quest list with status
	* Dungeon and associated rewards list with status
	* Custom notes
	* Character access can be set to public or private

- Authenticator service (HTML interface)
	- Generate new access tokens

# Planned work
- Search items across characters on an account in:
    + Character equipment
    + Character inventory
    + Persistent storage (ie casier d'Ibee)



# Build

```sh
git clone https://github.com/CromFr/nwn-lib-d.git ../nwn-lib-d
dub add local ../nwn-lib-d
dub build --build=release
```

# Usage

see
```sh
cp config.example.json config.json
vim config.json
./LcdaAccountManager --help
```

