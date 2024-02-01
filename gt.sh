ruby gg.rb $1

mkdir $1

cat $1.txt | sort | uniq | xargs -I {} trufflehog docker --image={} --debug --only-verified --no-update | tee -a $1-truff.txt

mv *.txt $1
