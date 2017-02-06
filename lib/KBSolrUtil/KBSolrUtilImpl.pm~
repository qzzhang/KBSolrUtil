package KBSolrUtil::KBSolrUtilImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = '0.0.1';
our $GIT_URL = '';
our $GIT_COMMIT_HASH = '';

=head1 NAME

KBSolrUtil

=head1 DESCRIPTION

A KBase module: KBSolrUtil
This module contains the utility methods and configuration details to access the KBase SOLR cores.

=cut

#BEGIN_HEADER
use Bio::KBase::AuthToken;
use Bio::KBase::workspace::Client;
use Config::IniFiles;
use Data::Dumper;
#END_HEADER

#################### methods for accessing SOLR using its web interface#######################
#
#Internal Method: to list the genomes already in SOLR and return an array of those genomes
#
sub _listGenomesInSolr {
    my ($self, $solrCore, $fields, $rowStart, $rowCount, $grp) = @_;
    my $start = ($rowStart) ? $rowStart : 0;
    my $count = ($rowCount) ? $rowCount : 10;
    $fields = ($fields) ? $fields : "*";

    my $params = {
        fl => $fields,
        wt => "json",
        rows => $count,
        sort => "genome_id asc",
        hl => "false",
        start => $start
    };
    my $query = { q => "*" };

    return $self->_searchSolr($solrCore, $params, $query, "json", $grp);
}

#
#Internal Method: to list the taxa already in SOLR and return an array of those taxa
#
sub _listTaxaInSolr {
    my ($self, $solrCore, $fields, $rowStart, $rowCount, $grp) = @_;
    $solrCore = ($solrCore) ? $solrCore : "taxonomy_ci";
    my $start = ($rowStart) ? $rowStart : 0;
    my $count = ($rowCount) ? $rowCount : 10;
    $fields = ($fields) ? $fields : "*";

    my $params = {
        fl => $fields,
        wt => "json",
        rows => $count,
        sort => "taxonomy_id asc",
        hl => "false",
        start => $start
    };
    my $query = { q => "*" };
    
    return $self->_searchSolr($solrCore, $params, $query, "json", $grp);    
}

#
# method name: _buildQueryString
# Internal Method: to build the query string for SOLR according to the passed parameters
# parameters:
# $searchQuery is a hash which specifies how the documents will be searched, see the example below:
# $searchQuery={
#   parent_taxon_ref => '1779/116411/1',
#   rank => 'species',
#   scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
#   scientific_name => 'Bradyrhizobium sp. rp3',
#   domain => 'Bacteria'
#}
# OR, simply:
# $searchQuery= { q => "*" };
#
# $searchParams is a hash which specifies how the query results will be displayed, see the example below:
# $searchParams={                                                                                                                                     
#   fl => 'object_id,gene_name,genome_source',
#   wt => 'json',
#   rows => $count,
#   sort => 'object_id asc',
#   hl => 'false',
#   start => $start,
#   count => $count
#}
#
sub _buildQueryString {
    my ($self, $searchQuery, $searchParams, $groupOption, $skipEscape) = @_;
    $skipEscape = {} unless $skipEscape;
    
    my $DEFAULT_FIELD_CONNECTOR = "AND";

    if (! $searchQuery) {
        $self->{is_error} = 1;
        $self->{errmsg} = "Query parameters not specified";
        return undef;
    }
    
    # Build the display parameter part 
    my $paramFields = "";
    foreach my $key (keys %$searchParams) {
        $paramFields .= "$key=". URI::Escape::uri_escape($searchParams->{$key}) . "&";
    }
    
    # Build the solr query part
    my $qStr = "q=";
    if (defined $searchQuery->{q}) {
        $qStr .= URI::Escape::uri_escape($searchQuery->{q});
    } else {
        foreach my $key (keys %$searchQuery) {
            if (defined $skipEscape->{$key}) {
                $qStr .= "+$key:\"" . $searchQuery->{$key} ."\" $DEFAULT_FIELD_CONNECTOR ";
            } else {
                $qStr .= "+$key:\"" . URI::Escape::uri_escape($searchQuery->{$key}) . "\" $DEFAULT_FIELD_CONNECTOR ";  
            }
        }
        # Remove last occurance of ' AND '
        $qStr =~ s/ AND $//g;
    }
    my $solrGroup = $groupOption ? "&group=true&group.field=$groupOption" : "";
    my $retStr = $paramFields . $qStr . $solrGroup;
    #print "Query string:\n$retStr\n";
    return $retStr;
}

#
# method name: _buildQueryString_wildcard---This is a modified version of the above function, all because the stupid SOLR 4.*
# handles the wildcard search string in a weird way:when the '*' is at either end of the search string, it returns 0 docs
# if the search string is within double quotes. On the other hand, when a search string has whitespace(s), it has to be inside
# double quotes otherwise SOLR will treat it as new field(s).
# So this method builds the search string WITHOUT the double quotes ONLY for the use case when '*' will be at the ends of the string.
# The rest is the same as the above method.
#
sub _buildQueryString_wildcard {
    my ($self, $searchQuery, $searchParams, $groupOption, $skipEscape) = @_;
    $skipEscape = {} unless $skipEscape;
    
    my $DEFAULT_FIELD_CONNECTOR = "AND";

    if (!$searchQuery) {
        $self->{is_error} = 1;
        $self->{errmsg} = "Query parameters not specified";
        return undef;
    }
    
    # Build the display parameter part                                             
        my $paramFields = "";                                                                                                                                                                                            
    foreach my $key (keys %$searchParams) {
        $paramFields .= "$key=". URI::Escape::uri_escape($searchParams->{$key}) . "&";
    }
    
    # Build the solr query part
    my $qStr = "q=";
    if (defined $searchQuery->{q}) {
        $qStr .= URI::Escape::uri_escape($searchQuery->{q});
    } else {
        foreach my $key (keys %$searchQuery) {
            if (defined $skipEscape->{$key}) {
                $qStr .= "+$key:" . $searchQuery->{$key} ." $DEFAULT_FIELD_CONNECTOR ";
            } else {
                $qStr .= "+$key:" . URI::Escape::uri_escape($searchQuery->{$key}) . " $DEFAULT_FIELD_CONNECTOR ";  
            } 
        }
        # Remove last occurance of ' AND '
        $qStr =~ s/ AND $//g;
    }
    my $solrGroup = $groupOption ? "&group=true&group.field=$groupOption" : "";
    my $retStr = $paramFields . $qStr . $solrGroup;
    #print "Query string:\n$retStr\n";
    return $retStr;
}




d name: _searchSolr
# Internal Method: to execute a search in SOLR according to the passed parameters
# parameters:
# $searchQuery is a hash which specifies how the documents will be searched, see the example below:
# $searchQuery={
#   parent_taxon_ref => '1779/116411/1',
#   rank => 'species',
#   scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
#   scientific_name => 'Bradyrhizobium sp. rp3',
#   domain => 'Bacteria'
#}
# OR, simply:
# $searchQuery= { q => "*" };
#
# $searchParams is a hash, see the example below:
# $searchParams={
#   fl => 'object_id,gene_name,genome_source',
#   wt => 'json',
#   rows => $count,
#   sort => 'object_id asc',
#   hl => 'false',
#   start => $start,
#   count => $count
#}
#
sub _searchSolr {
    my ($self, $searchCore, $searchParams, $searchQuery, $resultFormat, $groupOption, $skipEscape) = @_;
    $skipEscape = {} unless $skipEscape;

    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    
    # If output format is not passed set it to XML
    $resultFormat = "xml" unless $resultFormat;
    my $queryString = $self->_buildQueryString($searchQuery, $searchParams, $groupOption, $skipEscape);
    my $solrCore = "/$searchCore"; 
    #my $sort = "&sort=genome_id asc";
    my $solrQuery = $self->{_SOLR_URL}.$solrCore."/select?".$queryString;
    #print "Search string:\n$solrQuery\n";
    
    my $solr_response = $self->_sendRequest("$solrQuery", "GET");
    #print "\nRaw response: \n" . $solr_response->{response} . "\n";
    
    my $responseCode = $self->_parseResponse($solr_response, $resultFormat);
        if ($responseCode) {
            if ($resultFormat eq "json") {
                my $out = JSON::from_json($solr_response->{response});
                $solr_response->{response}= $out;
            }
    }
    if($groupOption){
        my @solr_records = @{$solr_response->{response}->{grouped}->{$groupOption}->{groups}};
        print "\n\nFound unique $groupOption groups of:" . scalar @solr_records . "\n";
        print @solr_records[0]->{doclist}->{numFound} ."\n";
    }
    
    return $solr_response;
}

#
# method name: _searchSolr_wildcard---This is a modified version of the above function, all because the stupid SOLR 4.*
# handles the wildcard search string in a weird way:when the '*' is at either end of the search string, it returns 0 docs
# if the search string is within double quotes. On the other hand, when a search string has whitespace(s), it has to be inside
# double quotes otherwise SOLR will treat it as new field(s).
# So this method will call the method that builds the search string WITHOUT the double quotes ONLY for the use case when '*' will be 
# at the ends of the string.
# The rest is the same as the above method.
#
sub _searchSolr_wildcard {
    my ($self, $searchCore, $searchParams, $searchQuery, $resultFormat, $groupOption, $skipEscape) = @_;
    $skipEscape = {} unless $skipEscape;

    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    
    # If output format is not passed set it to XML
    $resultFormat = "xml" unless $resultFormat;
    my $queryString = $self->_buildQueryString_wildcard($searchQuery, $searchParams, $groupOption, $skipEscape);
    my $solrCore = "/$searchCore"; 
    my $solrQuery = $self->{_SOLR_URL}.$solrCore."/select?".$queryString;
    #print "Search string:\n$solrQuery\n";
    
    my $solr_response = $self->_sendRequest("$solrQuery", "GET");
    #print "\nRaw response: \n" . $solr_response->{response} . "\n";
    
    my $responseCode = $self->_parseResponse($solr_response, $resultFormat);
        if ($responseCode) {
            if ($resultFormat eq "json") {
                my $out = JSON::from_json($solr_response->{response});
                $solr_response->{response}= $out;
            }
    }
    if($groupOption){
        my @solr_records = @{$solr_response->{response}->{grouped}->{$groupOption}->{groups}};
        if( scalar @solr_records > 0 ) {
            print "\n\nFound unique $groupOption groups of:" . scalar @solr_records . "\n";
            print @solr_records[0]->{doclist}->{numFound} ."\n";
        }
    }
    
    return $solr_response;
}

                                                                                                                                                    
# method name: _deleteRecords
# Internal Method: to delete record(s) in SOLR that matches the given id(s) in the query
# parameters:
# $criteria is a hash that holds the conditions for field(s) to be deleted, see the example below:
# $criteria {
#   'object_id' => 'kb|ws.2869.obj.72243',
#   'workspace_name' => 'KBasePublicRichGenomesV5'
#}
#

sub _deleteRecords
{
    my ($self, $searchCore, $criteria) = @_;
    my $solrCore = "/$searchCore";

    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }

    # Build the <query/> string that concatenates all the criteria into query tags
    my $queryCriteria = "<delete>";
    if (! $criteria) {
        $self->{is_error} = 1;
        $self->{errmsg} = "No deletion criteria specified";
        return undef;
    }
    foreach my $key (keys %$criteria) {
        $queryCriteria .= "<query>$key:". URI::Escape::uri_escape($criteria->{$key}) . "</query>";
    }

    $queryCriteria .= "</delete>&commit=true";
    #print "The deletion query string is: \n" . "$queryCriteria \n";

    my $solrQuery = $self->{_SOLR_URL}.$solrCore."/update?stream.body=".$queryCriteria;
    #print "The final deletion query string is: \n" . "$solrQuery \n";

    my $solr_response = $self->_sendRequest("$solrQuery", "GET");
    return $solr_response;
}

#
# method name: _sendRequest
# Internal Method used for sending HTTP
# url : Requested url
# method : HTTP method
# dataType : Type of data posting (binary or text)
# headers : headers as key => value pair
# data : if binary it will as sequence of character
#          if text it will be key => value pair
sub _sendRequest
{
    my ($self, $url, $method, $dataType, $headers, $data) = @_;

    # Intialize the request params if not specified
    $dataType = ($dataType) ? $dataType : 'text';
    $method = ($method) ? $method : 'POST';
    $url = ($url) ? $url : $self->{_SOLR_URL};
    $headers = ($headers) ?  $headers : {};
    $data = ($data) ? $data: '';

    my $out = {};

    # create a HTTP request
    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new;
    $request->method($method);
    $request->uri($url);

    # set headers
    foreach my $header (keys %$headers) {
        $request->header($header =>  $headers->{$header});
    } 

    # set data for posting
    $request->content($data);
    #print "The HTTP request: \n" . Dumper($request) . "\n";
    
    # Send request and receive the response
    my $response = $ua->request($request);
    $out->{responsecode} = $response->code();
    $out->{response} = $response->content;
    $out->{url} = $url;
    return $out;
}

#
# Internal Method: to parse solr server response
# Responses from Solr take the form shown here:
#<response>
#  <lst name="responseHeader">
#    <int name="status">0</int>
#    <int name="QTime">127</int>
#  </lst>
#</response>
#
sub _parseResponse
{
    my ($self, $response, $responseType) = @_;

    # Clear the error fields
    $self->{is_error} = 0;
    $self->{error} = undef;

    $responseType = "xml" unless $responseType;

    # Check for successfull request/response
    if ($response->{responsecode} eq "200") {
           if ($responseType eq "json") {
                my $resRef = JSON::from_json($response->{response});
                if ($resRef->{responseHeader}->{status} eq 0) {
                        return 1;
                }
            } else {
                my $xs = new XML::Simple();
                my $xmlRef;
                eval {
                        $xmlRef = $xs->XMLin($response->{response});
                };
                if ($xmlRef->{lst}->{'int'}->{status}->{content} eq 0){
                        return 1;
                }
            }
    } 
    $self->{is_error} = 1;
    $self->{error} = $response;
    $self->{error}->{errmsg} = $@;
    return 0;
}

#
# method name: _addXML2Solr
# Internal method: to add XML documents to solr for indexing.
# It sends a xml http request.  First it will convert the raw datastructure to required ds then it will convert
# this ds to xml. This xml will be posted to Apache solr for indexing.
# Depending on the flag AUTOCOMMIT the documents will be indexed immediatly or on commit is issued.
# parameters:   
#     $params: This parameter specifies set of list of document fields and values.
# return
#    1 for successful posting of the xml document
#    0 for any failure
#
#
sub _addXML2Solr
{
    my ($self, $solrCore, $params) = @_;
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    
    my $ds = $self->_rawDsToSolrDs($params);
    my $doc = $self->_toXML($ds, 'add');
    #print Dumper($doc);
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    my $url = "$self->{_SOLR_URL}/$solrCore/update?commit=" . $commit;
    my $response = $self->_sendRequest($url, 'POST', undef, $self->{_CT_XML}, $doc);
    return 1 if ($self->_parseResponse($response));
    $self->{error} = $response;
    $self->{error}->{errmsg} = $@;
    #print "\nSolr indexing error:\n" . $self->_error->{response}; #Dumper($response);
    return 0;
}

#
# method name: _toXML
# Internal Method
# This function will convert the datastructe to XML document
# For XML Formatted Index Updates
#
# The XML schema recognized by the update handler for adding documents is very straightforward:
# The <add> element introduces one or more documents to be added.
# The <doc> element introduces the fields making up a document.
# The <field> element presents the content for a specific field.
# For example:
# <add>
#  <doc>
#    <field name="authors">Patrick Eagar</field>
#    <field name="subject">Sports</field>
#    <field name="dd">796.35</field>
#    <field name="numpages">128</field>
#    <field name="desc"></field>
#    <field name="price">12.40</field>
#    <field name="title" boost="2.0">Summer of the all-rounder: Test and championship cricket in England 1982</field>
#    <field name="isbn">0002166313</field>
#    <field name="yearpub">1982</field>
#    <field name="publisher">Collins</field>
#  </doc>
#  <doc boost="2.5">
#  ...
#  </doc>
#</add>
# Index update commands can be sent as XML message to the update handler using Content-type: application/xml or Content-type: text/xml.
# For adding Documents
#
sub _toXML
{
    my ($self, $params, $rootnode) = @_;
    my $xs = new XML::Simple();
    my $xml;
    if (! $rootnode) {
    $xml = $xs->XMLout($params);
    } else {
    $xml = $xs->XMLout($params, rootname => $rootnode);
    }
    #print "\n$xml\n";                                               
        return $xml;
}

#
# method name: _rawDs2SolrDs
#
# Convert raw DS to sorl requird DS.
# Input format :
#    [
#    {
#        attr1 => [value1, value2],
#        attr2 => [value3, value4]
#    },
#    ...
#    ]
# Output format:
#    [
#    { field => [ { name => attr1, content => value1 },
#             { name => attr1, content => value2 },
#             { name => attr2, content => value3 },
#             { name => attr2, content => value4 }
#            ],
#    },
#    ...
#    ]
#
sub _rawDsToSolrDs
{
    my ($self, $docs) = @_;
    #print "\nInput data:\n". Dumper($docs);
    my $ds = [];
    if( ref($docs) eq 'ARRAY' && scalar (@$docs) ) {
        for my $doc (@$docs) {
            my $d = [];
            for my $field (keys %$doc) {
                my $values = $doc->{$field};
                if (ref($values) eq 'ARRAY' && scalar (@$values) ){
                    for my $val (@$values) {
                        my @fval_data = split(/;;/, $val);
                        foreach my $fval (@fval_data) {
                            push @$d, {name => $field, content => $fval} unless $field eq '_version_';
                        }
                    }
                } else {#only a single member in the list
                    my @fval_data = split(/;;/, $values);
                    foreach my $fval (@fval_data) {
                        push @$d, { name => $field, content => $fval} unless $field eq '_version_';
                    }
                }
            }
            push @$ds, {field => $d};
        }
    }
    else {#only a single member in the list
        my $d = [];
        for my $field (keys %$docs) {
            my $values = $docs->{$field};
            #print "$field => " . Dumper($values);
            if (ref($values) eq 'ARRAY' && scalar (@$values) ){
                for my $val (@$values) {
                    my @fval_data = split(/;;/, $val);
                    foreach my $fval (@fval_data) {
                        push @$d, {name => $field, content => $fval} unless $field eq '_version_';
                    }
                }
            } else {#only a single member in the list
                my @fval_data = split(/;;/, $values);
                foreach my $fval (@fval_data) {
                    push @$d, { name => $field, content => $fval} unless $field eq '_version_'; 
                }
            }
        }
        push @$ds, {field => $d};
    }
    
    $ds = { doc => $ds };
    #print "\noutput data:\n" .Dumper($ds);
    return $ds;
}
#
# method name: _error
#     returns the errors details that has occured during last transaction action.
# params : -
# returns : response details includes the following details
#    {
#       url => 'url which is being accessed',
#       response => 'response from server',
#       code => 'response code',
#       errmsg => 'for any internal error error msg'
#     }
#
#
sub _error
{
    my ($self) = @_;
    return $self->{error};
}

#
# method name: _autocommit
#    This method is used for setting the autocommit on or off.
# params:
#     flag: 1 or 0, 1 for setting autocommit on and 0 for off.
# return
#    always returns true
#
sub _autocommit
{
    my ($self, $flag) = @_;
    $self->{_AUTOCOMMIT} = $flag | 1;
    return 1;
}

#
# method name: _commit
#    This method is used for commiting the transaction that was initiated.
#     Request XML format:
#         true
# params : -
# returns :
#    1 for success
#    0 for any failure
#
#
sub _commit
{
    my ($self, $solrCore) = @_;
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    
    my $url = $self->{_SOLR_POST_URL} . "/$solrCore/update";
    my $cmd = $self->_toXML('true', 'commit');
    my $response = $self->_sendRequest($url, 'POST', undef, $self->{_CT_XML}, $cmd);

    return 1 if ($self->_parseResponse($response));
    return 0;
}
#
# method name: _rollback
#    This method is used for issuing rollback on transaction that
# was initiated. Request XML format:
#     <rollback>
# params : -
# returns :
#    1 for success
#    0 for any failure
#
#
sub _rollback
{
    my ($self, $solrCore) = @_;

    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }

    my $url = $self->{_SOLR_POST_URL} . "/$solrCore/update";
    my $cmd = $self->_toXML('', 'rollback');
    my $response = $self->_sendRequest($url, 'POST', undef, $self->{_CT_XML}, $cmd);

    return 1 if ($self->_parseResponse($response));
    return 0;
}

#
# method name: _exists
# Checking if the document with the specified search string exists
# params :
# $searchCriteria is a hash which specifies how the documents will be searched, see the example below:
# $searchCriteria={
#   parent_taxon_ref => '1779/116411/1',
#   rank => 'species',
#   scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
#   scientific_name => 'Bradyrhizobium sp. rp3',
#   domain => 'Bacteria'
#}
# returns :
#    1 for yes (document match found) 
#    0 for any failure
#
#
sub _exists
{
    my ($self, $solrCore, $searchCriteria) = @_;

    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    my $queryString = $self->_buildQueryString($searchCriteria);
    my $url = $self->{_SOLR_URL}."/$solrCore/select?";
    $url = $url. $queryString;

    my $response = $self->_sendRequest($url, 'GET');

    my $status = $self->_parseResponse($response);
    if ($status == 1) {
        my $xs = new XML::Simple();
        my $xmlRef;
        eval {
            $xmlRef = $xs->XMLin($response->{response});
        };
        print "\n$url result:\n" . Dumper($xmlRef->{result}) . "\n";
        if ($xmlRef->{lst}->{'int'}->{status}->{content} eq 0){
            if ($xmlRef->{result}->{numFound} gt 0) {
            return 1;
        }
     }   
    }
    return 0;
}


# method name: _ping
#    This methods is check Apache solr server is reachable or not
# params : -
# returns :
#     1 for success
#     0 for failure
# Check error method for for getting the error details for last command
#
sub _ping
{
    my ($self, $errors) = @_;
    #print "Pinging server: $self->{_SOLR_PING_URL}\n";
    my $response = $self->_sendRequest($self->{_SOLR_PING_URL}, 'GET');
    #print "Ping's response:\n" . Dumper($response) . "\n";
    
    return 1 if ($self->_parseResponse($response));
    return 0;
}

sub _clear_error
{
    my ($self) = @_;
    $self->{is_error} = 0;
    $self->{error} = undef;
}

#
# method name: _error
# returns the errors details that was occured during last transaction action.
# params : -
# returns : response details includes the following details
#    {
#       url => 'url which is being accessed',
#       response => 'response from server',
#       code => 'response code',
#       errmsg => 'for any internal error error msg'
#     }
#
# Check error method for for getting the error details for last command
#
sub _error
{
    my ($self) = @_;
    return $self->{error};
}
#
# Internal Method: to check if a given genome has been indexed by KBase in SOLR.  Returns a string stating the status
#
# params :
# $current_genome is a genome object whose KBase status is to be checked.
# $solr_core is the name of the SOLR core
#
# returns : a string
#
sub _checkTaxonStatus
{
    my ($self, $current_genome, $solr_core) = @_;
    #print "\nChecking taxon status for genome:\n " . Dumper($current_genome) . "\n";

    my $status = "";
    my $params = {
        fl => "taxonomy_id,domain",
        wt => "json"
    };
    my $query = { taxonomy_id => $current_genome->{tax_id} };
    my $solr_response = $self->_searchSolr($solr_core, $params, $query, "json");
    if( $solr_response->{response}->{response}->{numFound} == 0 ) {
        $status = "Taxon not found";
    }
    else {
        my $solr_records = $solr_response->{response}->{response}->{docs};
        #print "\n\nFound " . scalar @{$solr_records} . " taxon/taxa\n";
        for (my $i = 0; $i < @{$solr_records}; $i++ ) {
            my $record = $solr_records->[$i];
            #print $solr_response->{response}->{response}->{numFound} ."\n";

            if ($record->{taxonomy_id} eq $current_genome->{tax_id} && $record->{domain} ne "Unknown"){
                $status = "Taxon inKBase";
                last;
            }
            else{
                $status = "Unknown domain";
                last;
            }
        }
    }
    #print "\nStatus:$status\n";
    return $status;
}
#
#
# Internal Method: to check if a given genome status against genomes in SOLR.  Returns a string stating the status
#
# params :
# $current_genome is a genome object whose KBase status is to be checked.
# $solr_core is the name of the SOLR core
#
# returns : a string
#    
sub _checkGenomeStatus 
{
    my ($self, $current_genome, $solr_core) = @_;
    #print "\nChecking status for genome:\n " . Dumper($current_genome) . "\n";

    my $status = "";
    my $groupOption = "genome_id";
    my $params = {
        fl => $groupOption,
        wt => "json"
    };
    my $query = { genome_id => $current_genome->{id} . "*" };
    my $solr_response = $self->_searchSolr_wildcard($solr_core, $params, $query, "json", $groupOption);
    if( $solr_response->{response}->{grouped}->{$groupOption}->{matches} == 0 ) {
        $status = "New genome";
    }
    else {
        my $solr_records = $solr_response->{response}->{grouped}->{$groupOption}->{groups};
        #print "\n\nFound unique $groupOption groups of:" . scalar @{$solr_records} . "\n";
        for (my $i = 0; $i < @{$solr_records}; $i++ ) {
            my $record = $solr_records->[$i];
            #print $record->{doclist}->{numFound} ."\n";
            my $genome_id = $record->{genome_id};

            if ($genome_id eq $current_genome->{accession}){
                $status = "Existing genome: current";
                $current_genome->{genome_id} = $genome_id;
                last;
            }elsif ($genome_id =~/$current_genome->{id}/){ 
                $status = "Existing genome: updated ";
                $current_genome->{genome_id} = $genome_id;
                last;
            }
        }
        if( $status eq "" )
        {
            $status = "New genome";#or "Existing genome: status unknown";
        }
    }
    #print "\nStatus:$status\n";
    return $status;
}

#
#Internal method, to fetch the information about a genome records from a given genome reference
#Input: a reference to a Workspace.object_info (which is a reference to a list containing 11 items)
#Output: a reference to a hash of the type of ReferenceDataManager.LoadedReferenceGenomeData
#
sub _getGenomeInfo 
{
    my ($self, $ws_objinfo) = @_;
    my $gn_info = [];

    $gn_info = {
        "ref" => $ws_objinfo->[6]."/".$ws_objinfo->[0]."/".$ws_objinfo->[4],
        id => $ws_objinfo->[0],
        workspace_name => $ws_objinfo->[7],
        type => $ws_objinfo->[2],
        source_id => $ws_objinfo->[10]->{"Source ID"},
        accession => $ws_objinfo->[1],
        name => $ws_objinfo->[1],
        version => $ws_objinfo->[4],
        source => $ws_objinfo->[10]->{Source},
        domain => $ws_objinfo->[10]->{Domain},
        save_date => $ws_objinfo->[3],
        contig_count => $ws_objinfo->[10]->{"Number contigs"},
        feature_count => $ws_objinfo->[10]->{"Number features"},
        size_bytes => $ws_objinfo->[9],
        ftp_url => $ws_objinfo->[10]->{"url"},
        gc => $ws_objinfo->[10]->{"GC content"}
    };
    return $gn_info;
}

#
#Internal method, to fetch genome records for a given set of ws_ref's and index the genome_feature combo in SOLR.
#First call get_objects2() to get the genome object one at a time.
#Then plow through the genome object data to assemble the data items for a Solr genome_feature object.
#Finally send the data document to Solr for indexing.
#Input: a list of KBaseReferenceGenomeData
#Output: a list of SolrGenomeFeatureData
#
sub _indexGenomeFeatureData 
{
    my ($self, $solrCore, $ws_gnData) = @_;
    my $ws_gnrefs = [];

    foreach my $ws_gn (@{$ws_gnData}) {
        push @{$ws_gnrefs}, {
            "ref" => $ws_gn->{ref}
        };
    }

    my $ws_gnout;
    my $solr_gnftData = [];
    my $gnft_batch = [];
    my $batchCount = 10000;
    #foreach my $ws_ref (@{$ws_gnrefs}) { 
    for( my $gf_i = 0; $gf_i < @{$ws_gnrefs}; $gf_i++ ) {
        my $ws_ref = $ws_gnrefs->[$gf_i];
        print "\nStart to fetch the object(s) for "  . $gf_i . ". " . $ws_ref->{ref} .  " on " . scalar localtime . "\n";
        eval {#return a reference to a list where each element is a Workspace.ObjectData with a key named 'data'
                $ws_gnout = $self->util_ws_client()->get_objects2({
                        objects => [$ws_ref]
                }); 
        };
        if($@) {
                print "Cannot get object information!\n";
                print "ERROR:".$@;
                if(defined($@->{status_line})) {
                    print $@->{status_line}."\n";
                }
        }
        else {
            $ws_gnout = $ws_gnout -> {data};#a reference to a list where each element is a Workspace.ObjectData
            print "Done getting genome object info for " . $ws_ref->{ref} . " on " . scalar localtime . "\n";
            my $ws_gn_data;#to hold a value which is a Workspace.objectData
            my $ws_gn_info;#to hold a value which is a Workspace.object_info
            my $ws_gn_onterms ={};
            my $ws_gn_features = {};
            my $ws_gn_tax;
            my $ws_gn_aliases;
            my $ws_gn_nm;
            my $loc_contig;
            my $loc_begin;
            my $loc_end;
            my $loc_strand;
            my $ws_gn_loc;
            my $ws_gn_save_date;
            my $numCDs = 0;
            # my $ws_gn_refseqcat;

            #fetch individual data item to assemble the genome_feature info for $solr_gnftData
            for (my $i=0; $i < @{$ws_gnout}; $i++) {
                $ws_gn_data = $ws_gnout -> [$i] -> {data};#an UnspecifiedObject
                $ws_gn_info = $ws_gnout -> [$i] -> {info};#is a reference to a list containing 11 items
                $ws_gn_features = $ws_gn_data->{features};
                $ws_gn_tax = $ws_gn_data->{taxonomy};
                $ws_gn_tax =~s/ *; */;;/g;
                $ws_gn_save_date = $ws_gn_info -> [3];
                
                $numCDs  = 0;
                foreach my $feature (@{$ws_gn_features}) {
                    $numCDs++ if $feature->{type} = 'CDS';
                }

                ###1)---Build the genome solr object for the sake of the search UI/search service
                my $ws_gnobj = {
                          object_id => "kb|ws_ref:" . $ws_ref->{ref},
                          object_name => "kb|g." . $ws_gn_data->{id}, ########
                          object_type => $ws_gn_info->[2], ########refseq_category => $ws_gn_data->{type},
                          ws_ref => $ws_ref->{ref},
                          genome_id => $ws_gn_data->{id},
                          genome_source_id => $ws_gn_info->[10]->{"Source ID"},
                          genome_source => $ws_gn_data->{source},
                          genetic_code => $ws_gn_data->{genetic_code},
                          domain => $ws_gn_data->{domain},
                          scientific_name => $ws_gn_data->{scientific_name},
                          genome_dna_size => $ws_gn_info->[10]->{Size},
                          num_contigs => $ws_gn_info->[10]->{"Number contigs"},#$ws_gn_data->{num_contigs},
                          assembly_ref => $ws_gn_data->{assembly_ref},
                          gc_content => $ws_gn_info->[10]->{"GC content"},
                          complete => $ws_gn_data->{complete},
                          taxonomy => $ws_gn_tax,
                          taxonomy_ref => $ws_gn_data->{taxon_ref},
                          workspace_name => $ws_gn_info->[7],
                          num_cds => $numCDs,
                          #gnmd5checksum => $ws_gn_info->[8],
                          save_date => $ws_gn_save_date,            
                };   
                #push @{$solr_gnftData}, $ws_gnobj;
                #push @{$gnft_batch}, $ws_gnobj;
                ###---end Build the genome solr object---
                
                ###2)---Build the genome_feature solr object
                for (my $ii=0; $ii < @{$ws_gn_features}; $ii++) {
                    if( defined($ws_gn_features->[$ii]->{aliases})) {
                        $ws_gn_nm = $ws_gn_features->[$ii]->{aliases}[0] unless $ws_gn_features->[$ii]->{aliases}[0]=~/^(NP_|WP_|YP_|GI|GeneID)/i;
                        $ws_gn_aliases = join(";", @{$ws_gn_features->[$ii]->{aliases}});
                        $ws_gn_aliases =~s/ *; */;;/g;
                    }
                    else {
                        $ws_gn_nm = undef;
                        $ws_gn_aliases = undef;
                    }

                    my $ws_gn_funcs = $ws_gn_features->[$ii]->{function};
                    $ws_gn_funcs = join(";;", split(/\s*;\s+|\s+[\@\/]\s+/, $ws_gn_funcs));

                    my $ws_gn_roles;
                    if( defined($ws_gn_features->[$ii]->{roles}) ) {
                        $ws_gn_roles = join(";;", $ws_gn_features->[$ii]->{roles});
                    }
                    else {
                        $ws_gn_roles = undef;
                    }
                    $loc_contig = "";
                    $loc_begin = 0;
                    $loc_end = "";
                    $loc_strand = "";
                    $ws_gn_loc = $ws_gn_features->[$ii]->{location};

                    my $end = 0;
                    foreach my $contig_loc (@{$ws_gn_loc}) {
                        $loc_contig = $loc_contig . ";;" unless $loc_contig eq "";
                        $loc_contig = $loc_contig . $contig_loc->[0];

                        $loc_begin = $loc_begin . ";;" unless $loc_begin eq "";
                        $loc_begin = $loc_begin . $contig_loc->[1];

                        if( $contig_loc->[2] eq "+") {
                            $end = $contig_loc->[1] + $contig_loc->[3];
                        }
                        else {
                            $end = $contig_loc->[1] - $contig_loc->[3];
                        }
                        $loc_end = $loc_end . ";;" unless $loc_end eq "";
                        $loc_end = $loc_end . $end;

                        $loc_strand = $loc_strand . ";;" unless $loc_strand eq "";
                        $loc_strand = $loc_strand . $contig_loc->[2];
                    }

                    $ws_gn_onterms = $ws_gn_features->[$ii]->{ontology_terms};

                    my $ws_gnft = {
                          #genome data (redundant)
                          genome_source_id => $ws_gn_info->[10]->{"Source ID"},
                          genome_id => $ws_gn_data->{id},
                          ws_ref => $ws_ref->{ref},
                          genome_source => $ws_gn_data->{source},
                          genetic_code => $ws_gn_data->{genetic_code},
                          domain => $ws_gn_data->{domain},
                          scientific_name => $ws_gn_data->{scientific_name},
                          genome_dna_size => $ws_gn_info->[10]->{Size},
                          num_contigs => $ws_gn_info->[10]->{"Number contigs"},#$ws_gn_data->{num_contigs},
                          assembly_ref => $ws_gn_data->{assembly_ref},
                          gc_content => $ws_gn_info->[10]->{"GC content"},
                          complete => $ws_gn_data->{complete},
                          taxonomy => $ws_gn_tax,
                          taxonomy_ref => $ws_gn_data->{taxon_ref},
                          workspace_name => $ws_gn_info->[7],
                          num_cds => $numCDs,
                          save_date => $ws_gn_save_date,
                          #feature data
                          genome_feature_id => $ws_gn_data->{id} . "|feature:" . $ws_gn_features->[$ii]->{id},
                          object_id => "kb|ws_ref:". $ws_ref->{ref}. "|feature:" . $ws_gn_features->[$ii]->{id},
                          object_name => $ws_gn_info->[1] . "|feature:" . $ws_gn_features->[$ii]->{id},
                          object_type => $ws_gn_info->[2] . ".Feature",
                          feature_type => $ws_gn_features->[$ii]->{type},
                          feature_id => $ws_gn_features->[$ii]->{id},
                          functions => $ws_gn_funcs,
                          roles => $ws_gn_roles,
                          md5 => $ws_gn_features->[$ii]->{md5},
                          gene_name => $ws_gn_nm,
protein_translation_length => ($ws_gn_features->[$ii]->{protein_translation_length}) != "" ? $ws_gn_features->[$ii]->{protein_translation_length} : 0,
                          dna_sequence_length => ($ws_gn_features->[$ii]->{dna_sequence_length}) != "" ? $ws_gn_features->[$ii]->{dna_sequence_length} : 0,
                          aliases => $ws_gn_aliases,
                          location_contig => $loc_contig,
                          location_strand => $loc_strand,
                          location_begin => $loc_begin,
                          location_end => $loc_end,
                          ontology_namespaces => $ws_gn_features->[$ii]->{ontology_terms}
                    };
                    push @{$solr_gnftData}, $ws_gnft;
                    push @{$gnft_batch}, $ws_gnft;
                    if(@{$gnft_batch} >= $batchCount) {
                        eval {
                              $self->_indexInSolr($solrCore, $gnft_batch);
                        };
                        if($@) {
                              print "Failed to index the genome_feature(s)!\n";
                              print "ERROR:". Dumper( $@ );
                              if(defined($@->{status_line})) {
                                  print $@->{status_line}."\n";
                              }
                        }
                        else {
                              print "\nIndexed " . @{$gnft_batch} . " genome_feature(s) on " . scalar localtime . "\n";
                              $gnft_batch = [];
                        }
                    }
                }
                if(@{$gnft_batch} > 0) {
                    eval {
                        $self->_indexInSolr($solrCore, $gnft_batch);
                    };
                    if($@) {
                        print "Failed to index the genome_feature(s)!\n";
                        print "ERROR:". Dumper( $@ );
                        if(defined($@->{status_line})) {
                            print $@->{status_line}."\n"; 
                        }
                    }
                    else {
                        print "\nIndexed " . @{$gnft_batch} . " genome_feature(s) on " . scalar localtime . "\n";
                        $gnft_batch = [];
                    }
                }
            }
        }
    }
    return $solr_gnftData;
}
#
#internal method, for fetching one taxon record to be indexed in solr
#
sub _getTaxon 
{
    my ($self, $taxonData, $wsref) = @_;

    my $t_aliases = defined($taxonData -> {aliases}) ? join(";", @{$taxonData -> {aliases}}) : "";
    my $current_taxon = {
        taxonomy_id => $taxonData -> {taxonomy_id},
        scientific_name => $taxonData -> {scientific_name},
        scientific_lineage => $taxonData -> {scientific_lineage},
        rank => $taxonData -> {rank},
        kingdom => $taxonData -> {kingdom},
        domain => $taxonData -> {domain},
        ws_ref => $wsref,
        aliases => $t_aliases,
        genetic_code => ($taxonData -> {genetic_code}) ? ($taxonData -> {genetic_code}) : "0",
        parent_taxon_ref => $taxonData -> {parent_taxon_ref},
        embl_code => $taxonData -> {embl_code},
        inherited_div_flag => ($taxonData -> {inherited_div_flag}) ? $taxonData -> {inherited_div_flag} : "0",
        inherited_GC_flag => ($taxonData -> {inherited_GC_flag}) ? $taxonData -> {inherited_GC_flag} : "0",
        division_id => ($taxonData -> {division_id}) ? $taxonData -> {division_id} : "0",
        mitochondrial_genetic_code => ($taxonData -> {mitochondrial_genetic_code}) ? $taxonData -> {mitochondrial_genetic_code} : "0",
        inherited_MGC_flag => ($taxonData -> {inherited_MGC_flag}) ? ($taxonData -> {inherited_MGC_flag}) : "0",
        GenBank_hidden_flag => ($taxonData -> {GenBank_hidden_flag}) ? ($taxonData -> {GenBank_hidden_flag}) : "0",
        hidden_subtree_flag => ($taxonData -> {hidden_subtree_flag}) ? ($taxonData -> {hidden_subtree_flag}) : "0",
        comments => $taxonData -> {comments}
    };
    return $current_taxon;
}


#
#internal method, for sending doc data to SOLR 
#
sub _indexInSolr 
{
    my ($self, $solrCore, $docData) = @_;
    if( @{$docData} >= 1) {
       if( $self -> _addXML2Solr($solrCore, $docData) == 1 ) {
           #commit the additions
           if (!$self->_commit($solrCore)) {
               die $self->_error->{response};
           }
       }
       else {
          die $self->{error};
       }
    }
}

#################### End subs for accessing SOLR #######################


sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    #SOLR specific parameters
    if (! $self->{_SOLR_URL}) {
        $self->{_SOLR_URL} = "http://kbase.us/internal/solr-ci/search";
        #$self->{_SOLR_URL} = "http://localhost:8983/solr/#/~cores";
    }
    $self->{_SOLR_POST_URL} = $self->{_SOLR_URL};
    $self->{_SOLR_PING_URL} = "$self->{_SOLR_URL}/select";
    $self->{_AUTOCOMMIT} = 0;
    $self->{_CT_XML} = { Content_Type => 'text/xml; charset=utf-8' };
    $self->{_CT_JSON} = { Content_Type => 'text/json'};
    
    my $config_file = $ENV{ KB_DEPLOYMENT_CONFIG };
    my $cfg = Config::IniFiles->new(-file=>$config_file);
    my $wsInstance = $cfg->val('KBSolrUtil','workspace-url');
    die "no workspace-url defined" unless $wsInstance;
    
    $self->{'workspace-url'} = $wsInstance;
    
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 index_genomes_in_solr

  $output = $obj->index_genomes_in_solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.IndexGenomesInSolrParams
$output is a reference to a list where each element is a KBSolrUtil.SolrGenomeFeatureData
IndexGenomesInSolrParams is a reference to a hash where the following keys are defined:
	genomes has a value which is a reference to a list where each element is a KBSolrUtil.KBaseReferenceGenomeData
	solr_core has a value which is a string
	create_report has a value which is a KBSolrUtil.bool
KBaseReferenceGenomeData is a reference to a hash where the following keys are defined:
	ref has a value which is a string
	id has a value which is a string
	workspace_name has a value which is a string
	source_id has a value which is a string
	accession has a value which is a string
	name has a value which is a string
	version has a value which is a string
	source has a value which is a string
	domain has a value which is a string
bool is an int
SolrGenomeFeatureData is a reference to a hash where the following keys are defined:
	genome_feature_id has a value which is a string
	genome_id has a value which is a string
	feature_id has a value which is a string
	ws_ref has a value which is a string
	feature_type has a value which is a string
	aliases has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	functions has a value which is a string
	genome_source has a value which is a string
	go_ontology_description has a value which is a string
	go_ontology_domain has a value which is a string
	gene_name has a value which is a string
	object_name has a value which is a string
	location_contig has a value which is a string
	location_strand has a value which is a string
	taxonomy has a value which is a string
	workspace_name has a value which is a string
	genetic_code has a value which is a string
	md5 has a value which is a string
	tax_id has a value which is a string
	assembly_ref has a value which is a string
	taxonomy_ref has a value which is a string
	ontology_namespaces has a value which is a string
	ontology_ids has a value which is a string
	ontology_names has a value which is a string
	ontology_lineages has a value which is a string
	dna_sequence_length has a value which is an int
	genome_dna_size has a value which is an int
	location_begin has a value which is an int
	location_end has a value which is an int
	num_cds has a value which is an int
	num_contigs has a value which is an int
	protein_translation_length has a value which is an int
	gc_content has a value which is a float
	complete has a value which is a KBSolrUtil.bool
	refseq_category has a value which is a string
	save_date has a value which is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.IndexGenomesInSolrParams
$output is a reference to a list where each element is a KBSolrUtil.SolrGenomeFeatureData
IndexGenomesInSolrParams is a reference to a hash where the following keys are defined:
	genomes has a value which is a reference to a list where each element is a KBSolrUtil.KBaseReferenceGenomeData
	solr_core has a value which is a string
	create_report has a value which is a KBSolrUtil.bool
KBaseReferenceGenomeData is a reference to a hash where the following keys are defined:
	ref has a value which is a string
	id has a value which is a string
	workspace_name has a value which is a string
	source_id has a value which is a string
	accession has a value which is a string
	name has a value which is a string
	version has a value which is a string
	source has a value which is a string
	domain has a value which is a string
bool is an int
SolrGenomeFeatureData is a reference to a hash where the following keys are defined:
	genome_feature_id has a value which is a string
	genome_id has a value which is a string
	feature_id has a value which is a string
	ws_ref has a value which is a string
	feature_type has a value which is a string
	aliases has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	functions has a value which is a string
	genome_source has a value which is a string
	go_ontology_description has a value which is a string
	go_ontology_domain has a value which is a string
	gene_name has a value which is a string
	object_name has a value which is a string
	location_contig has a value which is a string
	location_strand has a value which is a string
	taxonomy has a value which is a string
	workspace_name has a value which is a string
	genetic_code has a value which is a string
	md5 has a value which is a string
	tax_id has a value which is a string
	assembly_ref has a value which is a string
	taxonomy_ref has a value which is a string
	ontology_namespaces has a value which is a string
	ontology_ids has a value which is a string
	ontology_names has a value which is a string
	ontology_lineages has a value which is a string
	dna_sequence_length has a value which is an int
	genome_dna_size has a value which is an int
	location_begin has a value which is an int
	location_end has a value which is an int
	num_cds has a value which is an int
	num_contigs has a value which is an int
	protein_translation_length has a value which is an int
	gc_content has a value which is a float
	complete has a value which is a KBSolrUtil.bool
	refseq_category has a value which is a string
	save_date has a value which is a string


=end text



=item Description

Index specified genomes in SOLR from KBase workspace

=back

=cut

sub index_genomes_in_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to index_genomes_in_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_genomes_in_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN index_genomes_in_solr
    if (! $self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }    
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        genomes => {},
        create_report => 0,
        solr_core => "GenomeFeatures_ci"
    });  

    my $msg = "";
    my $genomes = $params->{genomes};
    my $solrCore = $params->{solr_core};
    print "\nTotal genomes to be indexed: ". @{$genomes} . "\n";

    $output = $self->_indexGenomeFeatureData($solrCore, $genomes);
    if (@{$output} < 10) {
            my $curr = @{$output}-1;
            $msg .= Data::Dumper->Dump([$output->[$curr]])."\n";
    }    
    #END index_genomes_in_solr
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to index_genomes_in_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_genomes_in_solr');
    }
    return($output);
}




=head2 list_solr_genomes

  $output = $obj->list_solr_genomes($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.ListSolrDocsParams
$output is a reference to a list where each element is a KBSolrUtil.SolrGenomeFeatureData
ListSolrDocsParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	row_start has a value which is an int
	row_count has a value which is an int
	create_report has a value which is a KBSolrUtil.bool
bool is an int
SolrGenomeFeatureData is a reference to a hash where the following keys are defined:
	genome_feature_id has a value which is a string
	genome_id has a value which is a string
	feature_id has a value which is a string
	ws_ref has a value which is a string
	feature_type has a value which is a string
	aliases has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	functions has a value which is a string
	genome_source has a value which is a string
	go_ontology_description has a value which is a string
	go_ontology_domain has a value which is a string
	gene_name has a value which is a string
	object_name has a value which is a string
	location_contig has a value which is a string
	location_strand has a value which is a string
	taxonomy has a value which is a string
	workspace_name has a value which is a string
	genetic_code has a value which is a string
	md5 has a value which is a string
	tax_id has a value which is a string
	assembly_ref has a value which is a string
	taxonomy_ref has a value which is a string
	ontology_namespaces has a value which is a string
	ontology_ids has a value which is a string
	ontology_names has a value which is a string
	ontology_lineages has a value which is a string
	dna_sequence_length has a value which is an int
	genome_dna_size has a value which is an int
	location_begin has a value which is an int
	location_end has a value which is an int
	num_cds has a value which is an int
	num_contigs has a value which is an int
	protein_translation_length has a value which is an int
	gc_content has a value which is a float
	complete has a value which is a KBSolrUtil.bool
	refseq_category has a value which is a string
	save_date has a value which is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.ListSolrDocsParams
$output is a reference to a list where each element is a KBSolrUtil.SolrGenomeFeatureData
ListSolrDocsParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	row_start has a value which is an int
	row_count has a value which is an int
	create_report has a value which is a KBSolrUtil.bool
bool is an int
SolrGenomeFeatureData is a reference to a hash where the following keys are defined:
	genome_feature_id has a value which is a string
	genome_id has a value which is a string
	feature_id has a value which is a string
	ws_ref has a value which is a string
	feature_type has a value which is a string
	aliases has a value which is a string
	scientific_name has a value which is a string
	domain has a value which is a string
	functions has a value which is a string
	genome_source has a value which is a string
	go_ontology_description has a value which is a string
	go_ontology_domain has a value which is a string
	gene_name has a value which is a string
	object_name has a value which is a string
	location_contig has a value which is a string
	location_strand has a value which is a string
	taxonomy has a value which is a string
	workspace_name has a value which is a string
	genetic_code has a value which is a string
	md5 has a value which is a string
	tax_id has a value which is a string
	assembly_ref has a value which is a string
	taxonomy_ref has a value which is a string
	ontology_namespaces has a value which is a string
	ontology_ids has a value which is a string
	ontology_names has a value which is a string
	ontology_lineages has a value which is a string
	dna_sequence_length has a value which is an int
	genome_dna_size has a value which is an int
	location_begin has a value which is an int
	location_end has a value which is an int
	num_cds has a value which is an int
	num_contigs has a value which is an int
	protein_translation_length has a value which is an int
	gc_content has a value which is a float
	complete has a value which is a KBSolrUtil.bool
	refseq_category has a value which is a string
	save_date has a value which is a string


=end text



=item Description

Lists genomes indexed in SOLR

=back

=cut

sub list_solr_genomes
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_solr_genomes:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_solr_genomes');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN list_solr_genomes
    if (! $self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "genomes",
        row_start => 0,
        row_count => 100,
        group_option => "",
        create_report => 0
    });

    $output = [];
    my $msg = "";
    my $solrout;
    my $solrCore = $params -> {solr_core};
    my $fields = "*";
    my $startRow = $params -> {row_start};
    my $topRows = $params -> {row_count};
    my $grpOpt = $params -> {group_option}; #"genome_id";

    eval {
        $solrout = $self->_listGenomesInSolr($solrCore, $fields, $startRow, $topRows, $grpOpt);
    };
    if($@) {
        print "Cannot list genomes in SOLR information!\n";
        print "ERROR:".$@;
        if(defined($@->{status_line})) {
            print $@->{status_line}."\n";
        }
    }
    else {
        #print "\nList of genomes: \n" . Dumper($solrout) . "\n";  
        $output = ($grpOpt eq "") ? $solrout->{response}->{response}->{docs} : $solrout->{response}->{grouped}->{$grpOpt}->{groups};

        if (@{$output} < 10) {
            my $curr = @{$output}-1;
            $msg .= Data::Dumper->Dump([$output->[$curr]])."\n";
        }
    }

    #END list_solr_genomes
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_solr_genomes:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_solr_genomes');
    }
    return($output);
}




=head2 list_solr_taxa

  $output = $obj->list_solr_taxa($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.ListSolrDocsParams
$output is a reference to a list where each element is a KBSolrUtil.SolrTaxonData
ListSolrDocsParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	row_start has a value which is an int
	row_count has a value which is an int
	create_report has a value which is a KBSolrUtil.bool
bool is an int
SolrTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	ws_ref has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.ListSolrDocsParams
$output is a reference to a list where each element is a KBSolrUtil.SolrTaxonData
ListSolrDocsParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	row_start has a value which is an int
	row_count has a value which is an int
	create_report has a value which is a KBSolrUtil.bool
bool is an int
SolrTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	ws_ref has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string


=end text



=item Description

Lists taxa indexed in SOLR

=back

=cut

sub list_solr_taxa
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_solr_taxa:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_solr_taxa');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN list_solr_taxa
    if (! $self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "taxonomy_ci",
        row_start => 0,
        row_count => 100,
        group_option => "",
        create_report => 0
    });

    my $msg = "";
    $output = [];
    my $solrout;
    my $solrCore = $params -> {solr_core};
    my $fields = "*";
    my $startRow = $params -> {row_start};
    my $topRows = $params -> {row_count};
    my $grpOpt = $params -> {group_option}; #"taxonomy_id";    
    eval {
        $solrout = $self->_listTaxaInSolr($solrCore, $fields, $startRow, $topRows, $grpOpt);
    };
    if($@) {
        print "Cannot list taxa in SOLR information!\n";
        print "ERROR:".$@;
        if(defined($@->{status_line})) {
            print $@->{status_line}."\n";
        }
    }
    else {
        #print "\nList of taxa: \n" . Dumper($solrout) . "\n";  
        $output = ($grpOpt eq "") ? $solrout->{response}->{response}->{docs} : $solrout->{response}->{grouped}->{$grpOpt}->{groups}; 

        if (@{$output} < 10) {
            my $curr = @{$output}-1;
            $msg .= Data::Dumper->Dump([$output->[$curr]])."\n";
        } 
    }
    #END list_solr_taxa
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_solr_taxa:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_solr_taxa');
    }
    return($output);
}




=head2 index_taxa_in_solr

  $output = $obj->index_taxa_in_solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.IndexTaxaInSolrParams
$output is a reference to a list where each element is a KBSolrUtil.SolrTaxonData
IndexTaxaInSolrParams is a reference to a hash where the following keys are defined:
	taxa has a value which is a reference to a list where each element is a KBSolrUtil.LoadedReferenceTaxonData
	solr_core has a value which is a string
	create_report has a value which is a KBSolrUtil.bool
LoadedReferenceTaxonData is a reference to a hash where the following keys are defined:
	taxon has a value which is a KBSolrUtil.KBaseReferenceTaxonData
	ws_ref has a value which is a string
KBaseReferenceTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string
bool is an int
SolrTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	ws_ref has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.IndexTaxaInSolrParams
$output is a reference to a list where each element is a KBSolrUtil.SolrTaxonData
IndexTaxaInSolrParams is a reference to a hash where the following keys are defined:
	taxa has a value which is a reference to a list where each element is a KBSolrUtil.LoadedReferenceTaxonData
	solr_core has a value which is a string
	create_report has a value which is a KBSolrUtil.bool
LoadedReferenceTaxonData is a reference to a hash where the following keys are defined:
	taxon has a value which is a KBSolrUtil.KBaseReferenceTaxonData
	ws_ref has a value which is a string
KBaseReferenceTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string
bool is an int
SolrTaxonData is a reference to a hash where the following keys are defined:
	taxonomy_id has a value which is an int
	scientific_name has a value which is a string
	scientific_lineage has a value which is a string
	rank has a value which is a string
	kingdom has a value which is a string
	domain has a value which is a string
	ws_ref has a value which is a string
	aliases has a value which is a reference to a list where each element is a string
	genetic_code has a value which is an int
	parent_taxon_ref has a value which is a string
	embl_code has a value which is a string
	inherited_div_flag has a value which is an int
	inherited_GC_flag has a value which is an int
	mitochondrial_genetic_code has a value which is an int
	inherited_MGC_flag has a value which is an int
	GenBank_hidden_flag has a value which is an int
	hidden_subtree_flag has a value which is an int
	division_id has a value which is an int
	comments has a value which is a string


=end text



=item Description

Index specified genomes in SOLR from KBase workspace

=back

=cut

sub index_taxa_in_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to index_taxa_in_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_taxa_in_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN index_taxa_in_solr

   f (! $self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        taxa => {},
        create_report => 0,
        solr_core => undef
    });

    my $msg = "";
    $output = [];
    my $taxa = $params->{taxa};
    my $solrCore = $params->{solr_core};
    my $solrBatch = [];
    my $solrBatchCount = 10000;
    print "\nTotal taxa to be indexed: ". @{$taxa} . "\n";

    for (my $i = 0; $i < @{$taxa}; $i++) {
        my $taxonData = $taxa -> [$i] -> {taxon};#an UnspecifiedObject
        my $wref = $taxa -> [$i] -> {ws_ref};
        my $current_taxon = $self -> _getTaxon($taxonData, $wref);

        push(@{$solrBatch}, $current_taxon);
        if(@{$solrBatch} >= $solrBatchCount) {
            eval {
                $self -> _indexInSolr($solrCore, $solrBatch );
            };
            if($@) {
                print "Failed to index the taxa!\n";
                print "ERROR:". Dumper( $@ );
                if(defined($@->{status_line})) {
                    print $@->{status_line}."\n";
                }
            }
            else {
                print "\nIndexed ". @{$solrBatch} . " taxa.\n";
                $solrBatch = [];
            }
        }

        push(@{$output}, $current_taxon);
        if (@{$output} < 10) {
            my $curr = @{$output}-1;
            $msg .= Data::Dumper->Dump([$output->[$curr]])."\n";
        }
    }
    if(@{$solrBatch} > 0) {
            eval {
                $self -> _indexInSolr($solrCore, $solrBatch );
            };
            if($@) {
                print "Failed to index the taxa!\n";
                print "ERROR:".$@;
                if(defined($@->{status_line})) {
                    print $@->{status_line}."\n";
                }
            }
            else {
                print "\nIndexed ". @{$solrBatch} . " taxa.\n";
            }
    }
    if ($params->{create_report}) {
        print "Indexed ". scalar @{$output}. " taxa!\n";
        $self->util_create_report({
            message => "Indexed ".@{$output}." taxa!",
            workspace => undef
        });
        $output = ["indexed taxa"];
    }
    #END index_taxa_in_solr
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to index_taxa_in_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_taxa_in_solr');
    }
    return($output);
}




=head2 status 

  $return = $obj->status()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module status. This is a structure including Semantic Versioning number, state and git info.

=back

=cut

sub status {
    my($return);
    #BEGIN_STATUS
    $return = {"state" => "OK", "message" => "", "version" => $VERSION,
               "git_url" => $GIT_URL, "git_commit_hash" => $GIT_COMMIT_HASH};
    #END_STATUS
    return($return);
}

=head1 TYPES



=head2 bool

=over 4



=item Description

A boolean.


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 SolrGenomeFeatureData

=over 4



=item Description

Struct containing data for a single genome element output by the list_solr_genomes and index_genomes_in_solr functions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome_feature_id has a value which is a string
genome_id has a value which is a string
feature_id has a value which is a string
ws_ref has a value which is a string
feature_type has a value which is a string
aliases has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
functions has a value which is a string
genome_source has a value which is a string
go_ontology_description has a value which is a string
go_ontology_domain has a value which is a string
gene_name has a value which is a string
object_name has a value which is a string
location_contig has a value which is a string
location_strand has a value which is a string
taxonomy has a value which is a string
workspace_name has a value which is a string
genetic_code has a value which is a string
md5 has a value which is a string
tax_id has a value which is a string
assembly_ref has a value which is a string
taxonomy_ref has a value which is a string
ontology_namespaces has a value which is a string
ontology_ids has a value which is a string
ontology_names has a value which is a string
ontology_lineages has a value which is a string
dna_sequence_length has a value which is an int
genome_dna_size has a value which is an int
location_begin has a value which is an int
location_end has a value which is an int
num_cds has a value which is an int
num_contigs has a value which is an int
protein_translation_length has a value which is an int
gc_content has a value which is a float
complete has a value which is a KBSolrUtil.bool
refseq_category has a value which is a string
save_date has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome_feature_id has a value which is a string
genome_id has a value which is a string
feature_id has a value which is a string
ws_ref has a value which is a string
feature_type has a value which is a string
aliases has a value which is a string
scientific_name has a value which is a string
domain has a value which is a string
functions has a value which is a string
genome_source has a value which is a string
go_ontology_description has a value which is a string
go_ontology_domain has a value which is a string
gene_name has a value which is a string
object_name has a value which is a string
location_contig has a value which is a string
location_strand has a value which is a string
taxonomy has a value which is a string
workspace_name has a value which is a string
genetic_code has a value which is a string
md5 has a value which is a string
tax_id has a value which is a string
assembly_ref has a value which is a string
taxonomy_ref has a value which is a string
ontology_namespaces has a value which is a string
ontology_ids has a value which is a string
ontology_names has a value which is a string
ontology_lineages has a value which is a string
dna_sequence_length has a value which is an int
genome_dna_size has a value which is an int
location_begin has a value which is an int
location_end has a value which is an int
num_cds has a value which is an int
num_contigs has a value which is an int
protein_translation_length has a value which is an int
gc_content has a value which is a float
complete has a value which is a KBSolrUtil.bool
refseq_category has a value which is a string
save_date has a value which is a string


=end text

=back



=head2 KBaseReferenceGenomeData

=over 4



=item Description

Structure of a single KBase genome in the input list of genomes of the index_genomes_in_solr function.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ref has a value which is a string
id has a value which is a string
workspace_name has a value which is a string
source_id has a value which is a string
accession has a value which is a string
name has a value which is a string
version has a value which is a string
source has a value which is a string
domain has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ref has a value which is a string
id has a value which is a string
workspace_name has a value which is a string
source_id has a value which is a string
accession has a value which is a string
name has a value which is a string
version has a value which is a string
source has a value which is a string
domain has a value which is a string


=end text

=back



=head2 IndexGenomesInSolrParams

=over 4



=item Description

Arguments for the index_genomes_in_solr function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genomes has a value which is a reference to a list where each element is a KBSolrUtil.KBaseReferenceGenomeData
solr_core has a value which is a string
create_report has a value which is a KBSolrUtil.bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genomes has a value which is a reference to a list where each element is a KBSolrUtil.KBaseReferenceGenomeData
solr_core has a value which is a string
create_report has a value which is a KBSolrUtil.bool


=end text

=back



=head2 ListSolrDocsParams

=over 4



=item Description

Arguments for the list_solr_genomes and list_solr_taxa functions


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
solr_core has a value which is a string
row_start has a value which is an int
row_count has a value which is an int
create_report has a value which is a KBSolrUtil.bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
solr_core has a value which is a string
row_start has a value which is an int
row_count has a value which is an int
create_report has a value which is a KBSolrUtil.bool


=end text

=back



=head2 SolrTaxonData

=over 4



=item Description

Struct containing data for a single taxon element output by the list_solr_taxa function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
taxonomy_id has a value which is an int
scientific_name has a value which is a string
scientific_lineage has a value which is a string
rank has a value which is a string
kingdom has a value which is a string
domain has a value which is a string
ws_ref has a value which is a string
aliases has a value which is a reference to a list where each element is a string
genetic_code has a value which is an int
parent_taxon_ref has a value which is a string
embl_code has a value which is a string
inherited_div_flag has a value which is an int
inherited_GC_flag has a value which is an int
mitochondrial_genetic_code has a value which is an int
inherited_MGC_flag has a value which is an int
GenBank_hidden_flag has a value which is an int
hidden_subtree_flag has a value which is an int
division_id has a value which is an int
comments has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
taxonomy_id has a value which is an int
scientific_name has a value which is a string
scientific_lineage has a value which is a string
rank has a value which is a string
kingdom has a value which is a string
domain has a value which is a string
ws_ref has a value which is a string
aliases has a value which is a reference to a list where each element is a string
genetic_code has a value which is an int
parent_taxon_ref has a value which is a string
embl_code has a value which is a string
inherited_div_flag has a value which is an int
inherited_GC_flag has a value which is an int
mitochondrial_genetic_code has a value which is an int
inherited_MGC_flag has a value which is an int
GenBank_hidden_flag has a value which is an int
hidden_subtree_flag has a value which is an int
division_id has a value which is an int
comments has a value which is a string


=end text

=back



=head2 KBaseReferenceTaxonData

=over 4



=item Description

Struct containing data for a single taxon element output by the list_loaded_taxa function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
taxonomy_id has a value which is an int
scientific_name has a value which is a string
scientific_lineage has a value which is a string
rank has a value which is a string
kingdom has a value which is a string
domain has a value which is a string
aliases has a value which is a reference to a list where each element is a string
genetic_code has a value which is an int
parent_taxon_ref has a value which is a string
embl_code has a value which is a string
inherited_div_flag has a value which is an int
inherited_GC_flag has a value which is an int
mitochondrial_genetic_code has a value which is an int
inherited_MGC_flag has a value which is an int
GenBank_hidden_flag has a value which is an int
hidden_subtree_flag has a value which is an int
division_id has a value which is an int
comments has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
taxonomy_id has a value which is an int
scientific_name has a value which is a string
scientific_lineage has a value which is a string
rank has a value which is a string
kingdom has a value which is a string
domain has a value which is a string
aliases has a value which is a reference to a list where each element is a string
genetic_code has a value which is an int
parent_taxon_ref has a value which is a string
embl_code has a value which is a string
inherited_div_flag has a value which is an int
inherited_GC_flag has a value which is an int
mitochondrial_genetic_code has a value which is an int
inherited_MGC_flag has a value which is an int
GenBank_hidden_flag has a value which is an int
hidden_subtree_flag has a value which is an int
division_id has a value which is an int
comments has a value which is a string


=end text

=back



=head2 LoadedReferenceTaxonData

=over 4



=item Description

Struct containing data for a single output by the list_loaded_taxa function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
taxon has a value which is a KBSolrUtil.KBaseReferenceTaxonData
ws_ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
taxon has a value which is a KBSolrUtil.KBaseReferenceTaxonData
ws_ref has a value which is a string


=end text

=back



=head2 IndexTaxaInSolrParams

=over 4



=item Description

Arguments for the index_taxa_in_solr function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
taxa has a value which is a reference to a list where each element is a KBSolrUtil.LoadedReferenceTaxonData
solr_core has a value which is a string
create_report has a value which is a KBSolrUtil.bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
taxa has a value which is a reference to a list where each element is a KBSolrUtil.LoadedReferenceTaxonData
solr_core has a value which is a string
create_report has a value which is a KBSolrUtil.bool


=end text

=back



=cut

1;
