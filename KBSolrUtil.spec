/*
A KBase module: KBSolrUtil
This module contains the utility methods and configuration details to access the KBase SOLR cores.
*/

module KBSolrUtil {
    /*
        A boolean.
    */
    typedef int bool;

   /*
        Struct containing data for a single genome element output by the list_solr_genomes and index_genomes_in_solr functions
    */
    typedef structure {
        string genome_feature_id;
        string genome_id;
        string feature_id;
        string ws_ref;
        string feature_type;
        string aliases;
        string scientific_name;
        string domain;
        string functions;
        string genome_source;
        string go_ontology_description;
        string go_ontology_domain;
        string gene_name;
        string object_name;
        string location_contig;
        string location_strand;
        string taxonomy;
        string workspace_name;
        string genetic_code;
        string md5;
        string tax_id;
        string assembly_ref;
        string taxonomy_ref;
        string ontology_namespaces;
        string ontology_ids;
        string ontology_names;
        string ontology_lineages;           
        int dna_sequence_length;     
        int genome_dna_size;
        int location_begin;
        int location_end;      
        int num_cds;
        int num_contigs;
        int protein_translation_length;     
        float gc_content;
        bool complete;
        string refseq_category;                  
        string save_date;
    } SolrGenomeFeatureData;
      
    /*  
        Structure of a single KBase genome in the input list of genomes of the index_genomes_in_solr function.
    */  
    typedef structure {
        string ref;
        string id; 
        string workspace_name;
        string source_id;
        string accession;
        string name;
        string version;
        string source;
        string domain;
    } KBaseReferenceGenomeData;    
 
    /*
        Arguments for the index_genomes_in_solr function
    */
    typedef structure {
        list<KBaseReferenceGenomeData> genomes;
        string solr_core;
        bool create_report;
    } IndexGenomesInSolrParams;

    /*
        Index specified genomes in SOLR from KBase workspace
    */
    funcdef index_genomes_in_solr(IndexGenomesInSolrParams params) returns (list<SolrGenomeFeatureData> output) authentication required;


    /*
        Arguments for the list_solr_genomes and list_solr_taxa functions
    */

    typedef structure {
        string solr_core;
        int row_start;
        int row_count;
        bool create_report;
    } ListSolrDocsParams;

    /* 
        Lists genomes indexed in SOLR
    */
    funcdef list_solr_genomes(ListSolrDocsParams params) returns (list<SolrGenomeFeatureData> output) authentication required;


    /*
        Struct containing data for a single taxon element output by the list_solr_taxa function
    */
    typedef structure {
        int taxonomy_id;
        string scientific_name;
        string scientific_lineage;
        string rank;
        string kingdom;
        string domain;
        string ws_ref;
        list<string> aliases;
        int genetic_code;
        string parent_taxon_ref;
        string embl_code;
        int inherited_div_flag;
        int inherited_GC_flag;
        int mitochondrial_genetic_code;
        int inherited_MGC_flag;
        int GenBank_hidden_flag;                                     
        int hidden_subtree_flag;
        int division_id;
        string comments;
    } SolrTaxonData;

    /* 
        Lists taxa indexed in SOLR
    */
    funcdef list_solr_taxa(ListSolrDocsParams params) returns (list<SolrTaxonData> output) authentication required;

    /*
        Struct containing data for a single taxon element output by the list_loaded_taxa function
    */
    typedef structure {
        int taxonomy_id;
        string scientific_name;
        string scientific_lineage;
        string rank;
        string kingdom;
        string domain;
        list<string> aliases;
        int genetic_code;
        string parent_taxon_ref;
        string embl_code;
        int inherited_div_flag;
        int inherited_GC_flag;
        int mitochondrial_genetic_code;
        int inherited_MGC_flag;
        int GenBank_hidden_flag;
        int hidden_subtree_flag;
        int division_id;
        string comments;
    } KBaseReferenceTaxonData;


    /*
        Struct containing data for a single output by the list_loaded_taxa function
    */
    typedef structure {
        KBaseReferenceTaxonData taxon; 
        string ws_ref;
    } LoadedReferenceTaxonData;

    /*  
        Arguments for the index_taxa_in_solr function
    
    */  
    typedef structure {
        list<LoadedReferenceTaxonData> taxa;
        string solr_core;
        bool create_report;
    } IndexTaxaInSolrParams;
    
    /*  
        Index specified genomes in SOLR from KBase workspace
    */  
    funcdef index_taxa_in_solr(IndexTaxaInSolrParams params) returns (list<SolrTaxonData> output) authentication required;
    
};
