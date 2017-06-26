package KBSolrUtil::KBSolrUtilImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = '0.0.2';
our $GIT_URL = 'https://github.com/qzzhang/KBSolrUtil.git';
our $GIT_COMMIT_HASH = '1016fadfaf48ddfdcc4d33bad6d6b9ae39d8adeb';

=head1 NAME

KBSolrUtil

=head1 DESCRIPTION

A KBase module: KBSolrUtil
This module contains the utility methods and configuration details to access the KBase SOLR cores.

=cut

#BEGIN_HEADER
use Bio::KBase::AuthToken;
use Workspace::WorkspaceClient;
use Bio::KBase::HandleService;
#use Bio::KBase::Workspace::Client;
use Config::IniFiles;
use Config::Simple;
use POSIX;
use FindBin qw($Bin);
use JSON;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;
use XML::Simple;
use XML::LibXML;
use Try::Tiny;
use DateTime;

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
    $self->{'workspace-url'} = $cfg->val('KBSolrUtil','workspace-url');
    die "no workspace-url defined" unless $self->{'workspace-url'};
    $self->{'shock-url'} = $cfg->val('KBSolrUtil','shock-url');
    die "no shock-url defined" unless $self->{'shock-url'};
    $self->{'handle-service-url'} = $cfg->val('KBSolrUtil','handle-service-url');
    die "no handle-service-url defined" unless $self->{'handle-service-url'};
    $self->util_timestamp(DateTime->now()->datetime());
    $self->{_wsclient} = new Workspace::WorkspaceClient($self->{'workspace-url'},token => $ctx->token());
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
#   rows => 20,
#   sort => 'object_id asc',
#   hl => 'false',
#   start => $start
#}
#
# NOTE: Because the stupid SOLR 4.* handles the wildcard search string in a weird way:when the '*' is at either end of the search string, it returns 0 docs.
# if the search string is within double quotes. On the other hand, when a search string has whitespace(s), it has to be inside
# double quotes otherwise SOLR will treat it as new field(s).
# So this method builds the search string in such a way, WITHOUT the double quotes ONLY for the use cases when '*' will be at the ends of the value string
# and, if there is any space in the middle of the string, it replaces the spaces with '*'; for cases when no '*' at the ends of the value string, it adds
# double quotes to enclose the whole value string (including spaces).
#
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
# $resultFormat is a string indicating what format you want SOLR to return the search results, json, csv, xml, etc.  It overrides the value for 'wt' set in the $searchParams
#
# returns a string
#
sub _buildQueryString {
    my ($self, $searchQuery, $searchParams, $groupOption, $resultFormat, $skipEscape) = @_;
    $skipEscape = {} unless $skipEscape;
    $resultFormat = "xml" unless $resultFormat;
    
    my $DEFAULT_FIELD_CONNECTOR = "AND";

    if (!$searchQuery) {
        $self->{is_error} = 1;
        $self->{errmsg} = "Query parameters not specified";
        return undef;
    }

    if (ref($searchQuery) ne "HASH") {#convert the json string to HASH first
        $searchQuery = JSON::from_json($searchQuery);
    } 
    if ($searchParams && (ref($searchParams) ne "HASH")) {#convert the json string to HASH first
        $searchParams = JSON::from_json($searchParams);
    } 
    # Build the display parameter part                                             
    my $paramFields = "";
    if( $resultFormat ne "xml" ) {
        $paramFields .= "wt=". URI::Escape::uri_escape($resultFormat) . "&";
    }
    foreach my $key (keys %$searchParams) {
        if( $key eq "wt" ) {
            #do nothing, wt is set according to the value of $resultFormat and default to 'xml'
        }
        else {
           $paramFields .= "$key=". URI::Escape::uri_escape($searchParams->{$key}) . "&";
        }
    }
    
    # Build the solr query part
    my $qStr = "q=";
    my $val;
    if (defined $searchQuery->{q}) {
        $qStr .= URI::Escape::uri_escape($searchQuery->{q});
    } else {
        foreach my $key (keys %$searchQuery) {
            $val = $searchQuery->{$key};
            if( $val =~ m/^\*.*|^\*.*\*$|.*\*$|.*\*.*/ ) {#when there is '*' at the ends or middle of the search value
                $val =~ s/\s+/\*/g;#replace the spaces with '*' otherwise without the double quote, spaces will be problematic
                $val =~ s/\.//g;#remove the periods because SOLR does not handle periods with '*' well
                if (defined $skipEscape->{$key}) {
                   $qStr .= "+$key:" . $val ." $DEFAULT_FIELD_CONNECTOR ";
                } else {
                   $qStr .= "+$key:" . URI::Escape::uri_escape($val) . " $DEFAULT_FIELD_CONNECTOR ";  
                }
            }
            else {
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
    my $solrGroup = $groupOption ? "&group=true&group.ngroups=true&group.field=$groupOption" : "";
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
    #print "\nThe HTTP request: \n" . Dumper($request) . "\n";
    
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
                if ($xmlRef->{lst}->{'int'}->{status}->{content} == 0){
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
# internal method: _toJSON, converts a given array of references (Perl scalars) to an array of JSON documents
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
    my ($self, $inputData) = @_;
    my $json_docs = [];
    $json_docs = JSON->new->encode($inputData); 
    return $json_docs; 
}

#
# method name: _addJSON2Solr
# Internal method: to add JSON documents to solr for indexing.
# Depending on the flag AUTOCOMMIT the documents will be indexed immediatly or on commit is issued.
# parameters:   
#     $inputObjs: This parameter specifies list of document fields and values.
#     $jsonString: true (1) if $inputObjs is passed as a json string in quotes; default to false (0).
# return
#    1 for successful posting of the xml document
#    0 for any failure
#
#
sub _addJSON2Solr
{
    my ($self, $solrCore, $inputObjs, $jsonString) = @_;
#=begin    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }
#=cut

    $jsonString = 0 unless $jsonString;
    my $docs;
    if ($jsonString == 1) {
        $docs = $inputObjs;
    }
    else {
        $docs = $self->_toJSON($inputObjs);
        #print "\nConverted Perl scalars to json:\n " . Dumper($docs);
    }
    
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    my $url = "$self->{_SOLR_URL}/$solrCore/update/json?commit=true";# . $commit; 
#=begin
    my $response = $self->_sendRequest($url, 'POST', 'binary', $self->{_CT_JSON}, $docs);

    if ($self->_parseResponse($response) == 0) {
            $self->{error} = $response;
            $self->{error}->{errmsg} = $@;
            print "\nSolr indexing error:\n" . $self->_error->{response}; 
            print "\n" . Dumper($response);
            return 0;
    }
#=cut
    if (!$self->_commit($solrCore)) {
        die $self->_error->{response};
        return 0;
    }
    else {
        return 1;
    }
}

#
# method name: _addXML2Solr
# Internal method: to add XML documents to solr for indexing.
# First it will convert the raw datastructure to required ds then it will convert
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
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    my $url = "$self->{_SOLR_URL}/$solrCore/update?commit=true";# . $commit;
    my $response = $self->_sendRequest($url, 'POST', undef, $self->{_CT_XML}, $doc);
    
    if ($self->_parseResponse($response) == 0) {
            $self->{error} = $response;
            $self->{error}->{errmsg} = $@;
            print "\nSolr indexing error:\n" . $self->_error->{response}; 
            #print "\n" . Dumper($response);
            return 0;
    }
    return 1;
}

#
# method name: _toXML
# Internal Method
# This function will convert the datastructe to an XML document for XML Formatted Solr indexing.
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
# $solrCore is a string that represents the name of the SOLR core
#
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
    #print "Exists checking query:" . $queryString;
    my $response = $self->_sendRequest($url, 'GET');
    my $status = $self->_parseResponse($response);
    if ($status == 1) {
        my $xs = new XML::Simple();
        my $xmlRef;
        eval {
            $xmlRef = $xs->XMLin($response->{response});
        };
        #print "\n$url result:\n" . Dumper($xmlRef->{result}) . "\n";
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
# Internal Method: to check if a given genome has been indexed by KBase in SOLR.  Returns a string stating the status
#
# Input parameters :
# $current_genome is a genome object whose KBase status is to be checked.
# $solr_core is the name of the SOLR core
#
# returns : a string stating the status
#    
sub _checkTaxonStatus
{
    my ($self, $current_genome, $solr_core) = @_;
    #print "\nChecking taxon status for genome:\n " . Dumper($current_genome) . "\n";
    
    my $status = "";
    my $query = { taxonomy_id => $current_genome->{tax_id} };
    
    if($self->exists_in_solr({search_core=>$solr_core,search_query=>$query})==1) {
        $status = "Taxon in KBase";
    }    
    else {
        $status = "Taxon not found";
    }
    #print "\nStatus:$status\n";
    return $status;
}


#
# Internal Method 
# Name: _checkEntryStatus
# Purpose: to check for a given genome's status against genomes in SOLR.  
#
# Input parameters :
#       $current_entry is a genome object whose KBase status is to be checked.
#       $solr_core is the name of the SOLR core
#
# returns : a string stating the status
#    
sub _checkEntryStatus 
{
    my ($self, $current_entry, $solr_core, $en_type) = @_;
    #print "\nChecking status for genome:\n " . Dumper($current_entry) . "\n";
    $en_type = "KBaseGenomes.Genome-8.2" unless $en_type;

    my $status = "";
    my $query = { 
        genome_id => $current_entry->{id} . "*", 
        object_type => $en_type
    };
    my $params = {
        fl => "genome_id",
        wt => "json",
        start => 0
    };
    
    my $solrgnm;
    my $gnms;
    my $gcnt;
    eval {
        $solrgnm = $self->search_solr({
          search_core => $solr_core,
          search_param => $params,
          search_query => $query,
          result_format => "json",
          group_option => "",
          skip_escape => {}
        });  
    };   
    if ($@) {
         print "ERROR:".$@;
         $status = "";
    } else {
        #print "Search results:" . Dumper($solrgnm->{response}) . "\n";
        $gnms = $solrgnm->{response}->{response}->{docs};
        $gcnt = $solrgnm->{response}->{response}->{numFound};
    }
    if( $gcnt == 0 ) {
        $status = "New entry";
    }
    else {
        for (my $i = 0; $i < @{$gnms}; $i++ ) {
            my $record = $gnms->[$i];
            my $gm_id = uc $record->{genome_id};

            if ($gm_id eq uc $current_entry->{accession}){
                $status = "Existing entry: current";
                $current_entry->{genome_id} = $gm_id;
                last;
            }elsif ($gm_id =~/uc $current_entry->{id}/){
                $status = "Existing entry: updated ";
                $current_entry->{genome_id} = $gm_id;
                last;
            }
        }
    }
        
    if( $status eq "" )
    {
        $status = "New entry";#or "Existing entry: status unknown";
    }
    
    #print "\nStatus:$status\n";
    return $status;
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
	solr_core has a value which is a string
	doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata
docdata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.IndexInSolrParams
$output is an int
IndexInSolrParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
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
        solr_core => "",
        doc_data => []
    });  
 
    my $docData = $params->{doc_data};
    my $solrCore = $params->{solr_core};

    if( @{$docData} >= 1) {
       if( $self->_addXML2Solr($solrCore, $docData) == 1 ) {
           #if( $self->_addJSON2Solr($solrCore, $docData) == 1 ) {
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




=head2 new_or_updated

  $return = $obj->new_or_updated($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.NewOrUpdatedParams
$return is a reference to a list where each element is a KBSolrUtil.searchdata
NewOrUpdatedParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_docs has a value which is a reference to a list where each element is a KBSolrUtil.searchdata
	search_type has a value which is a string
searchdata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.NewOrUpdatedParams
$return is a reference to a list where each element is a KBSolrUtil.searchdata
NewOrUpdatedParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_docs has a value which is a reference to a list where each element is a KBSolrUtil.searchdata
	search_type has a value which is a string
searchdata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

The new_or_updated function that returns a list of docs

=back

=cut

sub new_or_updated
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to new_or_updated:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'new_or_updated');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($return);
    #BEGIN new_or_updated
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "GenomeFeatures_ci",
        search_docs => undef,
        search_type => "KBaseGenomes.Genome-12.3"
    });
    
    $return = [];
    my $solr_core = $params->{solr_core};
    my $tx_solr_core = ($solr_core =~ /prod$/i) ? "taxonomy_prod" : "taxonomy_ci";

    if (defined($params->{search_docs})) {
        my $src_docs = $params->{search_docs};
        
        foreach my $current_doc (@{$src_docs}){
            my $en_status = $self->_checkEntryStatus( $current_doc, $solr_core, $params->{search_type} );
	    my $tx_status = $self->_checkTaxonStatus($current_doc, $tx_solr_core);
            if( $en_status=~/(new|updated)/i && $tx_status=~/in KBase/i ) {
                $current_doc->{gn_status} = $en_status;
                push @{$return},$current_doc;
            }
        }
    } 

    #END new_or_updated
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to new_or_updated:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'new_or_updated');
    }
    return($return);
}




=head2 exists_in_solr

  $output = $obj->exists_in_solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.ExistsInputParams
$output is an int
ExistsInputParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_query has a value which is a KBSolrUtil.searchdata
searchdata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.ExistsInputParams
$output is an int
ExistsInputParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_query has a value which is a KBSolrUtil.searchdata
searchdata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

The exists_in_solr function that returns 0 or 1

=back

=cut

sub exists_in_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to exists_in_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'exists_in_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN exists_in_solr
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        search_core => "Genomes_ci",
        search_query => {q=>"*"},
    });  
    my $solrCore = $params->{search_core}; 
    my $searchQuery = $params->{search_query};
    
    $output = $self->_exists($solrCore, $searchQuery);

    if($output == 1) {
        #print "Found record in solr database";
    } else {
        #print "No record found in solr database";
    }
            
    #END exists_in_solr
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to exists_in_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'exists_in_solr');
    }
    return($output);
}




=head2 get_total_count

  $output = $obj->get_total_count($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.TotalCountParams
$output is an int
TotalCountParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_query has a value which is a KBSolrUtil.searchdata
searchdata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.TotalCountParams
$output is an int
TotalCountParams is a reference to a hash where the following keys are defined:
	search_core has a value which is a string
	search_query has a value which is a KBSolrUtil.searchdata
searchdata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

The get_total_count function that returns a positive integer (including 0) or -1

=back

=cut

sub get_total_count
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_total_count:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_total_count');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN get_total_count
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        search_core => "Genomes_ci",
        search_query => {q=>"*"}
    });  
    my $solrCore = $params->{search_core};
    my $query = $params->{search_query};
    
    my $solrout;
    my $output;
    eval {
        $solrout = $self->search_solr({
                search_core => $solrCore, 
                search_param => {fl=>"*",wt=>"json",rows=>0}, 
                search_query => $query, 
                result_format => "json", 
                group_option => "",
                skip_escape => {}
            });
    };
    if ($@) {
        #print "ERROR:".$@;
        $output = -1;
    } else {
        $output = $solrout->{response}->{response}->{numFound};
    }
    
    print "The total count of documents found= ". $output;
    #END get_total_count
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_total_count:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_total_count');
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

The search_solr function that returns a solrresponse consisting of a string in the format of the Perl structure (hash)

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
        search_core => "Genomes_ci",
        search_param => {},
        search_query => {q=>"*"},
        result_format => "xml",
        group_option => "",
        skip_escape => {}
    });  
    my $solrCore = $params->{search_core}; 
    my $searchParam = $params->{search_param};
    my $searchQuery = $params->{search_query};
    my $resultFormat = $params->{result_format};
    my $groupOption = $params->{group_option};
    my $skipEscape = $params->{skip_escape};
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }

    my $queryString = $self->_buildQueryString($searchQuery, $searchParam, $groupOption, $resultFormat, $skipEscape);
    #print "Search query string:\n$queryString\n";
    my $solrQuery = $self->{_SOLR_URL}."/".$solrCore."/select?".$queryString;
    #print "Search query string:\n$solrQuery\n";
    
    my $solr_response = $self->_sendRequest("$solrQuery", "GET");
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




=head2 search_kbase_solr

  $output = $obj->search_kbase_solr($params)

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

The search_kbase_solr function that returns a solrresponse consisting of a string in the format of the specified 'result_format' in SearchSolrParams
The interface is exactly the same as that of search_solr, except the output content will be different. And this function is exposed to the narrative for users to search KBase Solr databases, while search_solr will be mainly serving RDM.

=back

=cut

sub search_kbase_solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to search_kbase_solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_kbase_solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN search_kbase_solr
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        search_core => "Genomes_ci",
        search_param => {},
        search_query => {q=>"*"},
        result_format => "xml",
        group_option => "",
        skip_escape => {}
    });  
    my $solrCore = $params->{search_core}; 
    my $searchParam = $params->{search_param};
    my $searchQuery = $params->{search_query};
    my $resultFormat = $params->{result_format};
    my $groupOption = $params->{group_option};
    my $skipEscape = $params->{skip_escape};
    
    if (!$self->_ping()) {
        die "\nError--Solr server not responding:\n" . $self->_error->{response};
    }

    my $queryString = $self->_buildQueryString($searchQuery, $searchParam, $groupOption, $resultFormat, $skipEscape);
    #print "Search query string:\n$queryString\n";
    my $solrQuery = $self->{_SOLR_URL}."/".$solrCore."/select?".$queryString;
    
    my $solr_response = $self->_sendRequest("$solrQuery", "GET");
    $output = {solr_search_result=>$solr_response->{response}};

    #print "Search results;\n" . $output->{'solr_search_result'};
    #END search_kbase_solr
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to search_kbase_solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_kbase_solr');
    }
    return($output);
}




=head2 add_json_2solr

  $output = $obj->add_json_2solr($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a KBSolrUtil.IndexJsonParams
$output is an int
IndexJsonParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	json_data has a value which is a string

</pre>

=end html

=begin text

$params is a KBSolrUtil.IndexJsonParams
$output is an int
IndexJsonParams is a reference to a hash where the following keys are defined:
	solr_core has a value which is a string
	json_data has a value which is a string


=end text



=item Description

The add_json_2solr function that returns 1 if succeeded otherwise 0

=back

=cut

sub add_json_2solr
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_json_2solr:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_json_2solr');
    }

    my $ctx = $KBSolrUtil::KBSolrUtilServer::CallContext;
    my($output);
    #BEGIN add_json_2solr
    $params = $self->util_initialize_call($params,$ctx);
    $params = $self->util_args($params,[],{
        solr_core => "Genomes_ci",
        json_data => "",
        is_json_string => undef
    });  
    my $solrCore = $params->{solr_core};
    my $docs = $params->{json_data}; 
    my $isJson = undef;
    if (!defined($params->{is_json_string})) {
        $isJson = 0;
    }
    else {
        $isJson = $params->{is_json_string};
    }
    if( $isJson != 1 ) {
        $isJson = 0;
    }

    my $output;
    $output = $self->_addJSON2Solr($solrCore, $docs, $isJson);    


    #END add_json_2solr
    my @_bad_returns;
    (!ref($output)) or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to add_json_2solr:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_json_2solr');
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

string solr_core - the name of the solr core to index to
list<docdata> doc_data - the doc to be indexed, a list of hashes


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
solr_core has a value which is a string
doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
solr_core has a value which is a string
doc_data has a value which is a reference to a list where each element is a KBSolrUtil.docdata


=end text

=back



=head2 NewOrUpdatedParams

=over 4



=item Description

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


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_docs has a value which is a reference to a list where each element is a KBSolrUtil.searchdata
search_type has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_docs has a value which is a reference to a list where each element is a KBSolrUtil.searchdata
search_type has a value which is a string


=end text

=back



=head2 ExistsInputParams

=over 4



=item Description

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


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_query has a value which is a KBSolrUtil.searchdata

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_query has a value which is a KBSolrUtil.searchdata


=end text

=back



=head2 TotalCountParams

=over 4



=item Description

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


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_query has a value which is a KBSolrUtil.searchdata

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
search_core has a value which is a string
search_query has a value which is a KBSolrUtil.searchdata


=end text

=back



=head2 SearchSolrParams

=over 4



=item Description

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



=head2 IndexJsonParams

=over 4



=item Description

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


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
solr_core has a value which is a string
json_data has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
solr_core has a value which is a string
json_data has a value which is a string


=end text

=back



=cut

1;
