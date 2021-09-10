#!/bin/bash

usage() { echo "Usage: $0 <-i  specify bbmap img name>" \
						  "<-l  specify bbmap docker URL>" \
						  "<-p  specify bbmap ref path>" \
						  "<-r  specify bbmap ref name>" \
						  "<-o  specify reads directory> " \
						  "<-b  specify singularity binding path>" 1>&2; exit 1; }

while getopts "i:l:p:r:o:b:" o; do
	case $o in
		i) BB_IMG=${OPTARG} ;;
		l) BB_LIB=${OPTARG} ;;
		p) BB_PATH=${OPTARG} ;;
		r) BB_REF=${OPTARG} ;;
		o) OUTDIR=${OPTARG} ;;
		b) BIND=${OPTARG} ;;
		*) usage ;;
	esac
done

# all arguments are required
if [ -z "${BB_IMG}" ] || [ -z "${BB_LIB}" ] || [ -z "${BB_PATH}" ] || [ -z "${BB_REF}" ] || [ -z "${OUTDIR}" ] || [ -z "${BIND}" ]; then
    usage
fi

if [ ! -f "$BB_IMG" ]; then
	singularity pull $BB_IMG $BB_LIB
fi

# compile inlist, in2list, outmlist for bbwrap.sh
mkdir -p ${OUTDIR}/filter/bbmap
for file in ${OUTDIR}/filter/*.gz; do
	if echo $file | grep -q '_R1'; then
		echo $file >> ${OUTDIR}/filter/bbmap/R1.txt
		temp=$(echo $(basename $file) | grep -o '.*_R1')
		echo ${OUTDIR}/filter/bbmap/${temp}.fasta >> ${OUTDIR}/filter/bbmap/outm_paired.txt
	elif echo $file | grep -q '_R2'; then
		echo $file >> ${OUTDIR}/filter/bbmap/R2.txt
	elif echo $file | grep -q 'unpaired'; then
		echo $file >> ${OUTDIR}/filter/bbmap/unpaired.txt
		temp=$(echo $(basename $file) | grep -o '.*unpaired')
		echo ${OUTDIR}/filter/bbmap/${temp}.fasta >> ${OUTDIR}/filter/bbmap/outm_unpaired.txt
	fi
done

singularity run --bind /mnt,$BIND $BB_IMG bbwrap.sh \
			ref=$BB_REF \
			path=$BB_PATH \
			inlist=${OUTDIR}/filter/bbmap/R1.txt \
			in2list=${OUTDIR}/filter/bbmap/R2.txt \
			outmlist=${OUTDIR}/filter/bbmap/outm_paired.txt \
			minratio=0.9 >/dev/null 2>&1

singularity run --bind /mnt,$BIND $BB_IMG bbwrap.sh \
			ref=$BB_REF \
			path=$BB_PATH \
			inlist=${OUTDIR}/filter/bbmap/unpaired.txt \
			outmlist=${OUTDIR}/filter/bbmap/outm_unpaired.txt \
			minratio=0.9 >/dev/null 2>&1

# run bbduk.sh to weed out low-complexity sequences
for file in ${OUTDIR}/filter/bbmap/*.fasta; do
	if [ -s $file ]; then
		mv $file ${file}.fasta
		singularity run --bind /mnt,$BIND $BB_IMG bbduk.sh \
					in=${file}.fasta \
					out=$file \
					entropy=0.7 >/dev/null 2>&1
		rm ${file}.fasta
	fi
done

for file in ${OUTDIR}/filter/bbmap/*.fasta; do
	hits=$(grep '>' $file | wc -l)
	temp=$(echo $file | grep -o '.*[^.fasta]')
	num_total=$(gunzip -c ${OUTDIR}/filter/$(basename $temp).fastq.gz | echo $((`wc -l`/4)))
    if (( $num_total == 0 )); then
      percent_hit=NA
    else
      percent_hit=$(echo "$hits $num_total" | awk '{printf "%.3f", $1*100/$2}')
    fi
    echo "$(basename $temp), we found $hits hits out of $num_total sequences, with hit_ratio = $percent_hit%" >> ${OUTDIR}/filter/bbmap/bbmap_result.txt
done