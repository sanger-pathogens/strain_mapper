#!/usr/bin/env python

from Bio import SeqIO
import matplotlib.pyplot as plt
import numpy as np

def concatenate_sequences(file):
    concatenated_seq = ""
    records = SeqIO.parse(file, "fasta")
    for record in records:
        concatenated_seq += str(record.seq).upper()
    return concatenated_seq

def calculate_alignment_stats(seq1, seq2):
    matches = 0
    mismatches = 0
    mismatch_types = {}
    mismatch_indices = []

    for i, (base1, base2) in enumerate(zip(seq1, seq2)):
        if base1 != base2 and base1 != '-' and base2 != '-':
            mismatches += 1
            mismatch_type = f"{base1}->{base2}"
            mismatch_types[mismatch_type] = mismatch_types.get(mismatch_type, 0) + 1
            mismatch_indices.append(i)
        else:
            matches += 1

    total_bases = matches + mismatches
    fraction_agreement = matches / total_bases

    base_counts = {
        'matches': matches,
        'mismatches': mismatches,
        'mismatch_types': mismatch_types,
        'mismatch_indices': mismatch_indices,
    }

    return fraction_agreement, base_counts

def plot_base_counts(ax, matches_percentage, mismatches_percentage, tools):
    ax.set_xlabel(f'Base Type {tools[0]} -> {tools[1]}')
    ax.set_ylabel('Base Count')
    ax.bar(['Matches', 'Mismatches'], [matches_percentage, mismatches_percentage], color=['green', 'red'])

    for i, percentage in enumerate([matches_percentage, mismatches_percentage]):
        ax.text(i, percentage + 2, f'{percentage:.2f}%', ha='center')

    return ax

def plot_mismatch_types(ax, mismatch_types, tools):
    ax.set_xlabel(f'Mismatch Type {tools[0]} -> {tools[1]}')
    ax.set_ylabel('Count')
    bars = ax.bar(mismatch_types.keys(), mismatch_types.values(), color='tomato')

    for bar, count in zip(bars, mismatch_types.values()):
        ax.annotate(f'{count}', xy=(bar.get_x() + bar.get_width() / 2, bar.get_height()), 
                     xytext=(0, 3), textcoords='offset points',
                     ha='center', va='bottom')
        
    # Set x-ticks and rotate x-labels by 90 degrees
    ax.set_xticks(range(len(mismatch_types)))
    ax.set_xticklabels(mismatch_types.keys(), rotation=90)


    return ax

def plot_cumulative_differences(ax, mismatch_indices):
    ax.set_xlabel('Position')
    ax.set_ylabel('Cumulative Count of Differences')
    ax.plot(mismatch_indices, range(1, len(mismatch_indices) + 1), marker='o', color='green')

    return ax


def plot_stats(base_counts, fraction_agreement, mismatch_types, mismatch_indices, tool_names, seq1, seq2):
    plt.style.use('ggplot')
    
    matches = base_counts['matches']
    mismatches = base_counts['mismatches']
    total_bases = matches + mismatches
    matches_percentage = (matches / total_bases) * 100
    mismatches_percentage = (mismatches / total_bases) * 100

    fig, axs = plt.subplots(3, 1, figsize=(8, 12))


    ax1 = plot_base_counts(axs[0], matches_percentage, mismatches_percentage, tool_names)
    ax2 = plot_mismatch_types(axs[1], mismatch_types, tool_names)
    ax3 = plot_cumulative_differences(axs[2], mismatch_indices)


    fig.tight_layout()
    plt.suptitle(f'Alignment Statistics\nTotal changes: {mismatches}', y=1.05) 

    plt.savefig("base_changes_across_length.jpg", bbox_inches='tight', dpi=300)

if __name__ == "__main__":
    tool1 = "mm2b"
    file1 = "/lustre/scratch126/pam/teams/team230/sd28/test/mm2b_no_indel/31663_7#10_BWA/31663_7#10.mfa"  
    tool2 = "SM"
    file2 = "/lustre/scratch126/pam/teams/team230/sd28/strain_mapper/assorted-sub-workflows/strain_mapper/bin/31663_7#10_Streptococcus_agalactiae_NGBS128_GCF_001552035_1.fa"  

    seq1 = concatenate_sequences(file1)
    seq2 = concatenate_sequences(file2)
    fraction_agreement, base_counts = calculate_alignment_stats(seq1, seq2)
    plot_stats(base_counts, fraction_agreement, base_counts['mismatch_types'], base_counts['mismatch_indices'], [tool1, tool2], seq1, seq2)