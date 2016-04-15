#!/bin/bash

set -e

npm install

dub build --build=release
npm run build:prod

#SERVER
if [ -f "LcdaAccountManager.exe" ]; then
	install LcdaAccountManager.exe public/
	install *.dll public/
else
	install LcdaAccountManager public/
fi

#CONFIG
install -m 644 config.example.json public/
