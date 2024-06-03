#!/usr/bin/env python

import pysam
import matplotlib.pyplot as plt
import numpy as np

class Variant:
    def __init__(self, record):
        self.chrom = record.chrom
        self.pos = record.pos
        self.ref = record.ref
        self.alt = record.alts[0] if record.alts else None
        self.variant_type = self.get_variant_type()
        self.mapping_score = record.qual  # Assuming quality score as mapping score
        self.dp4 = record.info.get('DP4', None)
        self.dp = record.info.get('DP', None)
        self.vdb = record.info.get('VDB', 0.0)
        self.info = record.info

    def __eq__(self, other):
        return (
            isinstance(other, Variant) and
            self.chrom == other.chrom and
            self.pos == other.pos and
            self.ref == other.ref and
            self.alt == other.alt
        )

    def get_variant_type(self):
        if len(self.ref) == 1 and all(len(alt) == 1 for alt in [self.alt]):
            return 'SNP'
        elif len(self.ref) == max(len(alt) for alt in [self.alt]):
            return 'Deletion'
        elif len(self.ref) < max(len(alt) for alt in [self.alt]):
            return 'Insertion'
        else:
            return 'Other'
    


# Step 1: Read VCF files and parse into Variant objects
def read_vcf(vcf_file):
    variants = []
    with pysam.VariantFile(vcf_file) as vcf_reader:
        for record in vcf_reader:
            if record.alts:
                variants.append(Variant(record))
    return variants

def is_transition(base_change):
    if base_change:
        ref_base, alt_base = base_change
        return (ref_base, alt_base) in [('A', 'G'), ('G', 'A'), ('C', 'T'), ('T', 'C')]
    return False
    
def plot_info_histograms(variant_list, outname):
    info_fields = sorted(set().union(*(variant.info.keys() for variant in variant_list)))

    # Define colors for each histogram
    colors = plt.cm.tab10(np.linspace(0, 1, len(info_fields)))

    num_plots = len(info_fields)
    num_cols = 3  # You can adjust the number of columns as per your preference
    num_rows = (num_plots + num_cols - 1) // num_cols  # Compute number of rows based on number of columns

    fig, axes = plt.subplots(num_rows, num_cols, figsize=(15, 5*num_rows))

    for color, ax, field in zip(colors, axes.flatten(), info_fields):
        values = [variant.info.get(field, None) for variant in variant_list]
        values = [v for v in values if v is not None]

        if field == "INDEL":
            continue
        try:
            if values:
                if field == "PV4" or field == "DP4":
                    # If the field is VP4 or DP4, sum the tuples in the lists
                    # Initialize an empty list to store the sums
                    sum_list = []

                    # Iterate over each tuple in the list
                    for tup in values:
                        tup_sum = sum(tup)
                        # Add the sum to the new list
                        sum_list.append(tup_sum)
                    ax.hist(sum_list, bins=20, color=color, edgecolor='black')
                else:
                    ax.hist(values, bins=20, color=color, edgecolor='black')

                ax.set_title(field)  # Set title for the subplot

                average_score = np.mean(values)
                ax.text(0.95, 0.95, f"Average: {average_score:.2f}", ha='right', va='top', transform=ax.transAxes, fontsize=10)


        except:
            print(field)
            continue

    # Remove empty subplots
    for i in range(num_plots, num_rows * num_cols):
        fig.delaxes(axes.flatten()[i])

    plt.tight_layout()
    plt.savefig(f"{outname}.jpg")

# Step 2: Compare true VCF to method VCF
def compare_vcf(true_vcf, method_vcf):
    true_variants = read_vcf(true_vcf)
    method_variants = read_vcf(method_vcf)

    print("Number of true variants:", len(true_variants))
    print("Number of method variants:", len(method_variants))

    # Create a dictionary of true variants indexed by (chromosome, position) tuples
    true_variants_dict = {(variant.chrom, variant.pos): variant for variant in true_variants}

    # Filter method variants to only those that occur in the same position as true variants
    method_variants_same_position = [variant for variant in method_variants if (variant.chrom, variant.pos) in true_variants_dict]

    print("Number of method variants at the same position as true variants:", len(method_variants_same_position))

    true_positive = 0
    false_positive = 0


    # Perform comparison
    for method_variant in method_variants_same_position:
        true_variant = true_variants_dict.get((method_variant.chrom, method_variant.pos))
        if true_variant:
            if method_variant == true_variant:
                true_positive += 1
            else:
                false_positive += 1

    print(f"positive supported in both VCFs: {true_positive}")
    print(f"positive supported in only method VCFs: {false_positive}")

    missed_variants = [true_variants_dict[(variant.chrom, variant.pos)] for variant in true_variants if (variant.chrom, variant.pos) not in {(v.chrom, v.pos) for v in method_variants_same_position}]
    print(f"positive supported in only true VCFs: {len(missed_variants)}")

    precision = true_positive / len(method_variants_same_position) if method_variants_same_position else 0
    recall = true_positive / len(true_variants) if true_variants else 0
    f1_score = 2 * (precision * recall) / (precision + recall) if precision + recall > 0 else 0

    # Example: Print results
    print("Precision:", precision)
    print("Recall:", recall)
    print("F1-score:", f1_score)

    plot_info_histograms(missed_variants, "vcf_missed_histo.jpg")

    plot_info_histograms(method_variants_same_position, "vcf_all_histo")

# Example usage for comparing one VCF against the true
compare_vcf('/lustre/scratch126/pam/teams/team230/sd28/test/mm2b_no_indel/31663_7#10_BWA/31663_7#10_variant.vcf', '/lustre/scratch126/pam/teams/team230/sd28/strain_mapper/results/31663_7#10/final_vcf/31663_7#10.vcf')


def parse_args():
    parser = argparse.ArgumentParser(
        description="Script to compare variants called from the same reference genome and read sets by two different methodologies"
    )
    parser.add_argument(
        "--vcf1",
        "-1",
        default="/lustre/scratch126/pam/teams/team230/sd28/test/mm2b_no_indel/31663_7#10_BWA/31663_7#10_variant.vcf",
        help="VCF file for variants called by the first method",
    )
    parser.add_argument(
        "--vcf2",
        "-2",
        default="/lustre/scratch126/pam/teams/team230/sd28/strain_mapper/results/31663_7#10/final_vcf/31663_7#10.vcf"
        help="VCF file for variants called by the second method",
    )
    parser.add_argument(
        "--method1",
        "-m",
        default='mm2b_no_indel'
        help="Label for first variant calling method",
    )
    parser.add_argument(
        "--method2",
        "-M",
        default='BWA_new_SM'
        help="Label for second variant calling method",
    )
    return parser.parse_args()

if __name__ == "__main__":

    args = parse_args()

    tool1_counts = count_bases_in_fasta(args.fasta1)
    tool2_counts = count_bases_in_fasta(args.fasta2)
    
    plot_base_counts(tool1_counts, tool2_counts, [args.method1, args.method2])