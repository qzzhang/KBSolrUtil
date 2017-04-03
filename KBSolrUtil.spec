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
        The search_solr function that returns a solrresponse consisting of a string in the format of the specified 'result_format' in SearchSolrParams
    */
    funcdef search_solr(SearchSolrParams params) returns (solrresponse output) authentication required;
};
