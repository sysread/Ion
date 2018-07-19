package Ion::Test;
# ABSTRACT: Utilities used by Ion unit tests

use common::sense;

BEGIN{
  require Test2::V0;

  if ($^O =~ /mswin32/i) {
    my $ok; local $SIG{CHLD} = sub { $ok = 1 }; kill 'CHLD', 0;
    Test2::V0::skip_all('broken perl detected') unless $ok;
  }

  Test2::V0::skip_all('broken perl detected') unless exists $SIG{USR1};

  require AnyEvent::Impl::Perl;
}

1;
