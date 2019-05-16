rule samtools_sort:
    input:
        "pipeline_output/best_ref_mapped_reads/{barcode}.sam"
    output:
        "pipeline_output/sorted_reads/{barcode}.bam"
    shell:
        "samtools sort -T sorted_reads/{wildcards.barcode} "
        "-O bam {input} > {output}"

rule samtools_index:
    input:
        "pipeline_output/sorted_reads/{barcode}.bam"
    output:
        "pipeline_output/sorted_reads/{barcode}.bam.bai"
    shell:
        "samtools index {input}"

rule bcftools_call:
    input:
        fasta="primer-schemes/noro2kb/Vsep/{barcode}.fasta",
        bam="pipeline_output/sorted_reads/{barcode}.bam",
        bai="pipeline_output/sorted_reads/{barcode}.bam.bai"
    output:
        "pipeline_output/calls/{barcode}.bcf.gz"
    shell:
        "bcftools mpileup --max-depth 10000 -Ou -f {input.fasta} {input.bam} | "
        "bcftools call -mv --ploidy 1 -Ob -o {output} "

rule index_calls:
    input:
        "pipeline_output/calls/{barcode}.bcf.gz"
    output:
        "pipeline_output/calls/{barcode}.bcf.gz.csi"
    shell:
        "bcftools index {input}"

rule normalise_indels:
    input:
        fasta="primer-schemes/noro2kb/Vsep/{barcode}.fasta",
        csi="pipeline_output/calls/{barcode}.bcf.gz.csi",
        bcf="pipeline_output/calls/{barcode}.bcf.gz"
    output:
        "pipeline_output/indel_normalised/{barcode}.norm.bcf.gz"
    shell:
        "bcftools norm -f {input.fasta} {input.bcf} -Ob -o {output}"

rule index_norm:
    input:
        "pipeline_output/indel_normalised/{barcode}.norm.bcf.gz"
    output:
        "pipeline_output/indel_normalised/{barcode}.norm.bcf.gz.csi"
    shell:
        "bcftools index {input}"

rule generate_quick_consensus:
    input:
        fasta="primer-schemes/noro2kb/Vsep/{barcode}.fasta",
        bcf="pipeline_output/indel_normalised/{barcode}.norm.bcf.gz",
        csi="pipeline_output/indel_normalised/{barcode}.norm.bcf.gz.csi"
    output:
        "pipeline_output/consensus/{barcode}.cns.fasta"
    shell:
        "cat {input.fasta} | bcftools consensus {input.bcf} > {output}"

rule quick_consensus_as_new_reference:
    input:
        "pipeline_output/consensus/{barcode}.cns.fasta"
    output:
        "primer-schemes/noro2kb/V_{barcode}/V1/V_{barcode}.reference.fasta"
    run:
        for input_fasta in input:
            with open(str(output),"w") as fw:
                for record in SeqIO.parse(input_fasta,"fasta"):
                    fw.write(">{}\n{}\n".format(record.id, record.seq))
