use strict;
use Data::Dumper;
use Test::More;
use Config::Simple;
use Time::HiRes qw(time);
use Bio::KBase::AuthToken;
use Workspace::WorkspaceClient;
use KBSolrUtil::KBSolrUtilImpl;

local $| = 1;
my $token = $ENV{'KB_AUTH_TOKEN'};
my $config_file = $ENV{'KB_DEPLOYMENT_CONFIG'};
my $config = new Config::Simple($config_file)->get_block('KBSolrUtil');
my $ws_url = $config->{"workspace-url"};
my $ws_name = undef;
my $ws_client = new Workspace::WorkspaceClient($ws_url,token => $token);
my $auth_token = Bio::KBase::AuthToken->new(token => $token, ignore_authrc => 1, auth_svc=>$config->{'auth-service-url'});
print("ws url:".$config->{'workspace-url'} . "\n");
print("auth url:".$config->{'auth-service-url'} . "\n");

my $ctx = LocalCallContext->new($token, $auth_token->user_id);
$KBSolrUtil::KBSolrUtilServer::CallContext = $ctx;
my $impl = new KBSolrUtil::KBSolrUtilImpl();

sub get_ws_name {
    if (!defined($ws_name)) {
        my $suffix = int(time * 1000);
        $ws_name = 'test_KBSolrUtil_' . $suffix;
        $ws_client->create_workspace({workspace => $ws_name});
    }
    return $ws_name;
}

=begin
    my $exists_ret;
    eval {
        $exists_ret = $impl->exists_in_solr({
          solr_core => "GenomeFeatures_prod",
          search_query => {"object_type"=>"KBaseGenomes.Genome-8.2",
                           "genome_id"=>"GCF_000518705.1"
                     }
        });
    };
    ok(!$@, "exists_in_solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print $exists_ret ."\n";
    }
    ok(defined($exists_ret),"_exists_in_solr command returned result.");
=cut   

eval {
#=begin
    my $solrgnm;
    my $ret_gnms;
    eval {
        $solrgnm = $impl->search_solr({
          solr_core => "GenomeFeatures_prod",
          search_param => {
                rows => 100000,
                wt => 'json'
          },
          search_query => {"object_type"=>'KBaseGenomes.Genome-8.2'},
          result_format => "json",
          group_option => "",
          skip_escape => {}
        });
    };
    ok(!$@, "search_solr command successful");
    if ($@) {
         print "ERROR:".$@;
    } else {
         #print "Search results:" . Dumper($solrgnm->{response}->{response}) . "\n";
         $ret_gnms = $solrgnm->{response}->{response}->{docs};
         my $num = $solrgnm->{response}->{response}->{numFound};
         foreach my $gnm (@{$ret_gnms}) {#remove the _version_ field added by SOLR
            delete $gnm->{_version_};
         }
         #then insert the $gnm
         eval {
                $impl->_addJSON2Solr("Genomes_prod", $ret_gnms);
         };
        ok(!$@, "addJSON2Solr command successful");
        if ($@) {
                print "ERROR:".$@;
        } else {
                print "Done!";
        }
    }
    ok(defined($solrgnm),"_addJSON2Solr completed.");
#=cut   

=begin
    my $solrcount;
    eval {
        $solrcount = $impl->get_total_count({
          search_core => "Reactions",
          search_query => {'abbreviation'=>'RXNQT-4349.c'} #{q=>"*"}
        });  
    };
    ok(!$@, "get_total_count command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print $solrcount ."\n";
    }
    ok(defined($solrcount),"get_total_count command returned result.");
=cut   

=begin
    my $solrret;
    eval {
        $solrret = $impl->search_solr({
          solr_core => "Reactions",
          search_param => {},
          search_query => {'abbreviation'=>'RXNQT-4349.c'}, #{q=>"*"},
          result_format => "json",
          group_option => "",
          skip_escape => {}
        });  
    };
    ok(!$@, "search_solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($solrret) ."\n";
    }
    ok(defined($solrret),"_search_solr command returned result.");
=cut   

=begin 
    eval {
        $solrret = $impl->search_solr({
          solr_core => "taxonomy_ci",
          search_param => {
                fl => 'taxonomy_id,domain,aliases',
                wt => 'json',
                rows => 20,
                sort => 'taxonomy_id asc',
                hl => 'false',
                start => 0,
                count => 100 
          },
          search_query => {
                parent_taxon_ref => '1779/116411/1',
                rank => 'species',
                scientific_lineage => 'cellular organisms; Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Bradyrhizobium',
                scientific_name => 'Bradyrhizobium sp. *',
                domain => 'Bacteria'
          },
          result_format => "json",
          group_option => "",
          skip_escape => {}
        });  
    };
    ok(!$@, "search_solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($solrret) ."\n";
    }
    ok(defined($solrret),"_search_solr command returned result.");
=cut

    my $inputObjs = [ 
      {
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
        "inherited_GC_flag"=>1,
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
      }
    ];
    my $jsonret;
=begin
    eval {
        $jsonret = $impl->_toJSON($inputObjs);
    };
    ok(!$@, "_toJSON command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($jsonret) ."\n";
    }
    ok(defined($jsonret)," JSON converson succeeded.");
=cut
    #This JSON string needs to be trimmed more because the newlines seem to throw off the solr update handler.
    my $json_out = '[
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
        "inherited_GC_flag":1,
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
      }
    ]';
=begin 
    eval {
        $jsonret = $impl->_addJSON2Solr("BiochemData", $inputObjs);
    };
    ok(!$@, "_addJSON2Solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($jsonret) ."\n";
    }
    ok(defined($jsonret)," JSON indexing succeeded.");
=cut
=begin 
    eval {
        $jsonret = $impl->_addJSON2Solr("BiochemData", $json_out, 1);
    };
    ok(!$@, "_addJSON2Solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($jsonret) ."\n";
    }
    ok(defined($jsonret)," JSON indexing succeeded.");
=cut

=begin 
    eval {
        $jsonret = $impl->add_json_2solr({solr_core=>"BiochemData", json_data=>$json_out});
    };
    ok(!$@, "add_json_2solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($jsonret) ."\n";
    }
    ok(defined($jsonret)," JSON indexing succeeded.");
=cut

=begin
    my $xmlret; 
    eval {
        $xmlret = $impl->_addXML2Solr("BiochemData", $inputObjs);
    };
    ok(!$@, "_addXML2Solr command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($xmlret) ."\n";
    }
    ok(defined($xmlret)," XML indexing succeeded.");
=cut
    done_testing(6);
};

my $err = undef;
if ($@) {
    $err = $@;
}
eval {
    if (defined($ws_name)) {
        $ws_client->delete_workspace({workspace => $ws_name});
        print("Test workspace was deleted\n");
    }
};
if (defined($err)) {
    if(ref($err) eq "Bio::KBase::Exceptions::KBaseException") {
        die("Error while running tests: " . $err->trace->as_string);
    } else {
        die $err;
    }
}

{
    package LocalCallContext;
    use strict;
    sub new {
        my($class,$token,$user) = @_;
        my $self = {
            token => $token,
            user_id => $user
        };
        return bless $self, $class;
    }
    sub user_id {
        my($self) = @_;
        return $self->{user_id};
    }
    sub token {
        my($self) = @_;
        return $self->{token};
    }
    sub provenance {
        my($self) = @_;
        return [{'service' => 'KBSolrUtil', 'method' => 'please_never_use_it_in_production', 'method_params' => []}];
    }
    sub authenticated {
        return 1;
    }
    sub log_debug {
        my($self,$msg) = @_;
        print STDERR $msg."\n";
    }
    sub method {
         my($self) = @_;
         return "TEST_METHOD";
     }    
    sub log_info {
        my($self,$msg) = @_;
        print STDERR $msg."\n";
    }
}
