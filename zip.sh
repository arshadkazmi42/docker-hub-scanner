PROGRAM=graph
NAME="$PROGRAM"$1

mkdir -p $NAME

ls $1*.txt | grep -v "$PROGRAM" | xargs -I {} mv {} $NAME

zip -r $NAME.zip $NAME
