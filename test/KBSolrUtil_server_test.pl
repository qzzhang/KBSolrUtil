use strict;
use Data::Dumper;
use Test::More;
use Config::Simple;
use Time::HiRes qw(time);
use Bio::KBase::AuthToken;
use Workspace::WorkspaceClient;
#use Bio::KBase::workspace::Client;
use KBSolrUtil::KBSolrUtilImpl;

local $| = 1;
my $token = $ENV{'KB_AUTH_TOKEN'};
my $config_file = $ENV{'KB_DEPLOYMENT_CONFIG'};
my $config = new Config::Simple($config_file)->get_block('KBSolrUtil');
my $ws_url = $config->{"workspace-url"};
my $ws_name = undef;
my $ws_client = new Workspace::WorkspaceClient($ws_url,token => $token);
my $auth_token = Bio::KBase::AuthToken->new(token => $token, ignore_authrc => 1);
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

eval {
    my $solrret;
=begin
    eval {
        $solrret = $impl->search_solr({
          solr_core => "JEtest",
          search_param => {},
          search_query => {q=>"*"},
          result_format => "xml",
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

    my $params = [ 
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
    eval {
        $jsonret = $impl->_toJSON($params);
    };
    ok(!$@, "_toJSON command successful");
    if ($@) { 
         print "ERROR:".$@;
    } else {
         print Dumper($jsonret) ."\n";
    }
    ok(defined($jsonret)," JSON converson succeeded.");

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