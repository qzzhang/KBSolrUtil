/*
A KBase module: KBSolrUtil
This module contains the utility methods and configuration details to access the KBase SOLR cores.
*/

module KBSolrUtil {
    /* 
        a bool defined as int
    */
    typedef int bool;
        
    /* User provided parameter data.
        Arbitrary key-value pairs provided by the user.
    */
    typedef mapping<string, string> searchdata;
    typedef mapping<string, string> docdata;
       
 
    /* Solr response data for search requests.
        Arbitrary key-value pairs returned by the solr.
    */
    typedef mapping<string, string> solrresponse;
 
    /*
        Arguments for the index_in_solr function - send doc data to solr for indexing
        
        string solr_core - the name of the solr core to index to
        list<docdata> doc_data - the doc to be indexed, a list of hashes 
    */
    typedef structure {
       string solr_core;
       list<docdata> doc_data;
    } IndexInSolrParams;

    /*
        The index_in_solr function that returns 1 if succeeded otherwise 0
    */
    funcdef index_in_solr(IndexInSolrParams params) returns (int output) authentication required;
    
    /*
        Arguments for the new_or_updated function - search solr according to the parameters passed and return the ones not found in solr.
        
        string search_core - the name of the solr core to be searched
        list<searchdata> search_docs - a list of arbitrary user-supplied key-value pairs specifying the definitions of docs 
            to be searched, a hash for each doc, see the example below:
                search_docs=[
                    {
                        field1 => 'val1',
                        field2 => 'val2',
                        domain => 'Bacteria'
                    },
                    {
                        field1 => 'val3',
                        field2 => 'val4',
                        domain => 'Bacteria'                     
                    }
                 ];
        string search_type - the object (genome) type to be searched
    */
    typedef structure {
       string search_core;
       list<searchdata> search_docs;
       string search_type;
    } NewOrUpdatedParams;

    /*
        The new_or_updated function that returns a list of docs
    */
    funcdef new_or_updated(NewOrUpdatedParams params) returns (list<searchdata>) authentication required;

    /*
        Arguments for the exists_in_solr function - search solr according to the parameters passed and return 1 if found at least one doc 0 if nothing found. A shorter version of search_solr.
                
        string search_core - the name of the solr core to be searched
        searchdata search_query - arbitrary user-supplied key-value pairs specifying the fields to be searched and their values to be matched, a hash which specifies how the documents will be searched, see the example below:
                search_query={
                        parent_taxon_ref => '1779/116411/1',
                        rank => 'species',
                        scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
                        scientific_name => 'Bradyrhizobium sp.*',
                        domain => 'Bacteria'
                }
        OR, simply:
                search_query= { q => "*" };
    */
    typedef structure {
       string search_core;
       searchdata search_query;
    } ExistsInputParams;

    /*
        The exists_in_solr function that returns 0 or 1
    */
    funcdef exists_in_solr(ExistsInputParams params) returns (int output) authentication required;

    /*
        Arguments for the get_total_count function - search solr according to the parameters passed and return the count of docs found, or -1 if error.
        
        string search_core - the name of the solr core to be searched
        searchdata search_query - arbitrary user-supplied key-value pairs specifying the fields to be searched and their values to be matched, a hash which specifies how the documents will be searched, see the example below:
                search_query={
                        parent_taxon_ref => '1779/116411/1',
                        rank => 'species',
                        scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
                        scientific_name => 'Bradyrhizobium sp.*',
                        domain => 'Bacteria'
                }
        OR, simply:
                search_query= { q => "*" };
    */
    typedef structure {
       string search_core;
       searchdata search_query;
    } TotalCountParams;

    /*
        The get_total_count function that returns a positive integer (including 0) or -1
    */
    funcdef get_total_count(TotalCountParams params) returns (int output) authentication required;

    /*
        Arguments for the search_solr function - search solr according to the parameters passed and return a string
        
        string search_core - the name of the solr core to be searched
        searchdata search_param - arbitrary user-supplied key-value pairs for controlling the presentation of the query response, 
                                a hash, see the example below:
                search_param={
                        fl => 'object_id,gene_name,genome_source',
                        wt => 'json',
                        rows => 20,
                        sort => 'object_id asc',
                        hl => 'false',
                        start => 100
                }
        OR, default to SOLR default settings, i
                search_param={{fl=>'*',wt=>'xml',rows=>10,sort=>'',hl=>'false',start=>0}

        searchdata search_query - arbitrary user-supplied key-value pairs specifying the fields to be searched and their values 
                                to be matched, a hash which specifies how the documents will be searched, see the example below:
                search_query={
                        parent_taxon_ref => '1779/116411/1',
                        rank => 'species',
                        scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
                        scientific_name => 'Bradyrhizobium sp.*',
                        domain => 'Bacteria'
                }
        OR, simply:
                search_query= { q => "*" };

        string result_format - the format of the search result, 'xml' as the default, can be 'json', 'csv', etc.
        string group_option - the name of the field to be grouped for the result
    */
    typedef structure {
       string search_core;
       searchdata search_param;
       searchdata search_query;
       string result_format;
       string group_option;      
    } SearchSolrParams;

    /*
        The search_solr function that returns a solrresponse consisting of a string in the format of the Perl structure (hash)
    */
    funcdef search_solr(SearchSolrParams params) returns (solrresponse output) authentication required;

    /*
        The search_kbase_solr function that returns a solrresponse consisting of a string in the format of the specified 'result_format' in SearchSolrParams
        The interface is exactly the same as that of search_solr, except the output content will be different. And this function is exposed to the narrative for users to search KBase Solr databases, while search_solr will be mainly serving RDM.
    */
    funcdef search_kbase_solr(SearchSolrParams params) returns (solrresponse output) authentication required;

    /*
        Arguments for the add_json_2solr function - send a JSON doc data to solr for indexing
        
        string solr_core - the name of the solr core to index to
        string json_data - the doc to be indexed, a JSON string 
=for example:
     $json_data = '[
     {
        "taxonomy_id":1297193,
        "domain":"Eukaryota",
        "genetic_code":1,
        "embl_code":"CS",
        "division_id":1,
        "inherited_div_flag":1,
        "inherited_MGC_flag":1,
        "parent_taxon_ref":"12570/1217907/1",
        "scientific_name":"Camponotus sp. MAS010",
        "mitochondrial_genetic_code":5,
        "hidden_subtree_flag":0,
        "scientific_lineage":"cellular organisms; Eukaryota; Opisthokonta; Metazoa; Eumetazoa; Bilateria; Protostomia; Ecdysozoa; Panarthropoda; Arthropoda; Mandibulata; Pancrustacea; Hexapoda; Insecta; Dicondylia; Pterygota; Neoptera; Endopterygota; Hymenoptera; Apocrita; Aculeata; Vespoidea; Formicidae; Formicinae; Camponotini; Camponotus",
        "rank":"species",
        "ws_ref":"12570/1253105/1",
        "kingdom":"Metazoa",
        "GenBank_hidden_flag":1,
        "inherited_GC_flag":1,"
        "deleted":0
      },
      {
        "inherited_MGC_flag":1,
        "inherited_div_flag":1,
        "parent_taxon_ref":"12570/1217907/1",
        "genetic_code":1,
        "division_id":1,
        "embl_code":"CS",
        "domain":"Eukaryota",
        "taxonomy_id":1297190,
        "kingdom":"Metazoa",
        "GenBank_hidden_flag":1,
        "inherited_GC_flag":1,
        "ws_ref":"12570/1253106/1",
        "scientific_lineage":"cellular organisms; Eukaryota; Opisthokonta; Metazoa; Eumetazoa; Bilateria; Protostomia; Ecdysozoa; Panarthropoda; Arthropoda; Mandibulata; Pancrustacea; Hexapoda; Insecta; Dicondylia; Pterygota; Neoptera; Endopterygota; Hymenoptera; Apocrita; Aculeata; Vespoidea; Formicidae; Formicinae; Camponotini; Camponotus",
        "rank":"species",
        "scientific_name":"Camponotus sp. MAS003",
        "hidden_subtree_flag":0,
        "mitochondrial_genetic_code":5,
        "deleted":0
      },
...
  ]';
=cut end of example
    */

    typedef structure {
       string solr_core;
       string json_data;
    } IndexJsonParams;

    /*
        The add_json_2solr function that returns 1 if succeeded otherwise 0
    */
    funcdef add_json_2solr(IndexJsonParams params) returns (int output) authentication required;
};
