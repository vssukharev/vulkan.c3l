
c3c run
cd import
for f in $(ls .) ; do c3c compile -C $f ; done

