while getopts ":f:x:z:o" opt; do
    case ${opt} in
        d)
            fasta_directory="$OPTARG";;
        x)
            xml_template="$OPTARG";;
        z)
            zip_filenae="$OPTARG";;         
        o)
            output_directory="$OPTARG";;
    esac
done

fasta_directory=" ***replace with your own path here***
xml_template=" ***replace with your own path here***
zip_filename="sarscov2.zip"
output_directory=" ***replace with your own path here***

# Create the output directory
mkdir output_directory

# Merge the fasta files into one .fsa file
cat ${fasta_directory}/*.{fasta,fa} > ${output_directory}/submission_fasta.fsa

# Copy the xml into the output directory
cp ${xml_template} ${output_directory}
