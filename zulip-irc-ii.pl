#!/usr/bin/env perl
use strict;
use warnings;
use 5.10.1;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use JSON;
use File::Tail;
# checkout App::Daemonize instead
use Net::Server::Daemonize 'daemonize';
use WebService::Zulip;
use Data::Printer;

# a name for ourselves
$0 = 'zulip-irc-ii parent';

# take options
my $options = get_options();
my $creds   = get_creds($options->{file});
my $logger  = get_logger($options);
my $zulip   = WebService::Zulip->new(%{$creds});

# daemonize - make these options
if ($options->{daemonize} == 1) {
    daemonize($options->{user}, $options->{group}, $options->{pidfile});
}

# fork off two workers -- one for processing input, one for output
$logger->("Starting...");
my $reader = forker($zulip, $options, \&reader);
my $writer = forker($zulip, $options, \&writer);

1 while (wait() != -1);

sub forker {
    my ($zulip, $options, $subref) = @_;
    my $pid = fork();
    # in the parent
    return $pid if ($pid);
    # couldn't fork
    die q{Couldn't fork reader} unless defined($pid);
    # in the child
    $subref->($zulip, $options);
}

sub reader {
    my ($zulip, $options) = @_;

    # get a pretty name
    $0 = 'zulip-irc-ii reader';

    my $queue = $zulip->get_message_queue();
    open my $fh, '>', $options->{in_fifo} or die "$!";
    # suffering from buffering tricks
    select((select($fh), $|=1)[0]);

    $logger->("Reader initialized, filehandle hot on $options->{in_fifo}");

    # eat messages forever
    while (1) {
        my $result = $zulip->get_new_events(
            queue_id      => $queue->{queue_id},
            last_event_id => $queue->{last_event_id},
            dont_block => 'false'
        );
        for my $event (@{$result->{events}}) {
            my $message = $event->{message};
            next unless $event->{type} eq 'message';
            if ($message->{type} eq 'private') {
                print $fh "$message->{sender_short_name} PMed you: $message->{content}\n";
                next;
            }
            print $fh "$message->{sender_short_name} in $message->{display_recipient}: $message->{content}\n";
        }
        $queue->{last_event_id} = $zulip->get_last_event_id($result);
    }
}

sub writer {
    my ($zulip, $options) = @_;

    # get a pretty name
    $0 = 'zulip-irc-ii writer';

    my $tailer = File::Tail->new(
        name        => $options->{out_file},
        maxinterval => 2,
    );

    my $translations = get_translations($options->{translations});
    $logger->("Writer initialized, translations loaded and tailing $options->{out_file}");

    # get a subscription list first/manage that?
    while (defined(my $line = $tailer->read())) {
        # look for stream: message
        # 2014-10-08 11:27 <stan_theman> k
        # http://tools.ietf.org/html/rfc2812#section-2.3.1
        if ($line =~ /
            ^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2} #timestamp
            \s
            <(?<nick>[^<]+)>         # nickname, sorry rfc
            \s
            (?<to>[^:\/]+)           # user or stream
            (?:\/(?<subject>[^:]+))? # optional literal slash and captured topic
            :\s*                     # get rid of any trailing spaces
            (?<content>.*)$          # content
        /x) {
            # ignore other people if they happen to be in the channel
            # at least ignore the bot itself
            next unless ($+{nick} eq $options->{nick});

            my $type = (index($+{to}, '@') == -1) ? 'stream' : 'private';
            if (scalar(keys(%$translations))) {
                for my $word (split(/ /, $+{content})) {
                    $+{content} =~ s/\Q$word\E/$translations->{$word}/g if (exists($translations->{$word}));
                }
            }

            my $result = $zulip->send_message(
                content => $+{content},
                subject => $+{subject},
                to      => $+{to},
                type    => $type,
            );
        }
    }
}

sub get_options {
    my %opts = (
        'file'      => '.zulip-rc',
        'directory' => './ii',
        'nick'      => '',
        'user'      => 'nobody',
        'group'     => 'nogroup',
        'pidfile'   => '/tmp/zulip-irc-ii.pid',
        'translations' => undef,
        'daemonize' => 1,
        'logfile'   => undef
    );

    # path to pid file option?
    GetOptions(\%opts,
        'directory|d:s',
        'file|f:s',
        'nick|n:s',
        'user|u:s',
        'group|g:s',
        'pidfile|p:s',
        'translations|t:s',
        'daemonize!',
        'logfile|l:s',
    ) or pod2usage(2);

    die qq{Zulip config file ($opts{file}) doesn't exist} unless -e -r $opts{file};
    unless (defined ($opts{directory}) && -d -r -w $opts{directory}) {
        die qq{Directory for ii ($opts{directory}) doesn't exist};
    }
    die qq{Must provide your IRC name} unless $opts{nick} ne '';

    # make life easier by specifically defining the in and out files
    $opts{in_fifo}  = $opts{directory} . '/in';
    $opts{out_file} = $opts{directory} . '/out';

    unless (-p -w $opts{in_fifo} && -f -r $opts{out_file}) {
        die qq{Directory for ii ($opts{directory}) doesn't look like an ii dir};
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

sub get_translations {
    my $filename = shift;
    print "THE FILENAME IS $filename\n";
    return unless $filename;
    my $translations;
    # kind of lame that the translations file is json
    open my $fh, '<', $filename or die "$!";
    {
        local $/ = undef;
        # stop being lazy about json decoding ;_;
        $translations = decode_json(<$fh>);
    }
    return $translations;
}

sub get_logger {
    my $options = shift;
    if ($options->{logfile}) {
        return sub {
            my $msg = shift;
            open my $fh, '>>', $options->{logfile};
            print $fh $msg;
        };
    } else {
        return sub {
            my $msg = shift;
            print $msg . "\n";
        };
    }
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
