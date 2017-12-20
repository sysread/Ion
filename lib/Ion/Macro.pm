package Ion::Macro;

use common::sense;
use Keyword::Declare;

sub import {
  keyword Encode (Block $block) {{{ $ION >>= sub<{$block}> }}}
  keyword Decode (Block $block) {{{ $ION <<= sub<{$block}> }}}

  keyword Listen (ScalarVar $var, String? $host = 'undef', Int? $port = 'undef', Block $block)
  {{{
    use Coro;
    require Ion::Server;
    my $ION;

    my $thread = async{
      my $ION = my <{$var}> = Ion::Server->new(host => <{$host}>, port => <{$port}>);
      $ION->start;
      <{$block}>;
    };

    $thread->join;
  }}}

  keyword Accept (ScalarVar $var, Block $block)
  {{{
    do{
      while (defined(my <{$var}> = <$ION>)) {
        async_pool{
          my $ION = my <{$var}> = shift;
          <{$block}>
        } <{$var}>;
      }
    }
  }}}

  keyword Respond (ScalarVar $var, Block $block)
  {{{
    my $inbox = Coro::Channel->new;

    async_pool{
      my ($conn, $inbox) = @_;
      while (defined(my $line = <$conn>)) {
        $inbox->put($line);
      }
    } $ION, $inbox;

    async_pool{
      my ($conn, $inbox) = @_;
      while (defined(my <{$var}> = $inbox->get)) {
        my $reply = do<{$block}>;
        last unless defined $reply;
        next unless $reply;
        $conn->($reply);
      }
    } $ION, $inbox;
  }}}

  keyword Remote (ScalarVar $ident, String $host, Int $port, Block $block)
  {{{
    use Coro;
    require Ion::Conn;
    my $ION;

    async{
      my <{$ident}> = Ion::Conn->new(host => <{$host}>, port => <{$port}>);
      my $ION = <{$ident}>;
      <{$block}>
    }->join;
  }}}

  keyword Request (ScalarVar $var, Expr $msg, Block $block)
  {{{
    $ION->(<{$msg}>);
    async_pool{ my <{$var}> = <$_[0]>; <{$block}> } $ION;
  }}}
}

1;

=head1 SYNOPSIS

  use JSON::XS     qw(encode_josn   decode_json);
  use MIME::Base64 qw(encode_base64 decode_base64);
  use Ion::Macro;

  Listen $server 4242 {
    # Encode messages out
    Encode { encode_json($_[0]) }
    Encode { encode_base64($_[0], '') }

    # Decode messages in
    Decode { decode_base64($_[0]) }
    Decode { decode_json($_[0]) }

    my $host = $server->host;
    my $port = $server->port;
    say "Service started on $host:$port";

    Accept $conn {
      Respond $msg {
        uc $msg;
      };
    }
  }

=head1 DESCRIPTION

An alternative to L<Ion> for describing a line-oriented TCP service using the
pluggable keyword feature introduced in Perl 5.12. L<Keyword::Declare> is
required to use this module.

Note that all of the same caveats apply as described in the documentation for
L<Ion>.

=head1 KEYWORDS

=head2 Listen $var $host? $port? $block

Starts the listening service. Optional C<$host> and C<$port> will be assigned
by the OS unless specified. Within the code C<$block>, C<$var> is assigned the
running L<Ion::Server>. The service runs within a coro thread.

=head2 Encode $block

=head2 Decode $block

These two keywords assign an encoder or decoder method. They must be called
within the L</Listen> block. It is an error to call thse within an L</Accept>
or L</Respond> block.

=head2 Accept $var $block

Assigns a code C<$block> to handle new connections. Within the C<$block>,
C<$var> is assigned the newly accepted L<Ion::Conn>. The accept block runs
within a coro thread.

=head2 Respond $var $block

Assigns a code C<$block> to respond to new messages. Within the C<$block>,
C<$var> is assigned the decoded message. If the return value of the block is
undefined, the connection is closed. If the return value is defined by falsey,
the return value is ignored and the thread begins waiting for the next message.
Otherwise, the return value is encoded and sent to the client in response.

=cut
