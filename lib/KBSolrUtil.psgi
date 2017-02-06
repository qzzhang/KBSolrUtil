use KBSolrUtil::KBSolrUtilImpl;

use KBSolrUtil::KBSolrUtilServer;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = KBSolrUtil::KBSolrUtilImpl->new;
    push(@dispatch, 'KBSolrUtil' => $obj);
}


my $server = KBSolrUtil::KBSolrUtilServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
