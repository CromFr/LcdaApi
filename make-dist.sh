#!/bin/bash

set -e

if [ -d dist/ ]; then
	rm -rf dist/*
fi
install -d dist/ dist/public/

npm install
dub build --build=release


#PUBLIC
npm run tsc
FILES=`find public/ -regextype posix-extended -regex ".*\.(js|css|html)"`
for FILE in $FILES; do
	install -d dist/`dirname $FILE`
	install -m 644 $FILE dist/$FILE
done
npm install --prefix dist/public/ --no-optional --only=prod .


#SERVER
if [ -f "LcdaAccountManager.exe" ]; then
	install LcdaAccountManager.exe dist/
	install *.dll dist/
else
	install LcdaAccountManager dist/
fi

#CONFIG
install -m 644 config.example.json dist/
