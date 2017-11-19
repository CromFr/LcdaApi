Scripts to build LcdaApi and produce a binary compatible with Ubuntu 17.04

- This script will create a docker image with Dlang tools
- You need to register `nwn-lib-d` dub package (`dub add-local /path/to/nwn-lib-d`)
- Only works if your user has UID 1000 (see [Dockerfile](Dockerfile))
