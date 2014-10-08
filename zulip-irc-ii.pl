#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use JSON;
use Net::Server::Daemonize 'daemonize';
use WebService::Zulip;
use Data::Printer;

# take options
my $options = get_options();
my $creds   = get_creds($options->{file});
my $zulip   = WebService::Zulip->new(%{$creds});

# daemonize
daemonize(
    'nobody',                 # User
    'nogroup',                 # Group
    '/run/zulip-irc-ii.pid'   # Path to PID file - optional
);

# fork off two workers -- one for processing input, one for output

sub get_options {
    my %opts = (
        'file' => '.zulip-rc',
        'directory' => './ii',
    );

    # path to pid file option?
    GetOptions(\%opts,
        'directory|d=s',
        'file|f:s',
    ) or pod2usage(2);

    die qq{Zulip config file ($opts{file}) doesn't exist} unless -e $opts{file};
    unless (defined ($opts{directory}) && -d $opts{directory}) {
        die qq{Directory for ii ($opts{directory}) doesn't exist};
    }

    return \%opts;
}

sub get_creds {
    my $filename = shift;
    my $creds;
    # kind of lame that the cred file is json
    open my $fh, '<', $filename or die "$!";
    {
        local $/ = undef;
        # stop being lazy about json decoding ;_;
        $creds = decode_json(<$fh>);
    }
    die q{Creds must contain api_key}  unless $creds->{api_key};
    die q{Creds must contain api_user} unless $creds->{api_user};
    return $creds;
}

__END__

=head1 zulip-irc-ii

zulip-irc-ii - Transport messages between Zulip and IRC using ii

=head1 USAGE

    ./zulip-irc-ii -d /path/to/ii/channel/dir -f /path/to/zulip/creds

=head1 DESCRIPTION

zulip-irc-ii allows you to interact with Zulip over IRC. Specifically,
zulip-irc-ii works in concert with ii, a FIFO-based IRC client. Install ii,
and have it join the IRC network and channel of your choice. Then, run
zulip-irc-ii (ZI3). ZI3 puts new messages into the IRC channel, and monitors your
responses to send messages back to Zulip.

=head1 DEPENDENCIES

zulip-irc-ii depends on ii, a FIFO-based IRC client.

zulip-irc-ii is written in perl, and depends on the not-yet-uploaded
WebService::Zulip module.

=head1 EXAMPLES

Install ii, then join it to an IRC network of your choice. For example,

    ii -s irc.freenode.org -p 6667 -n zulipbot -f zulipbot -i /tmp/ii

You'll want to read the ii man page for descriptions of the commands. Then, you
can join your bot to a channel with a command like

    echo '/j ##zulip-for-me' > /tmp/ii/irc.freenode.org/in

Once it's joined, run zulip-irc-ii:

    ./zulip-irc-ii -d /tmp/ii/irc.freenode.org/\#\#zulip-for-me -f .zulip-rc

You should see new messages in the channel. You can respond to messages by
<doing some thing I haven't figured out yet, etc etc regex>

=head1 BUGS

The code doesn't exist yet

=head1 AUTHOR

Stan Schwertly (http://www.schwertly.com)
