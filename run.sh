ruby run.rb $1

mkdir $1

cat $1_users.txt | grep -vw $1 | sort | uniq | xargs -I {} ruby run.rb {}
mv *.txt $1

cd $1
../trufflehog filesystem . --debug --only-verified --no-update | tee -a ../trufflehog.txt && mv ../trufflehog.txt log.txt

cd ..

zip -r $1.zip $1

