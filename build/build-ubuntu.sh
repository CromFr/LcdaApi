#!/bin/sh

(docker images | grep lcdaserver-dlang-builder) || docker build -t lcdaserver-dlang-builder .

docker run --rm -it -u $UID \
	-v $PWD/..:/mnt/LcdaApi -u $UID \
	-v $(dub list |grep -E 'nwn-lib-d\s+' | cut -d ' ' -f 5):/mnt/nwn-lib-d \
	lcdaserver-dlang-builder \
	bash -c "dub add-local /mnt/nwn-lib-d \
		&& cd /mnt/LcdaApi \
		&& dub build -b release"
