package KBSolrUtil::KBSolrUtilImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = '0.0.1';
our $GIT_URL = 'https://github.com/qzzhang/KBSolrUtil.git';
our $GIT_COMMIT_HASH = 'd0036c7d07a4de8ee4025cfdafd9b56f521bdc4f';

=head1 NAME

KBSolrUtil

=head1 DESCRIPTION

A KBase module: KBSolrUtil
This module contains the utility methods and configuration details to access the KBase SOLR cores.

=cut

#BEGIN_HEADER
use Bio::KBase::AuthToken;
use Workspace::WorkspaceClient;
#use Bio::KBase::Workspace::Client;
use Config::IniFiles;
use Config::Simple;
use POSIX;
use FindBin qw($Bin);
use JSON;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;
use XML::Simple;
use Try::Tiny;

#The first thing every function should do is call this function
sub util_initialize_call {
    my ($self,$params,$ctx) = @_;
    $self->{_token} = $ctx->token();
    $self->{_username} = $ctx->user_id();
    $self->{_method} = $ctx->method();
    $self->{_provenance} = $ctx->provenance();

    my $config_file = $ENV{ KB_DEPLOYMENT_CONFIG };
    my $cfg = Config::IniFiles->new(-file=>$config_file);
    $self->{data} = $cfg->val('KBSolrUtil','data');
    $self->{scratch} = $cfg->val('KBSolrUtil','scratch');
    $self->{workspace_url} = $cfg->val('KBSolrUtil','workspace-url');
    die "no workspace-url defined" unless $self->{workspace_url};

    $self->util_timestamp(DateTime->now()->datetime());
    $self->{_wsclient} = new Workspace::WorkspaceClient($self->{workspace_url},token => $ctx->token());
    return $params;
}

#This function validates the arguments to a method making sure mandatory arguments are present and optional arguments are set
sub util_args {
    my($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
    if (!defined($args)) {
        $args = {};
    }
    if (ref($args) ne "HASH") {
        die "Arguments not hash";
    }
    if (defined($substitutions) && ref($substitutions) eq "HASH") {
        foreach my $original (keys(%{$substitutions})) {
            $args->{$original} = $args->{$substitutions->{$original}};
        }
    }
    if (defined($mandatoryArguments)) {
        for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
            if (!defined($args->{$mandatoryArguments->[$i]})) {
                push(@{$args->{_error}},$mandatoryArguments->[$i]);
            }
        }
    }
    if (defined($args->{_error})) {
        die "Mandatory arguments ".join("; ",@{$args->{_error}})." missing";
    }
    foreach my $argument (keys(%{$optionalArguments})) {
        if (!defined($args->{$argument})) {
            $args->{$argument} = $optionalArguments->{$argument};
        }
    }
    return $args;
}


#This function returns a timestamp recorded when the functionw was first started
sub util_timestamp {
    my ($self,$input) = @_;
    if (defined($input)) {
        $self->{_timestamp} = $input;
    }
    return $self->{_timestamp};
}

#################### methods for accesssng SOLR using its web interface#######################
#
# method name: _buildQueryString
# Internal Method: to build the query string for SOLR according to the passed parameters
# parameters:
# $searchQuery is a hash which specifies how the documents will be searched, see the example below:
# $searchQuery={
#   parent_taxon_ref => '1779/116411/1',
#   rank => 'species',
#   scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
#   scientific_name => 'Bradyrhizobium sp. *',
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
# NOTE: Because the stupid SOLR 4.* handles the wildcard search string in a weird way:when the '*' is at either end of the search string, it returns 0 docs.
# if the search string is within double quotes. On the other hand, when a search string has whitespace(s), it has to be inside
# double quotes otherwise SOLR will treat it as new field(s).
# So this method builds the search string in such a way, WITHOUT the double quotes ONLY for the use cases when '*' will be at the ends of the value string
# and, if there is any space in the middle of the string, it replaces the spaces with '*'; for cases when no '*' at the ends of the value string, it adds
# double quotes to enclose the whole value string (including spaces).
#
sub _buildQueryString {
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
    my $val;
    if (defined $searchQuery->{q}) {
        $qStr .= URI::Escape::uri_escape($searchQuery->{q});
    } else {
        foreach my $key (keys %$searchQuery) {
            $val = $searchQuery->{$key};
            if( $val =~ m/^\*.*|^\*.*\*$|.*\*$/ ) {
                $val =~ s/\s+/\*/g;
                if (defined $skipEscape->{$key}) {
                   $qStr .= "+$key:" . $val ." $DEFAULT_FIELD_CONNECTOR ";
                } else {
                   $qStr .= "+$key:" . URI::Escape::uri_escape($val) . " $DEFAULT_FIELD_CONNECTOR ";  
                }
            }
            else {
                #$val = "\"" + $val + "\"";
                if (defined $skipEscape->{$key}) {
                  $qStr .= "+$key:\"" . $val ."\" $DEFAULT_FIELD_CONNECTOR ";
                } else {
                  $qStr .= "+$key:\"" . URI::Escape::uri_escape($val) . "\" $DEFAULT_FIELD_CONNECTOR ";  
                }
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
print $url;
    my $out = {};

    # create a HTTP request
    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new;
    $request->method($method);
    $request->uri($url);

    # set headers
    foreach my $header (keys %$headers) {
        $request->header($header=>$headers->{$header});
    }

    # set data for posting
    $request->content($data);
    print "The HTTP request: \n" . Dumper($request) . "\n";
    
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
# internal method: _toJSON, converts a given array of references to an array of JSON documents
# input format:
# A list/an array that consists references to an object maps, 
=for example:
    $params = 
[      {
        "taxonomy_id"=>1297193,
        "domain"=>"Eukaryota",
        "genetic_code"=>1,
        "embl_code"=>"CS",
        "division_id"=>1,
        "inherited_div_flag"=>1,
        "inherited_MGC_flag"=>1,
        "parent_taxon_ref"=>"12570/1217907/1",
        "scientific_name"=>"Camponotus sp. MAS010",
        "mitochondrial_genetic_code"=>5,
        "hidden_subtree_flag"=>0,
        "scientific_lineage"=>"cellular organisms; Eukaryota; Opisthokonta; Metazoa; Eumetazoa; Bilateria; Protostomia; Ecdysozoa; Panarthropoda; Arthropoda; Mandibulata; Pancrustacea; Hexapoda; Insecta; Dicondylia; Pterygota; Neoptera; Endopterygota; Hymenoptera; Apocrita; Aculeata; Vespoidea; Formicidae; Formicinae; Camponotini; Camponotus",
        "rank"=>"species",
        "ws_ref"=>"12570/1253105/1",
        "kingdom"=>"Metazoa",
        "GenBank_hidden_flag"=>1,
        "inherited_GC_flag"=>1,"
        _version_"=>1558736913013145600,
        "deleted"=>0
      },
      {
        "inherited_MGC_flag"=>1,
        "inherited_div_flag"=>1,
        "parent_taxon_ref"=>"12570/1217907/1",
        "genetic_code"=>1,
        "division_id"=>1,
        "embl_code"=>"CS",
        "domain"=>"Eukaryota",
        "taxonomy_id"=>1297190,
        "kingdom"=>"Metazoa",
        "GenBank_hidden_flag"=>1,
        "inherited_GC_flag"=>1,
        "ws_ref"=>"12570/1253106/1",
        "scientific_lineage"=>"cellular organisms; Eukaryota; Opisthokonta; Metazoa; Eumetazoa; Bilateria; Protostomia; Ecdysozoa; Panarthropoda; Arthropoda; Mandibulata; Pancrustacea; Hexapoda; Insecta; Dicondylia; Pterygota; Neoptera; Endopterygota; Hymenoptera; Apocrita; Aculeata; Vespoidea; Formicidae; Formicinae; Camponotini; Camponotus",
        "rank"=>"species",
        "scientific_name"=>"Camponotus sp. MAS003",
        "hidden_subtree_flag"=>0,
        "mitochondrial_genetic_code"=>5,
        "deleted"=>0
      },
...
   ];
=cut end of example
#
# output format:
# A list/an array of documents in JSON format:
=for example:
     $json_out = [
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
        _version_":1558736913013145600,
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
  ] 
=cut end of example
#
sub _toJSON
{
    my ($self, $params) = @_;
    my $json = new JSON;
    my $json_docs = [];
    for (my $i=0; $i < @{ $params }; $i++) {
        push(@{$json_docs}, $json->pretty->encode($params->[$i]));
    }
    return $json_docs; 
}

#
# method name: _addJSON2Solr
# Internal method: to add JSON documents to solr for indexing.
# Depending on the flag AUTOCOMMIT the documents will be indexed immediatly or on commit is issued.
# parameters:   
#     $params: This parameter specifies list of document fields and values.
# return
#    1 for successful posting of the xml document
#    0 for any failure
#
#
sub _addJSON2Solr
{
    my ($self, $solrCore, $params) = @_;
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }

    my $docs = $self->_toJSON($params);
    #print Dumper($docs);
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    my $url = "$self->{_SOLR_URL}/$solrCore/update/json/docs";

    foreach my $doc (@{$docs})  { 
        my $response = $self->_sendRequest($url, 'POST', 'binary', $self->{_CT_JSON}, $doc);
        if (!$self->_parseResponse($response)) {
            $self->{error} = $response;
            $self->{error}->{errmsg} = $@;
            print "\nSolr indexing error:\n" . $self->_error->{response}; 
            print "\n" . Dumper($response);
            return 0;
        }
     }
     return 1;
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
    if (!$rootnode) {
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
    #$self->{_CT_JSON} = { Content_Type => 'text/json'};
    $self->{_CT_JSON} = { Content_Type => 'application/json'};

    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 index_in_solr

  $output = $obj->index_in_solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.IndexInSolrParams
$output is an int
IndexInSolrParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata
docdata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.IndexInSolrParams
$output is an int
IndexInSolrParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata
docdata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

The index_in_solr function that returns 1 if succeeded otherwise 0

=back

=cut

sub index_in_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to index_in_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_in_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN index_in_solr
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "GenomeFeatures_ci",
        doc_data => []
    });  
 
    my $docData = $params->{doc_data};
    my $solrCore = $params->{solr_core};

    if( @{$docData} >= 1) {
       if( $self->_addXML2Solr($solrCore, $docData) == 1 ) {
           #commit the additions
           if (!$self->_commit($solrCore)) {
               die $self->_error->{response};
               $output= 0;
           }
       }
       else {
          die $self->{error};
          $output = 0;
       }
       $output = 1;
    }
    #END index_in_solr
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to index_in_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'index_in_solr');
    }
    return($output);
}




=head2 search_solr

  $output = $obj->search_solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.SearchSolrParams
$output is a KBSolrUtil.solrresponse
SearchSolrParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_param has a value which is a KBSolrUtil.searchdata
	search_query has a value which is a KBSolrUtil.searchdata
	result_format has a value which is a string
	group_option has a value which is a string
searchdata is a reference to a hash where the key is a string and the value is a string
solrresponse is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.SearchSolrParams
$output is a KBSolrUtil.solrresponse
SearchSolrParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_param has a value which is a KBSolrUtil.searchdata
	search_query has a value which is a KBSolrUtil.searchdata
	result_format has a value which is a string
	group_option has a value which is a string
searchdata is a reference to a hash where the key is a string and the value is a string
solrresponse is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

The search_solr function that returns a solrresponse consisting of a string in the format of the specified 'result_format' in SearchSolrParams

=back

=cut

sub search_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to search_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN search_solr
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "GenomeFeatures_ci",
        search_param => {},
        search_query => {q=>"*"},
        result_format => "xml",
        group_option => "",
        skip_escape => {}
    });  
    my $solrCore = $params->{ solr_core }; 
    my $searchParam = $params->{ search_param };
    my $searchQuery = $params->{ search_query };
    my $resultFormat = $params->{ result_format };
    my $groupOption = $params->{ group_option };
    my $skipEscape = $params->{ skip_escape };
    my $resultFormat = $params->{ result_format };
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
    
    my $queryString = $self->_buildQueryString($searchQuery, $searchParam, $groupOption, $skipEscape);
    #my $sort = "&sort=genome_id asc";
    my $solrQuery = $self->{_SOLR_URL}."/".$solrCore."/select?".$queryString;
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
    $output = $solr_response;

    #END search_solr
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to search_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_solr');
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

a bool defined as int


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



=head2 searchdata

=over 4



=item Description

User provided parameter data.
Arbitrary key-value pairs provided by the user.


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 docdata

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 solrresponse

=over 4



=item Description

Solr response data for search requests.
Arbitrary key-value pairs returned by the solr.


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 IndexInSolrParams

=over 4



=item Description

Arguments for the index_in_solr function - send doc data to solr for indexing

string search_core - the name of the solr core to index to
list<docdata> doc_data - the doc to be indexed, a list of hashes


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
search_core has a value which is a string
doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
search_core has a value which is a string
doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata


=end text

=back



=head2 SearchSolrParams

=over 4



=item Description

Arguments for the search_solr function - search solr according to the parameters passed and return a string

string search_core - the name of the solr core to be searched
searchdata search_param - arbitrary user-supplied key-value pairs defining how the search should be conducted, 
        a hash, see the example below:
        search_param={
                fl => 'object_id,gene_name,genome_source',
                wt => 'json',
                rows => 20,
                sort => 'object_id asc',
                hl => 'false',
                start => 0,
                count => 100
        }

searchdata search_query - arbitrary user-supplied key-value pairs defining the fields to be searched and their values 
                        to be matched, a hash which specifies how the documents will be searched, see the example below:
        search_query={
                parent_taxon_ref => '1779/116411/1',
                rank => 'species',
                scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
                scientific_name => 'Bradyrhizobium sp. rp3',
                domain => 'Bacteria'
        }
OR, simply:
        search_query= { q => "*" };

string result_format - the format of the search result, 'xml' as the default, can be 'json', 'csv', etc.
string group_option - the name of the field to be grouped for the result


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_param has a value which is a KBSolrUtil.searchdata
search_query has a value which is a KBSolrUtil.searchdata
result_format has a value which is a string
group_option has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_param has a value which is a KBSolrUtil.searchdata
search_query has a value which is a KBSolrUtil.searchdata
result_format has a value which is a string
group_option has a value which is a string


=end text

=back



=cut

1;