#!/bin/bash

docker pull $1

docker run --rm -it $1 find / -name ".git"

docker rmi $1

