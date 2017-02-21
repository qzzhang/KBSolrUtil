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
    
    #like($@, qr/Parameter min_length is not set in input arguments/);
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
