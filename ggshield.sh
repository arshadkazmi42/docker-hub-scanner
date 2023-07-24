ggshield secret scan docker $2 | tee -a $1-gg.txt

docker rmi $2

rm -rf /tmp/tmp*
