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
use Bio::KBase::Workspace::Client;
use Config::IniFiles;
use Config::Simple;
use POSIX;
use FindBin qw($Bin);
use JSON;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;
use XML::Simple;
use Try::Tiny;


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
    $solrCore = ($solrCore) ? $solrCore : "taxonomy_prod";
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

#
# method name: _searchSolr
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
        #print "\nFound unique $groupOption groups of:" . scalar @solr_records . "\n";
        #print @solr_records[0]->{doclist}->{numFound} ."\n";
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
            #print "\nFound unique $groupOption groups of:" . scalar @solr_records . "with recourds of: ";
            #print @solr_records[0]->{doclist}->{numFound} ."\n";
        }
    }
    
    return $solr_response;
}

#
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

#END_HEADER

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
    }
    $self->{_SOLR_POST_URL} = $self->{_SOLR_URL};
    $self->{_SOLR_PING_URL} = "$self->{_SOLR_URL}/select";
    $self->{_AUTOCOMMIT} = 0;
    $self->{_CT_XML} = { Content_Type => 'text/xml; charset=utf-8' };
    $self->{_CT_JSON} = { Content_Type => 'text/json'};

    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
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
1;
