ruby gg.rb $1

mkdir $1

cat $1.txt | sort | uniq | xargs -I {} sh ggshield.sh $1 {}

cat $1-gg.txt  | grep -v "Pull\|Waiting\|Verifying\|Download\|Digest\|Already" > $1-clean.txt

mv *.txt $1

#docker images | grep $1 | awk -F " " '{print $1":"$2}' | xargs -I {} docker rmi {}
#mkdir $1

#cat $1_users.txt | grep -vw $1 | sort | uniq | xargs -I {} ruby run.rb {}
#mv *.txt $1

#cd $1
#../trufflehog filesystem . --debug --only-verified --no-update | tee -a ../trufflehog.txt && mv ../trufflehog.txt log.txt

#cd ..

#zip -r $1.zip $1

