package Ion::Macro;
# ABSTRACT: An alternate syntax using pluggable keywords

use common::sense;
use Keyword::Declare;

sub import {
  keyword Encode (Block $block) {qq/\$_ >>= sub$block/}
  keyword Decode (Block $block) {qq/\$_ <<= sub$block/}

  keyword Listen (String? $host = 'undef', Int? $port = 'undef', Block $block)
  {{{
    do{
      use Coro;
      require Ion::Server;

      my $thread = async{
        local $_ = Ion::Server->new(host => <{$host}>, port => <{$port}>);
        $_->start;
        do<{$block}>;
      };

      $thread->join;
    };
  }}}

  keyword Accept (Block $block)
  {{{
    do{
      while (defined(my $conn = $_->accept)) {
        async_pool{
          local $_ = shift;
          do<{$block}>
        } $conn;
      }
    };
  }}}

  keyword Respond (Block $block)
  {{{
    do{
      # Watch for incoming messages and post them to an inbox
      my $inbox = Coro::Channel->new;

      async_pool{
        my ($conn, $inbox) = @_;
        while (defined(my $line = $conn->readline)) {
          $inbox->put($line);
        }
      } $_, $inbox;

      # Respond to incoming messages
      async_pool{
        my ($conn, $inbox) = @_;
        while (defined(local $_ = $inbox->get)) {
          my $reply = do<{$block}>;
          last unless defined $reply; # undef:  disconnect client
          next unless $reply;         # falsey: ignore
          $conn->($reply);            # truthy: send reply
        }
      } $_, $inbox;
    };
  }}}

  keyword Remote (String $host, Int $port, Block $block)
  {{{
    do{
      use Coro;
      require Ion::Conn;

      async{
        local $_ = Ion::Conn->new(host => <{$host}>, port => <{$port}>);
        do<{$block}>
      }->join;
    };
  }}}

  keyword Recv (Block $block)
  {{{
    my $msg = <$_>;
    local $_ = $msg;
    do<{$block}>;
  }}}

  keyword Send (Expr $msg)
  {{{
    $_->(<{$msg}>)
  }}}

  keyword Send (Expr $msg, Block $block)
  {{{
    Send <{$msg}>;
    Recv <{$block}>;
  }}}
}

1;

=head1 SYNOPSIS

  use MIME::Base64 qw(encode_base64 decode_base64);
  use Ion::Macro;

  # Server
  Listen 4242 {
    # Encode messages out
    Encode { encode_base64($_[0], '') }

    # Decode messages in
    Decode { decode_base64($_[0]) }

    my $host = $_->host;
    my $port = $_->port;
    say "Service started on $host:$port";

    Accept {
      Respond {
        uc $_;
      };
    }
  }

  # Client
  Remote 'some.host.name' 4242 {
    # Encode messages out
    Encode { encode_base64($_[0], '') }

    # Decode messages in
    Decode { decode_base64($_[0]) }

    say 'Connected to remote host';

    Send 'how now brown bureaucrat' {
      my $response = $_;
    };
  };

=head1 DESCRIPTION

An alternative to L<Ion> for describing a line-oriented TCP service using the
pluggable keyword feature introduced in Perl 5.12. L<Keyword::Declare> is
required to use this module.

Note that all of the same caveats apply as described in the documentation for
L<Ion>.

=head1 KEYWORDS

=head2 Listen $host? $port? $block

Starts the listening service. Optional C<$host> and C<$port> will be assigned
by the OS unless specified. Within the code C<$block>, C<$_> is assigned the
running L<Ion::Server>. The service runs within a coro thread.

=head2 Encode $block

=head2 Decode $block

These two keywords assign an encoder or decoder method. They must be called
within the L</Listen> block. It is an error to call thse within an L</Accept>
or L</Respond> block.

=head2 Accept $block

Assigns a code C<$block> to handle new connections. Within the C<$block>,
C<$_> is assigned the newly accepted L<Ion::Conn>. The accept block runs
within a coro thread.

=head2 Respond $block

Assigns a code C<$block> to respond to new messages. Within the C<$block>,
C<$_> is assigned the decoded message. If the return value of the block is
undefined, the connection is closed. If the return value is defined by falsey,
the return value is ignored and the thread begins waiting for the next message.
Otherwise, the return value is encoded and sent to the client in response.

=head2 Remote $host $port $block

Connects to C<$host>:C<$Port> and executes C<$block>. Within the C<$block>,
C<$_> is assigned to the L<Ion::Conn>.

=head2 Recv $block

Reads a message from the remote host and executes C<$block>. Within C<$block>,
C<$_> is assigned the decoded message received.

=head2 Send $msg

=head2 Send $msg $block

Sends a message to the remote host, optionally executing a block of code when a
response is received. Within C<$block>, C<$_> is assigned the decoded response.

=cut
