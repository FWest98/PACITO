#!/bin/bash
#SBATCH --time=10-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --job-name=github_mina
#SBATCH --mem=100GB
#SBATCH --mail-type=ALL
#SBATCH --mail-user=f.a.de.capela@student.rug.nl
#SBATCH --output=job-%j-pinot_mina_refactor.log
#SBATCH --partition=regular

module load Java/1.7.0_80
export CLASSPATH=${CLASSPATH}:/apps/generic/software/Java/1.7.0_80/jre/lib/rt.jar

COUNTER=1

cd /data/s4040112/sourcecodes/mina
git pull
FINAL_COMMIT=$(git show -s --format=%H)

#depending on the project, the main branch can either be master or trunk
git rev-list --reverse master > commitOrder.txt
#git rev-list --reverse trunk > commitOrder.txt

filename=commitOrder.txt
file_lines=`cat $filename`

#mkdir -p outputs

projectpath="/data/s4040112/sourcecodes/mina"
projectname="mina"
verbose=false
TEMP=`getopt --long -o "p:v" "$@"`
eval set -- "$TEMP"
while true ; do
case "$1" in
-p )
projectpath=$2
projectnametmp=${projectpath%/}
projectname=${projectnametmp##*/}
unset projectnametmp
shift 2;;
-v )
verbose=true
shift ;;
--) shift ; break ;;
*)
break;;
esac
done

for line in $file_lines ; 
do
	git reset --hard $line
    	CURRENT_COMMIT=$(git log -n1 --format=format:"%H")

	#don't forget to run sudo updatedb, since locate finds all files but needs to be updated 	using this command
	#updatedb

	find ${projectpath} -name '*.java' > ${projectname}-files.list
	#locate ${projectpath}**.java > ${projectname}-files.list

	if [ "$verbose" = true ] ; then
	echo "$(<${projectname}-files.list)"
	fi

	mvn dependency:copy-dependencies -DoutputDirectory=dependencies -Dhttps.protocols=TLSv1.2

	find ${projectpath} -name '*.jar' > ${projectname}-jars.list

	last_line=$(wc -l < ${projectname}-jars.list)
	current_line=0

	while read line1
  	do
    		export CLASSPATH=${CLASSPATH}:$line1
	done < ${projectname}-jars.list

	java -jar /home/s4040112/data/Internship_RuG_2020/0-ProjectRefactorer/out/artifacts/0_ProjectRefactorer_jar/0-ProjectRefactorer.jar $projectname


	/home/s4040112/tools/bin/pinot @${projectname}-newfiles.list 2>&1 | tee /data/s4040112/Pinot_results/github-looper-${projectname}/$COUNTER-ID-$CURRENT_COMMIT.txt

	rm ${projectname}-files.list
	rm ${projectname}-newfiles.list
	rm ${projectname}-jars.list

	find ${projectpath} -name '*refactored.java' > ${projectname}-deletefiles.list

	while read line
  	do
		rm $line
  	done < ${projectname}-deletefiles.list

	COUNTER=$((COUNTER+1))
	git log -1 --pretty=format:"%h - %an, %ar"
	echo $(git log $CURRENT_COMMIT..$FINAL_COMMIT --pretty=oneline | wc -l) " - Number of commits left"
done
